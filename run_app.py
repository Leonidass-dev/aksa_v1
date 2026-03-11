import subprocess
import sys
import os
import signal
import time

def main():
    print("[*] AKSA Projesi Baslatiliyor...")
    
    # Paths
    base_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.join(base_dir, "backend")
    
    # Backend command (using absolute path to the virtual environment's python)
    python_exe = os.path.join(backend_dir, "venv", "Scripts", "python.exe")
    backend_cmd = [python_exe, "-m", "uvicorn", "main:app", "--port", "8000"]
    
    # Start Backend
    print("[*] Backend (FastAPI) baslatiliyor...")
    backend_process = subprocess.Popen(
        backend_cmd, 
        cwd=backend_dir,
        creationflags=subprocess.CREATE_NEW_CONSOLE if os.name == 'nt' else 0
    )
    
    time.sleep(2) # Give backend a moment to start
    
    # Start Flutter
    print("[*] Flutter Uygulamasi baslatiliyor...")
    flutter_cmd = ["flutter", "run"]
    flutter_process = subprocess.Popen(flutter_cmd, cwd=base_dir, shell=True)
    
    def force_kill(pid):
        try:
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def signal_handler(sig, frame):
        print("\n[*] Kapatiliyor...")
        force_kill(flutter_process.pid)
        force_kill(backend_process.pid)
        sys.exit(0)
        
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        # Wait for Flutter app to close naturally
        flutter_process.wait()
        print("Flutter uygulaması kapandı. Backend durduruluyor...")
    except KeyboardInterrupt:
        pass
    finally:
        force_kill(flutter_process.pid)
        force_kill(backend_process.pid)
        print("[*] Gorusmek uzere!")

if __name__ == "__main__":
    main()
