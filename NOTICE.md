# Atribuciones

Aplicación SinBachesAPP 2.0.0: Yurandir Loayza Rosas, 2026. Código de esta entrega distribuido bajo AGPL-3.0; véase LICENSE.

Motor aprendido de terceros: peterhdd/pothole-detection-yolov8, revisión da7747eea7abb4319a0f55961f31809a16c1b10a. Arquitectura YOLOv8s. No fue entrenado por el autor de esta aplicación. Fuente: https://huggingface.co/peterhdd/pothole-detection-yolov8

La tarjeta del repositorio declara Apache-2.0; los metadatos incrustados en ONNX declaran AGPL-3.0 de Ultralytics. Se conservan ambas declaraciones, sus textos y la procedencia. La aplicación no atribuye derechos exclusivos sobre los pesos. Esta discrepancia queda identificada para revisión antes de una distribución comercial.

Ejemplos y anotaciones: Ryukijano/Pothole-detection-Yolov8, revisión 7191ceeb92bbf46359794d7ba23a884043da96e1. La ficha declara licencia OpenRAIL; se conserva su ficha original. Las diez imágenes test se usan para evaluación exploratoria, sin afirmar representatividad local ni independencia respecto del entrenamiento del modelo.

ONNX Runtime, FastAPI, NumPy, Pillow y otras dependencias conservan sus propias licencias. La aplicación implementa el preprocesado y la supresión de cajas con operaciones NumPy y Pillow; no carga pickle ni ejecuta archivos PT de terceros.
