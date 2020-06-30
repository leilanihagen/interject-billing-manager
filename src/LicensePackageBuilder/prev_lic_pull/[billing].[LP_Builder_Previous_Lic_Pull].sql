/*
USE [Interject_Demos_Students]
*/

/*
Declare @ClientName nvarchar(max)
Declare @ClientPartnerName nvarchar(max)
Declare @Location nvarchar(max)
Declare @LicensedUsers int
Declare @UserMinimum int
Declare @BaseInterjectPrice money
Declare @PartnerSplitPercentage float
Declare @PackageDiscount float
Declare @LicenseTermMonths int
Declare @LicenseStartDate date
Declare @LicenseExpirationDate date
Declare @Note varchar(max)

Execute [billing].[LP_Builder_Previous_Lic_Pull]
@LicensePackageID = 74
,@LicensePackageChangeID = 1
,@ClientName = @ClientName output
,@ClientPartnerName = @ClientPartnerName output
,@Location = @Location output
,@LicensedUsers = @LicensedUsers output
,@BaseInterjectPrice = @BaseInterjectPrice output
,@LicenseTermMonths = @LicenseTermMonths output
,@UserMinimum = @UserMinimum output
,@PackageDiscount = @PackageDiscount output
,@PartnerSplitPercentage = @PartnerSplitPercentage output
,@LicenseStartDate = @LicenseStartDate output
,@LicenseExpirationDate = @LicenseExpirationDate output
,@Note = @Note output

Select @ClientName as '@ClientName'
,@ClientPartnerName as '@ClientPartnerName'
,@Location as '@Location'
,@LicensedUsers as '@LicensedUsers'
,@UserMinimum as '@UserMinimum'
,@BaseInterjectPrice as '@BaseInterjectPrice'
,@PartnerSplitPercentage as '@PartnerSplitPercentage'
,@PackageDiscount as '@PackageDiscount'
,@LicenseTermMonths as '@LicenseTermMonths'
,@LicenseStartDate as '@LicenseStartDate'
,@LicenseExpirationDate as '@LicenseExpirationDate'
,@Note as '@Note'
*/

ALTER PROC [billing].[LP_Builder_Previous_Lic_Pull]
/* Add functionality to query to search hisotry tables IF a ChangeID is provided.*/
@LicensePackageID INT
,@LicensePackageChangeID INT
/* Header info: */
,@ClientName NVARCHAR(500) OUTPUT
,@ClientPartnerName NVARCHAR(500) OUTPUT
,@Location NVARCHAR(200) OUTPUT
,@LicensedUsers INT OUTPUT
,@BaseInterjectPrice MONEY OUTPUT
,@LicenseTermMonths INT OUTPUT
,@UserMinimum INT OUTPUT
,@PackageDiscount DECIMAL(5, 4) OUTPUT
,@PartnerSplitPercentage DECIMAL(5, 4) OUTPUT
,@LicenseStartDate DATE OUTPUT
,@LicenseExpirationDate DATE OUTPUT
,@Note VARCHAR(MAX) OUTPUT
AS
	DECLARE @base_license_id INT = 5

--***************************************************************************************************************************************************
--- Input validation on ClientID and PackageChangeID entered:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''
	
	IF ((NOT EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageHeader] WHERE PackageID = @LicensePackageID))
		AND (@LicensePackageID <> 0))
	BEGIN
		SET @ErrorMessageToUser = 'Previous license package ID entered ("' + CONVERT(VARCHAR, @LicensePackageID) + '") does not exist.'
									+ ' Please search for an existing package using the LicensePackageFinder and try again.'
		GOTO FinalResponseToUser
	END
	ELSE IF ((NOT EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
					WHERE PackageID = @LicensePackageID AND ChangeID = @LicensePackageChangeID))
				AND @LicensePackageChangeID <> 0)
	BEGIN
		SET @ErrorMessageToUser = 'Previous license package ID entered ("' + CONVERT(VARCHAR, @LicensePackageID)
									+ '") does not have a history entry #' + CONVERT(VARCHAR, @LicensePackageChangeID)
									+ '. Please use the LicensePackageFinder to search for a valid ChangeID for this Package.'
		GOTO FinalResponseToUser
	END

