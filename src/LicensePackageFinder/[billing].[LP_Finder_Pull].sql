USE [Interject_Demos_Students]
GO
/****** Object:  StoredProcedure [billing].[LP_Finder_Pull]    Script Date: 1/3/2020 12:47:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
USE [Interject_Demos_Students]
*/

/*
EXEC [billing].[LP_Finder_Pull]
@ClientNameSearchString = ''
,@ClientPartnerNameSearchString = ''
,@LocationSearchString = ''
,@StartDateRangeStartString = ''
,@StartDateRangeEndString = ''
,@EndDateRangeStartString = ''
,@EndDateRangeEndString = ''
,@NoteSearchString = ''
,@EnableHistorySearchString = '0'
,@EnableInactiveLicSearchString = '0'
*/

ALTER PROC [billing].[LP_Finder_Pull]
@ClientNameSearchString NVARCHAR(200) = ''
,@ClientPartnerNameSearchString NVARCHAR(200) = ''
,@LocationSearchString NVARCHAR(200) = ''
,@StartDateRangeStartString VARCHAR(7) = ''
,@StartDateRangeEndString VARCHAR(7) = ''
,@EndDateRangeStartString VARCHAR(7) = ''
,@EndDateRangeEndString VARCHAR(7) = ''
,@NoteSearchString NVARCHAR(300) = ''
,@EnableHistorySearchString VARCHAR(3) = ''
,@EnableInactiveLicSearchString VARCHAR(3) = ''
AS
DECLARE @BaseInterjectItemID INT = 5

--***************************************************************************************************************************************************
-- Input validation:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''
	DECLARE @ErrorFound BIT = 0

	DECLARE @ErrorFound_StartRangeStart BIT
	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @StartDateRangeStartString
	,@ErrorFound = @ErrorFound_StartRangeStart OUTPUT
	IF (@ErrorFound_StartRangeStart = 1)
	BEGIN
		SET @ErrorMessageToUser = ', date entered as FROM date on Start date range filter could not be interpreted'
		SET @ErrorFound = 1
	END

	DECLARE @ErrorFound_StartRangeEnd BIT
	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @StartDateRangeEndString
	,@ErrorFound = @ErrorFound_StartRangeEnd OUTPUT
	IF (@ErrorFound_StartRangeEnd = 1)
	BEGIN
		SET @ErrorMessageToUser = @ErrorMessageToUser + ', date entered as TO date in the Start date range filter could not be interpreted'
		SET @ErrorFound = 1
	END

	DECLARE @ErrorFound_EndRangeStart BIT
	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @EndDateRangeStartString
	,@ErrorFound = @ErrorFound_EndRangeStart OUTPUT
	IF (@ErrorFound_EndRangeStart = 1)
	BEGIN
		SET @ErrorMessageToUser = @ErrorMessageToUser + ', date entered as FROM date in the Expiration date range filter could not be interpreted'
		SET @ErrorFound = 1
	END

	DECLARE @ErrorFound_EndRangeEnd BIT
	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @EndDateRangeEndString
	,@ErrorFound = @ErrorFound_EndRangeEnd OUTPUT
	IF (@ErrorFound_EndRangeEnd = 1)
	BEGIN
		SET @ErrorMessageToUser = @ErrorMessageToUser + ', date entered as TO date in the Expiration date range filter could not be interpreted'
		SET @ErrorFound = 1
	END

	IF (@ErrorFound = 1)
	BEGIN
		GOTO FinalResponseToUser
	END

--***************************************************************************************************************************************************
-- Parse Start/End-YearMonth filter strings:
--***************************************************************************************************************************************************
	DECLARE @StartRangeStartDate DATE
	DECLARE @StartRangeEndDate DATE
	DECLARE @EndRangeStartDate DATE
	DECLARE @EndRangeEndDate DATE
	
	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @StartDateRangeStartString
	,@DateResult = @StartRangeStartDate OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @StartDateRangeEndString
	,@DateResult = @StartRangeEndDate OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @EndDateRangeStartString
	,@DateResult = @EndRangeStartDate OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @EndDateRangeEndString
	,@DateResult = @EndRangeEndDate OUTPUT

