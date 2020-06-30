/*
USE [Interject_Demos_Students]
*/
/* Rewrite with "NEW_" schema desgin. */

ALTER PROC [billing].[NEW_LP_Builder_Save]
@UserSuppliedLicPackageID INT
,@ClientName NVARCHAR(500) = ''
,@ClientPartnerName NVARCHAR(500) = ''
,@Location NVARCHAR(200) = ''
,@UserMinimum INT
,@PackageDiscount DECIMAL(5, 4)
,@PartnerSplit DECIMAL(5, 4)
,@LicenseStartDate DATE
,@LicenseExpirationDate DATE
,@Note VARCHAR(MAX) = ''
,@FinalLicensePackageID_Output INT OUTPUT
,@LicensedUsers_Output INT OUTPUT
,@BaseInterjectPrice_Output INT OUTPUT
,@Interject_XMLDataToSave VARCHAR(MAX) = ''
,@Interject_LoginName VARCHAR(200)
,@TestMode bit = 0

AS

--***************************************************************************************************************************************************
-- Definitions:
--***************************************************************************************************************************************************
/* ItemID of the base interject item: */
	DECLARE @BaseInterjectItemID INT = 5

--***************************************************************************************************************************************************
-- Excel XML data parsing:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''
    
	/* Verify that the XML returned is in an acceptable form to be stored in an XML variable: */ 
	IF DATALENGTH(@Interject_XMLDataToSave) > 0 
	BEGIN

		DECLARE @LineItemDataToSaveXML as XML
		/* Conversion of XML text into an XML variable: */  
		BEGIN TRY
			SET @LineItemDataToSaveXML = CAST(@Interject_XMLDataToSave AS XML)
		END TRY
		BEGIN CATCH
			SET @ErrorMessageToUser = 'Error in Parsing XML from Interject.  Error: ' + ERROR_MESSAGE()
			GOTO FinalResponseToUser
		END CATCH

		/* Create a table variable to store the data that will be parsed out of the XML: */
		DECLARE @LineItemDataToSave TABLE
		(
			[_ExcelRow] INT 
			,[_MessageToUser] VARCHAR(500) DEFAULT('')
			,[ItemID] INT
			,[ItemName] NVARCHAR(500)
			,[Price] MONEY
			,[Quantity] INT
			,[ItemDiscount] DECIMAL(5,4)
			,[LicenseFactor] DECIMAL(5,4)
			,[NextChangeID] INT
		)
        
		/* Insert the XML into the table variable: */
		BEGIN TRY
			INSERT into @LineItemDataToSave(
				[_ExcelRow]
				,[ItemName]
				,[Price]
				,[Quantity]
				,[ItemDiscount]
				,[LicenseFactor]
			)
			SELECT
            
				T.c.value('Row[1]', 'INT') as [_ExcelRow] -- Excel row number(?)
				,T.c.value('ItemName[1]', 'NVARCHAR(500)') as [ItemName]
				,T.c.value('ItemPrice[1]', 'MONEY')	 as [Price]
				,T.c.value('Quantity[1]', 'INT') as [Quantity]
				,T.c.value('ItemDiscount[1]', 'DECIMAL(5,4)') as [ItemDiscount]
				,T.c.value('LicenseFactor[1]', 'DECIMAL(5,4)') as [LicenseFactor]
			FROM @LineItemDataToSaveXML.nodes('/Root/r') T(c)
		END TRY
		BEGIN CATCH
			SET @ErrorMessageToUser = ERROR_MESSAGE()
			GOTO FinalResponseToUser
		END CATCH
	END

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- TestMode output after XML parsing:
-----------------------------------------------------------------------------------------------------------------------------------------------------
    IF (@TestMode =1)
    BEGIN
        SELECT '@LineItemDataToSave - After XML Processing' as ResultName
        SELECT * FROM @LineItemDataToSave
    END

