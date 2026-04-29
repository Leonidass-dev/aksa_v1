# AKSA — Akıllı Kişisel Sağlık Asistanı 🩺

> **Ondokuz Mayıs Üniversitesi — Bilgisayar Mühendisliği Bitirme Tezi**
> Gökdeniz Çoban · Batuhan Yılmaz · Elif Sude Çetinkaya
> Danışman: Prof. Dr. Erdal Kılıç

AKSA, kullanıcıların giyilebilir cihazlardan (akıllı saat, fitness bilekliği) toplanan sağlık verilerini yapay zeka ile analiz ederek **kişiselleştirilmiş risk skoru**, **anomali tespiti**, **beslenme analizi**, **egzersiz önerisi** ve **AI sağlık asistanı** sunan uçtan uca (end-to-end) bir mobil sağlık platformudur.

---

## ✨ Öne Çıkan Özellikler

| Özellik | Açıklama |
|---|---|
| **Hibrit Risk Skoru** | XGBoost + GRU füzyon modeli ile 0-100 arası sağlık risk değerlendirmesi |
| **SHAP Açıklanabilirlik** | Risk skorunu etkileyen faktörlerin yüzdesel dağılımı (XAI) |
| **Anomali Tespiti** | Z-skor + LSTM-AE ile günlük sağlık verilerindeki sapmaların saptanması |
| **AI Sağlık Asistanı** | Google Gemini 2.5 Flash entegrasyonu ile bağlam-duyarlı sağlık danışmanlığı |
| **Yemek Analizi** | Fotoğraftan besin değeri tespiti ve kişisel diyet planı üretimi |
| **Egzersiz Önerisi** | Risk seviyesine göre güvenli, kişiselleştirilmiş antrenman planı |
| **Dinamik Su Takibi** | Kilo ve aktiviteye göre hesaplanan hedef + dalga animasyonlu arayüz |
| **Ruh Hali Takibi** | Günlük mental durum kaydı ve fiziksel metriklerle korelasyon |
| **Haftalık Raporlar** | Radar chart ile 5 boyutlu sağlık dengesi analizi |
| **Akıllı Bildirimler** | Su, hareket ve veri girişi için proaktif hatırlatıcılar |

---

## 🏗 Sistem Mimarisi

```
┌─────────────────────────────────────────────────────────────────┐
│                        KULLANICI CİHAZI                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │ Akıllı Saat  │───▶│Health Connect│───▶│  Flutter (Dart)   │  │
│  │ Mi Fitness   │    │  / HealthKit │    │  Mobil Uygulama   │  │
│  └──────────────┘    └──────────────┘    └────────┬─────────┘  │
│                                                   │            │
│                                          ┌────────▼─────────┐  │
│                                          │  Firebase Auth   │  │
│                                          │  Cloud Firestore │  │
│                                          └────────┬─────────┘  │
└───────────────────────────────────────────────────┼────────────┘
                                                    │ HTTP/REST
                                          ┌─────────▼──────────┐
                                          │  FastAPI Backend    │
                                          │  ┌──────────────┐  │
                                          │  │ ML Pipeline   │  │
                                          │  │ (Preprocessing)│  │
                                          │  ├──────────────┤  │
                                          │  │ Risk Model    │  │
                                          │  │ (XGBoost+GRU) │  │
                                          │  ├──────────────┤  │
                                          │  │ Anomaly Model │  │
                                          │  │ (Z-skor+LSTM) │  │
                                          │  ├──────────────┤  │
                                          │  │ Gemini API    │  │
                                          │  │ (LLM Gateway) │  │
                                          │  └──────────────┘  │
                                          │  SQLite/PostgreSQL  │
                                          └────────────────────┘
```

---

## 📂 Proje Yapısı

