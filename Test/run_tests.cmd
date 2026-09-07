@echo off
:: Builds and runs the KittoX test suite.
::   run_tests.cmd [platform] [config] [bdspath]
::     [platform] : Win32 | Win64        (default: Win64)
::     [config]   : Debug | Release      (default: Debug - runs with range and
::                                        overflow checking on, which is the
::                                        point of running the tests at all)
:: Note: the variable is called KXPLATFORM, not PLATFORM: rsvars.bat clears the
::       latter, and MSBuild then refuses to build with an empty PLATFORM.
:: Exit code: 0 = all tests passed, 1 = build failed or some test failed.
setlocal

set DEFAULT_BDS=C:\BDS\Studio\37.0
set KXPLATFORM=%~1
if "%KXPLATFORM%"=="" set KXPLATFORM=Win64
set CFG=%~2
if "%CFG%"=="" set CFG=Debug
set BDS_PATH=%~3
if "%BDS_PATH%"=="" if not "%BDS%"=="" set BDS_PATH=%BDS%
if "%BDS_PATH%"=="" set BDS_PATH=%DEFAULT_BDS%

if not exist "%BDS_PATH%\bin\rsvars.bat" (
  echo [ERROR] rsvars.bat not found in "%BDS_PATH%\bin".
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