--***************************************************************************************************************************************************
--- Set the output vars (header info):
--***************************************************************************************************************************************************
	/* Check if history should be the source: */
	IF (EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
				WHERE PackageID = @LicensePackageID AND ChangeID = @LicensePackageChangeID) AND (@LicensePackageChangeID <> 0))
	BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull header info from HISTORY: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		SELECT
			@ClientName = c.ClientName
			,@ClientPartnerName = cp.ClientName
			,@Location = lph_l.Location
			,@LicensedUsers = lpd_l_base.Quantity
			,@UserMinimum = lph_l.UserMinimum
			,@BaseInterjectPrice = lpd_l_base.Price
			,@PartnerSplitPercentage = lpcp_l.PartnerSplitPercentage
			,@LicenseTermMonths = DATEDIFF(month, lph_l.LicenseStartDate, lph_l.LicenseExpirationDate)
			,@PackageDiscount = lph_l.PackageDiscount
			,@LicenseStartDate = lph_l.LicenseStartDate
			,@LicenseExpirationDate = lph_l.LicenseExpirationDate
			,@Note = lpn_l.Note
		FROM [billing_history].[LicensePackageChangeLog] lpcl
			LEFT JOIN [billing_history].[LicensePackageHeaderLog] lph_l
				ON lpcl.PackageID = lph_l.PackageID AND lpcl.HeaderChangeID = lph_l.HeaderChangeID
			LEFT JOIN [billing_history].[LicensePackageDetailLog] lpd_l_base
				ON lpcl.PackageID = lpd_l_base.PackageID AND lpcl.DetailGroupChangeID = lpd_l_base.DetailGroupChangeID AND lpd_l_base.ItemID = @base_license_id
			LEFT JOIN [app].[Client] c
				ON lph_l.ClientID = c.ClientID
			LEFT JOIN [billing_history].[LicensePackageClientPartnerLog] lpcp_l
				ON lph_l.PackageID = lpcp_l.PackageID AND lpcl.ClientPartnerChangeID = lpcp_l.ClientPartnerChangeID
			LEFT JOIN [app].[Client] cp --client partner
				ON lpcp_l.ClientPartnerID = cp.ClientID
			LEFT JOIN [billing_history].[LicensePackageNoteLog] lpn_l
				ON lpcl.PackageID = lpn_l.PackageID AND lpcl.ChangeID = lpn_l.LicPackageChangeID
		WHERE lpcl.PackageID = @LicensePackageID
			AND lpcl.ChangeID = @LicensePackageChangeID
	END
	ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull header info from MAIN tables: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		SELECT
			@ClientName = c.ClientName
			,@ClientPartnerName = cp.ClientName
			,@Location = lph.Location
			,@LicensedUsers = lpd_base.Quantity
			,@UserMinimum = lph.UserMinimum
			,@BaseInterjectPrice = lpd_base.Price
			,@PartnerSplitPercentage = lpcp.PartnerSplitPercentage
			,@LicenseTermMonths = DATEDIFF(month, lph.LicenseStartDate, lph.LicenseExpirationDate)
			,@PackageDiscount = lph.PackageDiscount
			,@LicenseStartDate = lph.LicenseStartDate
			,@LicenseExpirationDate = lph.LicenseExpirationDate
			,@Note = lpn.Note
		FROM [billing].[LicensePackageHeader] lph
			LEFT JOIN [billing].[LicensePackageDetail] lpd_base
				ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @base_license_id
			LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
				ON lph.PackageID = lpcp.PackageID
			LEFT JOIN [app].[Client] c
				ON lph.ClientID = c.ClientID
			LEFT JOIN [app].[Client] cp --client partner
				ON lpcp.ClientPartnerID = cp.ClientID
			LEFT JOIN [billing].[LicensePackageNote] lpn
				ON lph.PackageID = lpn.PackageID
		WHERE lph.PackageID = @LicensePackageID
	END

--***************************************************************************************************************************************************
--- Select the line items:
--***************************************************************************************************************************************************
	/* Check if hist. should be the source: */
	IF (EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
				WHERE PackageID = @LicensePackageID AND ChangeID = @LicensePackageChangeID) AND (@LicensePackageChangeID <> 0))
	BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull line items from HISTORY: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		SELECT
				ItemName
				,Price AS ItemPrice
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
			WHERE lpci.LicensePackageID = @LicensePackageID
				AND lpci.LicensePackageChangeID = @LicensePackageChangeID
	END
	ELSE BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Pull line items from MAIN tables: */
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
	END

--***************************************************************************************************************************************************
-- Final response if errors occurred:
--***************************************************************************************************************************************************
	FinalResponseToUser:
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