/* Set default values for dates if none entered by user: */
	IF (@StartRangeStartDate IS NULL)
	BEGIN
		SET @StartRangeStartDate = DATEADD(YEAR, -100, GETDATE())
	END

	IF (@StartRangeEndDate IS NULL)
	BEGIN
		SET @StartRangeEndDate = DATEADD(YEAR, 100, GETDATE()) --Could default to today, but possible that license packages could be created
	END															--to start in the future.

	IF (@EndRangeStartDate IS NULL)
	BEGIN
		SET @EndRangeStartDate = DATEADD(YEAR, -100, GETDATE())
	END

	IF (@EndRangeEndDate IS NULL)
	BEGIN
		SET @EndRangeEndDate = DATEADD(YEAR, 100, GETDATE())
	END

--***************************************************************************************************************************************************
-- Parse Start/End-YearMonth filter strings:
--***************************************************************************************************************************************************
	DECLARE @HistorySearchEnabled BIT
	DECLARE @InactiveLicSearchEnabled BIT
	
	EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
	@InputString = @EnableHistorySearchString
	,@Result = @HistorySearchEnabled OUTPUT

	EXEC [billing].[Lic_Report_Yes_No_Input_Validator]
	@InputString = @EnableInactiveLicSearchString
	,@Result = @InactiveLicSearchEnabled OUTPUT

--***************************************************************************************************************************************************
-- Select line item data from main tables:
--***************************************************************************************************************************************************
	;WITH total_cost_cte AS
	(
		SELECT
			lph.PackageID
			,( DATEDIFF(MONTH, LicenseStartDate, LicenseExpirationDate)
			* (SUM(Quantity*((Price + Price*LicenseFactor)*(1 - 1*Discount))))*(1 - 1*PackageDiscount)) TotalPackageCost
		FROM [billing].[LicensePackageDetail] lpd
			LEFT JOIN [billing].[LicensePackageHeader] lph
				ON lpd.PackageID = lph.PackageID
		GROUP BY lph.PackageID, lph.LicenseStartDate, lph.LicenseExpirationDate, lph.PackageDiscount
	)
	, total_cost_hist_cte AS
	(
		SELECT
			lph_l.PackageID
			,( DATEDIFF(MONTH, LicenseStartDate, LicenseExpirationDate)
			* (SUM(Quantity*((Price + Price*LicenseFactor)*(1 - 1*Discount))))*(1 - 1*PackageDiscount)) TotalPackageCost
		FROM [billing_history].[LicensePackageDetailLog] lpd_l
			LEFT JOIN [billing_history].[LicensePackageHeaderLog] lph_l
				ON lpd_l.PackageID = lph_l.PackageID
		GROUP BY lph_l.PackageID, lph_l.LicenseStartDate, lph_l.LicenseExpirationDate, lph_l.PackageDiscount
	)
	SELECT
		c.ClientName
		,cp.ClientName AS ClientPartnerName
		,lph.Location
		,lph.PackageID
		,lpd_base.Quantity AS LicensedUsers
		,lph.UserMinimum
		,lpd_base.Price AS BaseInterjectPrice
		,lph.LicenseStartDate
		,lph.LicenseExpirationDate
		,DATEDIFF(MONTH, lph.LicenseStartDate, lph.LicenseExpirationDate) AS DurationMonths
		,total_cost_cte.TotalPackageCost
		,(CASE WHEN lph.Inactive = 1 THEN 'Inactive' ELSE 'Active' END) AS Status
		,'Current Version' AS FromCacheOrCurrentText
		,MAX(lpcl.ChangeID) AS ChangeID
		,lpn.Note
	FROM [billing].[LicensePackageHeader] lph
		INNER JOIN [billing_history].[LicensePackageChangeLog] lpcl
			ON lph.PackageID = lpcl.PackageID
		LEFT JOIN [app].[Client] c
			ON lph.ClientID = c.ClientID
		LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [app].[Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
		-- LEFT JOIN in case there is no base interject item in the pkg:
		LEFT JOIN [billing].[LicensePackageDetail] lpd_base
			ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @BaseInterjectItemID
		LEFT JOIN [billing].[LicensePackageNote] lpn
			ON lph.PackageID = lpn.PackageID
		/* Calculate the total package cost using subquery: */
		-- LEFT JOIN in case there are NO items in pkg:
		LEFT JOIN total_cost_cte
			ON lph.PackageID = total_cost_cte.PackageID
	/* Where clause determines which entries from lph to pull... */
	WHERE ((@LocationSearchString = '') OR (lph.Location LIKE '%' + @LocationSearchString + '%'))
		AND ((@ClientNameSearchString = '') OR (c.ClientName LIKE '%' + @ClientNameSearchString + '%'))
		AND ((@ClientPartnerNameSearchString = '') OR (cp.ClientName LIKE '%' + @ClientPartnerNameSearchString + '%'))
			 --OR (LEN(@ClientPartnerNameSearchString) = 0))
		AND (lph.LicenseStartDate BETWEEN @StartRangeStartDate AND @StartRangeEndDate)
		AND (lph.LicenseExpirationDate BETWEEN @EndRangeStartDate AND @EndRangeEndDate)
		AND ((@InactiveLicSearchEnabled = 1) OR (lph.Inactive = 0))
		AND ((@NoteSearchString = '') OR (lpn.Note LIKE '%' + @NoteSearchString + '%'))
	GROUP BY lph.PackageID
			,c.ClientName
			,cp.ClientName
			,lph.Location
			,lpd_base.Quantity
			,lph.UserMinimum
			,lpd_base.Price
			,lph.LicenseStartDate
			,lph.LicenseExpirationDate
			,total_cost_cte.TotalPackageCost
			,lph.Inactive
			,lpn.Note
