"""Start the whole MedFarm backend from one terminal; Ctrl+C stops everything.

    backend\\start.bat            (or: backend\\.venv\\Scripts\\python backend\\run_backend.py)

- Ollama (the chatbot's AI model), if installed and not already running
- Chatbot server            http://127.0.0.1:8001
- Image disease API (FastAPI) http://127.0.0.1:8000

Set MEDFARM_HOST=0.0.0.0 first to let a phone on the same Wi-Fi connect.
"""
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

BACKEND = Path(__file__).resolve().parent
CHATBOT = BACKEND / "models" / "chat_bot"
HOST = os.environ.get("MEDFARM_HOST", "127.0.0.1")


def find_ollama():
    path = shutil.which("ollama")
    if path:
        return path
    local = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Ollama" / "ollama.exe"
    return str(local) if local.exists() else None


def ollama_running():
    try:
        urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=2)
        return True
    except OSError:
        return False


def start_ollama(procs):
    ollama = find_ollama()
    if not ollama:
        print("[medfarm] Ollama not installed: the chatbot gives instant answers only "
              "(install with: winget install Ollama.Ollama)")
        return
    if not ollama_running():
        print("[medfarm] starting Ollama...")
        procs.append(("Ollama", subprocess.Popen([ollama, "serve"], stdout=subprocess.DEVNULL,
                                                 stderr=subprocess.DEVNULL)))
        for _ in range(20):
            if ollama_running():
                break
            time.sleep(0.5)
    models = subprocess.run([ollama, "list"], capture_output=True, text=True).stdout
    if "medfarm-llama" not in models and (CHATBOT / "medfarm-llama-Q4_K_M.gguf").exists():
        print("[medfarm] registering medfarm-llama with Ollama (one-time, copies 4.9 GB)...")
        subprocess.run([ollama, "create", "medfarm-llama", "-f", "Modelfile"], cwd=CHATBOT)


def main():
    sys.stdout.reconfigure(line_buffering=True)  # show status lines at once
    procs = []
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    try:
        start_ollama(procs)
        procs.append(("Chatbot", subprocess.Popen(
            [sys.executable, "app/server.py"], cwd=CHATBOT, env=env)))
        procs.append(("Image API", subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "app.main:app", "--host", HOST, "--port", "8000"],
            cwd=BACKEND, env=env)))
        print("[medfarm] chatbot: http://127.0.0.1:8001   image API: http://127.0.0.1:8000/docs")
        print("[medfarm] press Ctrl+C to stop everything")
        while all(p.poll() is None for name, p in procs if name != "Ollama"):
            time.sleep(1)
        stopped = [name for name, p in procs if p.poll() is not None]
        print(f"[medfarm] {', '.join(stopped)} stopped; shutting down the rest.")
    except KeyboardInterrupt:
        print("\n[medfarm] stopping...")
    finally:
        for _, p in reversed(procs):
            if p.poll() is None:
                p.terminate()
        for _, p in procs:
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                p.kill()


if __name__ == "__main__":
    main()
