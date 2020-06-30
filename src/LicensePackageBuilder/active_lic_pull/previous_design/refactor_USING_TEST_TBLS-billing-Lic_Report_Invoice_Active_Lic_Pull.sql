/*
USE [Interject_Demos_Students]
*/

/*
DECLARE @ClientName NVARCHAR(500)
DECLARE @ClientPartnerName NVARCHAR(500)
DECLARE @Location NVARCHAR(200)
DECLARE @LicensedUsers INT
DECLARE @UserMinimum INT
DECLARE @BaseInterjectPrice MONEY
DECLARE @PartnerSplit DECIMAL(5, 4)
DECLARE @PackageDiscount DECIMAL(5, 4)
DECLARE @DefaultPackageStartDate DATE
DECLARE @DefaultPackageEndDate DATE
DECLARE @Note VARCHAR(MAX)

EXEC [billing].[TEST_Lic_Report_Invoice_Active_Lic_Pull]
@LicensePackageID = '136'
,@PrevLicensePackageID = '136'
,@PrevLicensePackageChangeID = 0
,@ClientName = @ClientName OUTPUT
,@ClientPartnerName = @ClientPartnerName OUTPUT
,@Location = @Location OUTPUT
,@EnableEditingModeString = 'n'
,@AutofillPrevHeaderString = 'yes'
,@AutofillPrevItemsString = 'y'
/* Header info: */
,@LicensedUsers = @LicensedUsers OUTPUT
,@BaseInterjectPrice = @BaseInterjectPrice OUTPUT
,@UserMinimum = @UserMinimum OUTPUT
,@PackageDiscount = @PackageDiscount OUTPUT
,@PartnerSplit = @PartnerSplit OUTPUT
,@DefaultPackageStartDate = @DefaultPackageStartDate OUTPUT
,@DefaultPackageEndDate = @DefaultPackageEndDate OUTPUT
,@Note = @Note OUTPUT

SELECT
@ClientName
,@ClientPartnerName
,@LicensedUsers
,@UserMinimum
,@BaseInterjectPrice
,@PartnerSplit
,@PackageDiscount
,@DefaultPackageStartDate
,@Note



Declare @ClientName nvarchar(max) = 'Moss Adams'
Declare @ClientPartnerName nvarchar(max) = 'Union 701'
Declare @Location nvarchar(max) = 'Vancouver'
Declare @LicensedUsers int
Declare @BaseInterjectPrice money
Declare @UserMinimum int = 100
Declare @PackageDiscount float = 0.05
Declare @PartnerSplit float = 0
Declare @DefaultPackageStartDate date = '02-02-2020'
Declare @DefaultPackageEndDate date = '03-02-2020'
Declare @Note varchar(max)

Execute [billing].[TEST_Lic_Report_Invoice_Active_Lic_Pull]
	@LicensePackageID = 136
	,@PrevLicensePackageID = 136
	,@PrevLicensePackageChangeID = 2
	,@ClientName = @ClientName output
	,@ClientPartnerName = @ClientPartnerName output
	,@Location = @Location output
	,@EnableEditingModeString = 'n'
	,@AutofillPrevHeaderString = 'y'
	,@AutofillPrevItemsString = 'y'
	,@LicensedUsers = @LicensedUsers output
	,@BaseInterjectPrice = @BaseInterjectPrice output
	,@UserMinimum = @UserMinimum output
	,@PackageDiscount = @PackageDiscount output
	,@PartnerSplit = @PartnerSplit output
	,@DefaultPackageStartDate = @DefaultPackageStartDate output
	,@DefaultPackageEndDate = @DefaultPackageEndDate output
	,@Note = @Note output

Select 	@ClientName as '@ClientName'	,@ClientPartnerName as '@ClientPartnerName'	,@Location as '@Location'	,@LicensedUsers as '@LicensedUsers'	,@BaseInterjectPrice as '@BaseInterjectPrice'	,@UserMinimum as '@UserMinimum'	,@PackageDiscount as '@PackageDiscount'	,@PartnerSplit as '@PartnerSplit'	,@DefaultPackageStartDate as '@DefaultPackageStartDate'	,@DefaultPackageEndDate as '@DefaultPackageEndDate'	,@Note as '@Note'



*/

