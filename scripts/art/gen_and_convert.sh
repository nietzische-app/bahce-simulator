#!/usr/bin/env bash
# Art pipeline wrapper (bot-free next time):
#   ./scripts/art/gen_and_convert.sh --icons-only
#   ./scripts/art/gen_and_convert.sh --world-props
#   ./scripts/art/gen_and_convert.sh --name Pet_Bunny --also-obj
#   ./scripts/art/gen_and_convert.sh --skip-image-gen --skip-trellis --name X --input-glb path.glb
# Needs: blender, python3 (+ Pillow for icons); HF_TOKEN for Z-Image/TRELLIS when quota allows
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export BLENDER="${BLENDER:-/usr/local/bin/blender}"
cd "$ROOT"
if [[ -x /tmp/artvenv/bin/python ]]; then
  PY=/tmp/artvenv/bin/python
elif [[ -x "$ROOT/../tools/.venv/bin/python" ]]; then
  PY="$ROOT/../tools/.venv/bin/python"
else
  PY=python3
fi
exec "$PY" "$ROOT/scripts/art/gen_and_convert.py" "$@"
