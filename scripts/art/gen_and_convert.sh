#!/usr/bin/env bash
# Wrapper: image gen → TRELLIS → Blender FBX
# Needs: HF_TOKEN (recommended), blender, python3 with gradio_client
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
