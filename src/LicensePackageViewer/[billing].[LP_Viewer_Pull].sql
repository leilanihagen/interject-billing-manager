/*
USE [Interject_Demos_Students]
*/

/*
Declare @LicensePackageStartDate date = '10-01-2019'
Declare @LicensePackageExpirationDate date = '12-31-2019'
Declare @ClientName nvarchar(max) = 'HP Inc.'
Declare @ClientAddress nvarchar(max) = '1115 SE 164th Ave'
Declare @BillingContactName nvarchar(max)
Declare @BillingPhoneNumber varchar(max) = '3607989181'
Declare @BillingEmail nvarchar(max)
Declare @PackageTerm int = 2
Declare @PackageDiscount float = 0

Execute [billing].[LP_Viewer_Pull]
@PackageID = 68
,@PackageChangeID = NULL
,@LicensePackageStartDate = @LicensePackageStartDate output
,@LicensePackageExpirationDate = @LicensePackageExpirationDate output
,@ClientName = @ClientName output
,@ClientAddress = @ClientAddress output
,@BillingContactName = @BillingContactName output
,@BillingPhoneNumber = @BillingPhoneNumber output
,@BillingEmail = @BillingEmail output
,@PackageTerm = @PackageTerm output
,@PackageDiscount = @PackageDiscount output

Select 	@LicensePackageStartDate as '@LicensePackageStartDate'
,@LicensePackageExpirationDate as '@LicensePackageExpirationDate'
,@ClientName as '@ClientName'
,@ClientAddress as '@ClientAddress'
,@BillingContactName as '@BillingContactName'
,@BillingPhoneNumber as '@BillingPhoneNumber'
,@BillingEmail as '@BillingEmail'
,@PackageTerm as '@PackageTerm'
,@PackageDiscount as '@PackageDiscount'
*/

ALTER PROC [billing].[LP_Viewer_Pull]
@PackageID INT
,@PackageChangeID INT
,@LicensePackageStartDate DATE OUTPUT
,@LicensePackageExpirationDate DATE OUTPUT
--,@PackageTermText VARCHAR(9) OUTPUT
,@ClientName NVARCHAR(200) OUTPUT
,@ClientAddress NVARCHAR(200) OUTPUT
,@BillingContactName NVARCHAR(200) OUTPUT
,@BillingPhoneNumber VARCHAR(20) OUTPUT
,@BillingEmail VARCHAR(50) OUTPUT
,@PackageTerm INT OUTPUT
,@PackageDiscount DECIMAL(5,4) OUTPUT
AS
--***************************************************************************************************************************************************
--- Input validation on ClientID and PackageChangeID entered:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''
	
	IF ((NOT EXISTS(SELECT TOP 1 1 FROM [billing].[LicensePackageHeader] WHERE PackageID = @PackageID))
		AND (@PackageID <> 0))
	BEGIN
		SET @ErrorMessageToUser = 'Previous license package ID entered ("' + CONVERT(VARCHAR, @PackageID) + '") does not exist.'
									+ ' Please search for an existing package using the LicensePackageFinder and try again.'
		GOTO FinalResponseToUser
	END
	ELSE IF ((NOT EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
					WHERE PackageID = @PackageID AND ChangeID = @PackageChangeID))
				AND @PackageChangeID <> 0)
	BEGIN
		SET @ErrorMessageToUser = 'Previous license package ID entered ("' + CONVERT(VARCHAR, @PackageID)
									+ '") does not have a history entry #' + CONVERT(VARCHAR, @PackageChangeID)
									+ '. Please use the LicensePackageFinder to search for a valid ChangeID for this Package.'
		GOTO FinalResponseToUser
	END

