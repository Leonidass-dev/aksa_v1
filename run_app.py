import subprocess
import sys
import os
import signal
import time
import socket


def get_local_ip():
    """Bilgisayarın Wi-Fi/LAN IP adresini bul."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


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
    local_ip = get_local_ip()

    print("=" * 55)
    print("   AKSA — Akıllı Kişisel Sağlık Asistanı (Lokal)")
    print("=" * 55)
    print()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.join(base_dir, "backend")

    # ── 0. PostgreSQL Otomatik Başlatıcı ─────────────────────
    pg_ctl = r"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe"
    pg_data = r"C:\Program Files\PostgreSQL\18\data"
    if os.path.exists(pg_ctl) and os.path.exists(pg_data):
        print("[*] PostgreSQL kontrol ediliyor (uykudaysa uyandirilir)...")
        subprocess.run(
            [pg_ctl, "start", "-D", pg_data],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    # ── 1. Backend başlat ────────────────────────────────────
    python_exe = os.path.join(backend_dir, "venv", "Scripts", "python.exe")
    if not os.path.exists(python_exe):
        print("[!] Backend venv bulunamadi!")
        print("    Cozum: cd backend && python -m venv venv && venv\\Scripts\\pip install -r requirements.txt")
        sys.exit(1)

    backend_cmd = [python_exe, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

    print("[1/2] Backend baslatiliyor...")
    backend_process = subprocess.Popen(
        backend_cmd,
        cwd=backend_dir,
        creationflags=subprocess.CREATE_NEW_CONSOLE if os.name == 'nt' else 0,
    )

    if check_backend_ready():
        print("[OK]  Backend hazir!")
    else:
        print("[!!]  Backend yavash basladi, devam ediliyor...")

    print()
    print(f"  Backend:   http://localhost:8000")
    print(f"  API Docs:  http://localhost:8000/docs")
    print(f"  Lokal IP:  {local_ip}")
    print()
    print("=" * 55)
    print(f"  Flutter baslatirken bu komutu kullanin:")
    print(f"  flutter run --dart-define=API_BASE_URL=http://{local_ip}:8000/api")
    print("=" * 55)
    print()

    # ── 2. Flutter başlat ────────────────────────────────────
    print("[2/2] Flutter baslatiliyor...")
    
    # Kullanıcı python run_app.py --release derse release moduna geç
    is_release = "--release" in sys.argv
    mode_text = "RELEASE (Yuksek Performans)" if is_release else "DEBUG (Gelistirici)"
    print(f"[*] Flutter {mode_text} modunda derleniyor...")
    
    flutter_cmd = [
        "flutter", "run",
        f"--dart-define=API_BASE_URL=http://{local_ip}:8000/api",
    ]
    if is_release:
        flutter_cmd.append("--release")
        
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
        print("Flutter kapandi. Backend durduruluyor...")
    except KeyboardInterrupt:
        pass
    finally:
        force_kill(flutter_process.pid)
        force_kill(backend_process.pid)
        print("[*] Gorusmek uzere!")


if __name__ == "__main__":
    main()
