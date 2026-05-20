"""
M6 — Egzersiz Planı Modeli
RNN varsa kullanır, yoksa kural tabanlı katalog fallback.
"""

import os
import logging
import numpy as np
import sys
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date, timedelta

logger = logging.getLogger(__name__)

# ── ML Import (Opsiyonel) ──────────────────────────────────────────
_HAS_ML = False
try:
    import torch
    import joblib

    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from ml_models.rnn_recommender import ExerciseRNN

    _HAS_ML = True
    logger.info("✅ Egzersiz modeli: RNN yüklendi")
except ImportError as e:
    logger.warning(f"⚠️  RNN yüklenemedi ({e}) — Kural tabanlı fallback aktif")

_rnn_model = None
_rnn_scaler = None


def _load_rnn():
    global _rnn_model, _rnn_scaler
    if not _HAS_ML or _rnn_model is not None:
        return
    try:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _rnn_scaler = joblib.load(
            os.path.join(base_path, "ml_models", "rnn_scaler.pkl")
        )
        _rnn_model = ExerciseRNN(input_size=4, hidden_size=16, num_classes=5)
        state_dict = torch.load(
            os.path.join(base_path, "ml_models", "exercise_rnn.pt"),
            map_location=torch.device("cpu"),
        )
        _rnn_model.load_state_dict(state_dict)
        _rnn_model.eval()
        logger.info("✅ RNN egzersiz modeli belleğe yüklendi")
    except Exception as e:
        logger.warning(f"⚠️  RNN model dosyaları yüklenemedi: {e}")


# ── Pydantic Modelleri ─────────────────────────────────────────────


class ExerciseRequest(BaseModel):
    age: int
    weight: float
    height: float
    gender: str
    risk_level: str  # 'low', 'medium', 'high'
    systolic_bp: Optional[float] = None
    diastolic_bp: Optional[float] = None
    heart_rate: Optional[float] = None
    force_refresh: bool = False


class ExerciseItem(BaseModel):
    title: str = Field(description="Egzersizin adı")
    duration_minutes: int = Field(description="Süre (dakika)")
    intensity: str = Field(description="Zorluk: Düşük, Orta, Yüksek")
    calories: int = Field(description="Tahmini yakılan kalori")
    type: str = Field(description="Egzersiz türü")
    description: str = Field(description="Kısa açıklama")


class ExercisePlanResponse(BaseModel):
    exercises: List[ExerciseItem]
    total_duration_minutes: int
    total_calories: int
    ai_advice: str = Field(description="Kullanıcıya özel tavsiye")


# ── Egzersiz Katalogları ───────────────────────────────────────────

