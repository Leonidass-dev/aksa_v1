# Base imaj olarak Python 3.12 Slim versiyonu (Daha küçük boyutlu ve güvenli)
FROM python:3.12-slim

# Sistem bağımlılıklarını güncelle ve gerekli C kütüphanelerini kur (ML kütüphaneleri için gerekebilir)
RUN apt-get update && apt-get install -y \
    build-essential \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Çalışma dizinini ayarla
WORKDIR /app

# Sadece requirements dosyasını kopyalayarak Docker'ın cache mekanizmasından faydalan
COPY requirements.txt .

# Ana bağımlılıkları ve ML bağımlılıklarını kur (PyTorch CPU versiyonunu kurarak imaj boyutunu küçültürüz)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt xgboost pandas scipy shap

# Kalan tüm uygulama kodlarını kopyala
COPY . .

# FastAPI portunu dışa aç
EXPOSE 8000

# Gunicorn ile production seviyesinde uvicorn worker'ları çalıştır
# Veya direkt uvicorn kullan (Performans için uvicorn default ayarları yeterli)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