ALTER PROC [billing].[TEST_Lic_Report_Invoice_Active_Lic_Pull]
/* Accepts a PackageID and pulls in the CURRENT license info which corresponds.
	
	USER STORY: use license search sheets (either the expiring licenses one or the general search)
	to find the license you would like to modify, then drill to the invoice sheet where it can be 
	modified. This procedure pulls in the current/active license info to be modified in the invoice
	sheet.
	
	TO DO:
	-Add autofilling prev license/comparison license items
*/
	@LicensePackageID INT
	,@PrevLicensePackageID INT
	,@PrevLicensePackageChangeID INT
	,@ClientName NVARCHAR(500) OUTPUT
	,@ClientPartnerName NVARCHAR(500) OUTPUT
	,@Location NVARCHAR(200) OUTPUT
	,@EnableEditingModeString NVARCHAR(10)
	,@AutofillPrevHeaderString NVARCHAR(10)
	,@AutofillPrevItemsString NVARCHAR(10)
	/* Header info: */
	,@LicensedUsers INT OUTPUT
	,@BaseInterjectPrice MONEY OUTPUT
	,@UserMinimum INT OUTPUT
	,@PackageDiscount DECIMAL(5, 4) OUTPUT
	,@PartnerSplit DECIMAL(5, 4) OUTPUT
	,@DefaultPackageStartDate DATE OUTPUT
	,@DefaultPackageEndDate DATE OUTPUT
	,@Note VARCHAR(MAX) OUTPUT
	AS
	DECLARE @base_license_id INT = 5

--***************************************************************************************************************************************************
--- Input validation on PrevClientID and PrevPackageChangeID entered:
----***************************************************************************************************************************************************
-- Section commented b/c these checks are already done in prev lic. pull and don't need to show to the user twice... to re-enable also uncomment
-- last block of code at the bottom of file.

--	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''
	
--	IF (NOT EXISTS(SELECT TOP 1 1 FROM [billing].[TEST_LicensePackageHeader] WHERE PackageID = @PrevLicensePackageID))
--	BEGIN
--		SET @ErrorMessageToUser = 'Previous license package ID entered ("' + CONVERT(VARCHAR, @PrevLicensePackageID) + '") does not exist.'
--									+ ' Please search for an existing package using the License Package Finder and try again.'
--		GOTO FinalResponseToUser
--	END
--	ELSE IF (NOT EXISTS(SELECT TOP 1 1 FROM [billing_history].[TEST_LicensePackageHeaderLog]
--					WHERE PackageID = @PrevLicensePackageID AND HeaderChangeID = @PrevLicensePackageChangeID))
--	BEGIN
--		SET @ErrorMessageToUser = 'Previous license package ID entered ("' + CONVERT(VARCHAR, @PrevLicensePackageID)
--									+ '") does not have a history entry #' + CONVERT(VARCHAR, @PrevLicensePackageChangeID)
--									+ '. Please use the License Package Finder to search for a valid ChangeID for this Package.'
--		GOTO FinalResponseToUser
--	END

