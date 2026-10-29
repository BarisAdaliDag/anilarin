#!/usr/bin/env bash
# Referans uygulamadan (reference/ altında çözülmüş APK) test görsellerini assets/ref/ altına kopyalar.
# assets/ref/ gitignore'dadır; bu dosyalar repoya gitmez. Kendi görsellerinizi aynı adlarla koyarak değiştirebilirsiniz.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/reference"
DST="$ROOT/assets/ref"
[ -d "$SRC/decoded" ] || { echo "reference/decoded bulunamadı (önce apktool ile çözün)"; exit 1; }

mkdir -p "$DST"/{home,themes,mockups/topdown,mockups/scene}
RES="$SRC/decoded/res"; XX="$SRC/decoded-xxhdpi/res/drawable-xxhdpi"

cp "$RES/drawable-nodpi/hero_photobooks.jpg" "$DST/home/hero_photobooks.jpg"
cp "$XX/product_selection_pbk.webp" "$DST/home/product_photobook.webp"
cp "$XX/onboarding_product_shot_2026.webp" "$DST/home/onboarding.webp"
for m in connections journeys rewinds; do cp "$XX/memories_example_$m.webp" "$DST/home/memories_$m.webp"; done

for f in "$RES"/drawable-nodpi/theme_app_photobook_*_preview.webp; do
  n="$(basename "$f" | sed 's/theme_app_photobook_//;s/_preview.webp//')"
  cp "$f" "$DST/themes/$n.webp"
done

for t in HARDBACK HARDBACK_SQUARE SOFTCOVER SOFTCOVER_SQUARE PHOTOBOOKLET; do
  for part in MASK LIGHTING TINT; do
    f="$SRC/decoded/assets/topdown/RENDER_TOPDOWN_PHOTOBOOK_${t}_${part}.webp"
    [ -f "$f" ] && cp "$f" "$DST/mockups/topdown/${t}_${part}.webp"
  done
done
for i in $(seq 1 12); do
  f="$SRC/decoded/assets/topdownscene/BACKGROUND_PBK$i.webp"
  [ -f "$f" ] && cp "$f" "$DST/mockups/scene/PBK-$i.webp"
done

# Ekran kayıtlarından çıkarılan kareler/klipler (reference/screens/media) varsa
if [ -d "$SRC/screens/media" ]; then mkdir -p "$DST/media"; cp "$SRC"/screens/media/* "$DST/media/" 2>/dev/null || true; fi

echo "Kopyalandı: $(find "$DST" -type f ! -name .gitkeep | wc -l | tr -d ' ') dosya → $DST"