_CATALOG = {
    0: ExercisePlanResponse(
        total_duration_minutes=20,
        total_calories=60,
        ai_advice="Bugünkü verileriniz yüksek risk gösterdiği için hafif mobilite ve nefes çalışması öneriyoruz. Eklemlerinizi korumak adına yavaş ve kontrollü hareket edin. Bol su için ve dinlenmeyi ihmal etmeyin.",
        exercises=[
            ExerciseItem(
                title="Oturarak Boyun ve Omuz Çevirme",
                duration_minutes=5,
                intensity="Çok Düşük",
                calories=10,
                type="Isınma",
                description="Oturarak boynu sağa-sola, öne-arkaya yavaşça çevirin. Omuzları yukarı kaldırıp 3 saniye tutun, bırakın. 10 tekrar.",
            ),
            ExerciseItem(
                title="Sandalyede Oturarak Bacak Kaldırma",
                duration_minutes=5,
                intensity="Çok Düşük",
                calories=15,
                type="Güç",
                description="Oturarak bir bacağı düz uzatın, 3 saniye tutun, indirin. Her bacak 10 tekrar. Hedef kas: Quadriceps.",
            ),
            ExerciseItem(
                title="Diyafram Nefes Egzersizi",
                duration_minutes=5,
                intensity="Çok Düşük",
                calories=10,
                type="Denge",
                description="4 saniye burundan nefes alın, 4 saniye tutun, 6 saniye ağızdan verin. 8 döngü. Parasempatik sinir sistemini aktive eder.",
            ),
            ExerciseItem(
                title="Duvar Desteğiyle Baldır Esnetme",
                duration_minutes=5,
                intensity="Çok Düşük",
                calories=10,
                type="Soğuma",
                description="Duvara ellerinizi dayayın, bir bacağı geriye uzatın. Topuğu yerde tutarak baldırı esnetin. Her taraf 30 saniye × 3 tekrar.",
            ),
        ],
    ),
    1: ExercisePlanResponse(
        total_duration_minutes=25,
        total_calories=100,
        ai_advice="Orta-yüksek risk seviyeniz göz önüne alınarak nefes odaklı yoga akışı ve hafif denge çalışması hazırlandı. Bu program stresi azaltır ve eklem hareketliliğini artırır.",
        exercises=[
            ExerciseItem(
                title="Kedi-İnek Duruşu (Cat-Cow)",
                duration_minutes=5,
                intensity="Düşük",
                calories=15,
                type="Isınma",
                description="Dört ayak pozisyonunda sırtı yukarı yuvarlayın (kedi), sonra çukurlaştırın (inek). 12 tekrar. Omurga mobilizasyonu sağlar.",
            ),
            ExerciseItem(
                title="Savaşçı Duruşu (Warrior I-II)",
                duration_minutes=7,
                intensity="Düşük",
                calories=25,
                type="Denge",
                description="Geniş adım açın, ön diz 90° bükün. Kolları yukarı (I) veya yanlara (II) açın. Her taraf 30 saniye × 3 tekrar. Hedef: Quadriceps, kalça fleksörleri.",
            ),
            ExerciseItem(
                title="Köprü Duruşu (Glute Bridge)",
                duration_minutes=5,
                intensity="Düşük",
                calories=20,
                type="Güç",
                description="Sırt üstü yatın, dizleri bükün. Kalçayı yukarı kaldırıp 3 saniye sıkın. 3 set × 10 tekrar. Hedef kas: Gluteus, hamstring.",
            ),
            ExerciseItem(
                title="Ağaç Duruşu (Tree Pose)",
                duration_minutes=3,
                intensity="Düşük",
                calories=10,
                type="Denge",
                description="Tek ayakta durun, diğer ayağı baldıra veya uyluğa koyun. Eller göğüste veya yukarıda. Her taraf 30 saniye × 2. Denge ve propriosepsiyon geliştirir.",
            ),
            ExerciseItem(
                title="Çocuk Duruşu ile Soğuma",
                duration_minutes=5,
                intensity="Çok Düşük",
                calories=10,
                type="Soğuma",
                description="Dizler üstünde oturup öne uzanın, kolları ileri veya yanlara açın. 60 saniye tutun, derin nefes alın. 3 tekrar.",
            ),
        ],
    ),
    2: ExercisePlanResponse(
        total_duration_minutes=35,
        total_calories=220,
        ai_advice="Orta risk seviyenize uygun bir kardiyo ve core stabilite programı hazırlandı. Tempolu yürüyüş kardiyovasküler sağlığınızı güçlendirirken, core egzersizleri duruşunuzu ve bel sağlığınızı koruyacaktır.",
        exercises=[
            ExerciseItem(
                title="Dinamik Isınma (Arm Circles + Leg Swings)",
                duration_minutes=5,
                intensity="Düşük",
                calories=20,
                type="Isınma",
                description="Kolları ileri-geri çevirin (20 tekrar). Bir ağaca tutunarak bacağı ileri-geri sallayın (her taraf 15 tekrar). Eklem sıvısını aktive eder.",
            ),
            ExerciseItem(
                title="Tempolu Yürüyüş",
                duration_minutes=15,
                intensity="Orta",
                calories=90,
                type="Kardiyo",
                description="Saatte 5.5-6.5 km hızda yürüyün. Nabzınızı maksimumun %60-70'inde tutun. Kolları aktif sallayın. Düz bir zeminde veya bantta.",
            ),
            ExerciseItem(
                title="Plank (Ön Köprü)",
                duration_minutes=5,
                intensity="Orta",
                calories=30,
                type="Güç",
                description="Ön kol desteğinde düz durun. Kalça aşağı düşmesin, sırt düz kalsın. 30 saniye × 4 set (30 sn dinlenme). Hedef: Core, omuz stabilizatörleri.",
            ),
            ExerciseItem(
                title="Direnç Bandıyla Squat",
                duration_minutes=5,
                intensity="Orta",
                calories=40,
                type="Güç",
                description="Direnç bandını dizlerin üstüne takın, omuz genişliğinde açılın. Kalçayı geriye iterek çömelin. 3 set × 12 tekrar. Hedef: Quadriceps, Gluteus. Dizler ayak uçlarını geçmesin.",
            ),
            ExerciseItem(
                title="Hamstring ve Kalça Esnetme",
                duration_minutes=5,
                intensity="Düşük",
                calories=15,
                type="Soğuma",
                description="Oturup bir bacağı uzatın, öne doğru eğilin. Her taraf 30 saniye × 3. Ardından kelebek oturuşunda kalçayı esnetin.",
            ),
        ],
    ),
    3: ExercisePlanResponse(
        total_duration_minutes=45,
        total_calories=350,
        ai_advice="Düşük risk seviyeniz harika! Bugünkü program koşu ile kardiyovasküler dayanıklılığınızı, vücut ağırlığı hareketleriyle de fonksiyonel gücünüzü artırmayı hedefliyor. Antrenman sonrası protein ağırlıklı bir atıştırmalık tüketmenizi öneririm.",
        exercises=[
            ExerciseItem(
                title="Dinamik Isınma (High Knees + Butt Kicks)",
                duration_minutes=5,
                intensity="Düşük",
                calories=25,
                type="Isınma",
                description="Yerinde yüksek diz kaldırma (30 sn) + topuk-kalçaya vurma (30 sn). 3 döngü. Kan dolaşımını hızlandırır.",
            ),
            ExerciseItem(
                title="Hafif Tempo Koşu",
                duration_minutes=15,
                intensity="Orta",
                calories=130,
                type="Kardiyo",
                description="6-7 dk/km temposunda koşu. Nabzı %65-75 bandında tutun. Nefes ritmi: 3 adım nefes al, 2 adım ver.",
            ),
            ExerciseItem(
                title="Bulgarian Split Squat",
                duration_minutes=5,
                intensity="Orta",
                calories=40,
                type="Güç",
                description="Arka ayağı sandalyeye koyun, ön bacakla çömelin. Her taraf 3 set × 10 tekrar. Hedef: Quadriceps, Gluteus, denge. Diz 90° geçmesin.",
            ),
            ExerciseItem(
                title="Push-up (Şınav) Varyasyonları",
                duration_minutes=5,
                intensity="Orta",
                calories=40,
                type="Güç",
                description="Standart şınav 10 + geniş tutuş 8 + dar tutuş 6 = 1 set. 3 set yapın. Hedef: Göğüs, triceps, ön omuz. Sırt düz kalsın.",
            ),
            ExerciseItem(
                title="Dead Bug (Sırt Üstü Core)",
                duration_minutes=5,
                intensity="Orta",
                calories=25,
                type="Güç",
                description="Sırt üstü yatın, kol ve bacakları havada tutun. Karşılıklı kol-bacağı yere indirip kaldırın. 3 set × 12 tekrar. Hedef: Derin karın kasları (transversus abdominis).",
            ),
            ExerciseItem(
                title="Foam Roller ile Soğuma",
                duration_minutes=5,
                intensity="Düşük",
                calories=15,
                type="Soğuma",
                description="Foam roller üzerinde quadriceps, IT bandı, sırt ve baldır kaslarını yavaşça yuvarlayın. Her bölge 45 saniye. Kas toparlanmasını hızlandırır.",
            ),
        ],
    ),
    4: ExercisePlanResponse(
        total_duration_minutes=45,
        total_calories=450,
        ai_advice="Verileriniz optimal seviyede! Bugün yüksek yoğunluklu devre antrenmanı ile hem kondisyon hem güç kazanacaksınız. HIIT formatında çalışmak metabolizmanızı antrenman sonrası 24 saat boyunca yüksek tutacaktır (EPOC etkisi).",
        exercises=[
            ExerciseItem(
                title="Dinamik Isınma (Jumping Jacks + Inchworm)",
                duration_minutes=5,
                intensity="Orta",
                calories=30,
                type="Isınma",
                description="Jumping Jack 30 sn + Inchworm (ayakta öne eğilip ellerle plank pozisyonuna yürüyün) 30 sn. 3 döngü.",
            ),
            ExerciseItem(
                title="HIIT Devre: Burpee → Squat Jump → Mountain Climber",
                duration_minutes=12,
                intensity="Yüksek",
                calories=150,
                type="Kardiyo",
                description="40 sn aktif / 20 sn dinlenme formatında: Burpee (40sn) → Squat Jump (40sn) → Mountain Climber (40sn). 4 tur. Tüm vücut kardiyo.",
            ),
            ExerciseItem(
                title="Dumbbell / Vücut Ağırlığı Lunge",
                duration_minutes=8,
                intensity="Yüksek",
                calories=80,
                type="Güç",
                description="İleriye adım atarak lunge. Opsiyonel: her elde 4-8 kg dumbbell. Her taraf 4 set × 10 tekrar. Hedef: Quadriceps, hamstring, gluteus.",
            ),
            ExerciseItem(
                title="Plank to Push-up (Komando)",
                duration_minutes=5,
                intensity="Yüksek",
                calories=50,
                type="Güç",
                description="Ön kollardan tam kol desteğine geçip geri inin. 3 set × 10 tekrar. Hedef: Core, triceps, omuz. Kalça sallanmamalı.",
            ),
            ExerciseItem(
                title="Kettlebell / Dumbbell Swing",
                duration_minutes=5,
                intensity="Yüksek",
                calories=60,
                type="Güç",
                description="Bacak açıklığında durun, kettlebell'i kalça menteşesi hareketiyle öne sallayın. 4 set × 15 tekrar. Hedef: Posterior zincir (hamstring, gluteus, sırt). Ekipman yoksa squat + overhead press yapın.",
            ),
            ExerciseItem(
                title="Soğuma: Dünya'nın En Büyük Esnemesi",
                duration_minutes=5,
                intensity="Düşük",
                calories=15,
                type="Soğuma",
                description="Lunge pozisyonunda öne eğilip dirsekle yere dokunun, sonra aynı taraf kolu göğe açın. Her taraf 5 tekrar. Tüm vücudu tek harekette esnetir.",
            ),
        ],
    ),
}


