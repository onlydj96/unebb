@echo off
REM Code generation script for Windows

echo ========================================
echo Running code generation...
echo ========================================

flutter pub run build_runner build --delete-conflicting-outputs

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ Code generation completed successfully!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo ❌ Code generation failed!
    echo ========================================
    exit /b 1
)
