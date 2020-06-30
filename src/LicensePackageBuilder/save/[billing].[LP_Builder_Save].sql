/*
USE [Interject_Demos_Students]
*/
/* Uses initial schema design. */

ALTER PROC [billing].[LP_Builder_Save]
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
			,[LastDetailItemChangeID] INT
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
				,T.c.value('ItemName[1]', 'VARCHAR(max)') as [ItemName]
				,T.c.value('ItemPrice[1]', 'MONEY')	 as [Price]
				,T.c.value('Quantity[1]', 'INT') as [Quantity]
				,T.c.value('ItemDiscount[1]', 'DECIMAL(5,4)') as [ItemDiscount]
				,T.c.value('LicenseFactor[1]', 'DECIMAL(5,4)') as [LicenseFactor]
			FROM @LineItemDataToSaveXML.nodes('/Root/r') T(c)
		END TRY
		BEGIN CATCH
			SELECT ERROR_MESSAGE() -- Not using @ErrorMessageToUser.. typical?
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
		LastDetailItemChangeID = lpd.DetailItemChangeID
	FROM @LineItemDataToSave d
		INNER JOIN [billing].[LicensePackageDetail] lpd
			ON d.ItemID = lpd.ItemID
	WHERE lpd.PackageID = @FinalLicensePackageID

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Grab last GroupItemChangeID for each Item that already exists in lpd: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	--IF (NOT EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog] WHERE PackageID = @UserSuppliedLicPackageID_Int))
	--BEGIN
	--	UPDATE @LineItemDataToSave
	--	SET LastDetailItemGroupID = 0
	--END
	--ELSE BEGIN
	--	UPDATE @LineItemDataToSave
	--	SET LastDetailItemGroupID = lpcl.DetailGroupChangeID
	--	FROM [billing_history].[LicensePackageChangeLog] lpcl
	--	WHERE lpcl.PackageID = @UserSuppliedLicPackageID_Int
	--END

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
		SET @ErrorMessageToUser =  ' ClientPartnerName entered does not match any entries in the database. Please only enter client partner names '
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
			,[DetailItemChangeID] INT -- == THIS change
        )
        
        BEGIN TRAN t1

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* DEPRECATED: Override the values for PRICE and QUANTITY of Interject Base License if edited in the header: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* This was used previously when Stan wanted to be able to edit the "Current Licensed Users" and "Per-User Renewal Cost" fields in the report. 
	I added this feature to override the line item values that corresponded to these header values. Stan does not want this feature and now these
	fields in the header section of the report are non-editable. */

			--UPDATE @LineItemDataToSave
			--SET
			--	Price = @BaseInterjectPrice
			--	,Quantity = @LicensedUsers
			--WHERE ItemID = @BaseInterjectItemID
			--	AND ((Price <> @BaseInterjectPrice AND @BaseInterjectPrice IS NOT NULL)
			--		OR (Quantity <> @LicensedUsers AND @LicensedUsers IS NOT NULL))

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Before modifying lpd, record the current state of which line items are present in lpd in [billing_histroy].[LicensePackageChangeItems] (for
	UPDATE and DELETE actions): */
