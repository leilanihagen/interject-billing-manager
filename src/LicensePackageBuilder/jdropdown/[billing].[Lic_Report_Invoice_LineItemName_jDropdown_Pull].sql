USE [Interject_Demos_Students]

ALTER PROC [billing].[Lic_Report_Invoice_LineItemName_jDropdown_Pull]
@FilterText NVARCHAR(200)
AS
SELECT
	ItemName
FROM [billing].[Item]
WHERE @FilterText = '' OR ItemName LIKE '%' + @FilterText + '%'