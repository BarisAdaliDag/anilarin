"""Şablonlara dikey (A4) format çerçevelerini ekler: assets/catalog/templates.json içindeki her şablonun
`square` çerçevelerinden `portrait` üretir.

Kural (Popsa'nın yatay çerçeveleri kareden aynı şekilde türemiş): dikey eksende boş aralıklar
(kenar boşlukları, fotoğraf arası) gerçek kalınlıkları aynı kalsın diye sayfa oranıyla çarpılır; elemanla
dolu aralıklar kalan yüksekliği orantılı paylaşır. Yatay eksen değişmez. Kapak şablonları aynen kopyalanır.

Kullanım: python3 -I tool/make_portrait_shapes.py [--check]
  --check: aynı kuralla kareden yatayı üretip mevcut yatay çerçevelerle karşılaştırır, dosyaya yazmaz.
"""
import json
import sys
from pathlib import Path

PORTRAIT_ASPECT = 21 / 29.7
LANDSCAPE_ASPECT = 1.3065
PATH = Path(__file__).resolve().parent.parent / 'assets' / 'catalog' / 'templates.json'


def derive(elements, aspect):
    frames = [e['frame'] for e in elements]
    edges = sorted({0.0, 100.0} | {float(f[1]) for f in frames} | {float(f[1] + f[3]) for f in frames})
    edges = [e for e in edges if 0 <= e <= 100]
    spans = list(zip(edges, edges[1:]))
    covered = [any(f[1] <= a + 1e-6 and f[1] + f[3] >= b - 1e-6 for f in frames) for a, b in spans]
    empty = sum(b - a for (a, b), c in zip(spans, covered) if not c)
    full = sum(b - a for (a, b), c in zip(spans, covered) if c)
    if full <= 0 or 100 - empty * aspect <= 0:
        return [dict(e) for e in elements]
    k = (100 - empty * aspect) / full
    mapped, pos = {edges[0]: 0.0}, 0.0
    for (a, b), c in zip(spans, covered):
        pos += (b - a) * (k if c else aspect)
        mapped[b] = pos

    def m(y):
        y = float(y)
        if y in mapped:
            return mapped[y]
        return y * aspect if y < 0 else 100 + (y - 100) * aspect  # sayfa dışına taşan kenar

    out = []
    for e in elements:
        x, y, w, h = e['frame']
        top, bottom = m(y), m(y + h)
        out.append({**e, 'frame': [x, round(top, 2), w, round(bottom - top, 2)]})
    return out


def floating(elements, aspect):
    """Kenarlara dayanmayan (ortada duran) düzenler: elemanlar gerçek boyutlarını korur, dikeyde ortalanır."""
    out = []
    for e in elements:
        x, y, w, h = e['frame']
        out.append({**e, 'frame': [x, round(50 + (y - 50) * aspect, 2), w, round(h * aspect, 2)]})
    return out


def shapes_for(t, aspect):
    square = t['shapes']['square']
    if t['tag'] == 'layout-front':
        return [dict(e) for e in square]
    top = min(e['frame'][1] for e in square)
    bottom = max(e['frame'][1] + e['frame'][3] for e in square)
    # Izgara: elemanlar üst ve alt kenar boşluğuna dayanır. Değilse düzen sayfanın ortasında durur.
    if top <= 8 and bottom >= 92:
        return derive(square, aspect)
    return floating(square, aspect)


CEWE_ASPECT = 205 / 270  # CEWE dikey kitap düzenlerinin sayfa oranı
MIN_SLOT_ASPECT = 0.35  # dikeyde bundan ince fotoğraf alanı olan şablon gizlenir (CEWE'nin en incesi)

# Kullanıcının ayıkladığı, dikeyde gösterilmeyen şablonlar (okul yıllığı: yazılılar ve CEWE düzenleri kalır).
PORTRAIT_REMOVED = {
    53, 54, 55, 56, 57, 58,  # üst üste binen
    6, 10, 15, 21, 29,  # CEWE karşılığı var (76, 77, 78, 85, 88)
    59, 60, 61, 62, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74,  # yazısız küçük (minimal)
    11, 12, 13, 14, 17, 24, 26, 27, 28,  # dar sütunlu kolajlar
}


def _grid(xs, w, ys, h):
    return [[x, y, w, h] for y in ys for x in xs]


