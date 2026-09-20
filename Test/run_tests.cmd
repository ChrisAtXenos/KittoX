@echo off
:: Builds and runs the KittoX test suite.
::   run_tests.cmd [platform] [config] [bdspath]
::     [platform] : Win32 | Win64        (default: Win64)
::     [config]   : Debug | Release      (default: Debug - runs with range and
::                                        overflow checking on, which is the
::                                        point of running the tests at all)
::     [bdspath]  : Delphi BDS path      (default: the BDS environment variable,
::                                        else the newest Delphi found in the
::                                        registry: 13, 12, 11, 10.4)
:: Note: the variable is called KXPLATFORM, not PLATFORM: rsvars.bat clears the
::       latter, and MSBuild then refuses to build with an empty PLATFORM.
:: Exit code: 0 = all tests passed, 1 = build failed or some test failed.
setlocal enabledelayedexpansion

:: --- Delphi BDS path (default) ---
:: Every Delphi writes its install folder in the registry at
:: HK(CU|LM)\Software\Embarcadero\BDS\<version>\RootDir:
::   37.0 = Delphi 13, 23.0 = Delphi 12, 22.0 = Delphi 11, 21.0 = Delphi 10.4.
:: Newest first; the historical C:\BDS\Studio\37.0 is the last resort.
set DEFAULT_BDS=
if "%DEFAULT_BDS%"=="" call :FindBDS 37.0
if "%DEFAULT_BDS%"=="" call :FindBDS 23.0
if "%DEFAULT_BDS%"=="" call :FindBDS 22.0
if "%DEFAULT_BDS%"=="" call :FindBDS 21.0
if "%DEFAULT_BDS%"=="" set DEFAULT_BDS=C:\BDS\Studio\37.0
set KXPLATFORM=%~1
if "%KXPLATFORM%"=="" set KXPLATFORM=Win64
set CFG=%~2
if "%CFG%"=="" set CFG=Debug
set BDS_PATH=%~3
if "%BDS_PATH%"=="" if not "%BDS%"=="" set BDS_PATH=%BDS%
if "%BDS_PATH%"=="" set BDS_PATH=%DEFAULT_BDS%

if not exist "%BDS_PATH%\bin\rsvars.bat" (
  echo [ERROR] rsvars.bat not found in "%BDS_PATH%\bin".
  echo         Pass the path as third argument, or set the BDS variable.
  exit /b 2
)
call "%BDS_PATH%\bin\rsvars.bat" >nul

set PROJ=%~dp0Projects\D13\KittoXTests.dproj
set EXE=%~dp0Bin\%KXPLATFORM%\%CFG%\KittoXTests.exe
:: DUnitX writes its NUnit-shaped report next to the binary, under its
:: default name; the run below sets the working directory accordingly.
set XMLOUT=%~dp0Bin\%KXPLATFORM%\%CFG%\dunitx-results.xml

echo ============================================
echo  KittoX test suite - %KXPLATFORM% / %CFG%
echo ============================================
msbuild "%PROJ%" /t:Build /p:Config=%CFG% /p:Platform=%KXPLATFORM% /nologo /v:minimal
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 1
)

if not exist "%EXE%" (
  echo [ERROR] "%EXE%" not found after a successful build.
  exit /b 1
)

pushd "%~dp0Bin\%KXPLATFORM%\%CFG%"
"%EXE%" --exitbehavior:Continue
set TESTRESULT=%ERRORLEVEL%
popd

echo.
if "%TESTRESULT%"=="0" (
  echo All tests passed. Report: "%XMLOUT%"
) else (
  echo Some tests failed. Report: "%XMLOUT%"
)
exit /b %TESTRESULT%

:: ============================================================
:FindBDS <version>
::   Sets DEFAULT_BDS to the RootDir of that BDS version (HKCU first, then
::   HKLM), without the trailing backslash, and only if it holds rsvars.bat.
:: ============================================================
call :ReadRootDir HKCU %~1
if "%DEFAULT_BDS%"=="" call :ReadRootDir HKLM %~1
:: Delayed expansion here: a %VAR:~-1% substring on an EMPTY variable breaks the
:: parse of the whole line (the version is not installed), !VAR:~-1! does not.
if "!DEFAULT_BDS:~-1!"=="\" set "DEFAULT_BDS=!DEFAULT_BDS:~0,-1!"
if not "%DEFAULT_BDS%"=="" if not exist "%DEFAULT_BDS%\bin\rsvars.bat" set DEFAULT_BDS=
exit /b 0

:: ============================================================
:ReadRootDir <hive> <version>
::   reg query prints "    RootDir    REG_SZ    C:\...\Studio\<version>\";
::   the line is picked by its first token (no "find": a Unix find.exe on
::   the PATH, e.g. under Git Bash, would break it) and tokens=1,2,* keeps
::   the whole path even when it contains spaces.
:: ============================================================
for /f "tokens=1,2,*" %%A in ('reg query "%~1\Software\Embarcadero\BDS\%~2" /v RootDir 2^>nul') do (
  if /i "%%A"=="RootDir" set "DEFAULT_BDS=%%C"
)
exit /b 0
