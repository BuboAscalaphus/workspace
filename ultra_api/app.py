from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from ultralytics import YOLO
from typing import Optional
import os, time

app = FastAPI()
_models = {}

class PredictReq(BaseModel):
    image_path: str
    model: Optional[str] = "yolov11n.pt"   # yolov8/11, detect/seg/pose/class are fine
    conf: Optional[float] = 0.25
    iou: Optional[float] = 0.7
    imgsz: Optional[int] = 640
    device: Optional[str] = None          # "0" for GPU 0; None for CPU

def get_model(name: str):
    if name not in _models:
        _models[name] = YOLO(name)
    return _models[name]

@app.post("/predict")
def predict(req: PredictReq):
    if not os.path.exists(req.image_path):
        raise HTTPException(status_code=400, detail=f"image not found: {req.image_path}")
    m = get_model(req.model)
    t0 = time.time()
    results = m.predict(
        source=req.image_path,
        conf=req.conf,
        iou=req.iou,
        imgsz=req.imgsz,
        device=req.device
    )
    dt = time.time() - t0
    res = results[0]
    return {
        "model": req.model,
        "path": res.path,
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