--***************************************************************************************************************************************************
-- Pre-input validation steps/retrieving additional data needed in order to update/insert/delete:
--***************************************************************************************************************************************************

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get FinalLicPackageID to use throughout. Generate new LicensePackageID if one was not supplied by Excel or if the one supplied was invalid: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @FinalLicensePackageID INT
	IF ((@UserSuppliedLicPackageID = 0)
		OR (NOT EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageHeader] WHERE PackageID = @UserSuppliedLicPackageID)))
	BEGIN
		-- Create new license package ID (creation of NEW license package):
		SET @FinalLicensePackageID = ISNULL( ((SELECT MAX(PackageID)
								FROM [billing].[LicensePackageHeader]) + 1), 1 )
	END
	ELSE BEGIN
		SET @FinalLicensePackageID = @UserSuppliedLicPackageID
	END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get NextPackageChangeID (used throughout): */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @NextPackageChangeID INT
	SET @NextPackageChangeID = ISNULL(((SELECT MAX(ChangeID)
									FROM [billing_history].[LicensePackageChangeLog]
									WHERE PackageID = @FinalLicensePackageID) + 1), 1)

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get ItemIDs for all line items from Excel: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	UPDATE lidts
	SET
		lidts.ItemID = i.ItemID
	FROM @LineItemDataToSave lidts
		INNER JOIN [billing].[Item] i
			ON lidts.ItemName = i.ItemName

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get last DetailItemChangeID for each Item that already exists in lpd: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	UPDATE @LineItemDataToSave
	SET
		NextChangeID = lpd.ChangeID + 1
	FROM @LineItemDataToSave d
		INNER JOIN [billing].[NEW_LicensePackageDetail] lpd
			ON d.ItemID = lpd.ItemID
	WHERE lpd.PackageID = @FinalLicensePackageID

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- TestMode output after pre-input validation steps:
-----------------------------------------------------------------------------------------------------------------------------------------------------
    IF (@TestMode = 1)
    BEGIN
        SELECT '@LineItemDataToSave - After XML Processing' as ResultName
        SELECT * FROM @LineItemDataToSave
    END

--***************************************************************************************************************************************************
-- Input validation from Excel:
--***************************************************************************************************************************************************

----ClientName and ClientPartnerName ----------------------------------------------------------------------------------------------------------------
/* Must be a name that is included in the [app].[Client] table: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (NOT EXISTS(SELECT TOP 1 1 FROM [app].[Client] WHERE ClientName = @ClientName))
	BEGIN
		SET @ErrorMessageToUser =  ' ClientName entered does not match any entries in the database. Please only enter client names from the '
									+ 'dropdown list.'
			GOTO FinalResponseToUser
	END

	IF (NOT EXISTS(SELECT TOP 1 1 FROM [app].[Client] WHERE ClientName = @ClientPartnerName)
		AND @ClientPartnerName <> '')
	BEGIN
		SET @ErrorMessageToUser = @ErrorMessageToUser + ' ClientPartnerName entered does not match any entries in the database. Please only enter client partner names '
									+ 'from the dropdown list.'
			GOTO FinalResponseToUser
	END

----No duplicates -----------------------------------------------------------------------------------------------------------------------------------
/* Validate that the details do not have duplicates on the primary key (ItemID): */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	UPDATE @LineItemDataToSave
	SET [_MessageToUser] = [_MessageToUser] + ', Duplicate key (two or more entries of the same item is forbidden)'
	FROM @LineItemDataToSave d
	INNER JOIN
	    (
	        SELECT [ItemID] 
	        FROM @LineItemDataToSave
	        WHERE [ItemID] IS NOT NULL
	        GROUP BY [ItemID]
	        HAVING COUNT(*) > 1
	    ) as t
	    ON
	        d.[ItemID] = t.[ItemID]

----ItemName ----------------------------------------------------------------------------------------------------------------------------------------
/* Must be a name that is included in the [billing].[Item] table: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	UPDATE @LineItemDataToSave
	SET [_MessageToUser] = [_MessageToUser] + ', Item entered was not found in the database: please check the Inventory report and only enter items '
											+ 'which exist there'
	FROM @LineItemDataToSave d
		LEFT JOIN [billing].[Item] i
				ON d.ItemName = i.ItemName
	WHERE i.ItemName IS NULL

----Price/Quantity ----------------------------------------------------------------------------------------------------------------------------------
/* Price and Quantity being 0/NULL: */
-----------------------------------------------------------------------------------------------------------------------------------------------------

	/* Price validation:*/
    UPDATE @LineItemDataToSave
	SET [_MessageToUser] = [_MessageToUser] + ', Price should not be left blank'
	FROM @LineItemDataToSave
	WHERE Price = 0 OR Price IS NULL

	/* Quantity validation:*/
    UPDATE @LineItemDataToSave
	SET [_MessageToUser] = [_MessageToUser] + ', Quantity should not be left blank'
	FROM @LineItemDataToSave
	WHERE Quantity = 0 OR Quantity IS NULL

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- TestMode output after Excel input validation:
-----------------------------------------------------------------------------------------------------------------------------------------------------
    IF @TestMode = 1 
    BEGIN
        SELECT '@LineItemDataToSave - After Validation' as ResultName
        SELECT * FROM @LineItemDataToSave
    END

