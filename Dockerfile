FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=7860 DB_PATH=/srv/data/sinbaches.db
WORKDIR /srv
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home appuser
COPY app ./app
COPY web ./web
COPY models ./models
COPY scripts/download_model.py ./scripts/download_model.py
RUN python scripts/download_model.py
RUN mkdir -p /srv/data && chown 10001:10001 /srv/data
USER 10001
EXPOSE 7860
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:'+os.getenv('PORT','7860')+'/health',timeout=3)"
CMD ["python", "-m", "app.serve"]
