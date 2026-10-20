@echo off
REM MedFarm UI launcher: starts Ollama, registers the model once, runs the UI.
cd /d "%~dp0"

where ollama >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" (
    set "PATH=%LOCALAPPDATA%\Programs\Ollama;%PATH%"
  ) else (
    echo Ollama is not installed. Install it with:  winget install Ollama.Ollama
    pause & exit /b 1
  )
)

ollama list >nul 2>nul
if errorlevel 1 (
  echo Starting Ollama server...
  start "" /b ollama serve >nul 2>nul
  timeout /t 5 >nul
)

ollama list | findstr /b /c:"medfarm-llama" >nul
if errorlevel 1 (
  echo Registering medfarm-llama with Ollama ^(one-time, copies 4.9 GB^)...
  ollama create medfarm-llama -f Modelfile || (pause & exit /b 1)
)

start "" http://127.0.0.1:8001
python app\server.py