--***************************************************************************************************************************************************
-- @ErrorMessageToUser initialization:
--***************************************************************************************************************************************************

    IF (EXISTS(SELECT TOP 1 1 FROM @LineItemDataToSave WHERE [_MessageToUser] <> ''))
    BEGIN
        SET @ErrorMessageToUser = 'There were errors in the details of your input.  Please review the errors noted in each row.'
        GOTO FinalResponseToUser
    END

--***************************************************************************************************************************************************
-- IF input validation passed w/o errors, set the FinalLicID output:
--***************************************************************************************************************************************************
	SET @FinalLicensePackageID_Output = @FinalLicensePackageID

--***************************************************************************************************************************************************
-- Modify [billing].[LicensePackageDetail] main tbl:
--***************************************************************************************************************************************************
	BEGIN TRY

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Create an intermediate changelog table that will be updated directly from the OUTPUT of the MERGE statement. This table will be used to update
	the actual [billing_history].[LicensePackageDetailLog] later on. */
-----------------------------------------------------------------------------------------------------------------------------------------------------
        DECLARE @DetailChangeLogIntermediate as TABLE
		(
             [_ExcelRow] INT	-- will capture the source row that affected the target table.
            ,[UpdateTypeCode] NVARCHAR(10)  -- Will show UPDATE, INSERT, or DELETE.
            ,[TargetTableKey] NVARCHAR(5)
			,[ItemID] INT
			,[ItemPrice] MONEY
			,[ItemQuantity] INT
			,[ItemDiscount] DECIMAL(5,4)
			,[ItemLicenseFactor] DECIMAL(5,4)
			,[Inactive] BIT
			,[ChangeID] INT -- == THIS change
        )
        
        BEGIN TRAN t1

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* MERGE [billing].[LicensePackageDetail]: */
-----------------------------------------------------------------------------------------------------------------------------------------------------

		MERGE [billing].[NEW_LicensePackageDetail] t -- t = the target table or view to update
		USING @LineItemDataToSave s -- s = the source data to be used to update the target table
		ON 
			s.[ItemID] = t.[ItemID]
			AND t.PackageID = @FinalLicensePackageID
                
		WHEN MATCHED -- Handles the update based on INNER JOIN
			AND 
			(
					--t.[ItemID] <> s.[ItemID] -- Doesn't really make sense to ask this?
				t.[Price] <> s.[Price]
				OR t.[Quantity] <> s.[Quantity]
				OR t.[Discount] <> s.[ItemDiscount]
				OR t.[LicenseFactor] <> s.[LicenseFactor]
			)
		THEN
			UPDATE SET
				t.[Price] = s.[Price]
				,t.[Quantity] = s.[Quantity]
				,t.[Discount] = s.[ItemDiscount]
				,t.[LicenseFactor] = s.[LicenseFactor]
				,t.[ChangeID] = s.[NextChangeID]
		WHEN NOT MATCHED BY TARGET
		THEN -- Handles the insert based on LEFT JOIN 
			INSERT (
					[PackageID]
					,[ItemID]
					,[Price]
					,[Quantity]
					,[Discount]
					,[LicenseFactor]
					,[Inactive]
					,[ChangeID]
			)
			VALUES (
				@FinalLicensePackageID
				,s.[ItemID]
				,s.[Price]
				,s.[Quantity]
				,s.[ItemDiscount]
				,s.[LicenseFactor]
				,0 -- active
				,1 -- first change
			)
		WHEN NOT MATCHED BY SOURCE
			AND t.PackageID = @FinalLicensePackageID
		THEN
			UPDATE SET
				t.Inactive = 1 -- "DELETE" = mark as inactive
				,t.ChangeID = s.NextChangeID
		OUTPUT 
			s.[_ExcelRow] -- OK for this to be NULL for DELTED rows?
			,$action as UpdateTypeCode  -- this logs into an a change log table variable
			,INSERTED.[ItemID]  -- could be in either order since id will not change on a line item modification
			,INSERTED.[ItemID]
			,INSERTED.[Price]
			,INSERTED.[Quantity]
			,INSERTED.[Discount]
			,INSERTED.[LicenseFactor]
			,INSERTED.[Inactive]
			,INSERTED.[ChangeID]
		INTO @DetailChangeLogIntermediate
		(
			[_ExcelRow]
			,[UpdateTypeCode]
			,[TargetTableKey] -- do we need both this ADN ItemID???
			,[ItemID]
			,[ItemPrice]
			,[ItemQuantity]
			,[ItemDiscount]
			,[ItemLicenseFactor]
			,[Inactive]
			,[ChangeID]
		);

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageDetailLog]: */
--***************************************************************************************************************************************************
		;WITH get_next_changeID AS
		(
			SELECT
				lpd_l.ItemID
				,MAX(lpd_l.ChangeID) + 1 AS NextChangeIDForExistingItems
			FROM [billing_history].[NEW_LicensePackageDetailChangeLog] lpd_l
				INNER JOIN @DetailChangeLogIntermediate cl
					ON cl.ItemID = lpd_l.ItemID
			WHERE lpd_l.PackageID = @FinalLicensePackageID
			GROUP BY lpd_l.ItemID
		)
		INSERT INTO [billing_history].[NEW_LicensePackageDetailChangeLog]
			(
				[PackageID]
				,[ChangeID]
				,[ItemID]
				,[Price]
				,[Quantity]
				,[Discount]
				,[LicenseFactor]
				,[Inactive]
				,[Operation]
			)
		SELECT
			@FinalLicensePackageID
				-- If no entires were found in lpd_l subquery, this item has never been in this pkg before and gets id=1:
			,ISNULL(get_next_changeID.NextChangeIDForExistingItems, 1)
			,cl.ItemID
			-- For the following cols, if not updated in the above MERGE, take the col for that record from lpd main table
			-- (this essetially records a snapshot of the modification event):
			,ISNULL(cl.ItemPrice, lpd.Price) 
			,ISNULL(cl.ItemQuantity, lpd.Quantity)
			,ISNULL(cl.ItemDiscount, lpd.Discount)
			,ISNULL(cl.ItemLicenseFactor, lpd.LicenseFactor)
			,ISNULL(cl.Inactive, lpd.Inactive)
			,cl.UpdateTypeCode -- UPDATE/INSERT
		FROM @DetailChangeLogIntermediate cl
			LEFT JOIN [billing].[NEW_LicensePackageDetail] lpd
				ON cl.ItemID = lpd.ItemID AND lpd.PackageID = @FinalLicensePackageID
			LEFT JOIN get_next_changeID
				ON cl.ItemID = get_next_changeID.ItemID

