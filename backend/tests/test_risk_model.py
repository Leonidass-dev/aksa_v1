"""
M3 Risk Modeli Birim Testleri
Kural tabanlı (expert-v1) ve eşik tutarlılığı testleri.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.risk_model import HealthSnapshot, compute_risk, _compute_risk_rules


class TestRiskThresholds:
    """Risk eşiklerinin tez ile tutarlılığı (0-33 low, 34-66 medium, 67-100 high)"""

    def test_healthy_person_low_risk(self):
        snap = HealthSnapshot(
            steps=10000, active_minutes=45,
            sleep_hours=7.5, sleep_quality=85,
            heart_rate_avg=72, heart_rate_resting=62,
            spo2=97, stress_level=25,
            weight=75, systolic=115, diastolic=75,
            age=28, gender="M", height=178,
        )
        result = _compute_risk_rules(snap)
        assert result.score <= 33, f"Sağlıklı kişi düşük risk olmalı, skor: {result.score}"
        assert result.level == "low"

    def test_unhealthy_person_high_risk(self):
        snap = HealthSnapshot(
            steps=500, active_minutes=0,
            sleep_hours=3.5, sleep_quality=30,
            heart_rate_avg=110, heart_rate_resting=105,
            spo2=89, stress_level=85,
            weight=120, systolic=165, diastolic=100,
            age=55, gender="M", height=170,
        )
        result = _compute_risk_rules(snap)
        assert result.score > 66, f"Riskli kişi yüksek risk olmalı, skor: {result.score}"
        assert result.level == "high"

    def test_score_within_bounds(self):
        """Tüm skorlar 0-100 aralığında olmalı"""
        # En kötü durum
        worst = HealthSnapshot(
            steps=0, sleep_hours=0, heart_rate_resting=160,
            spo2=80, stress_level=100, systolic=200, diastolic=120,
            weight=200, age=80, height=160,
        )
        result_worst = _compute_risk_rules(worst)
        assert 0 <= result_worst.score <= 100

        # En iyi durum
        best = HealthSnapshot(
            steps=15000, sleep_hours=8, heart_rate_resting=58,
            spo2=99, stress_level=10, systolic=110, diastolic=70,
            weight=70, age=25, height=175,
        )
        result_best = _compute_risk_rules(best)
        assert 0 <= result_best.score <= 100

    def test_threshold_boundary_33(self):
        """Skor 33 ise level 'low' olmalı"""
        snap = HealthSnapshot(steps=5000, sleep_hours=6.5, age=30, height=175)
        result = _compute_risk_rules(snap)
        if result.score <= 33:
            assert result.level == "low"
        elif result.score <= 66:
            assert result.level == "medium"
        else:
            assert result.level == "high"

    def test_threshold_boundary_66(self):
        """Skor 66 ise level 'medium' olmalı"""
        snap = HealthSnapshot(
            steps=2000, sleep_hours=4, heart_rate_resting=95,
            systolic=135, diastolic=88, age=50, height=170,
        )
        result = _compute_risk_rules(snap)
        if result.score <= 33:
            assert result.level == "low"
        elif result.score <= 66:
            assert result.level == "medium"
        else:
            assert result.level == "high"


class TestRiskFactors:
    """Risk faktörü analizi testleri"""

    def test_factors_sorted_by_contribution(self):
        snap = HealthSnapshot(
            steps=1000, sleep_hours=3, heart_rate_resting=110,
            spo2=91, stress_level=80, systolic=150, diastolic=95,
            age=60, height=175, weight=100,
        )
        result = _compute_risk_rules(snap)
        contributions = [f.contribution for f in result.top_factors]
        assert contributions == sorted(contributions, reverse=True), \
            "Faktörler katkı büyüklüğüne göre sıralı olmalı"

    def test_max_5_factors(self):
        snap = HealthSnapshot(
            steps=500, sleep_hours=2, heart_rate_resting=120,
            spo2=85, stress_level=90, systolic=180, diastolic=110,
            weight=130, age=70, height=165,
        )
        result = _compute_risk_rules(snap)
        assert len(result.top_factors) <= 5

    def test_zero_steps_no_penalty(self):
        """steps=0 (veri yok) durumunda hareketsizlik cezası verilmemeli"""
        snap = HealthSnapshot(steps=0, age=30, height=175)
        result = _compute_risk_rules(snap)
        step_factors = [f for f in result.top_factors if "Hareketsizlik" in f.name or "Adım" in f.name]
        assert len(step_factors) == 0, "steps=0 (eksik veri) olduğunda ceza verilmemeli"


class TestDataCleaning:
    """M2 veri temizleme testleri"""

    def test_heart_rate_clamping(self):
        from models.risk_model import _clean_data
        snap = HealthSnapshot(heart_rate_avg=300)
        cleaned = _clean_data(snap)
        assert cleaned.heart_rate_avg <= 220

    def test_spo2_clamping(self):
        from models.risk_model import _clean_data
        snap = HealthSnapshot(spo2=150)
        cleaned = _clean_data(snap)
        assert cleaned.spo2 <= 100

    def test_steps_clamping(self):
        from models.risk_model import _clean_data
        snap = HealthSnapshot(steps=100000)
        cleaned = _clean_data(snap)
        assert cleaned.steps <= 50000


class TestRecommendations:
    """Öneri üretimi testleri"""

    def test_high_bp_recommendation(self):
        snap = HealthSnapshot(systolic=160, diastolic=95, age=30, height=175)
        result = _compute_risk_rules(snap)
        has_bp_rec = any("Tansiyon" in r or "tuz" in r.lower() for r in result.recommendations)
        assert has_bp_rec, "Yüksek tansiyon önerisi olmalı"

    def test_healthy_gets_positive_message(self):
        snap = HealthSnapshot(
            steps=10000, sleep_hours=8, heart_rate_resting=60,
            spo2=98, age=25, height=175,
        )
        result = _compute_risk_rules(snap)
        assert len(result.recommendations) > 0

    def test_model_version_set(self):
        snap = HealthSnapshot(age=30, height=175)
        result = _compute_risk_rules(snap)
        assert result.model_version == "expert-v1.2"


if __name__ == "__main__":
    import pytest
    pytest.main([__file__, "-v"])
