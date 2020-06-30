USE [Interject_Demos_Students]
GO
/****** Object:  StoredProcedure [billing].[TEST_Lic_Report_License_Finder_Pull]    Script Date: 1/3/2020 12:47:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
USE [Interject_Demos_Students]
*/

/*
EXEC [billing].[TEST_Lic_Report_License_Finder_Pull]
@ClientNameSearchString = '3m'
,@ClientPartnerNameSearchString = ''
,@LocationSearchString = ''
,@StartRangeStartYearMonth_String = ''
,@StartRangeEndYearMonth_String = ''
,@EndRangeStartYearMonth_String = ''
,@EndRangeEndYearMonth_String = ''
,@NoteSearchString = ''
,@EnableHistorySearchString = '0'
,@EnableInactiveLicSearchString = '0'
*/

ALTER PROC [billing].[TEST_Lic_Report_License_Finder_Pull]
@ClientNameSearchString NVARCHAR(200)
,@ClientPartnerNameSearchString NVARCHAR(200)
,@LocationSearchString NVARCHAR(200)
,@StartRangeStartYearMonth_String VARCHAR(7)
,@StartRangeEndYearMonth_String VARCHAR(7)
,@EndRangeStartYearMonth_String VARCHAR(7)
,@EndRangeEndYearMonth_String VARCHAR(7)
,@NoteSearchString NVARCHAR(300)
,@EnableHistorySearchString VARCHAR(3)
,@EnableInactiveLicSearchString VARCHAR(3)
AS
DECLARE @BaseInterjectItemID INT = 5
--***************************************************************************************************************************************************
-- Input validation:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''
	
	DECLARE @ErrorFound_StartRangeStartYearMonth BIT
	DECLARE @ErrorFound_StartRangeEndYearMonth BIT
	DECLARE @ErrorFound_EndRangeStartYearMonth BIT
	DECLARE @ErrorFound_EndRangeEndYearMonth BIT

	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @StartRangeStartYearMonth_String
	,@ErrorFound = @ErrorFound_StartRangeStartYearMonth OUTPUT

	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @StartRangeEndYearMonth_String
	,@ErrorFound = @ErrorFound_StartRangeEndYearMonth OUTPUT

	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @EndRangeStartYearMonth_String
	,@ErrorFound = @ErrorFound_EndRangeStartYearMonth OUTPUT

	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @EndRangeEndYearMonth_String
	,@ErrorFound = @ErrorFound_EndRangeEndYearMonth OUTPUT

	IF (@ErrorFound_StartRangeStartYearMonth = 1 OR @ErrorFound_StartRangeEndYearMonth = 1
		OR @ErrorFound_EndRangeStartYearMonth = 1 OR @ErrorFound_EndRangeEndYearMonth = 1)
	BEGIN
		SET @ErrorMessageToUser = 'One or more of the dates entered could not be interpreted. Please enter in the form YYYY-MM or YYYY/MM.'
		GOTO FinalResponseToUser
	END
