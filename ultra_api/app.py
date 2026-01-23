from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from ultralytics import YOLO
from typing import Optional, Dict
import os
import time

import cv2
import numpy as np

app = FastAPI()
_models: Dict[str, YOLO] = {}


class PredictReq(BaseModel):
    image_path: str
    model: Optional[str] = "yolov11n.pt"   # yolov8/11, detect/seg/pose/class are fine
    conf: Optional[float] = 0.25
    iou: Optional[float] = 0.7
    imgsz: Optional[int] = 640
    device: Optional[str] = None          # "0" for GPU 0; None for CPU

    # Rotazione in step da 90° clockwise:
    # 0 = 0°, 1 = 90° CW, 2 = 180°, 3 = 270° CW (equivale a 90° CCW)
    rotate_quadrants: Optional[int] = 0


def resolve_model_path(val: str) -> str:
    if os.path.isabs(val):
        return val
    cand = os.path.join("/models", val)
    return cand if os.path.exists(cand) else val


def get_model(val: str) -> YOLO:
    path = resolve_model_path(val)
    if not os.path.exists(path):
        raise HTTPException(404, detail=f"Model not found in container: {path}")
    if path not in _models:
        _models[path] = YOLO(path)
    return _models[path]


def rotate_90n(img: np.ndarray, q: int) -> np.ndarray:
    q = int(q) % 4
    if q == 0:
        return img
    if q == 1:
        return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    if q == 2:
        return cv2.rotate(img, cv2.ROTATE_180)
    return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)  # q == 3


@app.post("/predict")
def predict(req: PredictReq):
    if not os.path.exists(req.image_path):
        raise HTTPException(status_code=400, detail=f"image not found: {req.image_path}")

    # Leggi l'immagine una volta e ruota in RAM (non riscrive file su disco)
    img = cv2.imread(req.image_path, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail=f"failed to read image: {req.image_path}")

    q = int(req.rotate_quadrants or 0) % 4
    if q:
        img = rotate_90n(img, q)

    m = get_model(req.model)
    t0 = time.time()
    results = m.predict(
        source=img,   # numpy array già ruotato
        conf=req.conf,
        iou=req.iou,
        imgsz=req.imgsz,
        device=req.device
    )
    dt = time.time() - t0

    res = results[0]

    return {
        "model": req.model,
        "image_path": req.image_path,
        "rotate_quadrants": q,

        # Quando source è un array, res.path può essere vuoto a seconda della versione
        "path": getattr(res, "path", req.image_path),

        "names": res.names,
        "speed": res.speed,          # per-stage ms: preprocess/inference/NMS
        "time_sec": dt,              # wall time

        "boxes_xyxy": res.boxes.xyxy.tolist() if res.boxes is not None else [],
        "boxes_conf": res.boxes.conf.tolist() if res.boxes is not None else [],
        "boxes_cls":  res.boxes.cls.tolist()  if res.boxes is not None else [],

        "masks": (res.masks.data.cpu().numpy().tolist()
                  if getattr(res, "masks", None) is not None else None),

        "keypoints": (res.keypoints.data.cpu().numpy().tolist()
                      if getattr(res, "keypoints", None) is not None else None),

        "probs": (res.probs.data.tolist()
                  if getattr(res, "probs", None) is not None else None),
    }