--***************************************************************************************************************************************************
/* Set the LicensedUsers and BaseInterjectPrice OUTPUT vars from @DetailChangeLogIntermediate: */
--***************************************************************************************************************************************************
		SET @LicensedUsers_Output = (SELECT Quantity
									FROM @LineItemDataToSave
									WHERE ItemID = @BaseInterjectItemID)

		SET @BaseInterjectPrice_Output = (SELECT Price
									FROM @LineItemDataToSave
									WHERE ItemID = @BaseInterjectItemID)

--***************************************************************************************************************************************************
/* Modify [billing].[LicensePackageHeader]: */
--***************************************************************************************************************************************************
		DECLARE @HeaderChangeLogIntermediate as TABLE
		(
			[UpdateTypeCode] NVARCHAR(10)  -- Will show UPDATE, INSERT, or DELETE
			,[ClientID] INT
			,[Location] NVARCHAR(200)
			,[LicenseStartDate] DATE
			,[LicenseExpirationDate] DATE
			,[PackageDiscount] DECIMAL(5,4)
			,[UserMinimum] INT
			,[NextHeaderChangeID] INT
			,[Inactive] BIT
		)

		/* Get ClientID from ClientName: */
		DECLARE @ClientID TINYINT
		SET @ClientID = (SELECT ClientID
							FROM [app].[Client]
							WHERE ClientName = @ClientName)

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* UPDATE existing package header case: */
-----------------------------------------------------------------------------------------------------------------------------------------------------	
		DECLARE @NextHeaderChangeID INT
		SET @NextHeaderChangeID = ISNULL((SELECT ChangeID + 1
										FROM [billing].[NEW_LicensePackageHeader]
										WHERE PackageID = @FinalLicensePackageID), 1)
		
		MERGE [billing].[NEW_LicensePackageHeader] t 
		USING (VALUES(
					@FinalLicensePackageID
					,@ClientID
					,@Location
					,@LicenseStartDate
					,@LicenseExpirationDate
					,@PackageDiscount
					,@UserMinimum
					,@NextHeaderChangeID
					,0))
					AS s(
						PackageID
						,ClientID
						,Location
						,LicenseStartDate
						,LicenseExpirationDate
						,PackageDiscount
						,UserMinimum
						,NextHeaderChangeID
						,Inactive)
		ON t.PackageID = s.PackageID
		WHEN MATCHED
		THEN
			UPDATE SET
				t.ClientID = s.ClientID
				,t.Location = s.Location
				,t.LicenseStartDate = s.LicenseStartDate
				,t.LicenseExpirationDate = s.LicenseExpirationDate
				,t.PackageDiscount = s.PackageDiscount
				,t.UserMinimum = s.UserMinimum
				,t.ChangeID = s.NextHeaderChangeID
		WHEN NOT MATCHED BY TARGET
		THEN
			INSERT
			(
				[PackageID]
				,[ClientID]
				,[Location]
				,[LicenseStartDate]
				,[LicenseExpirationDate]
				,[PackageDiscount]
				,[UserMinimum]
				,[Inactive]
				,[ChangeID]
			)
			VALUES
			(
				s.ClientID
				,s.Location
				,s.LicenseStartDate
				,s.LicenseExpirationDate
				,s.PackageDiscount
				,s.UserMinimum
				,s.Inactive
				,s.NextHeaderChangeID
			)
		OUTPUT
			$ACTION
			,INSERTED.ClientID
			,INSERTED.Location
			,INSERTED.LicenseStartDate
			,INSERTED.LicenseExpirationDate
			,INSERTED.PackageDiscount
			,INSERTED.UserMinimum
			,INSERTED.Inactive
		INTO @HeaderChangeLogIntermediate
		(
			[UpdateTypeCode]
			,[ClientID]
			,[Location]
			,[LicenseStartDate]
			,[LicenseExpirationDate]
			,[PackageDiscount]
			,[UserMinimum]
			,[NextHeaderChangeID]
			,[Inactive]
		);
		--WHERE s.PackageID = t.FinalLicensePackageID
		--	AND
		--	(
		--		t.ClientID <> s.ClientID
		--		OR t.Location <> s.@Location
		--		OR t.LicenseStartDate <> s.@LicenseStartDate
		--		OR t.LicenseExpirationDate <> s.@LicenseExpirationDate
		--		OR t.PackageDiscount <> s.@PackageDiscount
		--		OR t.UserMinimum <> s.@UserMinimum
		--	)
		

		--IF (EXISTS(SELECT TOP 1 1 FROM [billing].[NEW_LicensePackageHeader] WHERE PackageID = @FinalLicensePackageID))
		--BEGIN
		--	SET @NextHeaderChangeID = (SELECT ChangeID
		--								FROM [billing].[NEW_LicensePackageHeader]
		--								WHERE PackageID = @FinalLicensePackageID) + 1

		--	UPDATE [billing].[NEW_LicensePackageHeader]
		--	SET
		--		PackageID = @FinalLicensePackageID
		--		,ClientID = @ClientID
		--		,Location = @Location
		--		,LicenseStartDate = @LicenseStartDate
		--		,LicenseExpirationDate = @LicenseExpirationDate
		--		,PackageDiscount = @PackageDiscount
		--		,UserMinimum = @UserMinimum
		--		,ChangeID = @NextHeaderChangeID
		--		,Inactive = 0 -- Entering an active license, fair assumption? Could check dates.
		--	OUTPUT
		--		'UPDATE'
		--		,INSERTED.ClientID
		--		,INSERTED.Location
		--		,INSERTED.LicenseStartDate
		--		,INSERTED.LicenseExpirationDate
		--		,INSERTED.PackageDiscount
		--		,INSERTED.UserMinimum
		--		,INSERTED.Inactive
		--	INTO @HeaderChangeLogIntermediate
		--	WHERE PackageID = @FinalLicensePackageID
		--		AND
		--		(
		--			ClientID <> @ClientID
		--			OR Location <> @Location
		--			OR LicenseStartDate <> @LicenseStartDate
		--			OR LicenseExpirationDate <> @LicenseExpirationDate
		--			OR PackageDiscount <> @PackageDiscount
		--			OR UserMinimum <> @UserMinimum
		--		)
		--END
		--ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* INSERT new package if no PackageID was entered or a NEW id was entered that doesn't exist: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		--	SET @NextHeaderChangeID = 1

		--	INSERT INTO [billing].[NEW_LicensePackageHeader](
		--		[PackageID]
		--		,[ClientID]
		--		,[Location]
		--		,[LicenseStartDate]
		--		,[LicenseExpirationDate]
		--		,[PackageDiscount]
		--		,[UserMinimum]
		--		,[Inactive]
		--		,[ChangeID]
		--	)
		--	OUTPUT
		--		'INSERT'
		--		,INSERTED.ClientID
		--		,INSERTED.Location
		--		,INSERTED.LicenseStartDate
		--		,INSERTED.LicenseExpirationDate
		--		,INSERTED.UserMinimum
		--		,INSERTED.PackageDiscount
		--		,INSERTED.Inactive
		--	INTO @HeaderChangeLogIntermediate
		--	VALUES
		--	(
		--		@FinalLicensePackageID
		--		,@ClientID
		--		,@Location
		--		,@LicenseStartDate
		--		,@LicenseExpirationDate
		--		,@PackageDiscount
		--		,@UserMinimum
		--		,0 -- Active
		--		,@NextHeaderChangeID
		--	)
		--END

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageHeaderLog]: */
--***************************************************************************************************************************************************
		INSERT INTO [billing_history].[NEW_LicensePackageHeaderChangeLog]
		(
			[PackageID]
		  ,[ChangeID]
		  ,[ClientID]
		  ,[Location]
		  ,[LicenseStartDate]
		  ,[LicenseExpirationDate]
		  ,[PackageDiscount]
		  ,[UserMinimum]
		  ,[Inactive]
		  ,[Operation]
		 )
		SELECT
			@FinalLicensePackageID
			,@NextHeaderChangeID
			,ClientID
			,Location
			,LicenseStartDate
			,LicenseExpirationDate
			,PackageDiscount
			,UserMinimum
			,Inactive
			,.UpdateTypeCode -- UPDATE/INSERT
		FROM @HeaderChangeLogIntermediate

