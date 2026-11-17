@echo off
rem Push every build in dist\ to itch.io. Usage: tools\push_itch.bat 0.17.0
rem Needs butler (https://itch.io/docs/butler/) signed in once with "butler login".
setlocal
if "%~1"=="" (echo usage: tools\push_itch.bat VERSION & exit /b 1)
set V=%~1
set BUTLER=butler
where butler >nul 2>nul || set BUTLER="%USERPROFILE%\Downloads\butler-windows-amd64\butler.exe"
cd /d "%~dp0.."
%BUTLER% push --if-changed "dist\Project-Ascent-v%V%-itch-web.zip" p4inz-code/project-ascent:html5 --userversion %V% || exit /b 1
%BUTLER% push --if-changed "dist\Project-Ascent-v%V%-Windows.zip" p4inz-code/project-ascent:windows --userversion %V% || exit /b 1
%BUTLER% push --if-changed "dist\Project-Ascent-v%V%-macOS.zip" p4inz-code/project-ascent:mac --userversion %V% || exit /b 1
%BUTLER% push --if-changed "dist\Project-Ascent-v%V%-Linux.zip" p4inz-code/project-ascent:linux --userversion %V% || exit /b 1
%BUTLER% status p4inz-code/project-ascent
