# AKSA (Akıllı Kişisel Sağlık Asistanı) 🧬🚀

AKSA, akıllı saat sensör verilerini (Health Connect / HealthKit) ve kullanıcı profillerini kullanarak, **Makine Öğrenimi (Yapay Zeka)** destekli kişiselleştirilmiş analizler sunan, yeni nesil bir **Akıllı Sağlık Asistanı** mobil uygulamasıdır. 

Bu proje, gelişmiş bir **Flutter** mobil arayüzü ile derin öğrenme ve büyük veri işleyen bir **Python (FastAPI)** backend sunucusunun entegrasyonundan oluşur. Proje, akademik bir tezin 7 ana modülünün mobil platforma aktarılmış halidir.

---

## 🏗️ Mimari ve Teknolojiler

Proje "Frontend", "Backend" ve "AI (Makine Öğrenimi)" olmak üzere üç ana ayaktan oluşur.

### 📱 Frontend (Mobil Uygulama)
- **Framework:** Flutter (Dart) - Android ve iOS Çapraz Platform desteği.
- **State Management:** Provider / ValueNotifier (Hafif ve hızlı durum yönetimi).
- **Routing:** GoRouter (Modern, auth-guard entegreli yönlendirme).
- **Authentication:** Firebase Auth (Google Sign-In, Apple Sign-In, Email/Password).
- **Cihaz Entegrasyonu:** `health` paketi. Android için **Google Health Connect**, iOS için **Apple HealthKit** entegrasyonu.
- **Tasarım Dili:** Özel "Glassmorphism" ve Material 3 harmanı dinamik tasarım (Karanlık/Aydınlık mod destekli).

### ⚙️ Backend (API ve İş Mantığı)
- **Framework:** FastAPI (Yüksek performanslı, asenkron Python API).
- **Veritabanı:** PostgreSQL (SQLAlchemy ORM ile asenkron bağlantı - `asyncpg`).
- **Migrasyon & Hata Yönetimi:** Küresel Exception Handler, `pool_recycle` ile dayanıklı bağlantı mimarisi.
- **LLM (Büyük Dil Modelleri):** Gemini / OpenAI GPT altyapılı AI Asistan, diyet planı jeneratörü ve egzersiz programı üretici.
- **Canlı Analiz:** PyTorch ve XGBoost modelleri kullanılarak saniyeler içinde anomali ve risk skoru hesabı.

### 🧠 Yapay Zeka (AI & ML)
- **Risk Analizi (M3):** XGBoost + GRU (Gated Recurrent Unit) modellerinin Ensemble (Topluluk) füzyonu. 
- **Anomali Tespiti (M7):** PyTorch tabanlı **LSTM-Autoencoder** (Zaman serisi anomalileri tespiti).
- **Açıklanabilir Yapay Zeka (XAI):** SHAP (Shapley Additive exPlanations) entegrasyonu ile risk faktörlerinin ağırlıklandırılması.
- **Veri Güvenliği (Clamping):** Cihazlardan (akıllı saat vb.) gelen veri kirliliğine karşı yaş, boy, kilo ve tansiyon uç değerlerinin (outliers) filtrelenmesi.

---

## 🧩 Sistem Modülleri (Tez Entegrasyonu)

Bu proje, akademik bir çalışmanın aşağıdaki 7 modülünü kapsar:

1. **Modül 1 (Veri Toplama):** Google Health Connect (Android) ve Apple HealthKit (iOS) üzerinden akıllı saatlerden (nabız, uyku, adım, SpO2 vb.) otomatik veri çekilmesi. Ayrıca manuel giriş imkanı (`/app/data-entry`).
2. **Modül 2 (Veri Ön İşleme):** Backend `_clean_data` metotlarıyla eksik veya hatalı verilerin (clamping & smoothing algoritmalarıyla) temizlenmesi.
3. **Modül 3 (Risk Analizi):** Temizlenen verilerin XGBoost ve GRU modellerine sokularak 0-100 arası kardiyovasküler sağlık risk skorunun üretilmesi.
4. **Modül 4 (Egzersiz Motoru):** Kullanıcının klinik risk grubuna (Sınıf 0 - Sınıf 4) göre AI destekli, dinamik spor salonu/ev egzersizi reçetesi yazılması.
5. **Modül 5 (Beslenme Motoru):** TÜBER standartlarına uygun, LLM destekli hiper-kişiselleştirilmiş diyet planları. (Besin tanıma modülü de mevcuttur).
6. **Modül 6 (AI Asistan):** Akıllı sohbet botu. Kullanıcının sensör verilerini bağlam (context) olarak alıp tavsiyeler verir.
7. **Modül 7 (Anomali Tespiti):** LSTM-Autoencoder ile son 7 günlük sağlık serisindeki sapmaların bulunup mobil uygulamada "Uyarı" (Push Notification) olarak kullanıcıya bildirilmesi.

