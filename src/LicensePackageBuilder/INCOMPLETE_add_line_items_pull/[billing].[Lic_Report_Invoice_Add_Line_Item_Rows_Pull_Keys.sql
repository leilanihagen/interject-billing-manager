/*
USE [Interject_Demos_Students]
*/

ALTER PROC [billing].[Lic_Report_Invoice_Add_Line_Item_Rows_Pull_Keys]
AS
	CREATE TABLE #EmptyString
	(
		EmptyString NVARCHAR(1)
	)
	INSERT INTO #EmptyString
	VALUES(''), (''), (''), (''), ('')
	SELECT
		'END_OF_LIST' AS EndOfListKey
		,EmptyString AS ItemName
		,EmptyString AS ItemPrice
		,EmptyString AS Quantity
		,EmptyString AS ItemDiscount
		,EmptyString AS LicenseFactor
	FROM #EmptyString
	DROP TABLE #EmptyString


	/* TEST:
	CREATE TABLE #EmptyString
	(
		EmptyString NVARCHAR(1)
	)
	INSERT INTO #EmptyString
	VALUES(''), (''), (''), (''), ('')
	SELECT
		'END_OF_LIST' AS EndOfListKey
		,EmptyString AS ItemName
		,EmptyString AS ItemPrice
		,EmptyString AS Quantity
		,EmptyString AS ItemDiscount
		,EmptyString AS LicenseFactor
	FROM #EmptyString
	DROP TABLE #EmptyString

*/