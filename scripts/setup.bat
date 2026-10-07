@echo off
REM Development environment setup script for Windows

echo ========================================
echo Setting up development environment...
echo ========================================
echo.

echo Step 1/3: Installing dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    exit /b 1
)
echo.

echo Step 2/3: Generating code...
call flutter pub run build_runner build --delete-conflicting-outputs
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to generate code
    exit /b 1
)
echo.

echo Step 3/3: Running analysis...
call flutter analyze
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Analysis found issues (check output above)
) else (
    echo ✅ No analysis issues found
)
echo.

echo ========================================
echo ✅ Development environment ready!
echo ========================================
echo.
echo Available commands:
echo   - scripts\codegen.bat  : Generate code
echo   - scripts\watch.bat    : Watch mode
echo   - flutter run          : Run the app
echo ========================================