--***************************************************************************************************************************************************
/* Modify [billing].[LicensePackageClientPartner]: */
--***************************************************************************************************************************************************
		
		-- REVIEW
		
		DECLARE @ClientPartnerChangeLogIntermediate as TABLE
		(
			[UpdateTypeCode] VARCHAR(6)
			,[ClientPartnerID] INT
			,[PartnerSplitPercentage] DECIMAL(5,4)
			,[NextClientPartnerChangeID] INT
			,[Inactive] BIT
		)

		--By this point, we know that the @ClientPartnerName entered is either '' or is a valid ClientName....
		IF (@ClientPartnerName <> '')
		BEGIN
			DECLARE @ClientPartnerID INT = (SELECT TOP 1 ClientID FROM [app].[Client] WHERE ClientName = @ClientPartnerName)
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* UPDATE: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			IF (EXISTS(SELECT TOP 1 1 FROM [billing].[NEW_LicensePackageClientPartner] WHERE PackageID = @FinalLicensePackageID))
			BEGIN
				UPDATE lpcp
				SET
					ClientPartnerID = @ClientPartnerID
					,PartnerSplitPercentage = @PartnerSplit
					,ChangeID = (lpcp.ChangeID + 1)
				OUTPUT
					'UPDATE'
					,INSERTED.ClientPartnerID
					,INSERTED.PartnerSplitPercentage
					,INSERTED.ChangeID
					,0
				INTO @ClientPartnerChangeLogIntermediate
				(
				[UpdateTypeCode]
				,[ClientPartnerID]
				,[PartnerSplitPercentage]
				,[NextClientPartnerChangeID]
				,[Inactive]
				)
				FROM [billing].[NEW_LicensePackageClientPartner] lpcp
				WHERE PackageID = @FinalLicensePackageID
					AND (lpcp.ClientPartnerID <> @ClientPartnerID
						OR lpcp.PartnerSplitPercentage <> @PartnerSplit)
			END
		-- Else INSERT new rcord to assign a client partner for this package:
			ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* INSERT: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
				INSERT INTO [billing].[NEW_LicensePackageClientPartner]
				OUTPUT
					'INSERT'
					,INSERTED.ClientPartnerID
					,INSERTED.PartnerSplitPercentage
					,INSERTED.ChangeID
					,INSERTED.Inactive
				INTO @ClientPartnerChangeLogIntermediate
				(
					[UpdateTypeCode]
					,[ClientPartnerID]
					,[PartnerSplitPercentage]
					,[NextClientPartnerChangeID]
					,[Inactive]
				)
				SELECT
					@FinalLicensePackageID
					,@ClientPartnerID
					,@PartnerSplit
					,ISNULL(MAX(ChangeID), 0) + 1 -- if no previous client partners, insert 1 for init
					,0
				FROM [billing_history].[NEW_LicensePackageClientPartnerChangeLog]
				WHERE PackageID = @FinalLicensePackageID
			END
		END
		ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Attempt "delete" if no client name was entered and there is already a record in ClientPartner: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			UPDATE [billing].[NEW_LicensePackageClientPartner]
			SET
				Inactive = 1
			OUTPUT
				'DELETE'
				,INSERTED.Inactive
			INTO @ClientPartnerChangeLogIntermediate
				(
				[UpdateTypeCode]
				,[Inactive]
				)
			WHERE PackageID = @FinalLicensePackageID
		END

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageClientPartnerLog]: */
--***************************************************************************************************************************************************
		INSERT INTO [billing_history].[NEW_LicensePackageClientPartnerChangeLog]
		SELECT
			@FinalLicensePackageID
			,cl.NextClientPartnerChangeID
			,ISNULL(cl.ClientPartnerID, lpcp.ClientPartnerID)
			,ISNULL(cl.PartnerSplitPercentage, lpcp.PartnerSplitPercentage)
			,cl.UpdateTypeCode
		FROM @ClientPartnerChangeLogIntermediate cl
			LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
				ON lpcp.PackageID = @FinalLicensePackageID

