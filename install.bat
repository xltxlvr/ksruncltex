@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------------
rem ksruncltex installer (Windows, TeX Live or MiKTeX)
rem
rem Usage:
rem   install.bat               : Install ksruncltex
rem   install.bat --uninstall   : Remove existing ksruncltex installation
rem   install.bat --reinstall   : Remove and then cleanly install again
rem ---------------------------------------------------------------------

echo ksruncltex installer for Windows (TeX Live / MiKTeX)
echo.

set "DO_UNINSTALL=0"
set "DO_INSTALL=1"
if /I "%~1"=="--uninstall" (
    set "DO_UNINSTALL=1"
    set "DO_INSTALL=0"
)
if /I "%~1"=="--reinstall" (
    set "DO_UNINSTALL=1"
    set "DO_INSTALL=1"
)

set "SCRIPT_DIR=%~dp0"
set "RES_DIR=%SCRIPT_DIR%Resources"

rem --- Cleanup: remove legacy cluttex_patched.lua (no longer needed) ------
for /f "delims=" %%i in ('kpsewhich --format=lua cluttex_patched.lua 2^>nul') do (
    set "LEGACY=%%i"
    set "LEGACY=!LEGACY:/=\!"
    if exist "!LEGACY!" (
        del /f /q "!LEGACY!" >nul 2>&1
        echo [Info] Removed legacy file: !LEGACY!
    )
)

rem --- 0. Uninstall Logic ------------------------------------------------
if "!DO_UNINSTALL!"=="1" (
    echo [Info] Uninstalling ksruncltex...

    for /f "delims=" %%i in ('kpsewhich --format=lua ksruncltex.lua 2^>nul') do (
        set "TARGET=%%i"
        set "TARGET=!TARGET:/=\!"
        if exist "!TARGET!" (
            del /f /q "!TARGET!" >nul 2>&1
            echo [Info] Removed: !TARGET!
        )
    )
    for /f "delims=" %%i in ('where ksruncltex.bat 2^>nul') do (
        set "TARGET=%%i"
        if exist "!TARGET!" (
            del /f /q "!TARGET!" >nul 2>&1
            echo [Info] Removed: !TARGET!
        )
    )

    where mktexlsr >nul 2>&1
    if not errorlevel 1 (
        mktexlsr >nul 2>&1
    ) else (
        where initexmf >nul 2>&1
        if not errorlevel 1 (
            initexmf --update-fndb >nul 2>&1
        )
    )

    if "!DO_INSTALL!"=="0" (
        echo [Info] Uninstall complete.
        exit /b 0
    )
    echo.
)

rem --- 1. Preconditions: a TeX distribution must already be on PATH -----
where kpsewhich >nul 2>&1
if errorlevel 1 (
    echo [Error] kpsewhich was not found. Please install TeX Live or MiKTeX first and make sure it is on PATH.
    exit /b 1
)
where texlua >nul 2>&1
if errorlevel 1 (
    echo [Error] texlua was not found. Make sure your TeX distribution includes LuaTeX.
    exit /b 1
)

if not exist "%RES_DIR%\ksruncltex.lua" (
    echo [Error] Resources\ksruncltex.lua was not found. Make sure install.bat and the Resources folder are in the same place.
    exit /b 1
)
if not exist "%RES_DIR%\ksruncltex.bat" (
    echo [Error] Resources\ksruncltex.bat was not found. Make sure install.bat and the Resources folder are in the same place.
    exit /b 1
)

rem --- 2. Determine install dir for the Lua scripts ----------------------
set "DEST="
set "EXISTING_LUA="
for /f "delims=" %%i in ('kpsewhich --format=lua ksruncltex.lua 2^>nul') do set "EXISTING_LUA=%%i"
if not "!EXISTING_LUA!"=="" (
    set "EXISTING_LUA=!EXISTING_LUA:/=\!"
    for %%F in ("!EXISTING_LUA!") do set "EXISTING_DIR=%%~dpF"
    if "!EXISTING_DIR:~-1!"=="\" set "EXISTING_DIR=!EXISTING_DIR:~0,-1!"

    >"!EXISTING_DIR!\.ksruncltex_write_test.tmp" (echo test) 2>nul
    if exist "!EXISTING_DIR!\.ksruncltex_write_test.tmp" (
        del /q "!EXISTING_DIR!\.ksruncltex_write_test.tmp" >nul 2>&1
        set "DEST=!EXISTING_DIR!"
        echo [Info] Detected an existing install: !EXISTING_LUA!
        echo [Info] Updating that location: !DEST!
    ) else (
        echo [Warning] Detected an existing install ^(!EXISTING_LUA!^) but it is not writable. Installing fresh at the default location instead.
    )
)