```
aksa_v1/
├── lib/                          # Flutter Mobil Uygulama
│   ├── main.dart                 # Uygulama giriş noktası, GoRouter, Auth Guard
│   ├── models/
│   │   ├── api_models.dart       # API istek/yanıt sınıfları
│   │   ├── health_data.dart      # RiskResult, HealthSnapshot modelleri
│   │   └── health_entry.dart     # Firestore veri modeli + serialization
│   ├── screens/
│   │   ├── dashboard_screen.dart # Ana kontrol paneli
│   │   ├── risk_score_screen.dart# Risk detay + SHAP faktörleri
│   │   ├── nutrition_screen.dart # Yemek analizi + diyet planı
│   │   ├── exercise_screen.dart  # Egzersiz önerileri
│   │   ├── reports_screen.dart   # Haftalık radar chart raporları
│   │   ├── alerts_screen.dart    # Anomali uyarıları
│   │   ├── assistant_screen.dart # AI sağlık asistanı chat
│   │   ├── profile_screen.dart   # Kullanıcı profili
│   │   ├── data_entry_screen.dart# Manuel veri girişi (tansiyon, kilo)
│   │   ├── auth/                 # Giriş, kayıt, şifre sıfırlama
│   │   └── onboarding/           # İlk kullanım tanıtım ekranları
│   ├── services/
│   │   ├── api_service.dart      # FastAPI backend iletişimi
│   │   ├── health_service.dart   # Health Connect senkronizasyonu
│   │   ├── health_data_parser.dart # Sensör verisi ayrıştırma
│   │   ├── risk_engine.dart      # Yerel (offline) risk hesaplama
│   │   ├── auth_service.dart     # Firebase Auth yönetimi
│   │   ├── user_profile_service.dart # Firestore profil CRUD
│   │   ├── notification_service.dart # Yerel bildirimler
│   │   └── interfaces/          # Servis arayüzleri (test edilebilirlik)
│   ├── widgets/
│   │   ├── dashboard/            # Dashboard alt bileşenleri
│   │   │   ├── health_gauge_card.dart   # Risk göstergesi (gauge)
│   │   │   ├── metrics_grid.dart        # Sağlık metrikleri grid
│   │   │   ├── water_tracker_card.dart  # Su takibi + dalga animasyonu
│   │   │   ├── mood_tracker_card.dart   # Ruh hali seçici
│   │   │   ├── anomaly_banner.dart      # Anomali uyarı banner
│   │   │   ├── weekly_trend_card.dart   # Haftalık trend çizgisi
│   │   │   ├── bp_entry_sheet.dart      # Tansiyon giriş bottom sheet
│   │   │   └── discover_grid.dart       # Keşfet navigasyon grid
│   │   ├── common_widgets.dart   # AppHeader, AppCard, ortak bileşenler
│   │   ├── bottom_nav.dart       # Alt navigasyon barı
│   │   └── water_wave_widget.dart# Dalga animasyonu widget
│   ├── theme/
│   │   ├── app_theme.dart        # Renk paleti, Material3 tema
│   │   └── theme_notifier.dart   # Karanlık/Aydınlık mod kontrolü
│   └── constants/                # Uygulama sabitleri
│
├── backend/                      # Python FastAPI Backend
│   ├── main.py                   # FastAPI app, CORS, router kayıtları
│   ├── database.py               # SQLAlchemy async engine + session
│   ├── db_models.py              # ORM modelleri (User, HealthRecord, Risk...)
│   ├── crud.py                   # Veritabanı CRUD operasyonları
│   ├── auth.py                   # Firebase token doğrulama middleware
│   ├── routers/
│   │   ├── risk.py               # POST /api/risk-score — Risk hesaplama
│   │   ├── anomaly.py            # POST /api/anomaly-check — Anomali tespiti
│   │   ├── food.py               # POST /api/analyze-food — Yemek analizi
│   │   ├── exercise.py           # POST /api/exercise-plan — Egzersiz önerisi
│   │   ├── assistant.py          # POST /api/assistant/chat — AI asistan
│   │   ├── health.py             # GET/POST /api/health — Sağlık verileri
│   │   └── data_pipeline.py      # POST /api/preprocess-sensor-data — M2
│   ├── models/
│   │   ├── risk_model.py         # XGBoost+GRU hibrit + kural fallback
│   │   ├── anomaly_model.py      # Z-skor + LSTM-AE anomali modeli
│   │   └── exercise_model.py     # Egzersiz sınıflandırma modeli
│   ├── ml_pipeline/
│   │   └── preprocessing.py      # Hampel filtre, sliding window, özellik çıkarım
│   ├── ml_models/                # Eğitilmiş model dosyaları (.pkl, .pt)
│   ├── ml_training/              # Model eğitim scriptleri
│   ├── services/
│   │   ├── diet_generator.py     # Gemini ile diyet planı üretimi
│   │   └── exercise_generator.py # Gemini ile egzersiz planı üretimi
│   ├── tests/
│   │   └── test_risk_model.py    # Risk modeli birim testleri (14 test)
│   └── requirements.txt         # Python bağımlılıkları
│
├── test/                         # Flutter Birim Testleri
│   ├── risk_engine_test.dart     # Kalibrasyon, eşik, faktör testleri (8 test)
│   └── health_entry_test.dart    # Serialization, copyWith testleri (8 test)
│
├── android/                      # Android build yapılandırması
└── run_app.py                    # Tek komutla backend+frontend başlatıcı
```

