@echo off
setlocal EnableExtensions
title Nivela
color 0B

set "REPO_URL=https://github.com/razvannicu15/Nivela.git"
set "DL_URL=https://github.com/razvannicu15/Nivela/releases/download/latest"
set "ADB_ZIP=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

rem Daca .bat-ul sta in folderul proiectului il folosim pe acela,
rem altfel lucram in D:\Apps\Nivela (ex. cand e pus pe Desktop).
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%pubspec.yaml" (
  set "APP_DIR=%SCRIPT_DIR:~0,-1%"
) else (
  set "APP_DIR=D:\Apps\Nivela"
)
set "OUT_DIR=%APP_DIR%\dist"
set "APK=%OUT_DIR%\Nivela-android.apk"

:menu
cls
echo.
echo   ==============================================
echo                      N I V E L A
echo   ==============================================
echo    Proiect: %APP_DIR%
echo.
echo    [1] DESCARCA ultimul APK      - fara Flutter, fara login
echo    [2] Instaleaza pe telefon     - prin cablu USB
echo    [3] Deschide folderul cu APK
echo    [4] Actualizeaza codul din GitHub
echo    [5] Build local               - doar daca ai Flutter instalat
echo    [0] Iesire
echo.
set "CH="
set /p "CH=   Alege optiunea: "
if "%CH%"=="1" goto cloud
if "%CH%"=="2" goto install
if "%CH%"=="3" goto open
if "%CH%"=="4" goto update
if "%CH%"=="5" goto local
if "%CH%"=="0" exit /b 0
goto menu

rem ------------------------------------------------------------ 1. cloud
:cloud
call :download || goto pause_menu
start "" explorer "%OUT_DIR%"
goto pause_menu

:download
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
echo.
echo   Descarc Nivela-android.apk ...
curl -L -f --progress-bar -o "%APK%.part" "%DL_URL%/Nivela-android.apk"
if errorlevel 1 goto dl_fail
move /y "%APK%.part" "%APK%" >nul
echo.
echo   ======  GATA  ======
echo   APK: %APK%
exit /b 0
:dl_fail
del /q "%APK%.part" >nul 2>&1
echo.
echo   Descarcarea a esuat. Verifica:
echo    - repo-ul este public pe GitHub
echo    - build-ul s-a terminat: https://github.com/razvannicu15/Nivela/actions
exit /b 1

rem ---------------------------------------------------------- 2. install
:install
if not exist "%APK%" (
  call :download || goto pause_menu
)
call :ensure_adb || goto pause_menu
echo.
echo   Pe telefon: Setari ^> Optiuni dezvoltator ^> Depanare USB = activ.
echo   Conecteaza cablul si accepta "Permiti depanarea USB?" pe telefon.
echo.
"%ADB%" start-server >nul 2>&1
"%ADB%" wait-for-device
echo   Instalez ...
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo.
  echo   Instalarea a esuat. Daca ai o versiune veche semnata altfel,
  echo   dezinstaleaz-o intai de pe telefon si incearca din nou.
  goto pause_menu
)
"%ADB%" shell monkey -p ro.noraz.nivela -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo   ======  INSTALAT  ======
goto pause_menu

rem ------------------------------------------------------------- 3. open
:open
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
start "" explorer "%OUT_DIR%"
goto menu

rem ----------------------------------------------------------- 4. update
:update
call :ensure_repo || goto pause_menu
echo.
git -C "%APP_DIR%" pull --ff-only
goto pause_menu

rem ------------------------------------------------------------ 5. local
:local
call :need_flutter || goto pause_menu
call :ensure_repo || goto pause_menu
call :build_apk
goto pause_menu

rem ============================================================ helpers
:ensure_adb
set "ADB="
for /f "delims=" %%A in ('where adb 2^>nul') do if not defined ADB set "ADB=%%A"
if defined ADB exit /b 0
set "ADB=%APP_DIR%\tools\platform-tools\adb.exe"
if exist "%ADB%" exit /b 0
echo.
echo   Descarc instrumentele Android (adb) - doar prima data ...
if not exist "%APP_DIR%\tools" mkdir "%APP_DIR%\tools"
curl -L -f --progress-bar -o "%APP_DIR%\tools\pt.zip" "%ADB_ZIP%"
if errorlevel 1 (
  echo   Nu am putut descarca adb.
  exit /b 1
)
tar -xf "%APP_DIR%\tools\pt.zip" -C "%APP_DIR%\tools"
del /q "%APP_DIR%\tools\pt.zip" >nul 2>&1
if exist "%ADB%" exit /b 0
echo   adb nu a putut fi pregatit.
exit /b 1

:ensure_repo
where git >nul 2>&1
if not errorlevel 1 goto have_git
echo.
echo   Instalez Git - doar prima data ...
winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
set "PATH=%PATH%;C:\Program Files\Git\cmd"
where git >nul 2>&1
if not errorlevel 1 goto have_git
echo   Git nu s-a putut instala. Instaleaza-l de la https://git-scm.com/download/win
exit /b 1
:have_git
if exist "%APP_DIR%\.git" exit /b 0
echo.
echo   Descarc proiectul in %APP_DIR% ...
if not exist "D:\Apps" mkdir "D:\Apps"
if exist "%APP_DIR%" (
  git clone "%REPO_URL%" "%APP_DIR%\_src"
  if errorlevel 1 exit /b 1
  xcopy /e /h /q /y "%APP_DIR%\_src\*" "%APP_DIR%\" >nul
  rmdir /s /q "%APP_DIR%\_src"
  exit /b 0
)
git clone "%REPO_URL%" "%APP_DIR%"
if errorlevel 1 exit /b 1
exit /b 0

:need_flutter
where flutter >nul 2>&1
if not errorlevel 1 exit /b 0
echo.
echo   Flutter nu este instalat. Foloseste optiunea 1 - build in cloud.
exit /b 1

:build_apk
cd /d "%APP_DIR%"
if not exist "%APP_DIR%\android\" (
  call flutter create --platforms=android --org ro.noraz --project-name nivela .
  if errorlevel 1 exit /b 1
)
call flutter pub get
if errorlevel 1 exit /b 1
call dart run tool/patch_platforms.dart
call dart run flutter_launcher_icons
call flutter build apk --release --target-platform android-arm64
if errorlevel 1 exit /b 1
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
copy /y "build\app\outputs\flutter-apk\app-release.apk" "%APK%" >nul
echo   APK: %APK%
exit /b 0

:pause_menu
echo.
pause
goto menu
