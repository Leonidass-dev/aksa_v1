# AKSA (Akıllı Kişisel Sağlık Asistanı) 🧬🚀

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)
![Flutter](https://img.shields.io/badge/Framework-Flutter%203.x-02569B?logo=flutter)
![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi)
![AI](https://img.shields.io/badge/AI-PyTorch%20%7C%20XGBoost-EE4C2C?logo=pytorch)

AKSA, akıllı saat sensör verilerini (Health Connect / HealthKit) ve detaylı kullanıcı profillerini kullanarak, **Makine Öğrenimi (Yapay Zeka)** ve **Büyük Dil Modelleri (LLM)** destekli hiper-kişiselleştirilmiş analizler sunan, yeni nesil bir **Akıllı Sağlık Asistanı** mobil uygulamasıdır. 

Bu proje, akademik bir tezin 7 ana modülünün doğrudan prodüksiyona hazır, gerçek zamanlı bir mobil platforma aktarılmış halidir.

---

## 📑 İçindekiler
1. [🏗️ Mimari ve Teknolojiler](#️-mimari-ve-teknolojiler)
2. [🧩 Sistem Modülleri (Tez Entegrasyonu)](#-sistem-modülleri-tez-entegrasyonu)
3. [🧠 Yapay Zeka (AI & ML) Altyapısı](#-yapay-zeka-ai--ml-altyapısı)
4. [🛠️ Kurulum ve Çalıştırma Rehberi](#️-kurulum-ve-çalıştırma-rehberi)
   - [Backend Kurulumu](#1-backend-kurulumu-fastapi--postgresql)
   - [Frontend Kurulumu (Android)](#2-frontend-kurulumu-flutter--android)
   - [Frontend Kurulumu (iOS)](#3-frontend-kurulumu-flutter--ios)
5. [🌐 Network ve API Yapılandırması (ÇOK ÖNEMLİ)](#-network-ve-api-yapılandırması-çok-önemli)
6. [📂 Dizin Yapısı ve Kod Organizasyonu](#-dizin-yapısı-ve-kod-organizasyonu)
7. [🛡️ Güvenlik, Exception Handling ve Hata Yakalama](#️-güvenlik-exception-handling-ve-hata-yakalama)
8. [👥 Geliştiricilere Tavsiyeler (Best Practices)](#-geliştiricilere-tavsiyeler-best-practices)

---

## 🏗️ Mimari ve Teknolojiler

Proje, birbirine entegre üç ana katmandan ("Frontend", "Backend", "AI") oluşur:

### 📱 Frontend (Mobil Uygulama Katmanı)
- **Çapraz Platform:** Flutter (Dart). Tek bir kod tabanıyla hem iOS hem Android native çıktıları üretilir.
- **State Management:** Provider / ValueNotifier. UI performansını artırmak için gereksiz rebuild'leri engelleyen hafif state yönetimi tercih edilmiştir.
- **Routing:** GoRouter. Kullanıcının giriş yapıp yapmadığını (Auth) denetleyen özel middleware yapısı (`_authGuard`) içerir.
- **Authentication:** Firebase Auth kullanılarak güvenli Google Sign-In, Apple Sign-In ve Email/Password modülleri entegre edilmiştir.
- **Veri Toplama (Sensörler):** `health` paketi aracılığıyla Android'de **Google Health Connect**, iOS'ta ise **Apple HealthKit** API'lerine bağlanarak saat üzerinden toplanan ham verileri asenkron okur.
- **UI/UX Tasarımı:** Uygulama genelinde modern "Glassmorphism" tasarımı, dinamik renk temaları ve karanlık mod desteği mevcuttur.

### ⚙️ Backend (API ve İş Mantığı Katmanı)
- **Framework:** FastAPI (Python). Asenkron (`async/await`) yapısıyla eşzamanlı yüzlerce AI modeli tahminleme isteğini kaldırabilecek güçtedir.
- **Veritabanı:** PostgreSQL. `SQLAlchemy` ORM üzerinden `asyncpg` asenkron driver'ı ile bağlanılmıştır.
- **Connection Pooling:** `pool_recycle=3600` gibi mekanizmalarla kopan veritabanı bağlantıları otomatik olarak onarılır.
- **LLM Entegrasyonu:** Gemini (veya Groq/OpenAI) kullanılarak tasarlanan özel prompt mühendisliğiyle çalışan AI Asistan, diyet ve egzersiz üretme modülleri bu katmandadır.

---

## 🧩 Sistem Modülleri (Tez Entegrasyonu)

Bu proje salt bir uygulama değil, akademik bir "Akıllı Sağlık Ekosistemi" tezinin somutlaştırılmış versiyonudur. İşte 7 Temel Modül:

1. **Modül 1 (Sürekli Veri Toplama):** Akıllı bileklik ve saatlerden `Adım, Nabız, Uyku Fazları (Derin, Hafif, REM), SpO2, Tansiyon` gibi 15 farklı sağlık metriğinin günde birkaç kez otonom çekilmesi.
2. **Modül 2 (Veri Ön İşleme / Veri Boru Hattı):** Backend `_clean_data` metotları, "Data Clamping" tekniğini uygulayarak imkansız (outlier) değerleri filtreler (örn. 250 nabız) ve eksik verileri enterpolasyonla tamamlar.
3. **Modül 3 (Kardiyovasküler Risk Analizi):** Temizlenmiş verilerin, eğitilmiş **XGBoost** ve **GRU (Zaman Serisi RNN)** ensemble modeline beslenmesi. Bu modeller kişinin anlık sağlık durumunu analiz edip 0'dan 100'e kadar objektif bir risk skoru ve Sınıf (0-4) atar.
4. **Modül 4 (Akıllı Egzersiz Reçetesi):** Modül 3'ten çıkan Risk Sınıfı'na göre LLM destekli egzersiz programı üretimi. Örneğin Sınıf 3 bir hipertansiyon hastasına ağır kardiyo önermez; yoga ve hafif esneme önerir.
5. **Modül 5 (Hiper-Kişiselleştirilmiş Beslenme Motoru):** TÜBER (Türkiye Beslenme Rehberi) standartlarına uygun olarak kişinin TDEE (Günlük Enerji İhtiyacı) hesaplanır. AI, matematiksel makro/mikro kısıtlamalarına uyan dinamik menüler oluşturur.
6. **Modül 6 (Context-Aware AI Asistan):** Uygulama içindeki sohbet asistanı kör değildir. O anki tansiyonunuzu, dün kaç saat uyuduğunuzu ve kalp ritminizi bilerek ("context") bağlamsal sohbet ve sağlık danışmanlığı yapar.
7. **Modül 7 (PyTorch LSTM-Autoencoder ile Anomali Tespiti):** Kişinin son 7 günlük normal uyku/adım/nabız döngüsü öğrenilir. Eğer dün geceki uyku kalitesi kullanıcının genel normalinden istatistiksel olarak aşırı sapmışsa (Anomali), mobil uygulama bir "Push Notification" (Bildirim) atarak kullanıcıyı uyarır.

---

## 🧠 Yapay Zeka (AI & ML) Altyapısı

AI katmanı tamamen `backend/ml_models` içerisinde barındırılan pre-trained ağırlıklarla (weights) çalışır.

- **Modeller:** XGBoost (Tabular veri için), GRU (Zaman serisi paternleri için), LSTM-Autoencoder (Zaman serisi rekonstrüksiyon anomalileri için).
- **Ölçekleyiciler:** Veriler modellere girmeden önce `MinMaxScaler` ve `StandardScaler` (`*_scaler.pkl`) kullanılarak (örneğin 0-1 arasına) normalize edilir.
- **XAI (Explainable AI):** Sistem sadece bir "Risk Skorusun" demekle kalmaz; arka planda SHAP (Shapley Additive exPlanations) algoritmasını çalıştırarak "Şu an tansiyonun yüksek olduğu için ve uykunu alamadığın için riskin bu kadar yüksek" gibi insan dilinde açıklamalar türetir.

---

## 🛠️ Kurulum ve Çalıştırma Rehberi

Projeyi yerel makinenizde (Localhost) ayağa kaldırmak için adım adım talimatlar:

### Gereksinimler
- **Git** (Projeyi klonlamak için)
- **Python 3.10 veya 3.11** (Backend için zorunlu - PyTorch vs. uyumluluğu)
- **Flutter SDK** (Mobil taraf için - Sürüm 3.x)
- **Android Studio / Xcode** (Cihaz emülatörleri ve build süreçleri için)

### 1. Backend Kurulumu (FastAPI & PostgreSQL)

Backend'in çalışması için bir `.env` dosyasına ihtiyacınız var. 
`backend` klasörüne girip `.env` adında bir dosya oluşturun:

```ini
# backend/.env
# LLM Altyapısı (Gemini Anahtarı)
GEMINI_API_KEY=AIzaSy... (Kendi API Key'inizi Girin)

# PostgreSQL Bağlantısı
DATABASE_URL=postgresql+asyncpg://kullanici:sifre@localhost:5432/aksa_db

# Geliştirme Modu (İsteğe bağlı test parametrelerini açar)
DEV_MODE=true
```

Ardından sanal ortamı kurup başlatın:

```bash
cd backend

# Sanal ortam (venv) oluşturma
python -m venv venv

# Aktivasyon (Windows)
venv\Scripts\activate
# Aktivasyon (Mac/Linux)
source venv/bin/activate

# Kütüphanelerin yüklenmesi
pip install -r requirements.txt

# Sunucunun başlatılması
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```
> **İpucu:** FastAPI arayüzüne (Swagger UI) ulaşmak için tarayıcınızdan `http://localhost:8000/docs` adresine gidebilirsiniz.

### 2. Frontend Kurulumu (Flutter & Android)

```bash
# Projenin kök dizininde olduğunuzdan emin olun
flutter pub get

# Android emülatöründe veya cihaza bağlı olarak başlatın
flutter run -d android
```
**Önemli Not (Android):** `Health Connect` uygulamasının cihazda/emülatörde kurulu olması gerekmektedir. Play Store'dan yükleyebilir veya ayarlardan aktifleştirebilirsiniz.

### 3. Frontend Kurulumu (Flutter & iOS)

iOS için macOS işletim sistemi ve Apple Developer hesabı **zorunludur**.

```bash
# Bağımlılıkları çekin
flutter pub get

# iOS CocoaPods paketlerini kurun
cd ios
pod install
cd ..
```
Ardından Xcode üzerinden `ios/Runner.xcworkspace` (DİKKAT: `.xcodeproj` değil) dosyasını açın:
1. **Signing & Capabilities** kısmından kendi Developer Team'inizi seçin.
2. (Opsiyonel) Bundle ID'sini `com.aksa.health` şeklinde benzersiz bir isimle değiştirin.
3. Aynı sayfada `+ Capability` butonuna basarak **HealthKit**'i projenize dahil edin. ("Background Delivery" kutusunu işaretlemeyi unutmayın).
4. `flutter run -d ios` diyerek uygulamayı başlatın.

---

## 🌐 Network ve API Yapılandırması (ÇOK ÖNEMLİ)

Eğer backend ve frontend (mobil uygulama) **aynı bilgisayar içinde emülatör** vasıtasıyla çalışmıyorsa; örneğin, uygulamanızı **gerçek bir cep telefonuna** kabloyla bağlayıp test etmek istiyorsanız `localhost` kavramı çalışmayacaktır!

Telefonunuzun API'ye erişebilmesi için `lib/services/api_service.dart` dosyası içindeki IP adresini kendi ağınızın IP adresiyle değiştirmelisiniz:

```dart
// lib/services/api_service.dart
final String _baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.42:8000/api', // <-- Buradaki IP'yi kendi IPv4 adresiniz yapın!
);
```

### Takım Çalışması İçin (Ngrok Kullanımı)
Diyelim ki backend Ali'nin bilgisayarında çalışıyor ama Ayşe evindeki telefondan bu API'ye bağlanarak iOS uygulamasını test etmek istiyor. Bunun için **Ngrok** kullanılmalıdır:
1. Ali bilgisayarında `ngrok http 8000` yazar.
2. Çıkan sonucu (`https://asdf-123.ngrok.app`) Ayşe'ye gönderir.
3. Ayşe bu adresi `api_service.dart` dosyasına yazar ve projeyi çalıştırır. Dünyanın öbür ucundan bile uygulamadaki AI çalışmaya devam edecektir.

---

## 📂 Dizin Yapısı ve Kod Organizasyonu

```text
aksa_v1/
├── backend/                  # FastAPI Sunucu ve İş Mantığı
│   ├── ml_models/            # Yapay Zeka ağırlıkları (.pt, .pkl) ve scaler dosyaları
│   ├── ml_pipeline/          # Veri kirliliğini temizleyen tez algoritmaları
│   ├── ml_training/          # Ağırlıkların eğitilmesinde kullanılan Jupyter Notebooks
│   ├── models/               # SQLAlchemy Veritabanı Modelleri & Pydantic Validation
│   ├── routers/              # API Endpoint'leri (User, Health, Chat, Diet)
│   ├── services/             # Backend İş Mantığı (AI Asistan, Risk Engine)
│   ├── database.py           # PostgreSQL Asenkron Bağlantı motoru
│   └── main.py               # Uvicorn giriş noktası
├── ios/                      # iOS Swift & Xcode Build Konfigürasyonları
├── android/                  # Android Kotlin & Gradle Build Konfigürasyonları
├── lib/                      # Flutter Uygulaması (Dart)
│   ├── constants/            # Renk paletleri, tipografi, sabit UI değerleri
│   ├── models/               # Dart Data Modelleri (JSON to Object)
│   ├── screens/              # UI Sayfaları (Dashboard, Profile, Chat, Auth)
│   ├── services/             # API HTTP istekleri, HealthKit servisleri, Local Storage
│   ├── utils/                # Logger (AppLogger), validator'lar ve helper fonksiyonlar
│   ├── widgets/              # Tekrar kullanılabilen tasarımsal custom komponentler
│   └── main.py               # Uygulama başlatıcısı, ThemeProvider ve GoRouter
├── scratch/                  # Geliştirme sürecinde kullanılan geçici DB Migration / test betikleri
├── pubspec.yaml              # Flutter paket listesi ve asset konfigürasyonu
└── README.md                 # Okumakta olduğunuz doküman
```

---

## 🛡️ Güvenlik, Exception Handling ve Hata Yakalama

Sistem, "Production-Ready" vizyonuyla tasarlandığı için çökmelere karşı koruma altındadır:

1. **Mobil Tarafında Güvenlik Ağı:** `FlutterError.onError` ve `PlatformDispatcher.onError` yapıları uygulamada herhangi bir hata meydana geldiğinde kırmızı "korkutucu" hata ekranlarını gizler. Hatayı sessizce yakalayıp `AppLogger` servisine iletir.
2. **Mounted Controller (Hafıza Sızıntısı Koruması):** HTTP API çağrıları çok uzun sürerse ve kullanıcı bu sırada ekranı kapatırsa uygulamanın çökmemesi için `if (!mounted) return;` denetimleri yapılmıştır.
3. **Backend Fallback (Toleranslı Hata Yönetimi):** Veritabanı koparsa, API anahtarı biterse veya AI halüsinasyon görüp bozuk JSON dönerse, FastAPI sunucusu çökmek yerine güvenli bir `try-catch` yakalayıcısı ile `500 Internal Error` yanıtı döner. Mobil uygulama da bu `null` yanıtı işleyerek kullanıcıya tatlı bir "Bağlantı hatası oluştu" mesajı gösterir.
4. **Soft Delete (GDPR Uyumluluğu):** Kullanıcı hesabını sildiğinde veriler anında yok olmaz; `deletion_scheduled_at` mantığıyla 30 günlük bir askıya alma havuzuna düşer. Bu, kullanıcının verilerini kaybetmemesi ve vazgeçebilmesi için global standartlarda bir protokoldür.

---

## 👥 Geliştiricilere Tavsiyeler (Best Practices)

Projeye katkı sağlayacak veya geliştirmeye devam edecek mühendisler için:

- **State Yönetimi Sınırı:** Her şeyi global `Provider` içine atmayın. Sadece uygulamanın her yerini ilgilendiren şeyleri (Tema rengi, Auth User) globale koyun. Buton tıklama animasyonları gibi şeyler için lokal `setState` veya `ValueNotifier` daha performanslıdır.
- **Loglama Kuralları:** Sistemin kalbinde bir yapay zeka olduğu için neyin yanlış gittiğini bulmak zor olabilir. Kod içerisinde klasik `print("hata")` komutunu ASLA kullanmayın. Bunun yerine `AppLogger.debug("Sensör verisi geldi: $data")` veya `AppLogger.error("API Cevap vermedi", error: e)` kullanın.
- **Model Eğitim Eşleşmesi:** Eğer `backend/ml_training` klasöründeki Python scriptlerini çalıştırarak yeni bir XGBoost veya LSTM modeli eğitirseniz, modelin özellik (feature) girdi matrisi ile canlı sunucudaki `backend/services/risk_engine.py` matris boyutlarının milimetrik uyduğundan emin olun.

**AKSA** ile sağlık verilerini salt "istatistik" olmaktan çıkarıp, hayat kurtaran "öngörülere" dönüştürüyoruz.
Katkılarınız ve projemize göstermiş olduğunuz ilgi için teşekkürler! 🌟