---

## 🧠 Tez Modülleri ve Nasıl Çalışır

### Modül 1 — Veri Toplama (Data Collection)

**Dosyalar:** `health_service.dart`, `health_data_parser.dart`

**Akış:**
1. Kullanıcının akıllı saati (Redmi Watch, Samsung Galaxy Watch vb.) verileri **Mi Fitness / Google Fit** uygulamasına yazar
2. Bu veriler **Health Connect** (Android) veya **HealthKit** (iOS) platformuna aktarılır
3. Flutter'daki `HealthServiceImpl.syncFromDevice()` metodu Health Connect SDK üzerinden verileri çeker
4. `HealthDataParser.parse()` ham verileri kaynak bazlı kümeleme ile işler:
   - **Adımlar:** Birden fazla kaynaktan gelen adım verileri **medyan** ile birleştirilir (aykırı değer dayanıklılığı)
   - **Kalori/Mesafe:** Kaynaklar arası **maksimum** değer seçilir
   - **Nabız/SpO2:** Tüm okumaların **ortalaması** hesaplanır
   - **Uyku:** Faz sürelerinin (derin, hafif, REM) toplamı hesaplanır
5. İşlenen veri `HealthEntry` modeli olarak **Cloud Firestore**'a kaydedilir (`merge: true`)

**Koruma Mekanizmaları:**
- 15 dakikalık **cooldown** ile gereksiz yeniden senkronizasyon engellenir
- Sıfır koruma: Sensör 0 döndürürse mevcut veri korunur
- Kaynak-duyarlı `toJson()`: Health Connect'ten gelen gerçek sıfırlar yazılır, manuel girişte atlanır

---

### Modül 2 — Veri Ön İşleme (Preprocessing Pipeline)

**Dosyalar:** `ml_pipeline/preprocessing.py`, `routers/data_pipeline.py`

**Akış:**
1. Flutter, ham sensör zaman serilerini (nabız + adım) `POST /api/preprocess-sensor-data` endpoint'ine gönderir
2. `PreprocessorPipeline` sınıfı verileri işler:

| Adım | Yöntem | Açıklama |
|---|---|---|
| 1. Kırpma | Aralık kontrolü | HR ≤0 veya >240 → NaN, Adım <0 → 0, Adım >300/dk → 300 |
| 2. Resample | 1 dakikalık çözünürlük | HR: medyan, Adım: toplam |
| 3. Interpolasyon | Lineer (max 5dk) | Kısa veri boşluklarını doldurur |
| 4. Hampel Filtresi | MAD tabanlı outlier | 3σ dışı aykırı değerleri medyanla değiştirir |
| 5. Medyan Filtre | scipy.signal.medfilt | Son kalan gürültüyü yumuşatır |
| 6. Feature Extraction | 60dk Sliding Window | 5dk stride ile istatistiksel özellikler çıkarır |

3. Her pencere için çıkarılan özellikler:
   - `hr_mean`, `hr_median`, `hr_min`, `hr_max`, `hr_std` — Nabız istatistikleri
   - `hr_rmssd` — HRV proxy (otonom sinir sistemi stresi)
   - `steps_sum`, `steps_active_mins`, `steps_max` — Aktivite metrikleri
   - `missing_pct` — Veri kalitesi (%80 doluluk eşiği)

4. Son pencerenin özellikleri **ml_features** olarak veritabanına kaydedilir → M3 ve M7 tarafından kullanılır

---

### Modül 3 — Risk Skoru (Hybrid AI Risk Assessment)

**Dosyalar:** `models/risk_model.py` (backend), `risk_engine.dart` (frontend fallback)

**Hibrit Mimari:**
```
                    ┌─────────────┐
 Sensör Verisi ────▶│ M2 Pipeline │──── ml_features (9 özellik)
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │    _clean_data()        │  ← Outlier kırpma
              │  HR:[40,220] SpO2:[70,100]│
              └────────────┬────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                                   ▼
  ┌──────────────┐                   ┌──────────────┐
  │   XGBoost    │ (%60 ağırlık)     │     GRU      │ (%40 ağırlık)
  │  Classifier  │                   │   Temporal   │
  └──────┬───────┘                   └──────┬───────┘
         │                                  │
         │    ┌──────────────────────┐       │
         └───▶│  Ağırlıklı Füzyon   │◀──────┘
              │  prob = 0.6×XGB +    │
              │        0.4×GRU       │
              └──────────┬───────────┘
                         │
              ┌──────────▼───────────┐
              │  SHAP TreeExplainer  │  ← Açıklanabilir AI
              │  Top-5 risk faktörü  │
              └──────────┬───────────┘
                         │
              ┌──────────▼───────────┐
              │  0-33: Düşük Risk    │
              │  34-66: Orta Risk    │
              │  67-100: Yüksek Risk │
              └──────────────────────┘
```

