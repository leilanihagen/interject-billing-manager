/*
USE [Interject_Demos_Students]
*/

ALTER PROC [billing].[LP_Builder_Active_Lic_Pull]
/* 
	USER STORY: use license search sheets (either the expiring licenses one or the general search)
	to find the license you would like to modify, then drill to the invoice sheet where it can be 
	modified. This procedure pulls in the current/active license info to be modified in the invoice
	sheet.
*/
	@LicensePackageID INT
	,@PrevLicensePackageID INT
	,@PrevLicensePackageChangeID INT
	,@ClientName NVARCHAR(500) OUTPUT
	,@ClientPartnerName NVARCHAR(500) OUTPUT
	,@Location NVARCHAR(200) OUTPUT
	,@AutofillPrevHeaderString NVARCHAR(10)
	,@AutofillPrevItemsString NVARCHAR(10)
	/* Header info: */
	,@LicensedUsers INT OUTPUT
	,@BaseInterjectPrice MONEY OUTPUT
	,@UserMinimum INT OUTPUT
	,@PackageDiscount DECIMAL(5, 4) OUTPUT
	,@PartnerSplitPercentage DECIMAL(5, 4) OUTPUT
	,@DefaultPackageStartDate DATE OUTPUT
	,@DefaultPackageEndDate DATE OUTPUT
	,@Note VARCHAR(MAX) OUTPUT
	AS
	DECLARE @base_license_id INT = 5

--***************************************************************************************************************************************************
-- Set the active license info. (pulled the same whether autofilling on or off):
--***************************************************************************************************************************************************
	SELECT
		@ClientName = c.ClientName
		,@ClientPartnerName = cp.ClientName
		,@Location = lph.Location
	FROM [billing].[LicensePackageHeader] lph
		LEFT JOIN [app].[Client] c
			ON lph.ClientID = c.ClientID
		LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [app].[Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
	WHERE lph.PackageID = @LicensePackageID

--***************************************************************************************************************************************************
--- Input validation for editing mode/autofill flags:
--***************************************************************************************************************************************************
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

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* AUTOFILLING OFF: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@AutofillHeader = 0)
	BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull header info from ACTIVE PackageID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		SELECT
			@LicensedUsers = lpd_base.Quantity
			,@UserMinimum = lph.UserMinimum
			,@BaseInterjectPrice = lpd_base.Price
			,@PartnerSplitPercentage = lpcp.PartnerSplitPercentage
			,@PackageDiscount = lph.PackageDiscount
			,@DefaultPackageStartDate = lph.LicenseStartDate
			,@DefaultPackageEndDate = lph.LicenseExpirationDate
			,@Note = lpn.Note
		FROM [billing].[LicensePackageHeader] lph
			LEFT JOIN [billing].[LicensePackageDetail] lpd_base
				ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @base_license_id
			LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
				ON lph.PackageID = lpcp.PackageID
			LEFT JOIN [billing].[LicensePackageNote] lpn
				ON lph.PackageID = lpn.PackageID
		WHERE lph.PackageID = @LicensePackageID
	END

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* AUTOFILLING ON: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@AutofillHeader = 1)
	BEGIN
		/* Check if there is an entry in hist. which matches ChangeID provided: */
		IF ((EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
			WHERE PackageID = @PrevLicensePackageID AND ChangeID = @PrevLicensePackageChangeID)) AND (@PrevLicensePackageChangeID <> 0))
		BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull header info from a HISTORY entry in Comparison pkgID and ChangeID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			SELECT
				@LicensedUsers = lpd_l_base.Quantity
				,@UserMinimum = lph_l.UserMinimum
				,@BaseInterjectPrice = lpd_l_base.Price
				,@PartnerSplitPercentage = lpcp_l.PartnerSplitPercentage
				,@PackageDiscount = lph_l.PackageDiscount
				,@DefaultPackageStartDate = DATEADD(DAY, 1, lph_l.LicenseExpirationDate)
				,@DefaultPackageEndDate = DATEADD(MONTH, (DATEDIFF(MONTH, lph_l.LicenseStartDate, lph_l.LicenseExpirationDate)),
													(DATEADD(DAY, 1, lph_l.LicenseExpirationDate)))
				,@Note = lpn_l.Note
			FROM [billing_history].[LicensePackageChangeLog] lpcl
				LEFT JOIN [billing_history].[LicensePackageHeaderLog] lph_l
					ON lpcl.PackageID = lph_l.PackageID AND lpcl.HeaderChangeID = lph_l.HeaderChangeID
				LEFT JOIN [billing_history].[LicensePackageDetailLog] lpd_l_base
					ON ((lpcl.PackageID = lpd_l_base.PackageID) 
						AND (lpcl.DetailGroupChangeID = lpd_l_base.DetailGroupChangeID)
						AND (lpd_l_base.ItemID = @base_license_id))
				LEFT JOIN [billing_history].[LicensePackageClientPartnerLog] lpcp_l
					ON lph_l.PackageID = lpcp_l.PackageID AND lpcl.ClientPartnerChangeID = lpcp_l.ClientPartnerChangeID
				LEFT JOIN [billing_history].[LicensePackageNoteLog] lpn_l
					ON lpcl.PackageID = lpn_l.PackageID AND lpcl.ChangeID = lpn_l.LicPackageChangeID
			WHERE lpcl.PackageID = @PrevLicensePackageID
				AND lpcl.ChangeID = @PrevLicensePackageChangeID
		END
		ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull header info from MAIN table based on Comparison pkgID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			SELECT
				@LicensedUsers = lpd_base.Quantity
				,@UserMinimum = lph.UserMinimum
				,@BaseInterjectPrice = lpd_base.Price
				,@PartnerSplitPercentage = lpcp.PartnerSplitPercentage
				,@PackageDiscount = lph.PackageDiscount
				,@DefaultPackageStartDate = DATEADD(DAY, 1, lph.LicenseExpirationDate)
				,@DefaultPackageEndDate = DATEADD(MONTH, (DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate)),
													(DATEADD(DAY, 1, lph.LicenseExpirationDate)))
				,@Note = lpn.Note
			FROM [billing].[LicensePackageHeader] lph
				LEFT JOIN [billing].[LicensePackageDetail] lpd_base
					ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @base_license_id
				LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
					ON lph.PackageID = lpcp.PackageID
				LEFT JOIN [billing].[LicensePackageNote] lpn
					ON lph.PackageID = lpn.PackageID
			WHERE lph.PackageID = @PrevLicensePackageID
		END
	END

