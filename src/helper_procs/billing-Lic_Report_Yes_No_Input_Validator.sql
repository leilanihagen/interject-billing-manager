USE [Interject_Demos_Students]

ALTER PROC [billing].[Lic_Report_Yes_No_Input_Validator]
@InputString NVARCHAR (500)
,@Result BIT OUTPUT
AS
	IF @InputString = 'yes'
		OR @InputString = 'y'
		OR @InputString = 'YES'
		OR @InputString = 'Yes'
		OR @InputString = '1'
	BEGIN SET @Result = 1
	END
	ELSE BEGIN SET @Result = 0
	END