--***************************************************************************************************************************************************
-- Modify [billing].[LicensePackageNote]:
--***************************************************************************************************************************************************
		DECLARE @NoteChangeLogIntermediate AS TABLE
		(
			UpdateTypeCode VARCHAR(10)
			,Note VARCHAR(MAX)
			,NextNoteChangeID INT
			,Inactive BIT
		)

		IF (EXISTS(SELECT TOP 1 1 FROM [billing].[NEW_LicensePackageNote] WHERE PackageID = @FinalLicensePackageID)
			AND (@Note <> ''))
		BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* UPDATE: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			UPDATE lpn
			SET
				Note = @Note
				,ChangeID = lpn.ChangeID + 1
			OUTPUT
				'UPDATE'
				,INSERTED.Note
				,INSERTED.ChangeID
				,0
			INTO @NoteChangeLogIntermediate
			(
				[UpdateTypeCode]
				,[Note]
				,[NextNoteChangeID]
				,[Inactive]
			)
			FROM [billing].[NEW_LicensePackageNote] lpn
			WHERE lpn.PackageID = @FinalLicensePackageID
				AND lpn.Note <> @Note
		END
		ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* INSERT: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			INSERT INTO	[billing].[NEW_LicensePackageNote]
			(
			[PackageID]
			 ,[Note]
			 ,[ChangeID]
			 )
			OUTPUT
				'INSERT'
				,INSERTED.Note
				,1
				,0
			INTO @NoteChangeLogIntermediate
			(
				[UpdateTypeCode]
				,[Note]
				,[NextNoteChangeID]
				,[Inactive]
			)
			VALUES
			(
				@FinalLicensePackageID
				,@Note
				,1
			)
		END
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* "Delete": */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		IF (@Note = '')
		BEGIN
			UPDATE lpn
			SET
				Inactive = 1
			OUTPUT
				'UPDATE'
				,1
			INTO @NoteChangeLogIntermediate
			(
				[UpdateTypeCode]
				,[Inactive]
			)
			FROM [billing].[NEW_LicensePackageNote] lpn
			WHERE lpn.PackageID = @FinalLicensePackageID
				AND lpn.Inactive =0
		END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Insert to [billing_history].[LicensePackageNoteLog]: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		INSERT INTO [billing_history].[NEW_LicensePackageNoteChangeLog]
		(
		[PackageID]
		 ,[ChangeID]
		 ,[Note]
		 ,[Operation]
		 ,[Inactive]
		  )
		SELECT
			@FinalLicensePackageID
			,NextNoteChangeID
			,Note
			,UpdateTypeCode
			,0
		FROM @NoteChangeLogIntermediate

