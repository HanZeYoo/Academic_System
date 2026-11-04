@echo off
echo =========================================================
echo  NOTIFYED - PERFORMANCE LATENCY BENCHMARK RUNNER (N=30)
echo  Testing: At-Risk Rule Evaluation and ECR Parsing Speed
echo =========================================================
echo.
flutter test test/performance_benchmark_test.dart
echo.
echo =========================================================
echo  BENCHMARK COMPLETE! You can screenshot the results above.
echo =========================================================
pause