--***************************************************************************************************************************************************
-- Parse Start/End-YearMonth filter strings:
--***************************************************************************************************************************************************
	DECLARE @StartRangeStartYearMonth_Date DATE
	DECLARE @StartRangeEndYearMonth_Date DATE
	DECLARE @EndRangeStartYearMonth_Date DATE
	DECLARE @EndRangeEndYearMonth_Date DATE
	
	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @StartRangeStartYearMonth_String
	,@DateResult = @StartRangeStartYearMonth_Date OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @StartRangeEndYearMonth_String
	,@DateResult = @StartRangeEndYearMonth_Date OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @EndRangeStartYearMonth_String
	,@DateResult = @EndRangeStartYearMonth_Date OUTPUT

	EXEC [billing].[Parse_Year_Month_Varchar_To_Date]
	@YearMonthString = @EndRangeEndYearMonth_String
	,@DateResult = @EndRangeEndYearMonth_Date OUTPUT

	--SELECT @StartRangeStartYearMonth_Date as startstart
	--SELECT @StartRangeEndYearMonth_Date as startend
	--SELECT @EndRangeStartYearMonth_Date as endstart
	--SELECT @EndRangeEndYearMonth_Date as endend

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
		,total_cost_query.TotalPackageCost
		,(CASE WHEN lph.Inactive = 1 THEN 'Inactive' ELSE 'Active' END) AS Status
		,'Current Version' AS FromCacheOrCurrentText
		,0 AS ChangeID
		,lpn.Note
	FROM [Interject_Demos_Students].[billing].[TEST_LicensePackageHeader] lph
		LEFT JOIN [Interject_Demos_Students].[app].[TEST_Client] c
			ON lph.ClientID = c.ClientID
		LEFT JOIN [billing].[TEST_LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [app].[TEST_Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
		-- LEFT JOIN in case there is no base interject item in the pkg:
		LEFT JOIN [Interject_Demos_Students].[billing].[TEST_LicensePackageDetail] lpd_base
			ON lph.PackageID = lpd_base.PackageID AND lpd_base.ItemID = @BaseInterjectItemID
		LEFT JOIN [billing].[TEST_LicensePackageNote] lpn
			ON lph.PackageID = lpn.PackageID
		-- LEFT JOIN in case there are NO items in pkg:
		LEFT JOIN (SELECT
							lph.PackageID
							,(DATEDIFF(MONTH, MAX(LicenseStartDate), MAX(LicenseExpirationDate))
							*(SUM(Quantity*((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor))
							- (SUM(Quantity*((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor)))*MAX(PackageDiscount))) TotalPackageCost
					FROM [billing].[TEST_LicensePackageDetail] lpd
						LEFT JOIN [billing].[TEST_LicensePackageHeader] lph
							ON lpd.PackageID = lph.PackageID
					GROUP BY lph.PackageID) total_cost_query
			ON lph.PackageID = total_cost_query.PackageID
	WHERE (lph.Location LIKE '%' + @LocationSearchString + '%')
		AND (c.ClientName LIKE '%' + @ClientNameSearchString + '%')
		AND ((cp.ClientName LIKE '%' + @ClientPartnerNameSearchString + '%')
			 OR (LEN(@ClientPartnerNameSearchString) = 0))
		AND ((lph.LicenseStartDate BETWEEN @StartRangeStartYearMonth_Date AND @StartRangeEndYearMonth_Date)
				OR (@StartRangeStartYearMonth_Date IS NULL OR @StartRangeEndYearMonth_Date IS NULL))
		AND ((lph.LicenseExpirationDate BETWEEN @EndRangeStartYearMonth_Date AND @EndRangeEndYearMonth_Date)
				OR (@EndRangeStartYearMonth_Date IS NULL OR @EndRangeEndYearMonth_Date IS NULL))
		AND ((@InactiveLicSearchEnabled = 1)
			OR (lph.Inactive = @InactiveLicSearchEnabled))
		AND ((lpn.Note LIKE '%' + @NoteSearchString + '%')
			OR (LEN(@NoteSearchString) = 0))
		--AND (c.ClientName IS NOT NULL)-- FIX REAL BUG
		--AND (lph.PackageID IS NOT NULL)
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
		,total_cost_query.TotalPackageCost
		,(CASE WHEN lph_l.Inactive = 1 THEN 'Inactive' ELSE 'Active' END) AS Status
		,'Previous version from cache' AS FromCacheOrCurrentText
		,lpcl.ChangeID
		,lpn_l.Note
	FROM [billing_history].[TEST_LicensePackageChangeLog] lpcl
		LEFT JOIN [billing_history].[TEST_LicensePackageHeaderLog] lph_l
			ON lpcl.PackageID = lph_l.PackageID AND lpcl.HeaderChangeID = lph_l.HeaderChangeID
		LEFT JOIN [billing_history].[TEST_LicensePackageDetailLog] lpd_l_base
			ON lpcl.PackageID = lpd_l_base.PackageID AND lpcl.DetailGroupChangeID = lpd_l_base.DetailGroupChangeID AND lpd_l_base.ItemID = @BaseInterjectItemID
		LEFT JOIN [app].[TEST_Client] c
			ON lph_l.ClientID = c.ClientID
		LEFT JOIN [billing_history].[TEST_LicensePackageClientPartnerLog] lpcp_l
			ON lpcl.PackageID = lpcp_l.PackageID AND lpcl.ClientPartnerChangeID = lpcp_l.ClientPartnerChangeID
		LEFT JOIN [app].[TEST_Client] cp
			ON lpcp_l.ClientPartnerID = cp.ClientID
		LEFT JOIN [Interject_Demos_Students].[billing_history].[LicensePackageNoteLog] lpn_l
				ON lpcl.PackageID = lpn_l.PackageID AND lpcl.ChangeID = lpn_l.LicPackageChangeID
		LEFT JOIN (SELECT
						lph_l.PackageID
						,(DATEDIFF(MONTH, MAX(lph_l.LicenseStartDate), MAX(lph_l.LicenseExpirationDate))*(SUM(Quantity*((Price - Price*Discount) + (Price - Price*Discount)*LicenseFactor)))) TotalPackageCost
					FROM [billing_history].[TEST_LicensePackageDetailLog] lpd_l
						LEFT JOIN [billing_history].[TEST_LicensePackageHeaderLog] lph_l
							ON lpd_l.PackageID = lph_l.PackageID
					GROUP BY lph_l.PackageID) total_cost_query
			ON lph_l.PackageID = total_cost_query.PackageID
	WHERE (@HistorySearchEnabled = 1)
		AND (lph_l.Location LIKE '%' + @LocationSearchString + '%')
		AND (c.ClientName LIKE '%' + @ClientNameSearchString + '%')
		AND ((cp.ClientName LIKE '%' + @ClientPartnerNameSearchString + '%')
			 OR (LEN(@ClientPartnerNameSearchString) = 0))
		AND((lph_l.LicenseStartDate BETWEEN @StartRangeStartYearMonth_Date AND @StartRangeEndYearMonth_Date)
			OR (@StartRangeStartYearMonth_Date IS NULL OR @StartRangeEndYearMonth_Date IS NULL))
		AND ((lph_l.LicenseExpirationDate BETWEEN @EndRangeStartYearMonth_Date AND @EndRangeEndYearMonth_Date)
			OR (@EndRangeStartYearMonth_Date IS NULL OR @EndRangeEndYearMonth_Date IS NULL))
		AND ((lpn_l.Note LIKE '%' + @NoteSearchString + '%')
			OR (LEN(@NoteSearchString) = 0))
		AND ((@InactiveLicSearchEnabled = 1)
			OR (lph_l.Inactive = @InactiveLicSearchEnabled))
		AND (lpcl.ChangeID <> 0)
		--AND (c.ClientName IS NOT NULL) -- FIX REAL BUG
		--AND (lph_l.PackageID IS NOT NULL)
	ORDER BY ClientName, ClientPartnerName, Location, PackageID, ChangeID
--***************************************************************************************************************************************************
-- Response for the SAVE action:
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