**Fallback Stratejisi:**
- ML kütüphaneleri yoksa → `expert-v1.2` kural tabanlı motor (AHA standartları)
- Backend erişilemezse → Flutter'daki `RiskEngine` yerel hesaplama
- BMI, yaş, adım, uyku, nabız, tansiyon, SpO2, stres + sinerjik risk çarpanı

---

### Modül 4 — Kullanıcı Arayüzü (Dashboard & Navigation)

**Dosyalar:** `dashboard_screen.dart`, `widgets/dashboard/*`, `main.dart`

**Ekranlar ve Bileşenler:**

| Ekran | Rota | İçerik |
|---|---|---|
| **Dashboard** | `/app/dashboard` | Risk gauge, metrik grid, su takibi, mood, anomali banner |
| **Risk Detay** | `/app/risk-score` | SHAP faktörleri, risk geçmişi grafiği, öneriler |
| **Beslenme** | `/app/nutrition` | Fotoğrafla yemek analizi, diyet planı |
| **Egzersiz** | `/app/exercise` | Kişisel antrenman planı, geri bildirim döngüsü |
| **Raporlar** | `/app/reports` | Haftalık radar chart, trend grafikleri |
| **Uyarılar** | `/app/alerts` | Anomali detayları, metrik bazlı Z-skor |
| **AI Asistan** | `/app/assistant` | Chat tabanlı sağlık danışmanlığı |
| **Profil** | `/app/profile` | Kullanıcı bilgileri, tema, çıkış |

**Navigasyon:** GoRouter + Firebase Auth guard + `_AuthNotifier` (auth değişikliklerinde otomatik yönlendirme)

**Tema:** Material 3, `AppColors` merkezi palet, `ThemeAwareMixin`, karanlık mod desteği

---

### Modül 5 — Beslenme Analizi (Nutrition)

**Dosyalar:** `routers/food.py`, `services/diet_generator.py`, `nutrition_screen.dart`

**Akış:**
1. Kullanıcı yemek fotoğrafı çeker → Base64'e çevrilir
2. `POST /api/analyze-food` → Gemini Vision ile yemek tanıma
3. Kalori, protein, karbonhidrat, yağ, lif analizi + sağlık skoru (0-100)
4. `POST /api/diet-plan` → Profil + risk seviyesine göre kişisel diyet planı
5. Tüm öğünler veritabanına kaydedilir, geçmiş sorgulanabilir

---

### Modül 6 — Egzersiz Önerisi (Exercise)

**Dosyalar:** `routers/exercise.py`, `models/exercise_model.py`, `services/exercise_generator.py`

**Akış:**
1. Risk seviyesi + profil + son 14 gün sağlık verileri toplanır
2. `get_exercise_class()` güvenli yoğunluk seviyesini (0-4) belirler:
   - Sınıf 0: Çok düşük (yüksek riskli hastalar)
   - Sınıf 4: Yüksek yoğunluk (düşük riskli, aktif kullanıcılar)
3. Gemini AI, bu sınıfa uygun kişiselleştirilmiş egzersiz planı üretir
4. Gemini başarısız olursa → statik fallback plan devreye girer
5. Kullanıcı geri bildirimi (`too_hard` / `too_easy` / `perfect`) sonraki planları etkiler

---

### Modül 7 — Anomali Tespiti (Anomaly Detection)

**Dosyalar:** `models/anomaly_model.py`, `routers/anomaly.py`, `alerts_screen.dart`

**İki Katmanlı Sistem:**
1. **Z-skor:** Son 3-7 günün ortalamasına göre bugünün sapmasını hesaplar
   - Z > 2.0: Dikkat (Uyarı)
   - Z > 3.0: Ciddi (Tehlike)
2. **LSTM-AE:** M2'den gelen ml_features ile derin öğrenme tabanlı anomali tespiti

**İzlenen Metrikler:** Adım, uyku, nabız, sistolik/diastolik tansiyon, SpO2, kilo

---

## 🔧 Kurulum ve Başlatma

### Gereksinimler

