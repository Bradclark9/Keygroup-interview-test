FROM python:3.12-slim AS build

WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src \
    PORT=8080 \
    APP_ENV=prod

RUN useradd --create-home --uid 10001 appuser
WORKDIR /app

COPY --from=build /install /usr/local
COPY src ./src

USER appuser
EXPOSE 8080

# One worker per pod (scale with replicas) so Prometheus metrics stay in one process.
# Request logs come from file_service.request_log, so uvicorn's access log is off.
CMD ["uvicorn", "file_service.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
