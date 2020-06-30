/*
USE [Interject_Demos_Students]
*/

CREATE PROC [billing].[Validate_Year_Month_Varchar_Date_Input]
@YearMonthString VARCHAR(7)
,@ErrorFound BIT OUTPUT
AS
	IF (
		(LEN(@YearMonthString) <> 0)
		AND (
			-- Check delimiters:
			(SUBSTRING(@YearMonthString, 5, 1) <> '-' AND SUBSTRING(@YearMonthString, 5, 1) <> '/')
			-- Check date parts:
			OR (ISNUMERIC(CONVERT(INT, SUBSTRING(@YearMonthString, 1, 4)))) = 0
			OR (ISNUMERIC(CONVERT(INT, SUBSTRING(@YearMonthString, 6, 2)))) = 0
			)
		)
	BEGIN
		SET @ErrorFound = 1
	END
	ELSE BEGIN
		SET @ErrorFound = 0
	END