| Araç | Sürüm |
|---|---|
| Flutter SDK | ≥ 3.11.0 |
| Dart SDK | ≥ 3.11.0 |
| Python | ≥ 3.10 |
| Android Studio | Son sürüm |
| Health Connect | Cihazda kurulu |

### 1. Repoyu Klonla
```bash
git clone <repo-url>
cd aksa_v1
```

### 2. Flutter Bağımlılıkları
```bash
flutter pub get
```

### 3. Firebase Yapılandırması
1. [Firebase Console](https://console.firebase.google.com/) → Yeni proje oluştur
2. Authentication → Email/Password ve Google Sign-In etkinleştir
3. Cloud Firestore → Veritabanı oluştur
4. `google-services.json` → `android/app/` dizinine kopyala
5. `flutterfire configure` ile `lib/firebase_options.dart` oluştur

### 4. Backend Kurulumu
```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS/Linux
pip install -r requirements.txt

# ML modelleri (opsiyonel — yoksa kural tabanlı fallback çalışır)
pip install torch xgboost pandas scipy shap
```

### 5. Ortam Değişkenleri
```bash
cp env.example .env
# .env dosyasını düzenleyin:
# GEMINI_API_KEY=your-google-ai-studio-key
# ALLOWED_ORIGINS=http://localhost:3000
```

### 6. Hızlı Başlatma
```bash
# Kök dizinde — backend + flutter eşzamanlı başlatır
python run_app.py

# Veya ayrı ayrı:
# Terminal 1: Backend
cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2: Flutter
flutter run
# Eski cihazlarda: flutter run --release
```

---

## 🧪 Testler

```bash
# Flutter testleri (16 test)
flutter test

# Backend testleri (14 test)
cd backend && python -m pytest tests/ -v
```

**Test Kapsamı:**
- `risk_engine_test.dart` — Kalibrasyon doğruluğu, eşik tutarlılığı, faktör sıralaması, sınır değerler
- `health_entry_test.dart` — Serialization, kaynak-duyarlı sıfır filtreleme, tip dönüşümleri
- `test_risk_model.py` — Backend eşikler, veri temizleme, öneri üretimi, faktör analizi

---

## 🔑 Teknoloji Yığını

### Frontend (Mobil)
| Paket | Kullanım |
|---|---|
| `flutter` | UI framework |
| `go_router` | Deklaratif navigasyon + auth guard |
| `firebase_auth` | Kullanıcı kimlik doğrulama |
| `cloud_firestore` | NoSQL veritabanı (sağlık verileri) |
| `health` | Health Connect / HealthKit SDK |
| `fl_chart` | Grafik ve radar chart |
| `flutter_local_notifications` | Hatırlatıcılar |
| `image_picker` | Kamera ile yemek fotoğrafı |
| `flutter_markdown` | AI asistan yanıt render |
| `http` | Backend API iletişimi |

### Backend (Sunucu)
| Paket | Kullanım |
|---|---|
| `fastapi` | REST API framework |
| `sqlalchemy[asyncio]` | Async ORM |
| `firebase-admin` | Token doğrulama |
| `numpy` + `scikit-learn` | ML temel |
| `xgboost` | Gradient boosting sınıflandırıcı |
| `torch` | GRU sinir ağı |
| `shap` | Açıklanabilir AI (XAI) |
| `scipy` | Sinyal işleme (Hampel, medyan filtre) |
| `google-generativeai` | Gemini LLM gateway |

---

## ⚠️ Önemli Notlar

- **Tıbbi Sorumluluk Reddi:** AKSA bir tıbbi cihaz değildir. Üretilen risk skorları ve öneriler yalnızca bilgilendirme amaçlıdır, tıbbi teşhis veya tedavi yerine geçmez.
- **Health Connect:** Cihazda Health Connect uygulamasının kurulu ve yetkilendirilmiş olması gerekir.
- **Release Modu:** Eski Android cihazlarda performans için `flutter run --release` kullanın.
- **ML Modelleri Opsiyonel:** XGBoost/GRU model dosyaları yoksa sistem otomatik olarak kural tabanlı (expert system) fallback'e geçer.
- **Veri Gizliliği:** Tüm kullanıcı verileri pseudonymous UID ile saklanır, kişisel bilgiler backend'e gönderilmez.

---

## 📄 Lisans

Bu proje Ondokuz Mayıs Üniversitesi Bilgisayar Mühendisliği Bölümü bitirme tezi kapsamında geliştirilmiştir. Tüm hakları saklıdır.
