USE [Interject_Demos_Students]

ALTER PROC [billing].[Lic_Report_Invoice_Location_jDropdown_Pull]
@FilterText NVARCHAR(200)
,@ClientName NVARCHAR(200)
AS
SELECT DISTINCT
	Location
FROM [billing_history].[TEST_LicensePackageHeaderLog] lpd_l
	INNER JOIN [app].[TEST_Client] c
		ON lpd_l.ClientID = c.ClientID
WHERE c.ClientName = @ClientName
	AND (@FilterText = '' OR Location LIKE '%' + @FilterText + '%')