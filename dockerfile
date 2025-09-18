FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    ffmpeg git curl build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY .env .
COPY agent.py .
CMD ["python", "agent.py"]
