# AKSA - Akıllı Kişisel Sağlık Asistanı 🩺

AKSA, kullanıcıların sağlık verilerini (adım, nabız, uyku, su tüketimi, mood vb.) takip ederek kişiselleştirilmiş analizler ve yapay zeka destekli öneriler sunan, tam kapsamlı bir "Premium" sağlık asistanıdır.

---

## ✨ Öne Çıkan Özellikler

- **AI Sağlık Asistanı:** Google Gemini entegrasyonu ile gerçek zamanlı sağlık ve yaşam tarzı danışmanlığı.
- **Dinamik Su Takibi:** Kişisel özelliklere (kilo vb.) göre hesaplanan günlük hedef ve interaktif dalga animasyonlu takip.
- **Ruh Hali (Mood) Analizi:** Günlük mental durum takibi ve fiziksel verilerle korelasyon.
- **Gelişmiş Raporlama:** Haftalık "Sağlık Dengesi" (Radar/Spider Chart) ile 5 ana boyutta derinlemesine analiz.
- **Akıllı Hatırlatıcılar:** Su tüketimi ve hareket için proaktif yerel bildirimler (Nudges).
- **Yemek Analizi:** Fotoğraf üzerinden kalori ve besin değeri tespiti.
- **Risk & Anomali Tespiti:** XGBoost ve ML modelleri ile sağlık verilerindeki sapmaların saptanması.

---

## 🛠 Başka Bir Bilgisayara Kurulum (Setup)

Projeyi yeni bir cihaza indirdiğinizde çalıştırabilmek için aşağıdaki gizli yapılandırma adımlarını tamamlamanız gerekmektedir:

### 1. Backend Güvenlik Yapılandırması 🔑
Güvenlik nedeniyle API anahtarlarımız GitHub'a yüklenmez.
1. `backend/env.example` dosyasını `backend/.env` adıyla kopyalayın.
2. İçindeki `GEMINI_API_KEY` alanına kendi Google AI Studio anahtarınızı girin.

### 2. Firebase Yapılandırması 🔥
Firebase ayarları platforma özeldir ve gizlidir.
1. [Firebase Console](https://console.firebase.google.com/)'dan projenizi oluşturun.
2. `google-services.json` dosyasını indirip `android/app/` dizinine yerleştirin.
3. Flutter projesi içinde `flutterfire configure` komutunu kullanarak `lib/firebase_options.dart` dosyasını oluşturun.

### 3. Hızlı Başlatma ⚡️
Tüm servisleri tek komutla başlatmak için kök dizinde:
```bash
# Geliştirme modu
python run_app.py

# Yüksek Performans (Release) modu - Eski cihazlar için önerilir
python run_app.py --release
```

---

## 🏗 Proje Mimarisi

- **Mobilde (Frontend):** Flutter & Dart (GoRouter, fl_chart, flutter_local_notifications)
- **Sunucuda (Backend):** Python & FastAPI (SQLAlchemy, SQLite)
- **Zeka (AI/ML):** Google Gemini Pro & Vision, ML modelleri (XGBoost, GRU)
- **Veri Kaynağı:** Mi Fitness / Health Connect → AKSA Veri Hattı

---

## 📂 Dosya Yapısı

- `lib/`: Mobil uygulama ekranları, widget'lar ve servisler.
- `backend/`: API route'ları, ML modelleri ve veritabanı şeması.
- `android/`: Android build ayarları (Desugaring, Permissions).
- `assets/`: Tasarım varlıkları ve logolar.

---

## ⚠️ Önemli Notlar
- **Health Connect:** Uygulamanın sağlık verilerini çekebilmesi için cihazda "Health Connect" uygulamasının kurulu ve yetkilendirilmiş olması gerekir.
- **Release Modu:** Eski Android cihazlarda takılma (jank) yaşamamak için mutlaka `--release` modunda derleme yapınız.

> [!NOTE] 
> Bu proje bir akademik tez kapsamında geliştirilmiştir. Tüm hakları saklıdır.
