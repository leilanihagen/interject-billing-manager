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

EXEC [billing].[TEST_Lic_Report_Invoice_Current_Lic_Pull]
@LicensePackageID = 20
,@ClientName = @ClientName OUTPUT
,@ClientPartnerName = @ClientPartnerName OUTPUT
,@Location = @Location OUTPUT
,@LicensedUsers = @LicensedUsers OUTPUT
,@UserMinimum = @UserMinimum OUTPUT
,@BaseInterjectPrice = @BaseInterjectPrice OUTPUT
,@PartnerSplit = @PartnerSplit OUTPUT
,@PackageDiscount = @PackageDiscount OUTPUT
,@DefaultPackageStartDate = @DefaultPackageStartDate OUTPUT

SELECT
@ClientName
,@ClientPartnerName
,@LicensedUsers
,@UserMinimum
,@BaseInterjectPrice
,@PartnerSplit
,@PackageDiscount
,@DefaultPackageStartDate
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
	,@AutofillPrevHeaderString NVARCHAR(10)
	,@AutofillPrevItemsString NVARCHAR(10)
	,@EnableEditingModeString NVARCHAR(10)
	/* Header info: */
	,@ClientName NVARCHAR(500) OUTPUT
	,@ClientPartnerName NVARCHAR(500) OUTPUT
	,@Location NVARCHAR(200) OUTPUT
	,@LicensedUsers INT OUTPUT
	,@UserMinimum INT OUTPUT
	,@BaseInterjectPrice MONEY OUTPUT
	,@PartnerSplit DECIMAL(5, 4) OUTPUT
	,@PackageDiscount DECIMAL(5, 4) OUTPUT
	,@DefaultPackageStartDate DATE OUTPUT
	,@Note VARCHAR(MAX) OUTPUT
	AS
	DECLARE @base_license_id INT = 5

--**************************************************************************************************************************
-- Set the active license info... (pulled the same whether autofilling on or off):
--**************************************************************************************************************************
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

--**************************************************************************************************************************
--- Input validation for LIC. EDITING MODE:
--**************************************************************************************************************************
	DECLARE @EditingEnabled BIT
	EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
	@InputString = @EnableEditingModeString
	,@Result = @EditingEnabled OUTPUT

--**************************************************************************************************************************
--- LIC. EDITING MODE = ON pull:
--**************************************************************************************************************************
/* Lic. editing mode = ON is used to edit a license that has already been worked on in the invoice builder
previously. Whatever the current state of the data for the active license package is what is pulled
in to the active license section. No autofilling from previous license is pulled, and line items are
not cleared. */
	IF @EditingEnabled = 1
	BEGIN
/* Query to set the header info: */
----------------------------------------------------------------------------------------------------------------------------
		SELECT
			@LicensedUsers = lpd_base.Quantity
			,@UserMinimum = lph.UserMinimum
			,@BaseInterjectPrice = lpd_base.Price
			,@PartnerSplit = lpcp.PartnerSplitPercentage
			,@PackageDiscount = lph.PackageDiscount
			,@DefaultPackageStartDate = CONVERT(DATE, GETDATE())
			,@Note = lpn.Note
		FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd_base
				ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @base_license_id
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageClientPartner] lpcp
				ON lph.PackageID = lpcp.PackageID
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageNote] lpn
				ON lph.PackageID = lpn.PackageID
		WHERE lph.PackageID = @LicensePackageID
/* Query to select the line items: */
----------------------------------------------------------------------------------------------------------------------------
		SELECT
			i.ItemName
			,lpd.Price AS ItemPrice
			,lpd.Quantity
			,lpd.Discount AS ItemDiscount
			,lpd.LicenseFactor
		FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_Item] i
				ON lpd.ItemID = i.ItemID
		WHERE lpd.PackageID = @LicensePackageID
	END
--**************************************************************************************************************************
-- LIC. EDITING MODE = OFF pull:
--**************************************************************************************************************************
/* When lic. editing mode = OFF, the user is entering a new license renewal. Autofilling from previous
license package information to active header and line items is available, but if autofilling is turned
off for header or line items, the respective section will be left blank. */
	ELSE
	BEGIN
/* Input validation for whether or not to autofill header and line items: */
----------------------------------------------------------------------------------------------------------------------------
		DECLARE @AutofillHeader BIT
		EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
		@InputString = @AutofillPrevHeaderString
		,@Result = @AutofillHeader OUTPUT

		DECLARE @AutofillItems BIT
		EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
		@InputString = @AutofillPrevItemsString
		,@Result = @AutofillItems OUTPUT

/* Select header info: */
----------------------------------------------------------------------------------------------------------------------------
		DECLARE @HeaderBasisPackageID INT
		IF @AutofillHeader = 1 --AND @PrevLicensePackageChangeID = NULL --not null then pull from hist. (add another case)
		BEGIN
			SET @HeaderBasisPackageID = @PrevLicensePackageID
		END
		ELSE BEGIN
			SET @HeaderBasisPackageID = @LicensePackageID
		END
		/* IMPORTANT: Add functionality for pulling from history tables with PrevLicChangeID: */
		SELECT
			@LicensedUsers = lpd.Quantity
			,@UserMinimum = lph.UserMinimum
			,@BaseInterjectPrice = lpd.Price
			,@PartnerSplit = lpcp.PartnerSplitPercentage
			,@PackageDiscount = lph.PackageDiscount
			,@DefaultPackageStartDate = CONVERT(DATE, GETDATE())
			,@Note = lpn.Note
		FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd
				ON lph.PackageID = lpd.PackageID
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageClientPartner] lpcp
				ON lph.PackageID = lpcp.PackageID
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageNote] lpn
			ON lph.PackageID = lpn.PackageID
		WHERE lph.PackageID = @HeaderBasisPackageID
			AND lpd.ItemID = @base_license_id

/* Select line items: */
----------------------------------------------------------------------------------------------------------------------------
		DECLARE @ItemsBasisPackageID INT -- either active license or prev license depending on value of @AutofillItems
		IF @AutofillItems = 1 --AND @PrevLicensePackageChangeID = NULL
		BEGIN
			SET @ItemsBasisPackageID = @PrevLicensePackageID
		END
		ELSE BEGIN
			SET @ItemsBasisPackageID = @LicensePackageID
		END
		SELECT
			i.ItemName
			,lpd.Price + (lpd.Price*lpd.LicenseFactor) AS ItemPrice
			,lpd.Quantity
			,lpd.Discount AS ItemDiscount
			,lpd.LicenseFactor
		FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd
				ON lph.PackageID = lpd.PackageID
			LEFT JOIN [Interject_Demos_Students].[billing].[TEST_Item] i
				ON lpd.ItemID = i.ItemID
		WHERE lph.PackageID = @ItemsBasisPackageID

	END