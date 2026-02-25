@echo off
REM =============================================================================
REM Dungeon Visualizer Build Script (Windows)
REM =============================================================================
REM Finds Odin compiler and runs the project
REM Configure ODIN_PATH environment variable to override default locations
REM
REM Usage:
REM   build.bat              # Build and run
REM   build.bat -debug       # Debug build
REM   build.bat -check       # Check syntax only
REM   set ODIN_PATH=C:\path\odin && build.bat
REM =============================================================================

setlocal enabledelayedexpansion

REM Parse arguments
set BUILD_MODE=run
set DEBUG_FLAG=

for %%A in (%*) do (
    if "%%A"=="-debug" set DEBUG_FLAG=-debug
    if "%%A"=="-check" set BUILD_MODE=check
    if "%%A"=="-run" set BUILD_MODE=run
    if "%%A"=="-build" set BUILD_MODE=build
)

REM Find Odin compiler
set ODIN_BIN=

REM Check user-provided path
if defined ODIN_PATH (
    if exist "%ODIN_PATH%\odin.exe" (
        set ODIN_BIN=%ODIN_PATH%\odin.exe
    )
)

REM Check common locations
if not defined ODIN_BIN (
    if exist "%USERPROFILE%\tools\Odin\odin.exe" (
        set ODIN_BIN=%USERPROFILE%\tools\Odin\odin.exe
    )
)

if not defined ODIN_BIN (
    if exist "C:\odin\odin.exe" (
        set ODIN_BIN=C:\odin\odin.exe
    )
)

if not defined ODIN_BIN (
    if exist "C:\tools\odin\odin.exe" (
        set ODIN_BIN=C:\tools\odin\odin.exe
    )
)

REM Check system PATH
if not defined ODIN_BIN (
    for %%X in (odin.exe) do (
        set ODIN_BIN=%%~$PATH:X
    )
)

REM Error if not found
if not defined ODIN_BIN (
    echo Error: Odin compiler not found!
    echo.
    echo Please install Odin or set ODIN_PATH environment variable:
    echo   set ODIN_PATH=C:\tools\Odin
    echo   build.bat
    echo.
    echo Checked locations:
    echo   - %%ODIN_PATH%%
    echo   - %%USERPROFILE%%\tools\Odin
    echo   - C:\odin
    echo   - C:\tools\odin
    exit /b 1
)

echo Found Odin: !ODIN_BIN!
echo.

REM Run build
if "!BUILD_MODE!"=="run" (
    echo Running: !ODIN_BIN! run src !DEBUG_FLAG!
    !ODIN_BIN! run src !DEBUG_FLAG!
) else if "!BUILD_MODE!"=="check" (
    echo Checking: !ODIN_BIN! check src
    !ODIN_BIN! check src
) else if "!BUILD_MODE!"=="build" (
    echo Building: !ODIN_BIN! build src !DEBUG_FLAG!
    !ODIN_BIN! build src !DEBUG_FLAG!
)
