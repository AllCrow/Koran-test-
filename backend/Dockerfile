# syntax=docker/dockerfile:1
FROM python:3.12-slim
WORKDIR /service

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg libgomp1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY backend/requirements*.txt /service/backend/
# Managed cloud builds can mount the combined session/system CA bundle as
# proxy_ca. Proxy build arguments remain inherited; credentials never enter ENV.
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi; \
    python -m pip install --no-cache-dir torch==2.7.1 --index-url https://download.pytorch.org/whl/cpu \
    && python -m pip install --no-cache-dir -r backend/requirements-inference.txt
COPY --chown=10001:10001 backend /service/backend
COPY --chown=10001:10001 Sources/QuranPractice/Resources/PracticeReferences /service/Sources/QuranPractice/Resources/PracticeReferences
RUN mkdir -p /var/lib/sakina/huggingface && chown -R 10001:10001 /var/lib/sakina
ENV HF_HOME=/var/lib/sakina/huggingface SAKINA_ENABLE_MODEL=1 PYTHONUNBUFFERED=1
USER 10001:10001
EXPOSE 8000
# Publishing the port is deliberately a separate explicit operation; the README
# uses 127.0.0.1 on the Docker host. No model is downloaded at server startup.
CMD ["python", "-m", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log", "--limit-concurrency", "4"]
