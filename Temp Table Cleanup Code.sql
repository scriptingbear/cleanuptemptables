/*
 Script to create a table valued function that returns a list of temporary tables
 as found in [tempdb].[sys].[tables]
*/

USE DB_Temp;
-- Create a few temp tables for testing.
GO
CREATE TABLE #TempTable1(ID INT, Computer_Name VARCHAR(100))
GO
CREATE TABLE #TempTable2(ID INT, Computer_Name VARCHAR(100))
GO
CREATE TABLE #TempTable3(ID INT, Computer_Name VARCHAR(100))
GO
CREATE TABLE #TempTable4(ID INT, Computer_Name VARCHAR(100))



GO
DROP FUNCTION dbo.GetTempTableBaseNames
GO

CREATE FUNCTION dbo.GetTempTableBaseNames()
RETURNS TABLE
AS

RETURN
	SELECT A.[TempTableBaseName]
	FROM
	(
		-- Look for 5 underscores in a row  and use that index to drop the remaining
		-- characters.
		SELECT [name],
			   [TempTableBaseName] =
					CASE
						WHEN CHARINDEX('_____',[name],1) > 0
						THEN SUBSTRING([name],1,(CHARINDEX('_____',[name],1))-1)
						ELSE [name]
					END 

		FROM [tempdb].[sys].[tables] 
	) A

-- Usage
--SELECT * FROM dbo.GetTempTableBaseNames()
--(4 rows affected)
-- Sample output
--TempTableBaseName
--#TempTable1
--#TempTable2
--#TempTable3
--#TempTable4



/*
 Script to create a stored procedure that calls the aforementioned table valued
 function and then uses dynamic SQL to delete each temporary table found.
*/

GO
DROP PROCEDURE dbo.CleanUpTempTables
GO
CREATE PROCEDURE dbo.CleanUpTempTables
AS
BEGIN
	BEGIN TRY
		IF NOT EXISTS(SELECT * FROM dbo.GetTempTableBaseNames())
			BEGIN
				PRINT 'No temp tables exist.'
				RETURN 0
			END

		DECLARE TempTableCursor CURSOR FOR
		SELECT * FROM dbo.GetTempTableBaseNames()

		DECLARE @TempTableName VARCHAR(100)
		DECLARE @SQL VARCHAR(1000)
		OPEN TempTableCursor

		FETCH NEXT FROM TempTableCursor INTO @TempTableName
		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @SQL = 'DROP TABLE ' + @TempTableName 
				EXEC(@SQL)
				PRINT 'Temp table ' + @TempTableName + ' has been deleted.'
				FETCH NEXT FROM TempTableCursor INTO @TempTableName
			END

		CLOSE TempTableCursor
		DEALLOCATE TempTableCursor
		RETURN 0 -- SUCCESS
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE()
		RETURN 1 -- FAILURE
	END CATCH
END

-- Usage:
DECLARE @Status INT
EXEC @Status = dbo.CleanUpTempTables
PRINT @Status

-- Sample output:
--Temp table #TempTable1 has been deleted.
--Temp table #TempTable2 has been deleted.
--Temp table #TempTable3 has been deleted.
--Temp table #TempTable4 has been deleted.
--0
-- Output when no temp tables exist in the current session
--No temp tables exist.
--0