# CEWE'nin dikey kitap düzenlerinden en yaygınları (editördeki SVG önizlemelerinden, sayfa yüzdesi [x, y, w, h]).
# (id, kategoriler, fotoğraf çerçeveleri, yazı çerçevesi)
CEWE = [
    (75, ['p2'], [[5.4, 4.1, 89.3, 28.7], [5.4, 35.7, 89.3, 60.3]], None),
    (76, ['p2'], [[5.4, 4.1, 89.3, 44.4], [5.4, 51.5, 89.3, 44.4]], None),
    (77, ['p3'], [[5.4, 4.1, 89.3, 44.4], [5.3, 51.5, 42.7, 44.4], [51.9, 51.5, 42.7, 44.4]], None),
    (78, ['p3'], _grid([5.4], 89.3, [4.1, 35.7, 67.3], 28.7), None),
    (79, ['p3'], [[5.3, 4.1, 42.7, 91.9], [51.9, 4.1, 42.7, 28.7], [51.9, 35.7, 42.7, 60.3]], None),
    (80, ['collage', 'p4'], [[5.4, 4.1, 89.3, 67.8]] + _grid([5.4, 36.4, 67.4], 27.2, [75.3], 20.7), None),
    (81, ['collage', 'p4'],
     [[5.4, 4.1, 89.3, 28.7], [5.4, 35.7, 58.2, 60.3], [67.4, 35.7, 27.2, 28.7], [67.4, 67.3, 27.2, 28.7]], None),
    (82, ['collage', 'p4'],
     [[5.4, 4.1, 89.3, 28.7], [5.3, 35.7, 42.7, 28.7], [51.9, 35.7, 42.7, 28.7], [5.4, 67.3, 89.3, 28.7]], None),
    (83, ['collage', 'p5'], [[5.4, 4.1, 56.6, 91.9]] + _grid([65.7], 29.6, [4.1, 27.8, 51.5, 75.2], 20.7), None),
    (84, ['collage', 'p5'],
     [[5.3, 4.1, 42.7, 28.7], [51.9, 4.1, 42.7, 28.7], [5.4, 35.7, 58.2, 60.3], [67.4, 35.7, 27.2, 28.7],
      [67.4, 67.3, 27.2, 28.7]], None),
    (85, ['collage'], _grid([5.4, 52], 42.8, [4.1, 35.7, 67.3], 28.7), None),
    (86, ['collage'], [[5.4, 4.1, 89.3, 28.7]] + _grid([5.4, 36.4, 67.4], 27.2, [35.7, 67.3], 28.7), None),
    (87, ['collage'], _grid([5.3, 51.9], 42.7, [4.1, 27.8, 51.5, 75.2], 20.7), None),
    (88, ['collage'], _grid([5.4, 36.4, 67.4], 27.2, [4.1, 35.7, 67.3], 28.7), None),
    # Yazılı: büyük fotoğraf + altta tam genişlikte yazı; yan yana iki fotoğraf + altta yazı.
    (89, ['text', 'p1'], [[5.4, 4.1, 89.3, 66]], [5.4, 74, 89.3, 21.9]),
    (90, ['text', 'p2'], [[5.3, 4.1, 42.7, 60], [51.9, 4.1, 42.7, 60]], [5.4, 68, 89.3, 27.9]),
]


def cewe_templates():
    out = []
    for tid, cats, photos, text in CEWE:
        elements = [{'type': 'photo', 'frame': f} for f in photos]
        if text:
            elements.append({'type': 'text', 'role': 'caption', 'frame': text, 'align': 'left'})
        out.append({
            'id': tid,
            'tag': 'layout-regular',
            'photoCount': len(photos),
            'automaticUse': text is None,
            'categories': cats if text or any(c.startswith('p') for c in cats) else cats + [f'p{len(photos)}'],
            'shapes': {'portrait': derive(elements, PORTRAIT_ASPECT / CEWE_ASPECT)},
        })
    return out


def too_tall(shape):
    """Dikey sayfada gerçek oranı [MIN_SLOT_ASPECT]'tan ince fotoğraf alanı var mı."""
    return any(e['frame'][2] * PORTRAIT_ASPECT / e['frame'][3] < MIN_SLOT_ASPECT
               for e in shape if e['type'] == 'photo' and e['frame'][3] > 0)


def main():
    data = json.loads(PATH.read_text())
    if '--check' in sys.argv:
        worst = 0.0
        for t in data['templates']:
            if 'square' not in t['shapes']:
                continue  # yalnız dikey (CEWE) şablonları
            got = shapes_for(t, LANDSCAPE_ASPECT)
            for a, b in zip(got, t['shapes']['landscape']):
                d = max(abs(p - q) for p, q in zip(a['frame'], b['frame']))
                worst = max(worst, d)
                if d > 3:
                    print(f"şablon {t['id']}: {a['frame']} ≠ {b['frame']}")
        print(f'en büyük sapma: {worst:.2f} puan')
        return
    ids = {tid for tid, *_ in CEWE}
    data['templates'] = [t for t in data['templates'] if t['id'] not in ids]
    hidden = []
    for t in data['templates']:
        t['shapes']['portrait'] = shapes_for(t, PORTRAIT_ASPECT)
        t.pop('hiddenIn', None)
        # Şablon seçicide 6–9 fotoğraf ayrı sekmeler: eski "5+" etiketi gerçek sayıya çevrilir.
        if t['photoCount'] > 5:
            t['categories'] = [f"p{t['photoCount']}" if c == 'p5' else c for c in t['categories']]
        if t['id'] in PORTRAIT_REMOVED or (t['tag'] != 'layout-front' and too_tall(t['shapes']['portrait'])):
            t['hiddenIn'] = ['portrait']
            hidden.append(t['id'])
    data['templates'] += cewe_templates()
    PATH.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
    print(f"portrait şekilleri yazıldı; dikeyde gizli: {hidden}; CEWE: {sorted(ids)}")


if __name__ == '__main__':
    main()