-----------------------------------------------------------------------------------------------------------------------------------------------------

		DECLARE @InsertToChangeItemsAfterMerge BIT = 0
		DECLARE @InsertToChangeItemsLast BIT = 0
		/* Check if new package creation/first insert of items into package, if so, write to LPChangeItems AFTER MERGE to record first insert into
			LPChangeItems. */
		IF (NOT EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageDetail] WHERE PackageID = @FinalLicensePackageID))
		BEGIN
			SET @InsertToChangeItemsAfterMerge = 1
		END
		ELSE BEGIN

			-- The following should only execute if an UPDATE OR INSERT IS ABOUT to happen on line items...
			IF (EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageDetail] lpd
										FULL JOIN @LineItemDataToSave dts ON lpd.ItemID = dts.ItemID
										WHERE lpd.PackageID = @FinalLicensePackageID
											AND (
												((lpd.ItemID IS NULL) OR (dts.ItemID IS NULL) OR (lpd.ItemID <> dts.ItemID))
												OR ((lpd.Price IS NULL) OR (dts.Price IS NULL) OR (lpd.Price <> dts.Price))
												OR ((lpd.Quantity IS NULL) OR (dts.Quantity IS NULL) OR (lpd.Quantity <> dts.Quantity))
												OR ((lpd.Discount IS NULL) OR (dts.ItemDiscount IS NULL) OR (lpd.Discount <> dts.ItemDiscount))
												OR ((lpd.LicenseFactor IS NULL) OR (dts.LicenseFactor IS NULL) OR (lpd.LicenseFactor <> dts.LicenseFactor))
												)))
			BEGIN
				INSERT INTO [billing_history].[LicensePackageChangeItems]
				SELECT
					@FinalLicensePackageID
					,@NextPackageChangeID
					,lpd.ItemID
					,max_group_id_query.MaxGroupChangeID
				FROM [billing].[LicensePackageDetail] lpd
					LEFT JOIN (SELECT
									PackageID
									,ItemID
									,MAX(DetailGroupChangeID) MaxGroupChangeID
								FROM [billing_history].[LicensePackageDetailLog]
								WHERE PackageID = @FinalLicensePackageID
								GROUP BY PackageID, ItemID) max_group_id_query
						ON lpd.ItemID = max_group_id_query.ItemID
				WHERE lpd.PackageID = @FinalLicensePackageID
			END
			/* If no UPDATE or INSERT on line items is about to occur, set a flag to insert into LPChangeItems at the very end when LPChangeLog
			is updated. This needs to be done so that there is a record in LPChangeItems corresponding to EVERY ChangeID in a given package. */
			ELSE BEGIN
				/* At this point we know no INSERT/UpDATE on line items will happen in this runtime, so updating ChangeItems at end is not a problem.
					Must insert at the very end along with LPChangeLog update so that LPChangeItems is ONLY updated when LPChangheLog is updated. */
				SET @InsertToChangeItemsLast = 1
			END
		END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* MERGE [billing].[LicensePackageDetail]: */
-----------------------------------------------------------------------------------------------------------------------------------------------------

		MERGE [billing].[LicensePackageDetail] t -- t = the target table or view to update
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
				,t.[DetailItemChangeID] = (s.[LastDetailItemChangeID] + 1)
		WHEN NOT MATCHED BY TARGET THEN -- Handles the insert based on LEFT JOIN 
			INSERT (
					[ItemID]
					,[PackageID]
					,[Price]
					,[Quantity]
					,[Discount]
					,[LicenseFactor]
					,[DetailItemChangeID]
			)
			VALUES (
				s.[ItemID]
				,@FinalLicensePackageID
				,s.[Price]
				,s.[Quantity]
				,s.[ItemDiscount]
				,s.[LicenseFactor]
				,1 -- first change
			)
		WHEN NOT MATCHED BY SOURCE
			AND t.PackageID = @FinalLicensePackageID THEN
			DELETE
		OUTPUT 
			s.[_ExcelRow] -- OK for this to be NULL for DELTED rows?
			,$action as UpdateTypeCode  -- this logs into an a change log table variable
			,ISNULL(DELETED.[ItemID],INSERTED.[ItemID])  -- could be in either order since id will not change on a line item modification
			,ISNULL(DELETED.[ItemID],INSERTED.[ItemID])
			,ISNULL(DELETED.[Price],INSERTED.[Price])
			,ISNULL(DELETED.[Quantity],INSERTED.[Quantity])
			,ISNULL(DELETED.[Discount],INSERTED.[Discount])
			,ISNULL(DELETED.[LicenseFactor],INSERTED.[LicenseFactor])
			,ISNULL((DELETED.[DetailItemChangeID] + 1), INSERTED.[DetailItemChangeID])
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
			,[DetailItemChangeID]
		);

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageDetailLog]: */
--***************************************************************************************************************************************************
		DECLARE @NextDetailGroupChangeID INT = ISNULL(((SELECT MAX(DetailGroupChangeID)
													FROM [billing_history].[LicensePackageDetailLog]
													WHERE PackageID = @FinalLicensePackageID) + 1), 1)

		INSERT INTO [billing_history].[LicensePackageDetailLog]
			(
				[PackageID]
				,[DetailItemChangeID]
				,[ItemID]
				,[DetailGroupChangeID]
				,[Price]
				,[Quantity]
				,[Discount]
				,[LicenseFactor]
				,[Operation]
			)
		SELECT
			@FinalLicensePackageID
				-- If no entires were found in lpd_l subquery, this item has never been in this pkg before and gets id=1:
			,ISNULL(lpd_l_query.NextChangeIDForExistingItems, 1)
			,cl.ItemID
			,@NextDetailGroupChangeID
			-- For the following cols, if not updated in the above MERGE, take the col for that record from lpd main table
			-- (this essetially records a snapshot of the modification event):
			,ISNULL(cl.ItemPrice, lpd.Price) 
			,ISNULL(cl.ItemQuantity, lpd.Quantity)
			,ISNULL(cl.ItemDiscount, lpd.Discount)
			,ISNULL(cl.ItemLicenseFactor, lpd.LicenseFactor)
			,cl.UpdateTypeCode -- UPDATE/INSERT/DELETE
		FROM @DetailChangeLogIntermediate cl
			LEFT JOIN [billing].[LicensePackageDetail] lpd
				ON cl.ItemID = lpd.ItemID AND lpd.PackageID = @FinalLicensePackageID
			LEFT JOIN (SELECT
							ItemID
							,MAX(DetailItemChangeID) + 1 AS NextChangeIDForExistingItems
						FROM [billing_history].[LicensePackageDetailLog]
						WHERE PackageID = @FinalLicensePackageID
						GROUP BY ItemID) lpd_l_query
				ON cl.ItemID = lpd_l_query.ItemID