--***************************************************************************************************************************************************
-- Insert to [billing_history].[LicensePackageChangeLog] based on changes made to Header, Detail, ClientPartner and Note tables:
--***************************************************************************************************************************************************
		IF (EXISTS(SELECT TOP 1 1 FROM @HeaderChangeLogIntermediate) OR EXISTS(SELECT TOP 1 1 FROM @DetailChangeLogIntermediate)
					OR EXISTS(SELECT 1 FROM @ClientPartnerChangeLogIntermediate) OR EXISTS(SELECT 1 FROM @NoteChangeLogIntermediate))
		BEGIN
			INSERT INTO [billing_history].[NEW_LicensePackageChangeLog]
			(
			[PackageID]
			 ,[ChangeID]
			 ,[HeaderChangeID]
			 ,[ClientPartnerChangeID]
			 ,[NoteChangeID]
			 ,[Updated]
			 ,[UpdatedBy]
			)
			SELECT
				@NextPackageChangeID
				,@FinalLicensePackageID
				,MAX(lph_l.ChangeID)
				,MAX(lpcp_l.ChangeID)
				,MAX(lpn_l.ChangeID)
				,GETDATE() --?
				,@Interject_LoginName
			FROM [billing_history].[NEW_LicensePackageHeaderChangeLog] lph_l
				LEFT JOIN [billing_history].[NEW_LicensePackageDetailChangeLog] lpd_l
					ON lph_l.PackageID = lpd_l.PackageID
				LEFT JOIN [billing_history].[NEW_LicensePackageClientPartnerChangeLog] lpcp_l
					ON lph_l.PackageID = lpcp_l.PackageID
				LEFT JOIN [billing_history].[NEW_LicensePackageNoteChangeLog] lpn_l
					ON lph_l.PackageID = lpn_l.PackageID
			WHERE lph_l.PackageID = @FinalLicensePackageID
		END

