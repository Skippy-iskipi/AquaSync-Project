@echo off
echo Running archive migration for AquaSync database...
echo.

echo Step 1: Adding archive columns to all tables...
psql -h your_host -U your_username -d your_database -f add_archive_columns.sql

if %errorlevel% neq 0 (
    echo Error: Failed to add archive columns
    pause
    exit /b 1
)

echo.
echo Step 2: Creating views for active records...
psql -h your_host -U your_username -d your_database -f update_queries_for_archive.sql

if %errorlevel% neq 0 (
    echo Error: Failed to create views
    pause
    exit /b 1
)

echo.
echo ✅ Archive migration completed successfully!
echo.
echo Next steps:
echo 1. Update your application queries to filter out archived records
echo 2. Test the archive functionality in your app
echo 3. Consider implementing an "Archived Items" view for admins
echo.
pause
