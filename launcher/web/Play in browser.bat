@echo off
rem Project Ascent web build: starts a local web server for this folder and opens the game in your browser.
rem (Opening index.html directly does not work: browsers block web games from file://.)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
