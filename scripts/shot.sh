#!/bin/bash
# bor-figures-style 截图脚本
#
# 用法: ./shot.sh <html文件> <画布高度> [宽度=1200] [倍率=2]
#   ./shot.sh fig-loop.html 574
#
# HTML 里的 body 和 .canvas 高度要写成同一个值，且和这里的 <画布高度> 一致。
# 脚本会顺带量出内容底边，告诉你高度该调成多少。
#
# 依赖: 无（直接用无头 Chromium，不需要起本地服务器）

set -e
SRC="$1"
H="$2"
W="${3:-1200}"
SCALE="${4:-2}"

[ -z "$SRC" ] || [ -z "$H" ] && { echo "用法: ./shot.sh <html文件> <画布高度> [宽度] [倍率]"; exit 1; }

DIR="$(cd "$(dirname "$SRC")" && pwd)"
NAME="$(basename "$SRC" .html)"
OUT="$DIR/$NAME.png"

# 找 Chromium
CHR="${CHROME_PATH:-}"
if [ -z "$CHR" ]; then
  for c in "$LOCALAPPDATA/ms-playwright"/chromium-*/chrome-win64/chrome.exe \
           "$LOCALAPPDATA/ms-playwright"/chromium-*/chrome-win/chrome.exe \
           "/c/Program Files/Google/Chrome/Application/chrome.exe"; do
    [ -f "$c" ] && CHR="$c" && break
  done
fi
[ -z "$CHR" ] && { echo "找不到 Chromium，用 CHROME_PATH 环境变量指定"; exit 1; }

# file:// 路径
URL="file:///$(cd "$DIR" && pwd -W 2>/dev/null || pwd | sed 's|^/||')/$NAME.html"
WIN_OUT="$(cd "$DIR" && pwd -W 2>/dev/null || pwd | sed 's|^/||')\\$NAME.png"

"$CHR" --headless --disable-gpu --hide-scrollbars --no-sandbox \
  --force-device-scale-factor="$SCALE" --window-size="$W,$H" \
  --virtual-time-budget=5000 \
  --screenshot="$WIN_OUT" "$URL" 2>/dev/null

# 量内容底边，报告留白（没有 Pillow 就跳过，不影响出图）
has_pil() {
  if command -v "$1" >/dev/null 2>&1; then "$1" -c "import PIL" >/dev/null 2>&1
  elif [ -x "$1" ]; then "$1" -c "import PIL" >/dev/null 2>&1
  else return 1; fi
}
PY="${PYTHON:-}"
if [ -z "$PY" ]; then
  for p in python python3 /d/python/python /c/Python*/python; do
    if has_pil "$p"; then PY="$p"; break; fi
  done
fi
if [ -z "$PY" ]; then
  echo "$(basename "$OUT") 已生成（装了 Pillow 才能看到高度建议，可用 PYTHON 环境变量指定解释器）"
  exit 0
fi
"$PY" - "$OUT" "$H" <<'PYEOF'
import sys, os
from PIL import Image
p, want = sys.argv[1], int(sys.argv[2])
im = Image.open(p).convert('RGB'); w, h = im.size; px = im.load()
last = 0
for y in range(h - 1, -1, -1):
    if any(px[x, y][0] < 246 or px[x, y][1] < 246 or px[x, y][2] < 246
           for x in range(0, w, 3)):
        last = y; break
content = (last + 1) // 2
gap = want - content
flag = 'OK'
if gap < 24:  flag = '底部太挤/被裁 → 调高'
elif gap > 56: flag = '底部留白过多 → 调低'
print('%s: %dx%d  %.0f KB | 画布 %d / 内容底 %d / 余 %d  %s'
      % (os.path.basename(p), w, h, os.path.getsize(p)/1024, want, content, gap, flag))
print('   建议高度: %d' % (content + 38))
PYEOF
