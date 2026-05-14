import pandas as pd
import numpy as np
from scipy.signal import medfilt
import joblib

class PreprocessorPipeline:
    def __init__(self, step_window_size=60, hr_window_size=60, stride=5, min_valid_pct=0.8):
        """
        Tezdeki Modül 2: Veri Ön İşleme (Preprocessing) sınıfı.
        - step_window_size: Pencerelerin dakika cinsinden boyutu
        - stride: Kayan pencere adımı (dakika)
        - min_valid_pct: Pencerenin geçerli sayılması için gereken minimum veri doluluk oranı
        """
        self.window_size = step_window_size
        self.stride = stride
        self.min_valid_pct = min_valid_pct
    
    def hampel_filter(self, series, window_size=5, n_sigmas=3):
        """HR için ani sıçramaları (outlier) temizleyen Hampel Filtresi (Vektörize)"""
        rolling_median = series.rolling(window=window_size, center=True).median()
        
        # Tamamen vektörize MAD hesaplaması (apply(lambda) darboğazı çözüldü)
        abs_diff = (series - rolling_median).abs()
        rolling_mad = abs_diff.rolling(window=window_size, center=True).median()
        
        # MAD'i standart sapmaya çevir (~1.4826)
        rolling_std = 1.4826 * rolling_mad
        
        outliers = np.abs(series - rolling_median) > (n_sigmas * rolling_std)
        
        # Aykırı değerleri medyan ile değiştir (ya da np.nan ver)
        series_clean = series.copy()
        series_clean[outliers] = rolling_median[outliers]
        
        # Kenarlardaki veya arada kalan NaN değerleri interpolasyon/fill ile onar
        series_clean = series_clean.bfill().ffill()
        
        return series_clean

    def process_heart_rate(self, df_hr):
        """
        Kalp atışı verisini ön işler:
        1. 1 dakikalık zaman aralığına resample (medyan ile)
        2. Imkansız değerleri (HR<=0 veya HR>240) NaN yap
        3. Kısa boşlukları lineer enterpolasyon ile doldur
        4. Hampel filtresi + Hareketli medyan (gürültü azaltma)
        """
        if df_hr.empty:
            return df_hr
            
        df = df_hr.copy()
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)
        
        # İmkansız değerleri kırp
        df.loc[(df['value'] <= 0) | (df['value'] > 240), 'value'] = np.nan
        
        # 1 dakikalık çözünürlüğe hizala
        df_resampled = df.resample('1min').median()
        
        # Kısa boşlukları (örn. maks 5 dk) lineer olarak doldur
        df_resampled['value'] = df_resampled['value'].interpolate(method='linear', limit=5)
        
        # Hampel Filtresi + Median Filter (Gürültü)
        df_resampled['value'] = self.hampel_filter(df_resampled['value'], window_size=5, n_sigmas=3)
        
        # BUG-9 Fix: Tüm değerler NaN ise medfilt anlamsız sonuç üretir
        v = df_resampled['value'].fillna(0).values
        if len(v) >= 3 and np.any(v != 0):
            df_resampled['value'] = medfilt(v, kernel_size=3)
        elif len(v) >= 3:
            # Tüm değerler 0 — veri yok, boş bırak
            df_resampled['value'] = np.nan
        else:
            df_resampled['value'] = v
        
        # Sıfır olan yerleri tekrar NaN yap (medfilt padding)
        df_resampled['value'] = df_resampled['value'].replace(0, np.nan)
        return df_resampled

    def process_steps(self, df_steps):
        """
        Adım verisini ön işler:
        1. Negatif değerleri 0 yap
        2. 1 dakikalık toplam (sum) resample
        3. Aşırı patlamaları (örn >300 adım/dakika) kırp (clip)
        """
        if df_steps.empty:
            return df_steps
            
        df = df_steps.copy()
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)
        
        # Negatif değerleri düzelt
        df.loc[df['value'] < 0, 'value'] = 0
        
        # Aşırı patlamaları kırp (insan dakikada 300'den fazla adım atamaz)
        df.loc[df['value'] > 300, 'value'] = 300
        
        # 1 dakikalık kovalara topla (sum)
        df_resampled = df.resample('1min').sum()
        df_resampled['value'] = df_resampled['value'].fillna(0)
        
        # NOT: log1p dönüşümü pencere bazında toplama yapıldıktan sonra uygulanmalı (M2 Düzeltme)
        return df_resampled

    def create_features(self, df_hr, df_steps):
        """
        İşlenmiş 1 dakikalık serileri 60 dakikalık kayan pencerelere (sliding window) böler
        ve her pencere için istatistiksel özellikleri (Feature Extraction) çıkarır.
        """
        # Zaman eksenlerini birleştir (Outer join)
        df = pd.merge(df_hr, df_steps, left_index=True, right_index=True, how='outer', suffixes=('_hr', '_steps'))
        
        # Zaman aralığını baştan sona eksiksiz 1 dakikalık endekse oturt
        if(df.empty):
            return pd.DataFrame()
            
        full_idx = pd.date_range(start=df.index.min(), end=df.index.max(), freq='1min')
        df = df.reindex(full_idx)
        
        features_list = []
        
        # Sliding Window İterasyonu
        # Pencereler 60dk, adım 5dk
        start_time = df.index.min()
        end_time = df.index.max()
        
        current_time = start_time
        while current_time + pd.Timedelta(minutes=self.window_size) <= end_time:
            window_end = current_time + pd.Timedelta(minutes=self.window_size)
            window = df.loc[current_time:window_end - pd.Timedelta(seconds=1)]
            
            hr_series = window['value_hr']
            steps_series = window['value_steps']
            
            # Veri kalite kontrolü (Tüm pencerenin %80'i dolu olmalı)
            valid_pct = hr_series.notna().sum() / self.window_size
            if valid_pct >= self.min_valid_pct:
                hr_clean = hr_series.dropna()
                
                # Tez Uyumluluğu: Otonom Sinir Sistemi Stresi İçin HRV Metrikleri (M3)
                hr_diffs = hr_clean.diff().dropna()
                hr_rmssd = np.sqrt((hr_diffs ** 2).mean()) if len(hr_diffs) > 0 else 0

                features = {
                    'window_start': current_time,
                    'window_end': window_end,
                    'hr_mean': hr_clean.mean(),
                    'hr_median': hr_clean.median(),
                    'hr_min': hr_clean.min(),
                    'hr_max': hr_clean.max(),
                    'hr_std': hr_clean.std(),
                    'hr_rmssd': hr_rmssd,                   # Yeni: HRV Proxy
                    'hr_q25': hr_clean.quantile(0.25),      # Yeni: Alt çeyreklik
                    'hr_q75': hr_clean.quantile(0.75),      # Yeni: Üst çeyreklik
                    'hr_skewness': hr_clean.skew(),         # Yeni: Çarpıklık
                    'steps_sum': steps_series.sum(),        # M2: Toplam adım hacmi
                    'steps_active_mins': (steps_series > 0).sum(),
                    'steps_max': steps_series.max(),
                    'missing_pct': 1.0 - valid_pct
                }
                features_list.append(features)
                
            current_time += pd.Timedelta(minutes=self.stride)
            
        df_features = pd.DataFrame(features_list)
        return df_features
