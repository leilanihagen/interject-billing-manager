USE [Interject_Demos_Students]
GO
/****** Object:  StoredProcedure [billing].[LP_Expiring_Lic_Pkg_Info_Pull]    Script Date: 1/1/2020 2:14:54 PM ******/
/* DEPRECATED. This procedure was created with the approach of pulling the client info and client
   license info seperately. We changed the appraoch to pull all data with a single pull. See
   LP_Expiring_License_Finder_Pull for final version/design. */
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

ALTER PROC [billing].[LP_Expiring_Lic_Pkg_Info_Pull]
@StartDateString varchar(7) =''									
,@EndDateString varchar(7) =''
,@ClientPartnerSearchString nvarchar(100) = ''
AS
--***************************************************************************************************************************************************
-- Definitions:
--***************************************************************************************************************************************************
	DECLARE @BaseInterjectItemID INT = 5
--***************************************************************************************************************************************************
-- Parse Start/End-YearMonth filter strings:
--***************************************************************************************************************************************************
	DECLARE @StartYearMonth_Date DATE
	DECLARE @EndYearMonth_Date DATE

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @StartDateString
	,@DateResult = @StartYearMonth_Date OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @EndDateString
	,@DateResult = @EndYearMonth_Date OUTPUT
--***************************************************************************************************************************************************
-- Return package info:
--***************************************************************************************************************************************************
	;WITH get_renewal_cost AS (
		SELECT
			lph.PackageID
			,(DATEDIFF(MONTH, MAX(LicenseStartDate), MAX(LicenseExpirationDate))
			*(SUM(Quantity*((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor))
			- (SUM(Quantity*((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor)))*MAX(PackageDiscount))) CalculatedRenewalCost
		FROM [billing].[LicensePackageDetail] lpd
			LEFT JOIN [billing].[LicensePackageHeader] lph
				ON lpd.PackageID = lph.PackageID
		GROUP BY lph.PackageID
		)
	SELECT
		CONVERT(VARCHAR, lph.ClientID) + '-' + lph.Location AS ClientLocationKey
		,lph.PackageID
		,ISNULL(lpd_base.Quantity, 0) AS LicensedUsers
		,lph.UserMinimum
		,lpd_base.Price AS InterjectBasePrice
		,lph.LicenseStartDate
		,lph.LicenseExpirationDate
		,DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate) AS DurationMonths
		--,(DATEDIFF(MONTH, lph.LicenseStartDate,lph.LicenseExpirationDate)*SUM((lpd.Price - lpd.Price*lpd.Discount) + (lpd.Price - lpd.Price*lpd.Discount)*lpd.LicenseFactor) OVER (PARTITION BY lph.PackageID)) CalculatedRenewalCost
		,ISNULL(get_renewal_cost.CalculatedRenewalCost, 0) AS CalculatedRenewalCost
	FROM [billing].[LicensePackageHeader] lph
		LEFT JOIN [billing].[LicensePackageDetail] lpd_base
			ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @BaseInterjectItemID
		LEFT JOIN get_renewal_cost
			ON lph.PackageID = get_renewal_cost.PackageID
		LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [app].[Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
	WHERE ((lph.LicenseExpirationDate BETWEEN @StartYearMonth_Date AND @EndYearMonth_Date)
			OR (@StartYearMonth_Date IS NULL OR @EndYearMonth_Date  IS NULL))
		AND ( (cp.ClientName LIKE '%' + @ClientPartnerSearchString + '%') )
			OR (@ClientPartnerSearchString = '' )
	ORDER BY MAX(lph.LicenseExpirationDate) OVER (PARTITION BY lph.ClientID) DESC
			,lph.ClientID
			,lph.LicenseExpirationDate DESC