--***************************************************************************************************************************************************
-- Set header info:
--***************************************************************************************************************************************************
	IF (EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
				WHERE PackageID = @PackageID AND ChangeID = @PackageChangeID) AND (@PackageChangeID <> 0))
	BEGIN
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get header info from HISTORY: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		SELECT
			@LicensePackageStartDate = lph_l.LicenseStartDate
			,@LicensePackageExpirationDate = lph_l.LicenseExpirationDate
			,@ClientName = c.ClientName
			,@ClientAddress = c.BillingAddress1
			,@BillingContactName = c.BillingContactName
			,@BillingPhoneNumber = c.BillingPhoneNumber
			,@PackageTerm = DATEDIFF(MONTH, lph_l.LicenseStartDate, lph_l.LicenseExpirationDate)
			,@PackageDiscount = lph_l.PackageDiscount
		FROM [billing_history].[LicensePackageChangeLog] lpcl
			LEFT JOIN [billing_history].[LicensePackageHeaderLog] lph_l
				ON lpcl.PackageID = lph_l.PackageID AND lpcl.HeaderChangeID = lph_l.HeaderChangeID
			LEFT JOIN [app].[Client] c
				ON lph_l.ClientID = c.ClientID
			--LEFT JOIN [billing_history].[LicensePackageClientPartnerLog] lpcp_l
			--	ON lph_l.PackageID = lpcp_l.PackageID AND lpcl.ClientPartnerChangeID = lpcp_l.ClientPartnerChangeID
			--LEFT JOIN [app].[Client] cp --client partner
			--	ON lpcp_l.ClientPartnerID = cp.ClientID
			--LEFT JOIN [billing_history].[LicensePackageNoteLog] lpn_l
			--	ON lpcl.PackageID = lpn_l.PackageID AND lpcl.ChangeID = lpn_l.LicPackageChangeID
		WHERE lpcl.PackageID = @PackageID
			AND lpcl.ChangeID = @PackageChangeID
	END
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get header info from MAIN table: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
	ELSE BEGIN
		SELECT
			@PackageID = lph.PackageID
			,@LicensePackageStartDate = lph.LicenseStartDate
			,@LicensePackageExpirationDate = lph.LicenseExpirationDate
			--,@PackageTermText = CASE DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate)
			--						WHEN 12 THEN 'Annual'
			--						WHEN 3 THEN 'Quarterly'
			--					ELSE CONCAT('Monthly: ', CONVERT(VARCHAR,DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate), ' mo') END,
			,@ClientName = c.ClientName
			,@ClientAddress = c.BillingAddress1
			,@BillingContactName = c.BillingContactName
			,@BillingPhoneNumber = c.BillingPhoneNumber
			,@BillingEmail = c.BillingEmail
			,@PackageTerm = DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate)
			,@PackageDiscount = lph.PackageDiscount
		FROM [billing].[LicensePackageHeader] lph
			LEFT JOIN [app].[Client] c
				ON lph.ClientID = c.ClientID
		WHERE lph.PackageID = @PackageID
	END

--***************************************************************************************************************************************************
-- Select line item data:
--***************************************************************************************************************************************************
	/* Check if entry in hist.: */
		IF (EXISTS(SELECT TOP 1 1 FROM [billing_history].[LicensePackageChangeLog]
					WHERE PackageID = @PackageID AND ChangeID = @PackageChangeID) AND (@PackageChangeID <> 0))
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get line items from HISTORY: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		BEGIN
			SELECT
				ItemName
				,Price AS ItemPrice
				,Quantity AS Quantity
				,Discount AS ItemDiscount
				,LicenseFactor
			FROM [billing_history].[LicensePackageChangeItems] lpci
				INNER JOIN [billing_history].[LicensePackageDetailLog] lpd_l
					ON lpci.LicensePackageID = lpd_l.PackageID
						AND lpci.LatestDetailGroupChangeID = lpd_l.DetailGroupChangeID
						AND lpci.ItemID = lpd_l.ItemID
				INNER JOIN [billing].[Item] i
					ON lpd_l.ItemID = i.ItemID
			WHERE lpci.LicensePackageID = @PackageID
				AND lpci.LicensePackageChangeID = @PackageChangeID
		END
-----------------------------------------------------------------------------------------------------------------------------------------------------
/* Get line items from MAIN table: */
-----------------------------------------------------------------------------------------------------------------------------------------------------
		ELSE BEGIN
			SELECT
				i.ItemName
				,lpd.Price AS ItemPrice
				,lpd.Quantity
				,lpd.Discount AS ItemDiscount
				,lpd.LicenseFactor
			FROM [billing].[LicensePackageDetail] lpd
				INNER JOIN [billing].[Item] i
					ON lpd.ItemID = i.ItemID
			WHERE lpd.PackageID = @PackageID
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