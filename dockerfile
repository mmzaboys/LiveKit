FROM python:3.11-slim

WORKDIR /app

# Install uv
RUN pip install uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen

COPY src ./src
COPY .env.local ./

CMD ["uv", "run", "python", "src/main.py"]