--***************************************************************************************************************************************************
/* Additional modification of [billing].[LicensePackageDetail]: */
--***************************************************************************************************************************************************

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Update lpds DetailItemChangeID after 1 is incorrectly inserted by MERGE above: */
-----------------------------------------------------------------------------------------------------------------------------------------------------

		/* For case in which an item that has previously been in a package is deleted and RE-ADDED later... preserve the
			DetailItemChangeID from the record in lpd_l: */
		UPDATE lpd
		SET lpd.DetailItemChangeID = lpd_l_query.DetailItemChangeIDFromLog
		FROM @DetailChangeLogIntermediate cl
				LEFT JOIN [billing].[LicensePackageDetail] lpd
					ON cl.ItemID = lpd.ItemID AND lpd.PackageID = @FinalLicensePackageID
				LEFT JOIN (SELECT
								ItemID
								,MAX(DetailItemChangeID) AS DetailItemChangeIDFromLog
							FROM [billing_history].[LicensePackageDetailLog] lpd_l
							WHERE PackageID = @FinalLicensePackageID
							GROUP BY ItemID) lpd_l_query
					ON cl.ItemID = lpd_l_query.ItemID
		WHERE lpd.DetailItemChangeID = 1

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- DEPRECATED: INSERT new interject base line item if base info was entered but there is no existing base item:
-----------------------------------------------------------------------------------------------------------------------------------------------------

		/* LPD update: */
		--DECLARE @AddedInterjectBaseItemFromHeader BIT = 0
		--IF (NOT EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageDetail] WHERE PackageID = @FinalLicensePackageID AND ItemID = @BaseInterjectItemID))
		--BEGIN
		--	SET @AddedInterjectBaseItemFromHeader = 1
		--	--Select the DetailItemChangeID for this INSERT
		--	DECLARE @BaseItemChangeIDFromHist INT
		--	SET @BaseItemChangeIDFromHist = (SELECT
		--										MAX(DetailItemChangeID) + 1
		--									FROM [billing_history].[LicensePackageDetailLog]
		--									WHERE PackageID = @FinalLicensePackageID AND ItemID = @BaseInterjectItemID
		--									GROUP BY ItemID)
			
		--	INSERT INTO [billing].[LicensePackageDetail]
		--	SELECT
		--		@BaseInterjectItemID
		--		,@FinalLicensePackageID
		--		,@BaseInterjectPrice
		--		,@LicensedUsers
		--		,0 --Discount
		--		,0 --LicFactor
		--		,ISNULL(@BaseItemChangeIDFromHist, 1) -- If nothing in detail hist., first entry with chID=1.

			/* LPD_LOG update: */
			--INSERT INTO [billing_history].[LicensePackageDetailLog]
			--	(
			--		[PackageID]
			--		,[DetailItemChangeID]
			--		,[ItemID]
			--		,[DetailGroupChangeID]
			--		,[Price]
			--		,[Quantity]
			--		,[Discount]
			--		,[LicenseFactor]
			--		,[Operation]
			--	)
			--	SELECT
			--		@FinalLicensePackageID
			--		,ISNULL(@BaseItemChangeIDFromHist, 1)
			--		,@BaseInterjectItemID
			--		,@NextDetailGroupChangeID
			--		,@BaseInterjectPrice
			--		,@LicensedUsers
			--		,0
			--		,0
			--		,'INSERT'
			--END
			
