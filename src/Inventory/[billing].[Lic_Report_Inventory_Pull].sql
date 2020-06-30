/*
USE [Interject_Demos_Students]
*/

/*
EXEC [billing].[Lic_Report_Inventory_Pull]
@ItemNameSearchString = 'in'
*/

CREATE PROC [billing].[Lic_Report_Inventory_Pull]
@ItemNameSearchString nvarchar(100)
AS
	SELECT
		i.ItemID
		,i.ItemName
		,i.DefaultPrice
		,il.Updated
	FROM [billing].[Item] i
		LEFT JOIN [billing_history].[ItemLog] il
			ON i.ItemChangeID = il.ItemChangeID
	WHERE ( ((LEN(@ItemNameSearchString) > 0) AND (i.ItemName LIKE '%' + @ItemNameSearchString + '%') )
			OR ((LEN(@ItemNameSearchString) = 0)) )
