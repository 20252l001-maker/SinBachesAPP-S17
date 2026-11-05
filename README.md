# SinBachesAPP

Proyecto integrador de la Sesión 17 — Yurandir Loayza Rosas.

Aplicación con inferencia real de baches en fotografías mediante un modelo preentrenado YOLOv8s en ONNX, API FastAPI segura, registro de incidencias georreferenciadas, revisión humana y monitoreo. Una detección es candidata: no acredita profundidad, gravedad o reparación de una vía.

## Funciones

- Carga JPEG o PNG, detección con confianza y cajas sobre la imagen.
- API key obligatoria para inferencia, reportes, tickets, métricas y esquema.
- Agrupación de reportes activos a 30 m, deduplicación por SHA256 de fotografía.
- Estados pendiente, validado y reparado mediante revisión humana.
- SQLite con transacciones; no almacena las fotografías originales.
- Métricas Prometheus, logs estructurados, Docker, Compose y automatización CI.

## Modelo preentrenado

Se consume realmente `peterhdd/pothole-detection-yolov8`, revisión `da7747eea7abb4319a0f55961f31809a16c1b10a`. `models/model.json` fija SHA256, entrada `[1,3,640,640]`, salida `[1,5,8400]` y clase bache. El modelo se entrenó previamente por un tercero; esta aplicación no declara haberlo entrenado. ONNX Runtime usa CPU con un hilo. No utiliza simulaciones como sustituto de inferencia.

Preprocesado: orientación EXIF, RGB, letterbox 640×640 con relleno 114 y normalización a 0–1. Postprocesado: confianza por defecto 0,25, conversión de cajas al tamaño original y NMS IoU 0,45. Se acotan candidatos NMS a 1000 y resultados a 100. Se verifica la huella del modelo al iniciar. Véase NOTICE.md para atribuciones y declaraciones de licencia del proveedor.

## Instalación y ejecución

