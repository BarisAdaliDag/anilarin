"""Popsa sahne arka planlarından (elle tutulan beyaz kitap) kapak yerleştirme katmanları üretir.

Her BACKGROUND_PBKn (kitap) ve BACKGROUND_PTSn (baskı) için:
  <kod>_OVERLAY.png : kitap/kâğıt yüzeyi saydam (hafif gölgeli), eller ve masa opak. Kapağın üstüne çizilir.
  rects.json        : kitabın sahnedeki dikdörtgeni (0..1 oranları).
Kullanım: python tool/make_scene_overlays.py <topdownscene klasörü> <çıktı klasörü>
"""
import json
import sys
from pathlib import Path

from collections import deque

import numpy as np
from PIL import Image, ImageFilter


def largest_component(mask):
    """Maskenin en büyük 4-komşulu bağlı parçası (el); masadaki küçük renkli lekeler atılır."""
    h, w = mask.shape
    label = np.zeros((h, w), np.int32)
    best, best_n, n = 0, 0, 0
    for sy, sx in zip(*np.nonzero(mask)):
        if label[sy, sx]:
            continue
        n += 1
        label[sy, sx] = n
        q, size = deque([(sy, sx)]), 0
        while q:
            y, x = q.popleft()
            size += 1
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not label[ny, nx]:
                    label[ny, nx] = n
                    q.append((ny, nx))
        if size > best_n:
            best, best_n = n, size
    return label == best if best else mask


