# The model is trained ONCE, at build time, and baked into the image.
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY train.py serve.py ./

# The model artifact has its own version, independent from the image tag.
# Override with --build-arg MODEL_VERSION=<version> when the weights change.
ARG MODEL_VERSION=iris-logreg-v1
ENV MODEL_VERSION=${MODEL_VERSION} \
    MODEL_PATH=/app/weights/model-${MODEL_VERSION}.joblib \
    PORT=8081
RUN mkdir -p /app/weights && python train.py

EXPOSE 8081

# `docker ps` shows (healthy) once /healthz answers. Kubernetes ignores this
# and uses the chart's probes instead.
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=10 \
  CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://localhost:%s/healthz' % os.environ.get('PORT', '8081'), timeout=2)"]

CMD ["python", "serve.py"]
