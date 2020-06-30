USE [Interject_Demos_Students]

ALTER PROC [billing].[Lic_Report_Invoice_ClientPartnerName_jDropdown_Pull]
@FilterText NVARCHAR(200)
AS
SELECT
	ClientName AS ClientPartnerName
FROM [app].[Client]
WHERE @FilterText = '' OR ClientName LIKE '%' + @FilterText + '%'