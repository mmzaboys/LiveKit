FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    ffmpeg git curl build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# انسخ requirements بس الأول علشان Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# انسخ باقي الملفات
COPY . .

# نزّل الموديلات المطلوبة قبل التشغيل
RUN python3 agent.py download-files

# شغل الـ agent
CMD ["python", "agent.py","start"]