--***************************************************************************************************************************************************
-- Set the active license info... (pulled the same whether autofilling on or off):
--***************************************************************************************************************************************************
	SELECT
		@ClientName = c.ClientName
		,@ClientPartnerName = cp.ClientName
		,@Location = lph.Location
	FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
		LEFT JOIN [Interject_Demos_Students].[app].[Client] c
			ON lph.ClientID = c.ClientID
		LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [Interject_Demos_Students].[app].[Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
	WHERE lph.PackageID = @LicensePackageID

--***************************************************************************************************************************************************
--- Input validation for editing mode/autofill flags:
--***************************************************************************************************************************************************
	/* Lic. editing mode = ON is used to edit a license that has already been worked on in the invoice builder previously.
	Whatever the current state of the data for the active license package is what is pulled in. */
	DECLARE @EditingEnabled BIT
	EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
	@InputString = @EnableEditingModeString
	,@Result = @EditingEnabled OUTPUT

	DECLARE @AutofillHeader BIT
	EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
	@InputString = @AutofillPrevHeaderString
	,@Result = @AutofillHeader OUTPUT

	DECLARE @AutofillItems BIT
	EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
	@InputString = @AutofillPrevItemsString
	,@Result = @AutofillItems OUTPUT

--***************************************************************************************************************************************************
--- Header info pull:
--***************************************************************************************************************************************************

/* NO AUTOFILLING: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@EditingEnabled = 1 OR @AutofillHeader = 0)
	BEGIN
		SELECT
			@LicensedUsers = lpd_base.Quantity
			,@UserMinimum = lph.UserMinimum
			,@BaseInterjectPrice = lpd_base.Price
			,@PartnerSplit = lpcp.PartnerSplitPercentage
			,@PackageDiscount = lph.PackageDiscount
			,@DefaultPackageStartDate = lph.LicenseStartDate
			,@DefaultPackageEndDate = lph.LicenseExpirationDate
			,@Note = lpn.Note
		FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd_base
				ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @base_license_id
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageClientPartner] lpcp
				ON lph.PackageID = lpcp.PackageID
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageNote] lpn
				ON lph.PackageID = lpn.PackageID
		WHERE lph.PackageID = @LicensePackageID
	END

/* AUTOFILL from prev. lic input variables for @PrevLicensePackageID and @PrevLicensePackageChangeID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@EditingEnabled = 0 AND @AutofillHeader = 1)
	BEGIN
		/* Check if there is an entry in hist. which matches ChangeID provided: */
		IF ((EXISTS(SELECT TOP 1 1 FROM [billing_history].[TEST_LicensePackageChangeLog]
			WHERE PackageID = @PrevLicensePackageID AND ChangeID = @PrevLicensePackageChangeID)) AND (@PrevLicensePackageChangeID <> 0))
		BEGIN
			/* Pull from history tables: */
			SELECT
				@LicensedUsers = lpd_l_base.Quantity
				,@UserMinimum = lph_l.UserMinimum
				,@BaseInterjectPrice = lpd_l_base.Price
				,@PartnerSplit = lpcp_l.PartnerSplit
				,@PackageDiscount = lph_l.PackageDiscount
				,@DefaultPackageStartDate = DATEADD(DAY, 1, lph_l.LicenseExpirationDate)
				,@DefaultPackageEndDate = DATEADD(MONTH, (DATEDIFF(MONTH, lph_l.LicenseStartDate, lph_l.LicenseExpirationDate)),
													(DATEADD(DAY, 1, lph_l.LicenseExpirationDate)))
				,@Note = lpn_l.Note
			FROM [billing_history].[TEST_LicensePackageChangeLog] lpcl
				LEFT JOIN [billing_history].[TEST_LicensePackageHeaderLog] lph_l
					ON lpcl.PackageID = lph_l.PackageID AND lpcl.HeaderChangeID = lph_l.HeaderChangeID
				LEFT JOIN [billing_history].[TEST_LicensePackageDetailLog] lpd_l_base
					ON ((lpcl.PackageID = lpd_l_base.PackageID) 
						AND (lpcl.DetailGroupChangeID = lpd_l_base.DetailGroupChangeID)
						AND (lpd_l_base.ItemID = @base_license_id))
				LEFT JOIN [Interject_Demos_Students].[billing_history].[TEST_LicensePackageClientPartnerLog] lpcp_l
					ON lph_l.PackageID = lpcp_l.PackageID AND lpcl.ClientPartnerChangeID = lpcp_l.ClientPartnerChangeID
				LEFT JOIN [Interject_Demos_Students].[billing_history].[TEST_LicensePackageNoteLog] lpn_l
					ON lpcl.PackageID = lpn_l.PackageID AND lpcl.ChangeID = lpn_l.LicPackageChangeID
			WHERE lpcl.PackageID = @PrevLicensePackageID
				AND lpcl.ChangeID = @PrevLicensePackageChangeID
		END
		ELSE BEGIN
			/* No match from hist., so pull from main: */
			SELECT
				@LicensedUsers = lpd_base.Quantity
				,@UserMinimum = lph.UserMinimum
				,@BaseInterjectPrice = lpd_base.Price
				,@PartnerSplit = lpcp.PartnerSplitPercentage
				,@PackageDiscount = lph.PackageDiscount
				,@DefaultPackageStartDate = DATEADD(DAY, 1, lph.LicenseExpirationDate)
				,@DefaultPackageEndDate = DATEADD(MONTH, (DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate)),
													(DATEADD(DAY, 1, lph.LicenseExpirationDate)))
				,@Note = lpn.Note
			FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
				LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd_base
					ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @base_license_id
				LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageClientPartner] lpcp
					ON lph.PackageID = lpcp.PackageID
				LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageNote] lpn
					ON lph.PackageID = lpn.PackageID
			WHERE lph.PackageID = @PrevLicensePackageID
		END
	END

--**************************************************************************************************************************
--- Line items pull:
--**************************************************************************************************************************

/* NO AUTOFILLING: */
----------------------------------------------------------------------------------------------------------------------------
	IF (@EditingEnabled = 1 OR @AutofillItems = 0)
	BEGIN
		SELECT
			--'' AS EndOfListKey
			i.ItemName
			,lpd.Price AS ItemPrice
			,lpd.Quantity
			,lpd.Discount AS ItemDiscount
			,lpd.LicenseFactor
		FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_Item] i
				ON lpd.ItemID = i.ItemID
		WHERE lpd.PackageID = @LicensePackageID
		UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
	END

