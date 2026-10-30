"""Popsa sahne arka planlarından (elle tutulan beyaz kitap) kapak yerleştirme katmanları üretir.

Her BACKGROUND_PBKn (kitap) ve BACKGROUND_PTSn (baskı) için:
  <kod>_OVERLAY.png : kitap/kâğıt yüzeyi saydam (hafif gölgeli), eller ve masa opak. Kapağın üstüne çizilir.
  rects.json        : kitabın sahnedeki dikdörtgeni (0..1 oranları).
Kullanım: python tool/make_scene_overlays.py <topdownscene klasörü> <çıktı klasörü>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
rects = {}
for kind, n in [("PBK", n) for n in range(1, 13)] + [("PTS", n) for n in range(2, 9)]:
    f = src / f"BACKGROUND_{kind}{n}.webp"
    if not f.exists():
        continue
    rgb = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
    lo, hi = rgb.min(axis=2), rgb.max(axis=2)
    # Kitap yüzeyi: açık ve renksiz pikseller
    book = np.clip((lo - 185) / 30, 0, 1) * np.clip((40 - (hi - lo)) / 20, 0, 1)
    ys, xs = np.nonzero(book > 0.9)
    x0, x1 = np.percentile(xs, [0.5, 99.5])
    y0, y1 = np.percentile(ys, [0.5, 99.5])
    h, w = book.shape
    inside = np.zeros_like(book)
    inside[int(y0):int(y1) + 1, int(x0):int(x1) + 1] = 1
    b = book * inside
    lum = rgb.mean(axis=2)
    shade = np.clip(1 - lum / np.percentile(lum[b > 0.9], 98), 0, 0.6)
    alpha = (1 - b) + b * shade
    color = rgb * (1 - b)[..., None]  # kitap bölgesinde siyah (gölge)
    out = np.dstack([color, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    img = img.resize((640, round(640 * h / w)), Image.LANCZOS)  # kartlar küçük; dosya hafif kalsın
    img.save(dst / f"{kind}-{n}_OVERLAY.png", optimize=True)
    rects[f"{kind}-{n}"] = [round(x0 / w, 4), round(y0 / h, 4), round(x1 / w, 4), round(y1 / h, 4)]
(dst / "rects.json").write_text(json.dumps(rects, indent=1))
print(f"{len(rects)} sahne → {dst}")