--***************************************************************************************************************************************************
-- Insert into ChangeItems AFTER MERGE:
--***************************************************************************************************************************************************
		IF ((@InsertToChangeItemsAfterMerge = 1)
			AND (EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageDetail])))
		BEGIN
			INSERT INTO [billing_history].[LicensePackageChangeItems]
			SELECT
				@FinalLicensePackageID
				,@NextPackageChangeID
				,lpd.ItemID
				,1 -- Init insert
			FROM [billing].[LicensePackageDetail] lpd
			WHERE lpd.PackageID = @FinalLicensePackageID
		END

--***************************************************************************************************************************************************
/* Set the LicensedUsers and BaseInterjectPrice OUTPUT vars from @DetailChangeLogIntermediate: */
--***************************************************************************************************************************************************
		SET @LicensedUsers_Output = (SELECT ISNULL(dts.Quantity, lpd.Price)
									FROM @LineItemDataToSave dts
										LEFT JOIN [billing].[LicensePackageDetail] lpd
											ON lpd.PackageID = @FinalLicensePackageID 
												AND lpd.ItemID = @BaseInterjectItemID
									WHERE dts.ItemID = @BaseInterjectItemID)

		SET @BaseInterjectPrice_Output = (SELECT ISNULL(dts.Price, lpd.Price)
									FROM @LineItemDataToSave dts
										LEFT JOIN [billing].[LicensePackageDetail] lpd
											ON lpd.PackageID = @FinalLicensePackageID 
												AND lpd.ItemID = @BaseInterjectItemID
									WHERE dts.ItemID = @BaseInterjectItemID)

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
			,[UserMinimum] INT
			,[Inactive] BIT 
			,[PackageDiscount] DECIMAL(5,4)
		)

		/* Get ClientID from ClientName: */
		DECLARE @ClientID TINYINT
		SET @ClientID = (SELECT ClientID
							FROM [app].[Client]
							WHERE ClientName = @ClientName)
			
		DECLARE @NextHeaderChangeID INT

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* UPDATE existing package header case: */
-----------------------------------------------------------------------------------------------------------------------------------------------------	
		IF (EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageHeader] WHERE PackageID = @FinalLicensePackageID))
		BEGIN
			SET @NextHeaderChangeID = (SELECT HeaderChangeID
										FROM [billing].[LicensePackageHeader]
										WHERE PackageID = @FinalLicensePackageID) + 1

			UPDATE [billing].[LicensePackageHeader]
			SET
				PackageID = @FinalLicensePackageID
				,ClientID = @ClientID
				,Location = @Location
				,LicenseStartDate = @LicenseStartDate
				,LicenseExpirationDate = @LicenseExpirationDate
				,PackageDiscount = @PackageDiscount
				,UserMinimum = @UserMinimum
				,HeaderChangeID = @NextHeaderChangeID
				,Inactive = 0 -- Entering an active license, fair assumption? Could check dates.
			OUTPUT
				'UPDATE'
				,DELETED.ClientID
				,DELETED.Location
				,DELETED.LicenseStartDate
				,DELETED.LicenseExpirationDate
				,DELETED.UserMinimum
				,DELETED.Inactive
				,DELETED.PackageDiscount
			INTO @HeaderChangeLogIntermediate
			WHERE PackageID = @FinalLicensePackageID
				AND
				(
					ClientID <> @ClientID
					OR Location <> @Location
					OR UserMinimum <> @UserMinimum
					OR PackageDiscount <> @PackageDiscount
					OR LicenseStartDate <> @LicenseStartDate
					OR LicenseExpirationDate <> @LicenseExpirationDate
				)
		END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* INSERT new package if no PackageID was entered or a NEW id was entered that doesn't exist: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		ELSE BEGIN
			SET @NextHeaderChangeID = 1

			INSERT INTO [billing].[LicensePackageHeader](
				[PackageID]
				,[ClientID]
				,[Location]
				,[LicenseStartDate]
				,[LicenseExpirationDate]
				,[UserMinimum]
				,[PackageDiscount]
				,[HeaderChangeID]
				,[Inactive]
			)
			OUTPUT
				'INSERT'
				,INSERTED.ClientID
				,INSERTED.Location
				,INSERTED.LicenseStartDate
				,INSERTED.LicenseExpirationDate
				,INSERTED.UserMinimum -- swapped with below row which solved crazy bug
				,INSERTED.PackageDiscount
				,INSERTED.Inactive
			INTO @HeaderChangeLogIntermediate
			VALUES
			(
				@FinalLicensePackageID
				,@ClientID
				,@Location
				,@LicenseStartDate
				,@LicenseExpirationDate
				,@UserMinimum
				,@PackageDiscount
				,@NextHeaderChangeID
				,0 -- Active
			)
	END

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageHeaderLog]: */
--***************************************************************************************************************************************************
		INSERT INTO [billing_history].[LicensePackageHeaderLog]
			SELECT
				@FinalLicensePackageID
				,@NextHeaderChangeID
				,ISNULL(cl.ClientID, lph.ClientID)
				,ISNULL(cl.Location, lph.Location)
				,ISNULL(cl.LicenseStartDate, lph.LicenseStartDate)
				,ISNULL(cl.LicenseExpirationDate, lph.LicenseExpirationDate)
				,ISNULL(cl.PackageDiscount, lph.PackageDiscount)
				,ISNULL(cl.UserMinimum, lph.UserMinimum)
				,ISNULL(cl.Inactive, lph.Inactive)
				,cl.UpdateTypeCode -- UPDATE/INSERT
			FROM @HeaderChangeLogIntermediate cl
				LEFT JOIN [billing].[LicensePackageHeader] lph
					ON lph.PackageID = @FinalLicensePackageID

