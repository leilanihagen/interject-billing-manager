USE [Interject_Demos_Students]

ALTER PROC [billing].[Lic_Report_Invoice_ClientName_jDropdown_Pull]
@FilterText NVARCHAR(200)
AS
SELECT
	ClientName
FROM [app].[Client]
WHERE @FilterText = '' OR ClientName LIKE '%' + @FilterText + '%'