if "!DEST!"=="" (
    set "TEXMFHOME="
    for /f "delims=" %%i in ('kpsewhich --var-value=TEXMFHOME 2^>nul') do set "TEXMFHOME=%%i"
    if not "!TEXMFHOME!"=="" set "TEXMFHOME=!TEXMFHOME:/=\!"

    if "!TEXMFHOME!"=="" (
        echo [Warning] kpsewhich returned no value for TEXMFHOME. Registering a new TEXMF root instead...
        set "TEXMFHOME=%LOCALAPPDATA%\ksruncltex\texmf"
        if not exist "!TEXMFHOME!" mkdir "!TEXMFHOME!"

        where initexmf >nul 2>&1
        if errorlevel 1 (
            echo [Error] Could not determine TEXMFHOME, and initexmf was not found either.
            exit /b 1
        )

        initexmf --register-root="!TEXMFHOME!" >nul 2>&1
        if errorlevel 1 (
            echo [Error] "initexmf --register-root" failed.
            exit /b 1
        )
        echo [Info] Registered "!TEXMFHOME!" as a new TEXMF root.
    )

    set "DEST=!TEXMFHOME!\scripts\ksruncltex"
)

if not exist "%DEST%" mkdir "%DEST%"
copy /y "%RES_DIR%\ksruncltex.lua" "%DEST%\" >nul
echo [Info] Installed ksruncltex.lua: %DEST%

rem --- 3. Determine bin dir for ksruncltex.bat -----------------------------
set "BINDIR="
for /f "delims=" %%i in ('where ksruncltex.bat 2^>nul') do (
    if "!BINDIR!"=="" set "BINDIR=%%i"
)
if not "!BINDIR!"=="" (
    for %%F in ("!BINDIR!") do set "BINDIR=%%~dpF"
    if "!BINDIR:~-1!"=="\" set "BINDIR=!BINDIR:~0,-1!"
    echo [Info] Detected an existing ksruncltex.bat. Updating that location: !BINDIR!
)

if "!BINDIR!"=="" (
    for /f "delims=" %%i in ('kpsewhich --var-value=SELFAUTOLOC 2^>nul') do set "BINDIR=%%i"
    if not "!BINDIR!"=="" set "BINDIR=!BINDIR:/=\!"

    if "!BINDIR!"=="" (
        echo [Warning] kpsewhich returned no value for SELFAUTOLOC. Falling back to kpsewhich.exe's own location...
        for /f "delims=" %%i in ('where kpsewhich') do (
            if "!BINDIR!"=="" for %%F in ("%%i") do set "BINDIR=%%~dpF"
        )
        if not "!BINDIR!"=="" if "!BINDIR:~-1!"=="\" set "BINDIR=!BINDIR:~0,-1!"
    )
)

if "!BINDIR!"=="" (
    echo [Error] Could not determine the TeX bin folder. Please copy ksruncltex.bat into a folder on PATH manually.
    exit /b 1
)

copy /y "%RES_DIR%\ksruncltex.bat" "%BINDIR%\" >nul
if errorlevel 1 (
    echo [Warning] Failed to copy ksruncltex.bat into %BINDIR%. Try running this script as Administrator.
) else (
    echo [Info] Installed ksruncltex.bat: %BINDIR%
)

rem --- 4. Refresh the filename database ----------------------------------
where mktexlsr >nul 2>&1
if not errorlevel 1 (
    mktexlsr >nul 2>&1
    echo [Info] mktexlsr completed
) else (
    where initexmf >nul 2>&1
    if not errorlevel 1 (
        initexmf --update-fndb >nul 2>&1
        echo [Info] initexmf --update-fndb completed
    ) else (
        echo [Warning] Neither mktexlsr nor initexmf was found. Please refresh the filename database manually.
    )
)

echo.
echo Install complete. Open a new command prompt and run 'ksruncltex --help' to verify.
endlocal
