@echo off
REM Watch mode for code generation (Windows)

echo ========================================
echo Starting code generation watch mode...
echo Press Ctrl+C to stop
echo ========================================
echo.

flutter pub run build_runner watch --delete-conflicting-outputs
