USE [Interject_Demos_Students]
/*
EXEC [billing].[Lic_Report_Invoice_Line_Items_Pull]
@LicensePackageID = 20
*/

ALTER PROC [billing].[Lic_Report_Invoice_Line_Items_Pull]
/* General proc to pull line items for invoice reports. Execute from other stored procedures. */
@LicensePackageID INT
AS
SELECT
	i.ItemName
	,lpd.Price AS ItemPrice
	,lpd.Quantity
	,lpd.Discount AS ItemDiscount
	,lpd.LicenseFactor
FROM [Interject_Demos_Students].[billing].[LicensePackageDetail] lpd
	LEFT JOIN [Interject_Demos_Students].[billing].[Item] i
		ON lpd.ItemID = i.ItemID
WHERE lpd.PackageID = @LicensePackageID