/* AUTOFILL line items from history or main prev package tables: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@EditingEnabled = 0 AND @AutofillItems = 1)
	BEGIN
		/* Check if entry in hist.: */
		IF (EXISTS(SELECT TOP 1 1 FROM [billing_history].[TEST_LicensePackageChangeLog]
					WHERE PackageID = @PrevLicensePackageID AND ChangeID = @PrevLicensePackageChangeID) AND (@PrevLicensePackageChangeID <> 0))
		BEGIN
			/* Fill line items based on a history entry: */
			SELECT
				ItemName
				,((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor) AS ItemPrice
				,Quantity AS Quantity
				,Discount AS ItemDiscount
				,LicenseFactor
			FROM [Interject_Demos_Students].[billing_history].[TEST_LicensePackageChangeVersionItems] lpcvi
				LEFT JOIN [Interject_Demos_Students].[billing_history].[TEST_LicensePackageDetailLog] lpd_l
					ON lpcvi.LicensePackageID = lpd_l.PackageID
						AND lpcvi.LatestDetailGroupChangeID = lpd_l.DetailGroupChangeID
						AND lpcvi.ItemID = lpd_l.ItemID
				LEFT JOIN [billing].[TEST_Item] i
					ON lpd_l.ItemID = i.ItemID
			WHERE lpcvi.LicensePackageID = @PrevLicensePackageID
				AND lpcvi.LicensePackageChangeID = @PrevLicensePackageChangeID
			--SELECT
			--	i_cv.ItemName
			--	,((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor) AS ItemPrice
			--	,lpd_l.Quantity AS Quantity
			--	,lpd_l.Discount AS ItemDiscount
			--	,lpd_l.LicenseFactor
			--FROM [Interject_Demos_Students].[billing_history].[TEST_LicensePackageChangeLog] lpcl
			--	LEFT JOIN [Interject_Demos_Students].[billing_history].[TEST_LicensePackageChangeVersionItems] lpcvi
			--		ON lpcl.PackageID = lpcvi.LicensePackageID AND lpcl.ChangeID = lpcvi.LicensePackageChangeID
			--	LEFT JOIN [billing].[TEST_Item] i_cv --change version (items from change ver. log)
			--		ON lpcvi.ItemID = i_cv.ItemID
			--	LEFT JOIN (SELECT
			--					-- Paried with the ON clause below, this partition selects the 
			--					ROW_NUMBER() OVER (PARTITION BY DetailGroupChangeID, ItemID) AS RowNum -- ORDER BY DetailItemChangeID DESC
			--					,DetailGroupChangeID
			--					,ItemID
			--					,((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor) AS NextPackagePrice
			--					,Quantity
			--					,Discount AS ItemDiscount
			--					,LicenseFactor
			--				FROM [billing_history].[TEST_LicensePackageDetailLog]
			--				WHERE PackageID = @LicensePackageID) latest_item_info
			--		ON latest_item_info.RowNum = 1
			--	--LEFT JOIN [billing_history].[TEST_LicensePackageDetailLog] lpd_l
			--			AND lpcl.DetailGroupChangeID = latest_item_info.DetailGroupChangeID
			--			AND lpcvi.ItemID = latest_item_info.ItemID
			--WHERE lpcl.PackageID = @PrevLicensePackageID
			--	AND lpcl.ChangeID = @PrevLicensePackageChangeID
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
		END
		ELSE BEGIN
			/* Fill line items based on a main table entry: */
			SELECT
				--'' AS EndOfListKey
				i.ItemName
				,((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor) AS ItemPrice
				,lpd.Quantity
				,lpd.Discount AS ItemDiscount
				,lpd.LicenseFactor
			FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd
				LEFT JOIN [Interject_Demos_Students].[billing].[TEST_Item] i
					ON lpd.ItemID = i.ItemID
			WHERE lpd.PackageID = @PrevLicensePackageID
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
			UNION ALL
			SELECT
				''
				,NULL
				,NULL
				,NULL
				,NULL
		END
	END

--***************************************************************************************************************************************************
-- Final response if errors occurred:
--***************************************************************************************************************************************************
	--FinalResponseToUser:
	--	IF @ErrorMessageToUser <> ''
	--	BEGIN
	--		-- by adding 'UserNotice:' as a prefix to the message, Interject will not consider it a unhandled error 
	--		-- and will present the error to the user in a message box.
	--		SET @ErrorMessageToUser = 'UserNotice:' + @ErrorMessageToUser
        
	--		RAISERROR (@ErrorMessageToUser,
	--		18, -- Severity,
	--		1) -- State)
	--		RETURN
	--	END