def fill_holes(mask, max_hole=4000):
    """Dışarıdan erişilemeyen küçük boşlukları doldurur."""
    h, w = mask.shape
    holes = ~mask
    seen = np.zeros_like(mask)
    out = mask.copy()
    for sy, sx in zip(*np.nonzero(holes)):
        if seen[sy, sx]:
            continue
        comp, q, edge = [], deque([(sy, sx)]), False
        seen[sy, sx] = True
        while q:
            y, x = q.popleft()
            comp.append((y, x))
            if y in (0, h - 1) or x in (0, w - 1):
                edge = True
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and holes[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if not edge and len(comp) <= max_hole:
            ys, xs = zip(*comp)
            out[list(ys), list(xs)] = True
    return out


def thumb_on_card(rgb, card, hand_below):
    """Kartın üstüne uzanan parmak (başparmak): kartın alt şeridinde kâğıt olmayan (renkli ya da koyu)
    pikseller; elin kart altındaki sütunlarından başlayan bağlı bölge, içindeki boşluklar (tırnak, parlama)
    doldurulur. Yumuşak kenarlı maske (0..1) döner."""
    h, w = card.shape
    ys = np.nonzero(card.any(axis=1))[0]
    xs = np.nonzero(card.any(axis=0))[0]
    y0, y1, x0, x1 = ys[0], ys[-1], xs[0], xs[-1]
    lum = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    r, g = rgb[..., 0], rgb[..., 1]
    # Kâğıt beyaz ve renksiz; ten kırmızımsı (yaprak arası kahve gölgeler r - g ≈ 15).
    skin = card & (chroma >= 18) & (r - g >= 18)
    skin[: int(y1 - (y1 - y0) * 0.3)] = False
    # Elin karta girdiği sütunlar: kartın hemen altında el olan yerler.
    cols = hand_below[min(h - 1, y1 + 2): min(h, y1 + 10)].any(axis=0)
    cols = largest_component(cols[None, :])[0]  # başparmağın altındaki el; uzaktaki parmak uçları değil
    cols = np.convolve(cols.astype(float), np.ones(9), mode="same") > 0
    seen = np.zeros_like(skin)
    q = deque((y1, x) for x in range(x0, x1 + 1) if cols[x] and skin[y1, x])
    for y, x in q:
        seen[y, x] = True
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            # Yalnız elin girdiği sütunlarda: kart alt kenarı boyunca uzanan yaprak gölgesi başparmağa eklenmesin.
            if y0 <= ny <= y1 and x0 <= nx <= x1 and cols[nx] and skin[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    # Kapat (genişlet + daralt) ve küçük delikleri doldur: tırnak ve parlak uç da parmağın parçası.
    seen = largest_component(seen)  # başparmak; kenardaki yaprak gölgeleri ayrı küçük parçalar
    m = Image.fromarray((seen * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(7))
    closed = np.asarray(m) > 127
    sub_ = closed[y0 : y1 + 1, x0 : x1 + 1]
    filled = np.zeros_like(sub_)
    band = (y1 - y0) * 0.3
    for cx in range(sub_.shape[1]):
        col = np.nonzero(sub_[:, cx])[0]
        # Parmak alttan girer: ilk el pikselinin altı da eldir. Kısa sütunlar (kenardaki ince gölge) atılır.
        if len(col) and (sub_.shape[0] - col[0]) >= band * 0.25:
            filled[col[0] :, cx] = True
    out = np.zeros((h, w), bool)
    out[y0 : y1 + 1, x0 : x1 + 1] = filled
    soft = Image.fromarray((out * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    return np.asarray(soft).astype(np.float32) / 255.0

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
    if kind == "PTS":
        # Baskı destesi yerine düz masa: destenin çevresindeki kutu, aynı satırın kutu dışındaki
        # ahşap dokusuyla (damarlar yatay) yeniden çizilir; sahneden yalnız el korunur.
        bx0, bx1 = max(0, int(x0 - (x1 - x0) * 0.25)), min(w, int(x1 + (x1 - x0) * 0.25))
        by0, by1 = max(0, int(y0 - (y1 - y0) * 0.25)), min(h, int(y1 + (y1 - y0) * 0.1))
        bw = bx1 - bx0
        recon = rgb.copy()
        # Kutu iki yandan aynalanır (soldaki ve sağdaki masa) ve konuma göre harmanlanır; sahnenin
        # kenar kararması yumuşak olduğundan ek yeri görünmez.
        for x in range(bx0, bx1):
            t = (x - bx0) / max(1, bw - 1)
            lx = max(0, bx0 - 1 - (x - bx0) % max(1, bx0))
            rx = min(w - 1, bx1 + (bx1 - 1 - x) % max(1, w - bx1))
            recon[by0:by1, x] = (1 - t) * rgb[by0:by1, lx] + t * rgb[by0:by1, rx]
        diff = np.abs(rgb - recon).mean(axis=2)
        chroma = hi - lo
        # Ten masadan daha doygun (masa ~36-41); kenar yumuşasın diye bir piksel genişletilir.
        hand = (diff > 18) & (chroma >= 50)
        hand = hand | np.roll(hand, 1, 0) | np.roll(hand, -1, 0) | np.roll(hand, 1, 1) | np.roll(hand, -1, 1)
        hand[: int(y0 + (y1 - y0) * 0.6)] = False  # el destenin alt kısmından girer
        hand = largest_component(hand)
        # Elin parlak ve soluk yerleri (tırnak, parlama) delik kalmasın: kapat ve küçük delikleri doldur.
        hm = Image.fromarray((hand * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
        hand = fill_holes(np.asarray(hm) > 127)
        box = np.zeros((h, w), bool)
        box[by0:by1, bx0:bx1] = True
        color = np.where(box[..., None], recon, color)
        alpha = np.where(box, 1.0, alpha)
        card = inside > 0
        alpha = np.where(card, 0.0, alpha)
        color = np.where(hand[..., None], rgb, color)
        alpha = np.where(hand, 1.0, alpha)
        # Başparmak kartın üstünde: tırnak ve açık tenli uç dahil tek parça, yumuşak kenarlı ve opak; altında
        # kâğıda düşen hafif gölge. Düz alfa için kenarda da ten rengi kullanılır (siyah hale olmasın).
        thumb = thumb_on_card(rgb, card, hand)
        shadow = np.asarray(Image.fromarray((thumb * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)))
        shadow = np.roll(np.roll(shadow / 255.0, 3, 0), 2, 1) * 0.25
        alpha = np.where(card, np.maximum(alpha, shadow * (thumb < 0.5)), alpha)
        color = np.where((thumb > 0.02)[..., None], rgb, color)
        alpha = np.maximum(alpha, thumb)
    out = np.dstack([color, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    img = img.resize((640, round(640 * h / w)), Image.LANCZOS)  # kartlar küçük; dosya hafif kalsın
    img.save(dst / f"{kind}-{n}_OVERLAY.png", optimize=True)
    rects[f"{kind}-{n}"] = [round(x0 / w, 4), round(y0 / h, 4), round(x1 / w, 4), round(y1 / h, 4)]
(dst / "rects.json").write_text(json.dumps(rects, indent=1))
print(f"{len(rects)} sahne → {dst}")
