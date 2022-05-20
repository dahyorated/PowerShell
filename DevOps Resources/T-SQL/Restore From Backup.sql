-- Change these variable to match the database being restored.
DECLARE @ClientId NVARCHAR(5) = '00002'; -- 2,5,6,7
DECLARE @DbPrefix NVARCHAR(32) = 'entityservice';
DECLARE @RestoreSuffix NVARCHAR(64) = '_2020-03-31T09-25Z';
-- Remainder of script does not need to be altered.
DECLARE @DbName NVARCHAR(64) = @DbPrefix+@ClientId+'db';
DECLARE @DbNameBak NVARCHAR(64) = @DbName + '_BAK';
DECLARE @DbNameRestore NVARCHAR(64) = @DbName + @RestoreSuffix;
USE master;
SELECT name, database_id, create_date FROM sys.databases WHERE name IN (@DbName, @DbNameBak, @DbNameRestore);
EXECUTE ('DROP DATABASE IF EXISTS ' + @DbNameBak);
EXECUTE ('ALTER DATABASE [' + @DbName + '] MODIFY NAME = [' + @DbNameBak + ']');
SELECT name, database_id, create_date FROM sys.databases WHERE name IN (@DbName, @DbNameBak, @DbNameRestore);
EXECUTE ('ALTER DATABASE [' + @DbNameRestore + '] MODIFY NAME = [' + @DbName + ']');
SELECT name, database_id, create_date FROM sys.databases WHERE name IN (@DbName, @DbNameBak, @DbNameRestore);

SELECT name, database_id, create_date FROM sys.databases WHERE name LIKE @DbPrefix+'%' ORDER BY name;