--***************************************************************************************************************************************************
/* Insert to [billing].[LicensePackageClientPartner]: */
--***************************************************************************************************************************************************
		DECLARE @ClientPartnerChangeLogIntermediate as TABLE
		(
			[ClientPartnerID] INT
			,[PartnerSplitPercentage] DECIMAL(5,4)
			,[NextClientPartnerChangeID] INT
			,[UpdateTypeCode] VARCHAR(6)
		)

		--By this point, we know that the @ClientPartnerName entered is either '' or is a valid ClientName....
		IF (@ClientPartnerName <> '')
		BEGIN
			DECLARE @ClientPartnerID INT = (SELECT TOP 1 ClientID FROM [app].[Client] WHERE ClientName = @ClientPartnerName)

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* UPDATE: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			IF (EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageClientPartner] WHERE PackageID = @FinalLicensePackageID))
			BEGIN
				UPDATE lpcp
				SET
					ClientPartnerID = @ClientPartnerID
					,PartnerSplitPercentage = @PartnerSplit
					,ClientPartnerChangeID = (lpcp.ClientPartnerChangeID + 1)
				OUTPUT
					DELETED.ClientPartnerID
					,DELETED.PartnerSplitPercentage
					,(DELETED.ClientPartnerChangeID + 1)
					,'UPDATE'
				INTO @ClientPartnerChangeLogIntermediate
				FROM [billing].[LicensePackageClientPartner] lpcp
				WHERE PackageID = @FinalLicensePackageID
					AND (lpcp.ClientPartnerID <> @ClientPartnerID
						OR lpcp.PartnerSplitPercentage <> @PartnerSplit)
			END
		-- Else INSERT new rcord to ass a client partner for this package:
			ELSE BEGIN
				INSERT INTO [billing].[LicensePackageClientPartner]
				OUTPUT
					INSERTED.ClientPartnerID
					,INSERTED.PartnerSplitPercentage
					,INSERTED.ClientPartnerChangeID
					,'INSERT'
				INTO @ClientPartnerChangeLogIntermediate
				SELECT
					@FinalLicensePackageID
					,@ClientPartnerID
					,@PartnerSplit
					,ISNULL(MAX(ClientPartnerChangeID) + 1, 1) -- if no previous client partners, insert 1 for init
				FROM [billing_history].[LicensePackageClientPartnerLog]
				WHERE PackageID = @FinalLicensePackageID
			END
		END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* INSERT: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		ELSE BEGIN
			DELETE FROM [billing].[LicensePackageClientPartner]
			OUTPUT
				DELETED.ClientPartnerID
				,DELETED.PartnerSplitPercentage
				,(DELETED.ClientPartnerChangeID + 1)
				,'DELETE'
			INTO @ClientPartnerChangeLogIntermediate
			WHERE PackageID = @FinalLicensePackageID
		END

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageClientPartnerLog]: */
--***************************************************************************************************************************************************
		INSERT INTO [billing_history].[LicensePackageClientPartnerLog]
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
			Note VARCHAR(MAX)
			,NextNoteChangeID INT
			,UpdateTypeCode VARCHAR(10)
		)

		UPDATE lpn
		SET
			Note = @Note
			,NoteChangeID = lpn.NoteChangeID + 1
		OUTPUT
			DELETED.Note
			,DELETED.NoteChangeID + 1
			,'UPDATE'
		INTO @NoteChangeLogIntermediate
		FROM [billing].[LicensePackageNote] lpn
		WHERE lpn.PackageID = @FinalLicensePackageID
			AND lpn.Note <> @Note

		IF (NOT EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageNote] WHERE PackageID = @FinalLicensePackageID)
			AND (@Note <> ''))
		BEGIN
			INSERT INTO	[billing].[LicensePackageNote]
			OUTPUT
				INSERTED.Note
				,1
				,'INSERT'
			INTO @NoteChangeLogIntermediate
			VALUES
			(
				@FinalLicensePackageID
				,@Note
				,1
			)
		END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Insert to [billing_history].[LicensePackageNoteLog]: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		INSERT INTO [billing_history].[LicensePackageNoteLog]
		SELECT
			@FinalLicensePackageID
			,NextNoteChangeID
			,Note
			,UpdateTypeCode
			,@NextPackageChangeID
			,GETDATE()
			,@Interject_LoginName
		FROM @NoteChangeLogIntermediate

