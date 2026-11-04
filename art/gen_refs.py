#!/usr/bin/env python3
"""Generate 2D reference images for bahce-simulator art pass.

Preferred free path: Hugging Face Space Z-Image Turbo via Gradio client
(mcp-tools/Z-Image-Turbo / gr1_z_image_turbo_generate). Falls back to
printing prompts if ZeroGPU quota is exhausted.

Usage:
  python art/gen_refs.py
  python art/gen_refs.py --only SunBloom_mature,GardenPlot
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "refs"
OUT.mkdir(parents=True, exist_ok=True)

STYLE = (
    "Cute kid-friendly stylized low-poly 3D game asset, isolated on pure white "
    "background, centered, soft flat studio lighting, colorful Roblox cartoon "
    "look, single object, no text, no watermark"
)

ASSETS = {
    "SunBloom_seedling": "tiny sunflower seedling sprout, short green stem, two leaves, yellow tip",
    "SunBloom_mature": "mature cheerful sunflower with big yellow petals and brown center, short green stem",
    "DewLeaf_seedling": "tiny green leafy dew seedling with two glossy leaves",
    "DewLeaf_mature": "mature lush green leafy plant with dew drop accents",
    "CloudBerry_seedling": "tiny cloud berry seedling with pale blue-white berry tips",
    "CloudBerry_mature": "mature cloud berry bush with fluffy pale blue-white berry clusters",
    "MoonPetal_seedling": "tiny moon petal seedling with soft purple crescent leaf tips",
    "MoonPetal_mature": "mature moon petal flower with lavender purple crescent petals",
    "StarRoot_seedling": "tiny star root seedling with pink star-shaped tip",
    "StarRoot_mature": "mature star root plant with bright pink magenta star flowers",
    "GardenPlot": "rectangular garden soil bed with wooden border and rich brown dirt",
    "SeedShopStall": "wooden seed shop market stall with striped awning and seed packets",
    "SellStand": "wooden farm sell stand booth with green striped awning and hanging sign board",
}


def prompt_for(name: str) -> str:
    return f"{STYLE}, {ASSETS[name]}"


def try_gradio(name: str) -> Path | None:
    try:
        from gradio_client import Client
    except ImportError:
        print("gradio_client not installed; pip install gradio_client", file=sys.stderr)
        return None
    prompt = prompt_for(name)
    # Official free turbo image space used by HF skills MCP
    spaces = [
        "mcp-tools/Z-Image-Turbo",
        "evalstate/flux1_schnell",
    ]
    for space in spaces:
        try:
            print(f"[{name}] trying {space} ...")
            client = Client(space)
            # Best-effort: spaces differ; try common infer signatures
            result = None
            for kwargs in (
                {"prompt": prompt, "random_seed": True, "steps": 8},
                {"prompt": prompt, "randomize_seed": True, "num_inference_steps": 4},
            ):
                try:
                    result = client.predict(**kwargs)
                    break
                except TypeError:
                    continue
                except Exception as e:
                    print(f"  predict failed: {e}")
                    break
            if result is None:
                continue
            # Result often (gallery, seed_str, seed_int) or a path
            path = None
            if isinstance(result, (list, tuple)):
                first = result[0]
                if isinstance(first, list) and first:
                    first = first[0]
                if isinstance(first, dict):
                    path = first.get("image") or first.get("path")
                else:
                    path = first
            elif isinstance(result, str):
                path = result
            if not path:
                continue
            dest = OUT / f"{name}.png"
            data = Path(path).read_bytes()
            dest.write_bytes(data)
            print(f"  wrote {dest}")
            return dest
        except Exception as e:
            print(f"  {space} error: {e}")
            time.sleep(1)
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="Comma-separated asset names")
    ap.add_argument("--prompts-only", action="store_true")
    args = ap.parse_args()
    names = list(ASSETS)
    if args.only:
        names = [n.strip() for n in args.only.split(",") if n.strip()]
        unknown = [n for n in names if n not in ASSETS]
        if unknown:
            print("unknown:", unknown, file=sys.stderr)
            return 2
    manifest = {}
    for name in names:
        p = prompt_for(name)
        manifest[name] = {"prompt": p}
        print("=" * 60)
        print(name)
        print(p)
        if args.prompts_only:
            continue
        out = try_gradio(name)
        manifest[name]["file"] = str(out) if out else None
        time.sleep(0.5)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print("done →", OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