---

## 🛠️ Kurulum ve Çalıştırma

### 1. Gereksinimler
- **Flutter SDK:** >= 3.0.0
- **Python:** 3.10 veya 3.11 (PyTorch ve XGBoost için optimum sürümler)
- **Veritabanı:** PostgreSQL (Lokal veya Neon/Supabase üzerinden).
- **İşletim Sistemi:** Windows (Android için) / macOS (iOS için).

### 2. Backend Ortam Değişkenleri (Environment Variables)
`backend/` dizininde `.env` dosyası oluşturun ve şu değişkenleri tanımlayın:
```ini
# backend/.env
GEMINI_API_KEY=AIzaSy... (Gemini API Anahtarınız)
DATABASE_URL=postgresql+asyncpg://kullanici:sifre@localhost:5432/aksa_db
# veya NeonDB kullanıyorsanız: postgresql+asyncpg://...
DEV_MODE=true
```

### 3. Backend'in Başlatılması
```bash
cd backend
python -m venv venv
# Windows: venv\Scripts\activate
# Mac/Linux: source venv/bin/activate
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```
*(Alternatif olarak proje kök dizinindeki `python run_app.py` scripti tüm backend ve frontend'i tek tuşla başlatır).*

### 4. Frontend Ortamı (API IP Ayarı)
**Çok Önemli:** Mobil uygulamanın backend'e bağlanabilmesi için IP adresinin doğru olması şarttır.
`lib/services/api_service.dart` dosyasındaki `_baseUrl` kısmında yer alan `192.168.1.X` adresinin, backend'i çalıştıran bilgisayarın **Lokal IPv4 adresi** olduğuna emin olun.

**Eğer uzak bir cihazda (örneğin arkadaşınız) test edilecekse:**
1. Backend bilgisayarında `ngrok` kurun (`ngrok http 8000`).
2. Size verilen `https://abc-xyz.ngrok.app` adresini kopyalayın.
3. Koddaki IP adresi yerine bu URL'yi koyun. Bu sayede dünyanın her yerinden cihaza bağlanılabilir.

### 5. Frontend'i Çalıştırma
```bash
flutter pub get
flutter run
```

---

## 📱 Platforma Özel Yapılandırmalar

### 🤖 Android (Tamamlandı)
- **Health Connect:** `AndroidManifest.xml` içerisine gerekli tüm `android.permission.health...` izinleri eklenmiştir. Android 14+ için Permission Dashboard entegrasyonu tamamdır.
- **Arka Plan Servisleri:** `WorkManager` kullanılarak arka planda (2 saatte bir) periyodik olarak su, adım, risk uyarısı kontrolü yapılır.
- **Bildirimler:** `flutter_local_notifications` kullanılarak anlık anomali uyarıları ve lokal hatırlatıcılar çalışır.

### 🍏 iOS (Tamamlandı)
- **HealthKit:** Uygulamanın çalışması için **Apple Developer Hesabı** gereklidir. Projeyi XCode ile açıp, *Signing & Capabilities* altından **HealthKit** (Background Delivery dahil) eklenmelidir. (Runner.entitlements dosyası kod içerisinde mevcuttur).
- **Deployment Target:** Projenin ve Pod'ların minimum sürümü `iOS 14.0` olarak ayarlanmıştır.
- **CocoaPods:** Projeyi klonladıktan sonra mutlaka `cd ios && pod install` komutu çalıştırılmalıdır.
- **Apple Sign-In:** Sadece iOS'ta çalışacak şekilde ayarlanmıştır. Backend (Firebase) üzerinden callback'leri tanımlanmıştır. `syncFromDevice` metotlarında Android'e özel Health Connect fonksiyonları `Platform.isAndroid` ile ayrıştırılarak iOS'taki çökmelerin (crash) önüne geçilmiştir.

---

## 📂 Dizin Yapısı

```text
aksa_v1/
├── backend/                  # FastAPI & Yapay Zeka Altyapısı
│   ├── ml_models/            # PyTorch (.pt) ve XGBoost (.pkl) ağırlıkları
│   ├── models/               # SQLAlchemy Veritabanı ve Pydantic Modelleri
│   ├── routers/              # API Endpoint'leri (User, Health, Chat vb.)
│   ├── services/             # İş Mantığı (AI, Diyet, Egzersiz Generatörleri)
│   ├── database.py           # PostgreSQL Bağlantısı
│   └── main.py               # Uvicorn giriş noktası
├── ios/                      # iOS (Swift & Xcode) Konfigürasyonları
├── android/                  # Android (Kotlin & Gradle) Konfigürasyonları
├── lib/                      # Flutter Uygulaması (Dart)
│   ├── constants/            # Uygulama içi sabit değerler
│   ├── models/               # Dart modelleri (JSON Serialization)
│   ├── screens/              # Ana Sayfalar, Onboarding, Chat, Raporlar
│   ├── services/             # API Servisi, HealthKit/Connect, Firebase Servisleri
│   ├── utils/                # Loglama mekanizmaları ve yardımcı fonksiyonlar
│   ├── widgets/              # Tekrar kullanılabilen tasarımsal bileşenler (Glassmorphism vb.)
│   └── main.py               # Uygulama başlatıcısı ve GoRouter ayarları
├── pubspec.yaml              # Flutter paket bağımlılıkları
└── README.md                 # Bu dosya
```

---

## 🛡️ Hata Yakalama ve Güvenlik Mekanizmaları

Canlı ortam (Production) hatalarını minimize etmek için sistemde şu önlemler bulunur:
1. **Flutter Global Error Handling:** `FlutterError.onError` ve `PlatformDispatcher` ile yakalanamayan hatalar uygulamanın çökmesini (crash) engeller, `AppLogger`'a düşer.
2. **Platform Çakışmaları:** `Health Connect SDK` sadece Android'de çalışır. Kod `Platform.isIOS` güvenlik bariyerleriyle donatılmıştır. iOS'ta sadece `HealthKit` yetkilendirmesi çağrılır.
3. **Backend Global Exception Catcher:** Beklenmeyen tipler veya DB bağlantı kopmalarında FastAPI sunucusu kilitlenmez, güvenli bir şekilde `500 Internal Error` JSON yanıtı döner.
4. **Pool Recycle:** `pool_recycle=3600` ile PostgreSQL uzun süre boşta kalan bağlantıları güvenli bir şekilde tazeler.

---

## 👥 Geliştiricilere Tavsiyeler (Best Practices)

- **Loglama:** Geliştirme aşamasında `print()` kullanmak yerine uygulamanın her yerinde `AppLogger.info()`, `AppLogger.debug()`, veya hata durumlarında `AppLogger.error()` kullanın.
- **State Yönetimi:** Mümkün oldukça state'i lokal tutun (`StatefulWidget`, `ValueNotifier`). UI'ı şişirmemeye özen gösterin.
- **Model Güncellemeleri:** Eğer ML tarafında (`backend/ml_training`) bir model yeniden eğitilip güncellenecekse, `backend/models/risk_model.py` içindeki özellik (feature) girdi sayısının (örn. MinMaxScaler parametrelerinin) eşleştiğinden kesinlikle emin olun.
- **API URL Değişimi:** Birden fazla geliştirici farklı ağlarda çalışıyorsa kodu değiştirmek yerine `flutter run --dart-define=API_BASE_URL=http://...` parametresi ile uygulamayı derlemeyi tercih edin.

**AKSA** ile sağlık verilerini salt istatistik olmaktan çıkarıp, hayat kurtaran öngörülere dönüştürüyoruz. Katkılarınız için teşekkürler! 🌟
