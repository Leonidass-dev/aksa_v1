# AKSA - Akıllı Kişisel Sağlık Asistanı

AKSA, kullanıcılarının sağlık verilerini takip ederek kişiselleştirilmiş analizler ve yapay zeka destekli öneriler sunan akıllı bir sağlık asistanı projesidir. Proje genel hatlarıyla iki ana kısımdan oluşmaktadır:
1. **Frontend (Mobil Uygulama):** Kullanıcı etkileşimi için geliştirilen, Firebase (Kimlik doğrulama, veritabanı) ve Health API (Apple Health / Google Fit) entegrasyonuna sahip Flutter tabanlı mobil uygulama.
2. **Backend (Yapay Zeka ve Veri İşleme):** Kullanıcının verilerine (Egzersiz, Beslenme vb.) dayanarak Risk Skoru, Anomali tespiti, kişiselleştirilmiş Asistan yanıtları (Google Gemini) sunan FastAPI tabanlı Python mikroservisi.

---

## 🚀 Başlangıç ve Nasıl Çalıştırılır?

Projeyi kendi ortamınızda test etmek veya geliştirmek için iki farklı yöntem bulunmaktadır.

### Yöntem 1: Tek Tıkla (Otomatik) Başlatma ⚡️

Proje kök dizininde bulunan `run_app.py` scripti sayesinde hem arka uç (FastAPI) hem de mobil uygulamayı (Flutter) aynı anda tek bir komutla başlatabilirsiniz. *(Not: Bu komutun sorunsuz çalışması için aşağıda **Yöntem 2**'de bahsedilen Python sanal ortamının - venv - önceden kurulmuş olması gerekmektedir).*

1. Proje kök dizininde terminali açın.
2. Aşağıdaki komutu çalıştırarak her iki servisi de başlatın:
   ```bash
   python run_app.py
   ```
Bu komut, otomatik olarak FastAPI sunucusunu başlatır, bir süre bekler ve ardından uygulamayı derlemek için `flutter run` komutunu çağırır. Sistemi tamamen kapatmak istediğinizde terminalden `Ctrl+C` yapmanız yeterlidir; böylece hem arka uç hem ön uç kapanacaktır.

---

### Yöntem 2: Servisleri Ayrı Ayrı (Manuel) Başlatma

#### 1- Backend (Python / FastAPI) Kurulumu

Arka uç servisi `backend` klasörü altında yer almaktadır ve uygulamanın veri işleme ile yapay zeka destekli analiz görevlerini yürütür.

**Gereksinimler:** Python 3.9+ (Önerilen)

1. Terminali açın ve projenin içerisindeki backend klasörüne geçiş yapın:
   ```bash
   cd backend
   ```
2. İzole bir geliştirme ortamı için sanal ortam (virtual environment) oluşturun:
   ```bash
   python -m venv venv
   ```
3. Sanal ortamı aktifleştirin:
   - **Windows:** `venv\Scripts\activate`
   - **macOS/Linux:** `source venv/bin/activate`
4. Gerekli kütüphaneleri (FastAPI, uvicorn, scikit-learn, google-generativeai vb.) yükleyin:
   ```bash
   pip install -r requirements.txt
   ```
5. `.env` Dosyası: Ortam değişkenleri için backend klasörü içerisindeki `.env` dosyasının gerekli apikey'ler ile (Örn. `GEMINI_API_KEY`) doldurulduğundan emin olun.
6. Sunucuyu başlatın:
   ```bash
   uvicorn main:app --reload
   ```
   **Not:** API varsayılan olarak `http://localhost:8000` adresinde çalışacaktır. Etkileşimli dokümantasyon (Swagger UI) ortamına `http://localhost:8000/docs` adresinden ulaşabilirsiniz.

#### 2- Frontend (Flutter) Kurulumu

Mobil arayüz projenin kök dizininde yer almaktadır.

**Gereksinimler:** Flutter SDK, Android Studio veya Xcode.

1. Ana dizinde (Projenin kökünde) terminali açın.
2. Flutter paketlerini ve bağımlılıklarını indirin:
   ```bash
   flutter pub get
   ```
3. **Firebase Bağlantısı:** Uygulamanız Firebase ile yapılandırılmıştır (`google_sign_in`, `firebase_auth`, `cloud_firestore`). Geliştirmeye başlamadan önce Firebase konsolu üzerinden projenizi bağlayın ve yapılandırma dosyalarını (`google-services.json` vb.) ilgili platform klasörlerine yerleştirdiğinizden emin olun.
4. Cihazınızı veya emülatörü (simülatör) seçin ve uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

---

## 🛠 Kullanılan Teknolojiler

- **Mobil Uygulama:** Flutter, Dart, GoRouter (routing)
- **Arka Uç (Backend):** Python, FastAPI, Uvicorn
- **Veritabanı & Kimlik Doğrulama:** Firebase (Cloud Firestore, Firebase Auth, Google/Apple Sign-In)
- **Sağlık Verisi Takibi:** Health paketleri ile Apple Health ve Google Fit entegrasyonu
- **Yapay Zeka ve Makine Öğrenimi:** Google Generative AI (Gemini), Scikit-Learn, NumPy

## 📂 Proje Yapısı

- `lib/`: Flutter mobil uygulamasının bileşenleri (UI screens, widgets, state yönetimi vb.).
- `backend/`: Risk analizi, beslenme takibi, anomali algılama ve sohbet botu (API) kodları.
- `android/`, `ios/`: Platformlara özgü yapılandırmalar.
- `assets/`: Görseller (Logo vb.) ve ikon kaynakları.
- `pubspec.yaml`: Flutter projesinin temel bağımlılıklarının kontrol dosyası.