--***************************************************************************************************************************************************
-- Update user message that will show in Excel for line item modifications:
--***************************************************************************************************************************************************
        UPDATE dtp
        SET [_MessageToUser] = 
            CASE cl.UpdateTypeCode
                WHEN 'INSERT' THEN ', Added!'
                WHEN 'UPDATE' THEN ', Updated!'
				WHEN 'DELETE' THEN ', Deleted!'
            END
        FROM @LineItemDataToSave dtp
            INNER JOIN @DetailChangeLogIntermediate cl 
                    ON dtp.[_ExcelRow] = cl.[_ExcelRow]

--***************************************************************************************************************************************************
-- Commit or roll back the transaction:
--***************************************************************************************************************************************************
        IF (@TestMode = 1)
        BEGIN
            SELECT '@DetailChangeLogIntermediate- Show log of changes made' as ResultName
            SELECT * FROM @DetailChangeLogIntermediate
            
            ROLLBACK TRAN t1 -- note this does not roll back changes to table variables, only real tables
            SELECT 'Changes rolled back since in TEST mode!' as TestModeNote
        END
        ELSE
        BEGIN
            COMMIT TRAN t1
        END
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
            ROLLBACK TRAN t1
        
        SET @ErrorMessageToUser =  @ErrorMessageToUser + ERROR_MESSAGE()
        GOTO FinalResponseToUser
    END CATCH
   
--***************************************************************************************************************************************************
-- Response for the SAVE action:
--***************************************************************************************************************************************************
FinalResponseToUser:
    
    -- if test mode, show the final table 
    IF @TestMode = 1 
    BEGIN
        SELECT '@LineItemDataToSave - Final Result' as ResultName
        SELECT * FROM @LineItemDataToSave

		SELECT '@DetailChangeLogIntermediate - Final Result' as ResultName
        SELECT * FROM @DetailChangeLogIntermediate

		SELECT '@HeaderChangeLogIntermediate - Final Result' as ResultName
        SELECT * FROM @HeaderChangeLogIntermediate

		SELECT '@ClientPartnerChangeLogIntermediate - Final Result' as ResultName
        SELECT * FROM @ClientPartnerChangeLogIntermediate

		SELECT '@NoteChangeLogIntermediate - Final Result' as ResultName
        SELECT * FROM @NoteChangeLogIntermediate
    END
    
    -- return the recordset results back to the spreadsheet, if needed:
    SELECT
        [_ExcelRow] as [Row] -- this relates to the original row of the spreadsheet the data came from
        ,SUBSTRING([_MessageToUser],3,1000) as [MessageToUser]  -- This is a field that, if it matches a column in the Results Range, will be placed in that column for the specified row
		---- DEPRECATED: Re-pull the item price and quantity info in case it was changed in the header (only applies to base interject item, but updating all to keep in one query):
		--,[Price] AS UpdatedItemPrice
		--,[Quantity] AS UpdatedQuantity
    FROM @LineItemDataToSave
    
    -- if there is an error, raise error and Interject will catch and present to the user.
    -- Note that this is specifically done after the above resultset is returned, since initiating an error before
    -- will not allow a result set to be returned to provide feedback on each row 
    IF @ErrorMessageToUser <> ''
    BEGIN
        -- by adding 'UserNotice:' as a prefix to the message, Interject will not consider it a unhandled error 
        -- and will present the error to the user in a message box.
        SET @ErrorMessageToUser = 'UserNotice:' + @ErrorMessageToUser
        
        RAISERROR (@ErrorMessageToUser,
        18, -- Severity,
        1) -- State)
        RETURN
    END
