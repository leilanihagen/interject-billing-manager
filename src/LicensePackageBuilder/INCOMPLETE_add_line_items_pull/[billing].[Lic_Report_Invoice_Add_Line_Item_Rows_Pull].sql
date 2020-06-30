USE [Interject_Demos_Students]

ALTER PROC [billing].[Lic_Report_Invoice_Add_Line_Item_Rows_Pull]
@ItemName NVARCHAR(200)
,@ItemPrice NVARCHAR(1000)
,@Quantity NVARCHAR(100)
,@ItemDiscount NVARCHAR(100)
,@LicenseFactor NVARCHAR(100)
,@BlankItemName NVARCHAR(1) OUTPUT
,@BlankItemPrice NVARCHAR(1) OUTPUT
,@BlankQuantity NVARCHAR(1) OUTPUT
,@BlankItemDiscount NVARCHAR(1) OUTPUT
,@BlankLicenseFactor NVARCHAR(1) OUTPUT
AS
--DECLARE @NewItemName NVARCHAR(100) = 'susan'
--DECLARE @NewItemUnitPrice NVARCHAR(1000) = '53'
--DECLARE @NewItemQuantity NVARCHAR(100) = '44'
--DECLARE @NewItemDiscount NVARCHAR(100) = '.2'
--DECLARE @NewItemLicFactor NVARCHAR(100) = '.2'

SELECT
	@BlankItemName = ''
	,@BlankItemPrice = ''
	,@BlankQuantity = ''
	,@BlankItemDiscount = ''
	,@BlankLicenseFactor = ''

CREATE TABLE #EmptyString
(
	EmptyString NVARCHAR(1)
)
INSERT INTO #EmptyString
VALUES(''), (''), (''), (''), ('')
SELECT
	@ItemName AS ItemName
	,@ItemPrice AS ItemPrice
	,@Quantity AS Quantity
	,@ItemDiscount AS ItemDiscount
	,@LicenseFactor AS LicenseFactor
UNION ALL
SELECT
	EmptyString AS ItemName
	,EmptyString AS ItemPrice
	,EmptyString AS Quantity
	,EmptyString AS ItemDiscount
	,EmptyString AS LicenseFactor
FROM #EmptyString
DROP TABLE #EmptyString


/* TEST:
DECLARE @ItemName NVARCHAR(100) = 'susan'
DECLARE @ItemPrice NVARCHAR(1000) = '53'
DECLARE @Quantity NVARCHAR(100) = '44'
DECLARE @ItemDiscount NVARCHAR(100) = '.2'
DECLARE @LicenseFactor NVARCHAR(100) = '.2'

--SELECT
--	@BlankItemName = ''
--	,@BlankItemPrice = ''
--	,@BlankQuantity = ''
--	,@BlankItemDiscount = ''
--	,@BlankLicenseFactor = ''

CREATE TABLE #EmptyString
(
	EmptyString NVARCHAR(1)
)
INSERT INTO #EmptyString
VALUES(''), (''), (''), (''), ('')
SELECT
	@ItemName AS ItemName
	,@ItemPrice AS ItemPrice
	,@Quantity AS Quantity
	,@ItemDiscount AS ItemDiscount
	,@LicenseFactor AS LicenseFactor
UNION ALL
SELECT
	EmptyString AS ItemName
	,EmptyString AS ItemPrice
	,EmptyString AS Quantity
	,EmptyString AS ItemDiscount
	,EmptyString AS LicenseFactor
FROM #EmptyString
DROP TABLE #EmptyString

*/