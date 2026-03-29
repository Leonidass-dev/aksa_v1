import subprocess
import sys
import os
import signal
import time

def check_backend_ready(url="http://localhost:8000/", timeout=15):
    """Backend'in hazır olmasını bekle."""
    import urllib.request
    start = time.time()
    while time.time() - start < timeout:
        try:
            urllib.request.urlopen(url, timeout=2)
            return True
        except Exception:
            time.sleep(1)
    return False

def main():
    print("=" * 50)
    print("   AKSA v2.0 — Akıllı Kişisel Sağlık Asistanı")
    print("=" * 50)
    print()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.join(base_dir, "backend")

    # ── 1. Backend başlat ────────────────────────────────────
    python_exe = os.path.join(backend_dir, "venv", "Scripts", "python.exe")
    if not os.path.exists(python_exe):
        print("[!] Backend venv bulunamadi!")
        print("    Cozum: cd backend && python -m venv venv && venv\\Scripts\\pip install -r requirements.txt")
        sys.exit(1)

    backend_cmd = [python_exe, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

    print("[1/2] Backend (FastAPI + PostgreSQL) baslatiliyor...")
    backend_process = subprocess.Popen(
        backend_cmd,
        cwd=backend_dir,
        creationflags=subprocess.CREATE_NEW_CONSOLE if os.name == 'nt' else 0,
    )

    # Backend'in hazır olmasını bekle
    if check_backend_ready():
        print("[OK]  Backend hazir  →  http://localhost:8000")
        print("[OK]  API Docs       →  http://localhost:8000/docs")
    else:
        print("[!!]  Backend baslatma zaman asimina ugradi, yine de devam ediliyor...")

    print()

    # ── 2. Flutter başlat ────────────────────────────────────
    print("[2/2] Flutter uygulamasi baslatiliyor...")
    print("      (Cihaz secimi Flutter CLI tarafindan yapilacak)")
    print()

    flutter_cmd = ["flutter", "run"]
    flutter_process = subprocess.Popen(flutter_cmd, cwd=base_dir, shell=True)

    # ── Temiz kapatma ────────────────────────────────────────
    def force_kill(pid):
        try:
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(pid)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass

    def signal_handler(sig, frame):
        print("\n[*] Kapatiliyor...")
        force_kill(flutter_process.pid)
        force_kill(backend_process.pid)
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)

    try:
        flutter_process.wait()
        print("Flutter uygulamasi kapandi. Backend durduruluyor...")
    except KeyboardInterrupt:
        pass
    finally:
        force_kill(flutter_process.pid)
        force_kill(backend_process.pid)
        print("[*] Gorusmek uzere!")

if __name__ == "__main__":
    main()
