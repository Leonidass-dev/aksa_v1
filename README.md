# AKSA (Akıllı Kişisel Sağlık Asistanı) 🧬🚀

AKSA, akıllı saat (Health Connect) sensör verilerini ve kullanıcı profillerini kullanarak makine öğrenimi (Yapay Zeka) destekli kişiselleştirilmiş analizler sunan, yeni nesil bir **Akıllı Sağlık Asistanı** mobil uygulamasıdır.

Bu proje, gelişmiş bir **Flutter** mobil arayüzü ile derin öğrenme ve büyük veri işleyen bir **Python (FastAPI)** backend sunucusunun entegrasyonundan oluşur. Proje, akademik bir tezin 7 ana modülünün mobil platforma aktarılmış halidir.

---

## 🏗️ Mimari ve Teknolojiler

Proje "Frontend", "Backend" ve "AI (Makine Öğrenimi)" olmak üzere üç ana ayaktan oluşur.

### 📱 Frontend (Mobil Uygulama)
- **Framework:** Flutter (Dart)
- **State Management:** Provider / ValueNotifier (Hafif ve hızlı durum yönetimi)
- **Routing:** GoRouter (Modern, auth-guard entegreli yönlendirme)
- **Authentication & DB:** Firebase Auth, Cloud Firestore (Abonelik, kullanıcı profili ve auth)
- **Cihaz Entegrasyonu:** `health` paketi (Google Health Connect API ile akıllı saat sensör verilerini otomatik okuma)
- **Tasarım Dili:** Özel "Glassmorphism" ve Material 3 harmanı dinamik tasarım (Karanlık/Aydınlık mod destekli)

### ⚙️ Backend (API ve İş Mantığı)
- **Framework:** FastAPI (Yüksek performanslı, asenkron Python API)
- **Veritabanı:** PostgreSQL (SQLAlchemy ORM ile asenkron bağlantı - `asyncpg`)
- **Migrasyon & Hata Yönetimi:** Küresel Exception Handler, `pool_recycle` ile dayanıklı bağlantı mimarisi
- **LLM (Büyük Dil Modelleri):** OpenAI GPT / Gemini altyapılı asistan, diyet ve egzersiz jeneratörü

### 🧠 Yapay Zeka (AI & ML)
- **Risk Analizi (M3):** XGBoost + GRU (Gated Recurrent Unit) modellerinin Ensemble (Topluluk) füzyonu.
- **Anomali Tespiti (M7):** PyTorch tabanlı **LSTM-Autoencoder** (Zaman serisi anomalileri tespiti).
- **Açıklanabilir Yapay Zeka (XAI):** SHAP (Shapley Additive exPlanations) entegrasyonu ile risk faktörlerinin ağırlıklandırılması.
- **Güvenlik (Clamping):** Veri kirliliğine karşı yaş, boy, kilo ve tansiyon uç değerlerinin (outliers) filtrelenmesi.

---

## 🧩 Sistem Modülleri (Tez Entegrasyonu)

Bu proje, akademik bir çalışmanın aşağıdaki 7 modülünü kapsar:

1. **Modül 1 (Veri Toplama):** Google Health Connect ile saatten (nabız, uyku, adım, SpO2) otomatik veri çekilmesi. Manuel giriş imkanı (`/app/data-entry`).
2. **Modül 2 (Veri Ön İşleme):** Backend `_clean_data` metotlarıyla eksik/uçuk verilerin (clamping & smoothing) temizlenmesi.
3. **Modül 3 (Risk Analizi):** Temizlenen verilerin XGBoost ve GRU modellerine sokularak 0-100 arası kardiyovasküler sağlık risk skorunun üretilmesi.
4. **Modül 4 (Egzersiz Motoru):** Kullanıcının klinik risk grubuna (Sınıf 0 - Sınıf 4) göre AI destekli, dinamik spor salonu/ev egzersizi reçetesi yazılması.
5. **Modül 5 (Beslenme Motoru):** TÜBER standartlarına uygun, LLM destekli hiper-kişiselleştirilmiş diyet planları. Porsiyon ölçüleri matematiksel kalori sınırına sadık kalarak rastgele (rotation) oluşturulur.
6. **Modül 6 (AI Asistan):** Akıllı sohbet botu. Kullanıcının mevcut sensör verilerini bağlam (context) olarak alıp tavsiyeler verir.
7. **Modül 7 (Anomali Tespiti):** LSTM-Autoencoder ile son 7 günlük sağlık serisindeki sapmaların bulunup mobil uygulamada "Alert (Uyarı)" olarak çıkarılması.

---

## 🛠️ Kurulum ve Çalıştırma

Geliştirme ortamını ayağa kaldırmak için aşağıdaki adımları izleyin. (Projeyi tek tıkla çalıştırmak için kök dizinde `run_app.py` scripti mevcuttur).

