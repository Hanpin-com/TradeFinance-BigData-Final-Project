FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       gcc \
       g++ \
       libgomp1 \
       curl \
    && rm -rf /var/lib/apt/lists/*

COPY trade_finance/requirements.txt /app/requirements.txt

RUN python -m pip install --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt

COPY trade_finance /app/trade_finance
COPY sql /app/sql

CMD ["python", "-m", "trade_finance.data_generator.app"]
