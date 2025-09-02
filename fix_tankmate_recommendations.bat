@echo off
echo ========================================
echo Fixing Fish Tankmate Recommendations
echo ========================================
echo.

echo Step 1: Running SQL table fixes...
echo Please run the following SQL in your Supabase dashboard:
echo.
echo 1. Go to your Supabase project dashboard
echo 2. Navigate to SQL Editor
echo 3. Copy and paste the contents of fix_tankmate_recommendations.sql
echo 4. Execute the SQL
echo.
pause

echo.
echo Step 2: Running Python compatibility fix script...
echo Using simple version to avoid dependency issues...
cd backend\scripts
python simple_tankmate_fix.py

echo.
echo ========================================
echo Fix complete! Check the generated files:
echo - simple_compatibility_matrix.json
echo - simple_tankmate_recommendations.json
echo - simple_compatibility_summary.json
echo ========================================
pause
