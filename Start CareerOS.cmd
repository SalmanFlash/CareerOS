@echo off
cd /d "%~dp0"
if not exist build\web\offline.js (
  echo Build the app first using the instructions in README.md.
  pause
  exit /b 1
)
echo Open http://127.0.0.1:4173 in Edge or Chrome. Keep this window open while using the preview.
node tool\serve.mjs
pause
