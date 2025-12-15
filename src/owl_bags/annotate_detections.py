#!/usr/bin/env python3
# annotate_detections.py

# example: python3 annotate_detections.py ./processed/2025-12-12/results.jsonl --out ./tmp/

import os
import json
import argparse
from typing import Any, Dict, List, Tuple, Optional

import cv2


def safe_int(x, default=0) -> int:
    try:
        return int(x)
    except Exception:
        return default


def safe_float(x, default=0.0) -> float:
    try:
        return float(x)
    except Exception:
        return default


def load_jsonl(path: str):
    """Yields (lineno, obj) for each valid JSON line."""
    with open(path, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                yield i, json.loads(line)
            except json.JSONDecodeError as e:
                print(f"[WARN] Line {i}: JSON decode error ({e}). Skipping.")
                continue


def ensure_dir(p: str) -> None:
    os.makedirs(p, exist_ok=True)


def build_label_map(names: Any) -> Dict[int, str]:
    """
    Ultralytics spesso mette 'names' come dict con chiavi stringa: {"0":"trunk"}.
    Normalizziamo a {0: "trunk"}.
    """
    out: Dict[int, str] = {}
    if isinstance(names, dict):
        for k, v in names.items():
            out[safe_int(k, -1)] = str(v)
    elif isinstance(names, list):
        for idx, v in enumerate(names):
            out[idx] = str(v)
    return out


def clamp_xyxy(x1, y1, x2, y2, w, h) -> Tuple[int, int, int, int]:
    x1 = max(0, min(int(round(x1)), w - 1))
    y1 = max(0, min(int(round(y1)), h - 1))
    x2 = max(0, min(int(round(x2)), w - 1))
    y2 = max(0, min(int(round(y2)), h - 1))
    if x2 < x1:
        x1, x2 = x2, x1
    if y2 < y1:
        y1, y2 = y2, y1
    return x1, y1, x2, y2


def annotate_image(
    img_bgr,
    boxes_xyxy: List[List[float]],
    boxes_conf: Optional[List[float]],
    boxes_cls: Optional[List[float]],
    label_map: Dict[int, str],
    draw_conf: bool = True,
):
    h, w = img_bgr.shape[:2]
    confs = boxes_conf or []
    clss = boxes_cls or []

    for idx, box in enumerate(boxes_xyxy):
        if not (isinstance(box, (list, tuple)) and len(box) == 4):
            continue

        x1, y1, x2, y2 = box
        x1, y1, x2, y2 = clamp_xyxy(x1, y1, x2, y2, w, h)

        # testo etichetta
        cls_id = safe_int(clss[idx], -1) if idx < len(clss) else -1
        conf = safe_float(confs[idx], 0.0) if idx < len(confs) else None

        name = label_map.get(cls_id, str(cls_id) if cls_id >= 0 else "obj")
        if draw_conf and conf is not None:
            text = f"{name} {conf:.2f}"
        else:
            text = name

        # box
        cv2.rectangle(img_bgr, (x1, y1), (x2, y2), (0, 255, 0), 2)

        # label con background
        (tw, th), baseline = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        ty1 = max(0, y1 - th - baseline - 6)
        cv2.rectangle(img_bgr, (x1, ty1), (x1 + tw + 8, ty1 + th + baseline + 6), (0, 255, 0), -1)
        cv2.putText(
            img_bgr,
            text,
            (x1 + 4, ty1 + th + 2),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 0, 0),
            2,
            cv2.LINE_AA,
        )

    return img_bgr


def make_out_path(out_dir: str, image_path: str, keep_tree: bool, root_prefix: Optional[str]) -> str:
    """
    - keep_tree=False: salva tutto in out_dir con lo stesso basename.
    - keep_tree=True: replica la struttura a partire da root_prefix (se fornito) o da '/'.
    """
    image_path = os.path.abspath(image_path)

    if not keep_tree:
        return os.path.join(out_dir, os.path.basename(image_path))

    base = os.path.abspath(root_prefix) if root_prefix else os.path.sep
    rel = os.path.relpath(image_path, start=base)
    return os.path.join(out_dir, rel)


def main():
    ap = argparse.ArgumentParser(description="Annotate images using detections stored in JSONL.")
    ap.add_argument("jsonl", help="Path to JSONL file (one JSON per line).")
    ap.add_argument("--out", required=True, help="Output directory for annotated images.")
    ap.add_argument("--skip-missing", action="store_true", help="Skip entries whose image_path does not exist.")
    ap.add_argument("--skip-empty", action="store_true", help="Skip entries with no boxes.")
    ap.add_argument("--keep-tree", action="store_true", help="Keep directory tree structure inside --out.")
    ap.add_argument("--root-prefix", default=None, help="Base path to strip when --keep-tree is used.")
    ap.add_argument("--ext", default=None, help="Force output extension (e.g. .jpg, .png). Default keeps original.")
    ap.add_argument("--no-conf", action="store_true", help="Do not draw confidence in label.")
    args = ap.parse_args()

    ensure_dir(args.out)

    total = 0
    saved = 0

    for lineno, obj in load_jsonl(args.jsonl):
        total += 1
        image_path = obj.get("image_path") or obj.get("data", {}).get("path")
        if not image_path:
            print(f"[WARN] Line {lineno}: no image_path. Skipping.")
            continue

        image_path = os.path.abspath(image_path)
        if not os.path.exists(image_path):
            msg = f"[WARN] Line {lineno}: missing file {image_path}"
            if args.skip_missing:
                print(msg + " (skipped)")
                continue
            else:
                print(msg + " (skipping anyway)")
                continue

        data = obj.get("data", {}) if isinstance(obj.get("data", {}), dict) else {}
        boxes_xyxy = data.get("boxes_xyxy") or []
        boxes_conf = data.get("boxes_conf") or []
        boxes_cls = data.get("boxes_cls") or []
        names = data.get("names") or {}
        label_map = build_label_map(names)

        if args.skip_empty and (not boxes_xyxy):
            continue

        img = cv2.imread(image_path, cv2.IMREAD_COLOR)
        if img is None:
            print(f"[WARN] Line {lineno}: cv2 could not read {image_path}. Skipping.")
            continue

        img = annotate_image(
            img,
            boxes_xyxy=boxes_xyxy,
            boxes_conf=boxes_conf,
            boxes_cls=boxes_cls,
            label_map=label_map,
            draw_conf=(not args.no_conf),
        )

        out_path = make_out_path(args.out, image_path, args.keep_tree, args.root_prefix)
        if args.ext:
            root, _ = os.path.splitext(out_path)
            out_path = root + args.ext

        ensure_dir(os.path.dirname(out_path))
        ok = cv2.imwrite(out_path, img)
        if not ok:
            print(f"[WARN] Line {lineno}: failed to write {out_path}")
            continue

        saved += 1

    print(f"Done. Processed lines: {total}, images saved: {saved}")


if __name__ == "__main__":
    main()

