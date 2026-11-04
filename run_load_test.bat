@echo off
echo =========================================================
echo  NOTIFYED - AUTOMATED LOAD AND STRESS TESTING TOOL (k6)
echo  Target: Supabase Backend API and Database Concurrency
echo  Simulating: 10 to 200 Virtual Users (VUs)
echo =========================================================
echo.
"C:\Program Files\k6\k6.exe" run tool/load_and_stress_test.js
echo.
echo =========================================================
echo  TEST COMPLETE! You can screenshot the summary box above.
echo =========================================================
pause