### 1. Gereksinimler
- **Flutter SDK:** >= 3.0.0
- **Python:** 3.10 veya 3.11 (PyTorch ve XGBoost uyumluluğu için)
- **PostgreSQL:** Lokal bir veritabanı veya bulut (Supabase/Neon) veritabanı.

### 2. Ortam Değişkenleri (Environment Variables)
Backend klasörünün içine `.env` dosyası oluşturun ve aşağıdaki değişkenleri tanımlayın:
```ini
# backend/.env
DATABASE_URL=postgresql+asyncpg://kullanici:sifre@localhost:5432/aksa_db
# (veya Supabase gibi bir sağlayıcı URL'si)
```

### 3. Backend Kurulumu
```bash
cd backend
python -m venv venv

# Windows için
venv\Scripts\activate
# Mac/Linux için
# source venv/bin/activate

pip install -r requirements.txt
```

### 4. Frontend Kurulumu
```bash
# Proje kök dizinindeyken
flutter pub get
```

### 5. Projeyi Çalıştırma (Otomatik)
Frontend ve Backend'i aynı anda, logları temiz bir şekilde görerek çalıştırmak için proje kökündeki scripti kullanın:
```bash
python run_app.py
```
*Script arka planda Uvicorn (FastAPI) sunucusunu başlatır, veritabanını oluşturur (migrations) ve ardından Flutter uygulamasını çalıştırır.*

---

## 🛡️ Hata Yakalama ve Güvenlik Mekanizmaları
Canlı ortam (Production) hatalarını minimize etmek için sistemde şu önlemler bulunur:
1. **Flutter Global Error Handling:** `FlutterError.onError` ve `PlatformDispatcher` ile yakalanamayan hatalar çökmeyi (crash) engeller, `AppLogger`'a düşer.
2. **Async-Gap (Mounted) Koruması:** Kullanıcı ekranlar arası hızlı geçiş yaptığında oluşan hafıza sızıntısı (memory leak) engellenmiştir.
3. **Backend Global Exception Catcher:** Beklenmeyen tipler veya DB bağlantı kopmalarında FastAPI sunucusu kilitlenmez, güvenli bir şekilde `500 JSON` yanıtı döner.
4. **Pool Recycle:** `pool_recycle=3600` ile PostgreSQL uzun süre boşta kalan bağlantıları güvenli bir şekilde tazeler.

---

## 📂 Dizin Yapısı (Directory Structure)

```text
aksa_v1/
├── backend/                  # FastAPI & Yapay Zeka Altyapısı
│   ├── ml_models/            # Eğitilmiş PyTorch (.pt) ve XGBoost (.pkl) ağırlıkları
│   ├── ml_pipeline/          # Tez M2 ön işleme kodları
│   ├── ml_training/          # Modellerin eğitildiği orjinal notebook/scriptler
│   ├── models/               # Veritabanı ve Pydantic Modelleri
│   ├── routers/              # API Endpoint'leri
│   ├── services/             # İş Mantığı (AI, Diyet, Egzersiz Generatörleri)
│   ├── database.py           # PostgreSQL Bağlantısı
│   └── main.py               # Uvicorn giriş noktası
├── lib/                      # Flutter Uygulaması
│   ├── constants/            # Renkler, Temalar, Sabitler
│   ├── models/               # Dart modelleri (Serialization)
│   ├── screens/              # UI Arayüzleri (Dashboard, Alerts, Chat vb.)
│   ├── services/             # API ve Firebase servis haberleşmeleri
│   ├── utils/                # Logger (AppLogger) ve Yardımcı fonksiyonlar
│   ├── widgets/              # Tekrar kullanılabilir ortak bileşenler
│   └── main.py               # Uygulama giriş noktası ve Routing mekanizması
├── run_app.py                # Geliştirme başlatma betiği
└── pubspec.yaml              # Flutter paket bağımlılıkları
```

---

## 👥 Proje Geliştiricilerine Notlar (Best Practices)
- **Yeni Ekran Eklerken:** Her zaman `GoRouter` kullanın ve state management tarafında mümkün mertebe `StatefulWidget` veya `ValueNotifier` kullanarak sayfa karmaşıklığını düşük tutun. Asenkron işlemlerden (örn. `await apiCall()`) sonra mutlaka `if (!mounted) return;` kontrolü yapın.
- **Loglama:** Geliştirme aşamasında `print()` kullanmak yerine uygulamanın her yerinde `AppLogger.info()`, `AppLogger.debug()`, veya hata durumlarında `AppLogger.error()` kullanın.
- **Model Güncellemeleri:** Eğer ML tarafında `risk_gru.pt` veya `risk_scaler.pkl` dosyaları yeniden eğitilip (`backend/ml_training`) güncellenecekse, `backend/models/risk_model.py` içindeki feature (özellik) sayısının eşleştiğinden emin olun.

**AKSA** ile sağlık verilerini birer istatistik olmaktan çıkarıp, hayata dokunan öngörülere dönüştürüyoruz. Katkılarınız için teşekkürler! 🌟