--***************************************************************************************************************************************************
-- Insert to [billing_history].[LicensePackageChangeLog] based on changes made to Header, Detail, ClientPartner and Note tables:
--***************************************************************************************************************************************************
		IF (EXISTS(SELECT TOP 1 1 FROM @HeaderChangeLogIntermediate) OR EXISTS(SELECT TOP 1 1 FROM @DetailChangeLogIntermediate)
					OR EXISTS(SELECT 1 FROM @ClientPartnerChangeLogIntermediate) OR EXISTS(SELECT 1 FROM @NoteChangeLogIntermediate)) --OR (@AddedInterjectBaseItemFromHeader = 1))
		BEGIN
			INSERT INTO [billing_history].[LicensePackageChangeLog]
			SELECT
				@NextPackageChangeID
				,@FinalLicensePackageID
				,MAX(lph_l.HeaderChangeID)
				,MAX(lpd_l.DetailGroupChangeID)
				,MAX(lpcp_l.ClientPartnerChangeID)
				,MAX(lpn_l.NoteChangeID)
				,GETDATE() --?
				,@Interject_LoginName
			FROM [billing_history].[LicensePackageHeaderLog] lph_l
				LEFT JOIN [billing_history].[LicensePackageDetailLog] lpd_l
					ON lph_l.PackageID = lpd_l.PackageID
				LEFT JOIN [billing_history].[LicensePackageClientPartnerLog] lpcp_l
					ON lph_l.PackageID = lpcp_l.PackageID
				LEFT JOIN [billing_history].[LicensePackageNoteLog] lpn_l
					ON lph_l.PackageID = lpn_l.PackageID
			WHERE lph_l.PackageID = @FinalLicensePackageID

--***************************************************************************************************************************************************
/* Insert to [billing_history].[LicensePackageChangeItems] LAST. For case when no line item modifications were made, but record must be inserted
	if ANY changes were made to the package as a whole. */
--***************************************************************************************************************************************************
			IF (@InsertToChangeItemsLast = 1)
			BEGIN
				INSERT INTO [billing_history].[LicensePackageChangeItems]
					SELECT
						@FinalLicensePackageID
						,@NextPackageChangeID
						,lpd.ItemID
						,max_group_id_query.MaxGroupChangeID
					FROM [billing].[LicensePackageDetail] lpd
						LEFT JOIN (SELECT
										PackageID
										,ItemID
										,MAX(DetailGroupChangeID) MaxGroupChangeID
									FROM [billing_history].[LicensePackageDetailLog]
									WHERE PackageID = @FinalLicensePackageID
									GROUP BY PackageID, ItemID) max_group_id_query
							ON lpd.ItemID = max_group_id_query.ItemID
					WHERE lpd.PackageID = @FinalLicensePackageID
			END
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
