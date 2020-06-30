/*
USE [Interject_Demos_Students]
*/

ALTER PROC [billing].[Parse_Year_Month_Varchar_To_Date]
@YearMonthString VARCHAR(7)
,@DateResult DATE OUTPUT
AS
	IF (LEN(@YearMonthString) > 0)
	BEGIN
		SET @DateResult = CONVERT(DATE, (SUBSTRING(@YearMonthString, 1, 4) + SUBSTRING(@YearMonthString, 6, 2) + '01'))
	END