--***************************************************************************************************************************************************
-- Select line item data from HISTORY tables:
--***************************************************************************************************************************************************
	UNION-- ALL
	SELECT
		c.ClientName
		,cp.ClientName AS ClientPartnerName
		,lph_l.Location
		,lph_l.PackageID
		,lpd_l_base.Quantity AS LicensedUsers
		,lph_l.UserMinimum
		,lpd_l_base.Price AS BaseInterjectPrice
		,lph_l.LicenseStartDate
		,lph_l.LicenseExpirationDate
		,DATEDIFF(MONTH, lph_l.LicenseStartDate, lph_l.LicenseExpirationDate) AS DurationMonths
		,total_cost_hist_cte.TotalPackageCost
		,(CASE WHEN lph_l.Inactive = 1 THEN 'Inactive' ELSE 'Active' END) AS Status
		,'Previous version from cache' AS FromCacheOrCurrentText
		,lpcl.ChangeID
		,lpn_l.Note
	FROM [billing_history].[LicensePackageHeaderLog] lph_l -- Basis b/c only including HIST
		INNER JOIN [billing_history].[LicensePackageChangeLog] lpcl
			ON lph_l.PackageID = lpcl.PackageID
				AND lph_l.HeaderChangeID = lpcl.HeaderChangeID
		LEFT JOIN [billing_history].[LicensePackageDetailLog] lpd_l_base
			ON lpcl.PackageID = lpd_l_base.PackageID
				AND lpcl.DetailGroupChangeID = lpd_l_base.DetailGroupChangeID
				AND lpd_l_base.ItemID = @BaseInterjectItemID
		LEFT JOIN [app].[Client] c
			ON lph_l.ClientID = c.ClientID
		LEFT JOIN [billing_history].[LicensePackageClientPartnerLog] lpcp_l
			ON lpcl.PackageID = lpcp_l.PackageID
				AND lpcl.ClientPartnerChangeID = lpcp_l.ClientPartnerChangeID
		LEFT JOIN [app].[Client] cp
			ON lpcp_l.ClientPartnerID = cp.ClientID
		LEFT JOIN [billing_history].[LicensePackageNoteLog] lpn_l
				ON lpcl.PackageID = lpn_l.PackageID AND lpcl.ChangeID = lpn_l.LicPackageChangeID
		LEFT JOIN total_cost_hist_cte
			ON lph_l.PackageID = total_cost_hist_cte.PackageID
	WHERE (@HistorySearchEnabled = 1)
		AND ((@LocationSearchString = '') OR (lph_l.Location LIKE '%' + @LocationSearchString + '%'))
		AND ((@ClientNameSearchString = '') OR (c.ClientName LIKE '%' + @ClientNameSearchString + '%'))
		AND ((@ClientPartnerNameSearchString = '') OR (cp.ClientName LIKE '%' + @ClientPartnerNameSearchString + '%'))
		AND (lph_l.LicenseStartDate BETWEEN @StartRangeStartDate AND @StartRangeEndDate)
		AND (lph_l.LicenseExpirationDate BETWEEN @EndRangeStartDate AND @EndRangeEndDate)
		AND ((@NoteSearchString = '') OR (lpn_l.Note LIKE '%' + @NoteSearchString + '%'))
		AND ((@InactiveLicSearchEnabled = 1) OR (lph_l.Inactive = 0))
	ORDER BY ClientName, ClientPartnerName, Location, PackageID, ChangeID
	
--***************************************************************************************************************************************************
-- Final response if errors occurred:
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