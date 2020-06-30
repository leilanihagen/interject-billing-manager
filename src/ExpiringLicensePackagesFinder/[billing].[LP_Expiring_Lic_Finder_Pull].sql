USE [Interject_Demos_Students]
GO
/****** Object:  StoredProcedure [billing].[LP_Expiring_Lic_Pkg_Info_Pull]    Script Date: 1/1/2020 2:14:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
USE [Interject_Demos_Students]
*/

/*
EXEC [billing].[LP_Expiring_Lic_Pkg_Info_Pull]
@StartDateString = '2020/01'
,@EndDateString = '2020/12'
,@ClientPartnerSearchString = ''

Execute [billing].[LP_Expiring_Lic_Pkg_Info_Pull]
	@StartDateString = ''
	,@EndDateString = ''
	,@ClientPartnerSearchString = ''

*/

ALTER PROC [billing].[LP_Expiring_Lic_Finder_Pull]
/* Attept to pack everything in ONE pull. Splitting into two was fancy but not necessary for the functionality needed. */
@StartDateString varchar(7) =''									
,@EndDateString varchar(7) =''
,@ClientSearchString nvarchar(100) = ''
,@ClientPartnerSearchString nvarchar(100) = ''
AS
--***************************************************************************************************************************************************
-- Definitions:
--***************************************************************************************************************************************************
	DECLARE @BaseInterjectItemID INT = 5

--***************************************************************************************************************************************************
-- Input validation:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''

	DECLARE @ErrorFound_StartDate BIT
	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @StartDateString
	,@ErrorFound = @ErrorFound_StartDate OUTPUT
	IF (@ErrorFound_StartDate = 1)
	BEGIN
		SET @ErrorMessageToUser = ', the start date filter entered could not be interpreted'
	END

	DECLARE @ErrorFound_EndDate BIT
	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @EndDateString
	,@ErrorFound = @ErrorFound_EndDate OUTPUT
	IF (@ErrorFound_EndDate = 1)
	BEGIN
		SET @ErrorMessageToUser = @ErrorMessageToUser + ', the end date filter entered could not be interpreted'
	END

	IF (@ErrorFound_StartDate = 1 OR @ErrorFound_EndDate = 1)
	BEGIN
		GOTO FinalResponseToUser
	END

--***************************************************************************************************************************************************
-- Parse Start/End-YearMonth filter strings:
--***************************************************************************************************************************************************
	DECLARE @StartDate DATE
	DECLARE @EndDate DATE

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @StartDateString
	,@DateResult = @StartDate OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @EndDateString
	,@DateResult = @EndDate OUTPUT

--***************************************************************************************************************************************************
-- Return package info:
--***************************************************************************************************************************************************
	;WITH get_renewal_cost AS (
		SELECT
			lph.PackageID
			,(DATEDIFF(MONTH, LicenseStartDate, LicenseExpirationDate)
			* (SUM(Quantity*((Price + Price*LicenseFactor)*(1 - 1*Discount))))*(1 - 1*PackageDiscount)) CalculatedRenewalCost
		FROM [billing].[LicensePackageDetail] lpd
			LEFT JOIN [billing].[LicensePackageHeader] lph
				ON lpd.PackageID = lph.PackageID
		GROUP BY lph.PackageID, lph.LicenseStartDate, lph.LicenseExpirationDate, lph.PackageDiscount
		)
	SELECT
		/* Client info: */
		c.ClientName
		,cp.ClientName AS ClientPartnerName
		,lph.Location
		,c.BillingContactName
		,c.BillingEmail
		/* Package info: */
		,lph.PackageID
		,ISNULL(lpd_base.Quantity, 0) AS LicensedUsers
		,lph.UserMinimum
		,lpd_base.Price AS InterjectBasePrice
		,lph.LicenseStartDate
		,lph.LicenseExpirationDate
		,DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate) AS DurationMonths
		,ISNULL(get_renewal_cost.CalculatedRenewalCost, 0) AS CalculatedRenewalCost
	FROM [billing].[LicensePackageHeader] lph
		LEFT JOIN [app].[Client] c
			ON lph.ClientID = c.ClientID
		LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [app].[Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
		LEFT JOIN [billing].[LicensePackageDetail] lpd_base
			ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @BaseInterjectItemID
		LEFT JOIN get_renewal_cost
			ON lph.PackageID = get_renewal_cost.PackageID
	WHERE ((lph.LicenseExpirationDate BETWEEN @StartDate AND @EndDate)
			OR (@StartDate IS NULL OR @EndDate IS NULL))
		AND ((@ClientSearchString = '') OR (c.ClientName LIKE '%' + @ClientSearchString + '%'))
		AND ((@ClientPartnerSearchString = '') OR (cp.ClientName LIKE '%' + @ClientPartnerSearchString + '%'))
	ORDER BY lph.LicenseExpirationDate ASC

--***************************************************************************************************************************************************
-- Error message:
--***************************************************************************************************************************************************
	FinalResponseToUser:
		IF @ErrorMessageToUser <> ''
		BEGIN
			-- by adding 'UserNotice:' as a prefix to the message, Interject will not consider it a unhandled error 
			-- and will present the error to the user in a message box.
			SET @ErrorMessageToUser = 'UserNotice:' + SUBSTRING(@ErrorMessageToUser, 2, 200) + '. Please enter dates in the form YYYY-MM or YYYY/MM.'
        
			RAISERROR (@ErrorMessageToUser,
			18, -- Severity,
			1) -- State)
			RETURN
		END