--***************************************************************************************************************************************************
--- Line items pull:
--***************************************************************************************************************************************************

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* AUTOFILLING OFF: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@AutofillItems = 0)
	BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull items from ACTIVE PackageID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		SELECT
			i.ItemName
			,lpd.Price AS ItemPrice
			,lpd.Quantity
			,lpd.Discount AS ItemDiscount
			,lpd.LicenseFactor
		FROM [billing].[LicensePackageDetail] lpd
			LEFT JOIN [billing].[Item] i
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

-----------------------------------------------------------------------------------------------------------------------------------------------------
/* AUTOFILLING ON: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	IF (@AutofillItems = 1)
	BEGIN
		/* Check if entry in hist.: */
		IF (EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
					WHERE PackageID = @PrevLicensePackageID AND ChangeID = @PrevLicensePackageChangeID) AND (@PrevLicensePackageChangeID <> 0))
		BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Fill line items based on a HISTORY entry from Comparison pkgID and ChangeID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			SELECT
				ItemName
				,((Price + Price*LicenseFactor)*(1 - Discount)) AS ItemPrice
				,Quantity AS Quantity
				,Discount AS ItemDiscount
				,LicenseFactor
			FROM [billing_history].[LicensePackageChangeItems] lpci
				LEFT JOIN [billing_history].[LicensePackageDetailLog] lpd_l
					ON lpci.LicensePackageID = lpd_l.PackageID
						AND lpci.LatestDetailGroupChangeID = lpd_l.DetailGroupChangeID
						AND lpci.ItemID = lpd_l.ItemID
				LEFT JOIN [billing].[Item] i
					ON lpd_l.ItemID = i.ItemID
			WHERE lpci.LicensePackageID = @PrevLicensePackageID
				AND lpci.LicensePackageChangeID = @PrevLicensePackageChangeID
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
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Fill line items based on MAIN table entry from Comparison pkgID: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
			SELECT
				i.ItemName
				,((Price + Price*LicenseFactor)*(1 - Discount)) AS ItemPrice
				,lpd.Quantity
				,lpd.Discount AS ItemDiscount
				,lpd.LicenseFactor
			FROM [billing].[LicensePackageDetail] lpd
				LEFT JOIN [billing].[Item] i
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

