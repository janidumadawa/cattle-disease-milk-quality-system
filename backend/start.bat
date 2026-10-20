@echo off
REM MedFarm backend: chatbot (port 8001) + image disease API (port 8000). Ctrl+C stops both.
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo First run: creating the Python environment and installing packages...
  python -m venv .venv || (pause & exit /b 1)
  .venv\Scripts\python.exe -m pip install -r requirements.txt || (pause & exit /b 1)
)

.venv\Scripts\python.exe run_backend.py