def _pick_plan_rules(req: ExerciseRequest) -> int:
    """Risk seviyesine göre basit kural tabanlı plan seçimi."""
    risk = req.risk_level.lower()
    if risk == "high":
        return 0  # Sadece hafif mobilite
    elif risk == "medium":
        # ── BUG-4 Fix: Yaşa göre kademeli egzersiz seviyesi ──
        if req.age > 60:
            return 1  # Yoga / denge
        elif req.age > 40:
            return 2  # Tempolu yürüyüş + core
        else:
            return 2  # Kardiyo + güç (ama HIIT değil)
    else:
        # Düşük risk — yaşa göre
        if req.age < 30:
            return 4  # HIIT
        elif req.age < 50:
            return 3  # Koşu + güç
        else:
            return 2  # Tempolu yürüyüş + core


def _pick_plan_rnn(
    req: ExerciseRequest,
    records: list = None,
    ml_features: list[float] | None = None,
    last_feedback: str | None = None,
) -> int:
    """RNN ile plan seçimi (Kullanıcının gerçek verileriyle)."""
    _load_rnn()
    if _rnn_model is None:
        return _pick_plan_rules(req)

    risk_map = {"low": 0, "medium": 1, "high": 2}
    risk_val = risk_map.get(req.risk_level.lower(), 1)

    seq_len = 14
    history = np.zeros((1, seq_len, 4))

    if records is None:
        records = []

    today = date.today()
    record_dict = {r.record_date: r for r in records}

    for i in range(seq_len):
        # Time index: 0 = en eski (13 gün önce), 13 = bugün
        target_date = today - timedelta(days=(seq_len - 1 - i))
        r = record_dict.get(target_date)

        # Bugünün kaydı ve M2 özellikleri varsa, temiz verileri kullan
        # ml_features formatı: [[9], [9], ...] (matris) veya [9] (flat)
        ml_vec = None
        if target_date == today and ml_features is not None:
            if isinstance(ml_features, list) and len(ml_features) > 0:
                if isinstance(ml_features[0], list):
                    ml_vec = ml_features[-1]  # Son pencereyi al
                elif len(ml_features) == 9:
                    ml_vec = ml_features

        if ml_vec and len(ml_vec) == 9:
            steps = float(ml_vec[5])  # steps_rolling_sum
            active_mins = float(ml_vec[6])  # steps_active_time
            sleep = float(r.sleep_hours or 5.0) if r else 5.0
        elif r:
            steps = float(r.steps or 0)
            # Aktif Süreyi aktif kaloriden veya adımdan tahmin et
            active_cals = getattr(r, "active_calories", 0)
            if active_cals and active_cals > 0:
                active_mins = float(active_cals / 5)
            else:
                active_mins = float(steps / 100)

            sleep = float(r.sleep_hours or 0)

            # Eğer veri 0 olarak geldiyse modeli şaşırtmamak için taban değerlere çek
            if steps == 0:
                steps = 1000.0
            if active_mins == 0:
                active_mins = 10.0
            if sleep == 0:
                sleep = 5.0
        else:
            # Padding (Kullanıcının eksik gününü sahte uç noktalara çekmek yerine düşük aktif bir profille doldur)
            steps = 2000.0
            active_mins = 15.0
            sleep = 6.0

        history[0, i, 0] = steps
        history[0, i, 1] = active_mins
        history[0, i, 2] = sleep
        history[0, i, 3] = risk_val

    h_flat = history.reshape(-1, 4)
    h_scaled = _rnn_scaler.transform(h_flat).reshape(1, seq_len, 4)

    x_t = torch.tensor(h_scaled, dtype=torch.float32)
    with torch.no_grad():
        probs = _rnn_model(x_t).numpy()[0]

    # Güvenlik Kapısı
    if risk_val == 2:
        probs[2] = 0.0
        probs[3] = 0.0
        probs[4] = 0.0
    elif risk_val == 1:
        probs[4] = 0.0

    class_id = int(np.argmax(probs))

    # Tez M6: Kullanıcı Geri Bildirimi (Feedback Loop) ile ayarlama
    if last_feedback == "too_hard" and class_id > 0:
        logger.info(
            f"Kullanıcı geri bildirimi 'too_hard' olduğu için zorluk {class_id}'den {class_id - 1}'e düşürüldü."
        )
        class_id -= 1
    elif last_feedback == "too_easy" and class_id < 4:
        # Risk seviyesi yüksekse artırmaya izin verme
        if not (risk_val == 2) and not (risk_val == 1 and class_id >= 3):
            logger.info(
                f"Kullanıcı geri bildirimi 'too_easy' olduğu için zorluk {class_id}'den {class_id + 1}'e artırıldı."
            )
            class_id += 1
    # ── BUG-11 Fix: Son güvenlik kapısı — tüm ayarlamalardan sonra kontrol ──
    if risk_val == 2 and class_id > 1:
        class_id = 1
    elif risk_val == 1 and class_id > 3:
        class_id = 3

    return class_id


async def get_exercise_class(
    req: ExerciseRequest,
    records: list = None,
    ml_features: list[float] | None = None,
    last_feedback: str | None = None,
) -> int:
    """Yoğunluk seviyesini (0-4) belirleyen ana sınıflandırıcı."""
    try:
        if _HAS_ML:
            return _pick_plan_rnn(
                req, records, ml_features=ml_features, last_feedback=last_feedback
            )
        else:
            return _pick_plan_rules(req)
    except Exception as e:
        logger.error(f"Egzersiz sınıflandırma hatası: {e}")
        return 0  # Fallback: Yürüyüş sınıfı


def get_fallback_plan(class_id: int) -> ExercisePlanResponse:
    """Gemini başarısız olursa kullanılacak statik plan."""
    return _CATALOG.get(class_id, _CATALOG[0])
