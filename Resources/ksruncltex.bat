@echo off
setlocal enabledelayedexpansion

:: kpsewhich를 사용하여 ksruncltex.lua의 절대 경로를 탐색
for /f "delims=" %%i in ('kpsewhich --format=lua ksruncltex.lua') do (
    set "LUA_SCRIPT=%%i"
)

:: 파일을 찾지 못한 경우 에러 처리
if "%LUA_SCRIPT%"=="" (
    echo [Error] ksruncltex.lua를 찾을 수 없습니다.
    echo 파일이 $TEXMFLOCAL\scripts\ksruncltex\ 폴더에 위치해 있는지 확인하고 'mktexlsr'를 실행하세요.
    exit /b 1
)

:: 발견된 루아 스크립트를 texlua로 실행하며 모든 인자(%*)를 전달
texlua "%LUA_SCRIPT%" %*