Python 3.13. En PowerShell, desde la raíz del proyecto:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe scripts/download_model.py
$env:API_KEY = (.\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_hex(32))")
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 7860 --log-config app/logging.json
```

Abra http://127.0.0.1:7860 y escriba esa misma clave en la interfaz. Las coordenadas iniciales son de ejemplo: reemplácelas con la ubicación real de su fotografía. La API key permanece en memoria de la página; no se incorpora al código ni al almacenamiento del navegador.

El ZIP incluye el modelo. En GitHub el peso se excluye por tamaño y se descarga automáticamente en la construcción Docker, con revisión y SHA256 fijados. No publique `.env`, `data/` ni `monitoring/api_key.txt`.

## Contrato API

| Ruta | Método | Acceso | Propósito |
|---|---|---|---|
| / | GET | Público | Interfaz de la aplicación |
| /health | GET | Público | Salud tras cargar el modelo |
| /predict | POST | API key | Imagen y confianza opcional, sin guardar reporte |
| /reports | POST | API key | Imagen, latitude, longitude, street, main_road |
| /tickets | GET | API key | Hasta 500 incidencias con conteos |
| /tickets/{id} | PATCH | API key | Estado pendiente, validado o reparado |
| /model | GET | API key | Identificación y huella del modelo |
| /metrics | GET | API key | Métricas Prometheus |
| /openapi.json | GET | API key | Contrato completo |

Los POST de imagen usan multipart/form-data. Encabezado `X-API-Key`. JPEG/PNG hasta 5 MB y 12 megapíxeles, mínimo 32 píxeles por lado. Cuerpo HTTP hasta 6 MB. Confianza entre 0,05 y 0,95; latitud −90..90 y longitud −180..180 finitas; calle de 3 a 120 caracteres. La detección se realiza antes de registrar; si no hay candidatos al umbral 0,25, no se crea incidencia. Una imagen repetida devuelve 409. Los reportes no confirman automáticamente un bache por acumular cierta cantidad.

200: éxito; 201: reporte creado; 401: acceso inválido; 409: duplicado; 413: cuerpo excesivo; 422: datos o imagen inválidos; 503: motor no disponible. Los errores de validación no repiten el cuerpo recibido. Las consultas SQLite usan parámetros. La interfaz muestra cadenas con textContent y no interpreta el nombre de calle como HTML.

Ejemplo con curl (sustituya clave y ruta):

```text
curl -H "X-API-Key: SU_CLAVE" -F "image=@foto.jpg" -F "confidence=0.25" http://127.0.0.1:7860/predict
```

## Verificación reproducible

```powershell
.\.venv\Scripts\python.exe -m pytest -q --junitxml=evidence/tests.xml
.\.venv\Scripts\python.exe -m scripts.evaluate
.\.venv\Scripts\python.exe -m scripts.smoke_http
```

Resultados reales guardados en `evidence`: 26 tests satisfactorios; prueba Uvicorn HTTP local con inferencia 200, acceso sin clave 401 y creación de reporte 201. Hay una advertencia de deprecación en TestClient registrada en tests.txt.

Evaluación exploratoria en las primeras diez fotografías test por nombre del conjunto declarado por el modelo: 23 cajas anotadas, 22 predicciones, 10 verdaderos positivos, 12 falsos positivos y 13 falsos negativos, con umbral 0,25 e IoU de correspondencia 0,5. Precisión 45,45 %, exhaustividad 43,48 % y F1 44,44 %. No es mAP, validación en Cusco ni muestra independiente acreditada. No se ajustó el umbral para mejorar retrospectivamente estos números. Los resultados muestran necesidad de revisión humana y de una evaluación mayor.

`evaluation.csv` y `evaluation_details.json` permiten recalcular resultados. Las imágenes `prediction_*.jpg` tienen verde para anotaciones y naranja para predicciones. `benchmark.json` conserva veinte tiempos secuenciales sobre una fotografía fija tras un calentamiento. `http_smoke.json` y `metrics.prom` son respuestas reales. `app_local.jpg` es una captura real de la interfaz local. El ambiente y versiones se describen en environment.json.

## Docker y Compose

```powershell
Copy-Item .env.example .env
# Edite .env y asigne una clave aleatoria real
docker compose config --quiet
docker compose up --build -d
docker compose ps
docker compose logs --tail 50 api
docker compose down
```

No use `down -v` si desea conservar reportes. El volumen reports mantiene SQLite en Compose. Usuario 10001, sin capacidades adicionales, sistema de archivos de solo lectura excepto volumen y /tmp, límites de recursos y logs rotados. Docker no está instalado en el equipo de desarrollo: la evidencia de construcción debe provenir del proveedor o del workflow, cuando se ejecute realmente.

## Monitoreo

Cree `monitoring/api_key.txt` con la misma clave del servicio (solo el valor). No suba ese archivo a GitHub.

```powershell
docker compose --profile monitoring up --build -d
```

Prometheus: http://127.0.0.1:9090. Consultas: `sinbaches_detections_total`, `rate(sinbaches_http_requests_total[5m])`, `histogram_quantile(0.95,sum by(le)(rate(sinbaches_inference_seconds_bucket[5m])))`. Se incluyen reglas de indisponibilidad y errores del motor. No se configuró envío externo por Alertmanager. Los contadores de API se reinician al reiniciar el proceso; el volumen prometheus conserva lo recolectado en Compose.

## Despliegue Render

El proyecto incluye Dockerfile que respeta PORT y `render.yaml` con plan free, healthcheck y API key sin valor incorporado. En Render seleccione New Web Service, conecte el repositorio, lenguaje Docker, plan Free y configure API_KEY en Environment. El secreto se genera y guarda fuera de Git. Use la URL HTTPS asignada para probar /health, inferencia autenticada, acceso sin clave y /metrics. Conserve logs de construcción y respuestas; un archivo de configuración no equivale a despliegue ejecutado.

El plan gratuito suspende el servicio tras inactividad y no conserva archivos locales entre reinicios o despliegues. SQLite en este modo sirve para demostración temporal; para operación sostenida migre reportes a una base externa persistente o un plan con disco persistente. No se ofrece conservación permanente de reportes en Render Free. Las imágenes no se guardan. No se contratará un plan pagado de forma automática.

La raíz del repositorio debe ser esta carpeta para que `.github/workflows/checks.yml` funcione. El workflow instala dependencias, descarga el modelo verificado, ejecuta pytest, construye Docker y comprueba salud del contenedor. La ejecución en GitHub se acredita solo cuando existe un resultado real del workflow.

## Limitaciones y mejoras

Modelo de una clase, muestra pequeña, falsos positivos y falsos negativos observados. Sin segmentación, profundidad, medición de tamaño real ni diagnóstico estructural. Sin adquisición automática desde acelerómetro ni captura GPS automática. Revisar iluminación, sombras, charcos y pavimento local. Recolectar y anotar una muestra independiente con imágenes negativas, evaluar precisión y exhaustividad por condición y comparar umbrales antes de uso operativo. La API key comparte permisos administrativos; para varios usuarios agregar roles, auditoría por identidad y límites de tasa en proxy. No usar fotos con rostros o placas sin tratamiento apropiado.

## Referencias

- Modelo y ficha: https://huggingface.co/peterhdd/pothole-detection-yolov8
- Conjunto público: https://huggingface.co/datasets/Ryukijano/Pothole-detection-Yolov8
- FastAPI: https://fastapi.tiangolo.com/tutorial/security/
- ONNX Runtime: https://onnxruntime.ai/docs/get-started/with-python.html
- Render Docker: https://render.com/docs/docker
- Límites del plan gratuito: https://render.com/docs/free

Las evidencias se presentan con su origen y alcance. No se atribuye a esta aplicación la autoría del modelo preentrenado ni se inventan mediciones de campo.
