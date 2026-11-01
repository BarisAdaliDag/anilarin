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


def main():
    data = json.loads(PATH.read_text())
    if '--check' in sys.argv:
        worst = 0.0
        for t in data['templates']:
            got = shapes_for(t, LANDSCAPE_ASPECT)
            for a, b in zip(got, t['shapes']['landscape']):
                d = max(abs(p - q) for p, q in zip(a['frame'], b['frame']))
                worst = max(worst, d)
                if d > 3:
                    print(f"şablon {t['id']}: {a['frame']} ≠ {b['frame']}")
        print(f'en büyük sapma: {worst:.2f} puan')
        return
    for t in data['templates']:
        t['shapes']['portrait'] = shapes_for(t, PORTRAIT_ASPECT)
    PATH.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
    print(f"{len(data['templates'])} şablona portrait eklendi")


if __name__ == '__main__':
    main()
