USE [Interject_Demos_Students]
GO
/****** Object:  StoredProcedure [billing].[LP_Expiring_Finder_Client_Info_Pull]    Script Date: 1/2/2020 1:18:36 PM ******/
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
EXEC [billing].[LP_Expiring_Finder_Client_Info_Pull]
@StartDateString = '2020/01'
,@EndDateString = '2020/12'
,@ClientPartnerSearchString = ''
*/

ALTER PROC [billing].[LP_Expiring_Finder_Client_Info_Pull]
@StartDateString varchar(7)
,@EndDateString varchar(7)
,@ClientPartnerSearchString nvarchar(100)
AS
--***************************************************************************************************************************************************
-- Input validation:
--***************************************************************************************************************************************************
	DECLARE @ErrorMessageToUser AS VARCHAR(1000) = ''

	DECLARE @ErrorFound_StartYearMonth BIT
	DECLARE @ErrorFound_EndYearMonth BIT

	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @StartDateString
	,@ErrorFound = @ErrorFound_StartYearMonth OUTPUT

	EXEC [billing].[Validate_Year_Month_Varchar_Date_Input]
	@YearMonthString = @EndDateString
	,@ErrorFound = @ErrorFound_EndYearMonth OUTPUT

	IF (@ErrorFound_StartYearMonth = 1 OR @ErrorFound_EndYearMonth = 1)
	BEGIN
		SET @ErrorMessageToUser = 'The start or end month entered could not be interpreted. Please enter in the form YYYY-MM or YYYY/MM.'
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
-- Return client info:
--***************************************************************************************************************************************************
	SELECT
		CONVERT(VARCHAR, lph.ClientID) + '-' + lph.Location AS ClientLocationKey
		,c.ClientName
		,cp.ClientName AS ClientPartnerName
		,lph.Location
		--,MAX(lph.LicenseExpirationDate) as MaxExp
		,c.BillingContactName
		,c.BillingEmail
	FROM [billing].[LicensePackageHeader] lph
		LEFT JOIN [app].[Client] c
			ON lph.ClientID = c.ClientID
		LEFT JOIN [billing].[LicensePackageClientPartner] lpcp
			ON lph.PackageID = lpcp.PackageID
		LEFT JOIN [app].[Client] cp --client partner
			ON lpcp.ClientPartnerID = cp.ClientID
	WHERE ((lph.LicenseExpirationDate BETWEEN @StartDate AND @EndDate)
			OR (@StartDate IS NULL OR @EndDate IS NULL))
		-- Added LEN() checks here bc we don't want to REQUIRE that there is a client partner in order to return a result:
		AND ((cp.ClientName LIKE '%' + @ClientPartnerSearchString + '%') -- cp.CliName LIKE -anything-
			OR (LEN(@ClientPartnerSearchString) = 0) )															-- requires cp.CliName exists.	
	GROUP BY lph.ClientID
			,lph.Location
			,c.ClientName
			,cp.ClientName
			,c.BillingContactName
			,c.BillingEmail
			,lph.LicenseExpirationDate
	ORDER BY lph.LicenseExpirationDate
	--ORDER BY MAX(MAX(lph.LicenseExpirationDate)) OVER (PARTITION BY lph.ClientID) DESC
	--		,lph.ClientID
	--		,MAX(lph.LicenseExpirationDate) DESC
--***************************************************************************************************************************************************
-- Error message:
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
