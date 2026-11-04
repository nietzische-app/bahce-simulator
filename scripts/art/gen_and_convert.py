#!/usr/bin/env python3
"""Reusable art pipeline for Minik bahçe models.

Flow (free tools only — no Fal/Higgsfield):
  1) Optional image gen via Hugging Face Gradio Spaces (Z-Image / Flux Schnell)
  2) Image → 3D via trellis-community/TRELLIS (needs ZeroGPU quota or HF_TOKEN)
  3) Blender cleanup → FBX (art/blender/cleanup_export.py)

Usage:
  export HF_TOKEN=hf_...   # recommended; raises ZeroGPU quota
  python scripts/art/gen_and_convert.py --from-manifest scripts/art/assets_manifest.json
  python scripts/art/gen_and_convert.py --name Pet_Bunny --skip-image-gen
  python scripts/art/gen_and_convert.py --name Decor_Bench --input-glb assets/models/raw/foo.glb
  python scripts/art/gen_and_convert.py --icons-only
  python scripts/art/gen_and_convert.py --world-props

Requires: gradio_client, huggingface_hub; blender at /usr/local/bin/blender
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF_DIR = ROOT / "assets" / "refs"
RAW_DIR = ROOT / "assets" / "models" / "raw"
OUT_DIR = ROOT / "assets" / "models"
CLEANUP = ROOT / "art" / "blender" / "cleanup_export.py"
BLENDER = os.environ.get("BLENDER", "/usr/local/bin/blender")
TRELLIS_SPACE = os.environ.get("TRELLIS_SPACE", "trellis-community/TRELLIS")
STYLE = (
    "Cute kid-friendly stylized low-poly 3D game asset, isolated on pure white background, "
    "centered, three-quarter view, soft flat studio lighting, colorful Roblox cartoon look, "
    "single object, no text, no watermark, no ground plane"
)


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def gen_image_z_image(prompt: str, out_png: Path) -> Path:
    """Best-effort: call Z-Image Space via gradio_client if available."""
    from gradio_client import Client

    full = f"{STYLE}: {prompt}"
    # mcp-tools/Z-Image-Turbo may change; allow override
    space = os.environ.get("ZIMAGE_SPACE", "mcp-tools/Z-Image-Turbo")
    token = os.environ.get("HF_TOKEN")
    client = Client(space, hf_token=token) if token else Client(space)
    # API surface varies; try common patterns
    result = None
    for api in ("/generate", "/predict", None):
        try:
            if api:
                result = client.predict(full, api_name=api)
            else:
                result = client.predict(full)
            break
        except Exception as e:
            last = e
            continue
    else:
        raise RuntimeError(f"Z-Image failed: {last}")
    # result often gallery path / tuple
    path = None
    if isinstance(result, (list, tuple)) and result:
        path = result[0]
        if isinstance(path, dict):
            path = path.get("path") or path.get("image")
        if isinstance(path, (list, tuple)) and path:
            path = path[0]
            if isinstance(path, dict):
                path = path.get("path")
    elif isinstance(result, dict):
        path = result.get("path")
    elif isinstance(result, str):
        path = result
    if not path or not Path(path).exists():
        raise RuntimeError(f"Z-Image returned no file: {result!r}")
    out_png.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, out_png)
    return out_png


def image_to_glb(image: Path, out_glb: Path) -> Path:
    from gradio_client import Client, handle_file

    token = os.environ.get("HF_TOKEN")
    client = Client(TRELLIS_SPACE, hf_token=token) if token else Client(TRELLIS_SPACE)
    try:
        client.predict(api_name="/start_session")
    except Exception:
        pass
    pre = client.predict(handle_file(str(image)), api_name="/preprocess_image")
    img_path = pre if isinstance(pre, str) else (pre.get("path") if isinstance(pre, dict) else str(image))
    video, gaussian, glb = client.predict(
        handle_file(img_path),
        [],
        0,
        7.5,
        12,
        3.0,
        12,
        "stochastic",
        0.95,
        1024,
        api_name="/generate_and_extract_glb",
    )
    glb_path = glb if isinstance(glb, str) else (glb.get("path") if isinstance(glb, dict) else None)
    if not glb_path or not Path(glb_path).exists():
        raise RuntimeError(f"TRELLIS returned no GLB: {glb!r}")
    out_glb.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(glb_path, out_glb)
    return out_glb


def blender_cleanup(inp: Path, out_fbx: Path, name: str, height: float, max_tris: int = 5000, also_obj: bool = False) -> None:
    cmd = [
        BLENDER,
        "--background",
        "--python",
        str(CLEANUP),
        "--",
        "--input",
        str(inp),
        "--output",
        str(out_fbx),
        "--name",
        name,
        "--max-tris",
        str(max_tris),
        "--target-height",
        str(height),
    ]
    if also_obj:
        cmd.append("--also-obj")
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, cwd=str(ROOT))



ICON_DIR = ROOT / "assets" / "icons"
WORLD_MANIFEST = [
    # (gltf_glob_or_path, name, height)
    ("assets/models/raw/_poly_WorldSapling/*.gltf", "WorldTree", 6.0),
    ("assets/models/raw/_poly_WorldRock/*.gltf", "WorldRock", 1.4),
    ("assets/models/raw/_poly_WorldRocks/*.gltf", "WorldRocks", 1.6),
    ("assets/models/raw/_poly_WorldFlowerA/*.gltf", "WorldFlowerA", 0.9),
    ("assets/models/raw/_poly_WorldFlowerB/*.gltf", "WorldFlowerB", 0.7),
    ("assets/models/raw/_poly_WorldFlowerC/*.gltf", "WorldFlowerC", 0.6),
    ("assets/models/raw/_poly_WorldFern/*.gltf", "WorldFern", 1.0),
    ("assets/models/raw/_poly_WorldLog/*.gltf", "WorldLog", 1.2),
]


def make_icons_from_refs(size: int = 256) -> list[dict]:
    """Cut white backgrounds from assets/refs into square transparent PNGs in assets/icons.
    Allowed post-process after AI refs (no procedural drawing).
    """
    from PIL import Image
    import numpy as np

    ICON_DIR.mkdir(parents=True, exist_ok=True)
    jobs = []
    for seed in ("SunBloom", "DewLeaf", "CloudBerry", "MoonPetal", "StarRoot"):
        jobs.append((REF_DIR / f"{seed}_mature.png", ICON_DIR / f"Seed_{seed}.png", size))
        jobs.append((REF_DIR / f"{seed}_seedling.png", ICON_DIR / f"Seedling_{seed}.png", 192))
    for name, ref in (
        ("GardenPlot", "GardenPlot.png"),
        ("SeedShop", "SeedShopStall.png"),
        ("SellStand", "SellStand.png"),
    ):
        jobs.append((REF_DIR / ref, ICON_DIR / f"World_{name}.png", size))
    for pet in ("Bunny", "Chick", "Frog", "Fox", "Owl", "Hedgehog", "Dragon"):
        jobs.append((REF_DIR / f"Pet_{pet}.png", ICON_DIR / f"Pet_{pet}.png", size))

    results = []
    for src, dst, sz in jobs:
        if not src.exists():
            results.append({"src": str(src), "dst": str(dst), "error": "missing ref"})
            continue
        im = Image.open(src).convert("RGBA")
        arr = np.asarray(im).copy()
        r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
        mask = (r >= 245) & (g >= 245) & (b >= 245)
        arr[:, :, 3] = np.where(mask, 0, a)
        im = Image.fromarray(arr, "RGBA")
        bbox = im.getbbox()
        if bbox:
            im = im.crop(bbox)
        w, h = im.size
        pad = int(max(w, h) * 0.06) + 4
        side = max(w, h) + pad * 2
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(im, ((side - w) // 2, (side - h) // 2), im)
        canvas = canvas.resize((sz, sz), Image.Resampling.LANCZOS)
        canvas.save(dst, optimize=True)
        results.append({"src": str(src), "dst": str(dst), "bytes": dst.stat().st_size})
    return results


def convert_world_props(max_tris: int = 5000) -> list[dict]:
    results = []
    for pattern, name, height in WORLD_MANIFEST:
        matches = sorted(ROOT.glob(pattern)) if "*" in pattern else [ROOT / pattern]
        if not matches:
            results.append({"name": name, "error": f"no match {pattern}"})
            continue
        gltf = matches[0]
        fbx = OUT_DIR / f"{name}.fbx"
        try:
            blender_cleanup(gltf, fbx, name, height, max_tris, also_obj=True)
            results.append({"name": name, "fbx": str(fbx), "obj": str(fbx.with_suffix(".obj"))})
        except Exception as e:
            results.append({"name": name, "error": str(e)})
    return results




def process_item(
    name: str,
    prompt: str,
    height: float,
    *,
    skip_image_gen: bool,
    skip_trellis: bool,
    input_glb: Path | None,
    max_tris: int,
    also_obj: bool = False,
) -> dict:
    ref = REF_DIR / f"{name}.png"
    raw = RAW_DIR / f"{name}.glb"
    fbx = OUT_DIR / f"{name}.fbx"
    status = {"name": name, "ref": None, "glb": None, "fbx": None, "error": None}
    try:
        if input_glb:
            raw = input_glb
        else:
            if not skip_image_gen and not ref.exists():
                print(f"[{name}] image gen…")
                gen_image_z_image(prompt, ref)
            if not ref.exists():
                raise FileNotFoundError(f"missing ref {ref} (generate or place PNG)")
            status["ref"] = str(ref)
            if not skip_trellis:
                print(f"[{name}] TRELLIS image→3D…")
                image_to_glb(ref, raw)
        if not raw.exists():
            raise FileNotFoundError(f"missing glb {raw}")
        status["glb"] = str(raw)
        print(f"[{name}] Blender cleanup → FBX…")
        blender_cleanup(raw, fbx, name, height, max_tris, also_obj=also_obj)
        status["fbx"] = str(fbx)
        if also_obj:
            status["obj"] = str(fbx.with_suffix(".obj"))
    except Exception as e:
        status["error"] = str(e)
        print(f"[{name}] FAIL: {e}", file=sys.stderr)
    return status


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-manifest", default=str(ROOT / "scripts/art/assets_manifest.json"))
    ap.add_argument("--name", action="append", default=[], help="Only these names (repeatable)")
    ap.add_argument("--skip-image-gen", action="store_true")
    ap.add_argument("--skip-trellis", action="store_true")
    ap.add_argument("--input-glb", default="", help="Existing GLB for single --name")
    ap.add_argument("--max-tris", type=int, default=5000)
    ap.add_argument("--contact-sheet", default="")
    ap.add_argument("--icons-only", action="store_true", help="Cut icons from assets/refs → assets/icons")
    ap.add_argument("--world-props", action="store_true", help="Convert Poly Haven world glTFs → FBX/OBJ")
    ap.add_argument("--also-obj", action="store_true", help="Also write OBJ next to FBX")
    args = ap.parse_args()

    if args.icons_only:
        results = make_icons_from_refs()
        print(json.dumps({"icons": results}, indent=2))
        bad = [r for r in results if r.get("error")]
        return 1 if bad and len(bad) == len(results) else 0

    if args.world_props:
        results = convert_world_props(args.max_tris)
        print(json.dumps({"world": results}, indent=2))
        bad = [r for r in results if r.get("error")]
        return 1 if bad and not any(r.get("fbx") for r in results) else 0

    man = load_manifest(Path(args.from_manifest))
    style = man.get("style") or STYLE
    global STYLE
    STYLE = style
    items = man["items"]
    if args.name:
        want = set(args.name)
        items = [i for i in items if i["name"] in want]

    results = []
    for it in items:
        inp = Path(args.input_glb) if (args.input_glb and len(items) == 1) else None
        results.append(
            process_item(
                it["name"],
                it["prompt"],
                float(it.get("height", 2.0)),
                skip_image_gen=args.skip_image_gen,
                skip_trellis=args.skip_trellis or bool(inp),
                input_glb=inp,
                max_tris=args.max_tris,
                also_obj=args.also_obj,
            )
        )

    if args.contact_sheet:
        fbx_ok = [Path(r["fbx"]) for r in results if r.get("fbx")]
        if not fbx_ok:
            fbx_ok = sorted(OUT_DIR.glob("Pet_*.fbx")) + sorted(OUT_DIR.glob("Decor_*.fbx"))
            spr = OUT_DIR / "Sprinkler.fbx"
            if spr.exists():
                fbx_ok.append(spr)
        if fbx_ok:
            cmd = [
                BLENDER,
                "--background",
                "--python",
                str(CLEANUP),
                "--",
                "--contact-sheet",
                args.contact_sheet,
                "--output-dir",
                str(OUT_DIR),
            ]
            for p in fbx_ok:
                cmd.extend(["--input", str(p)])
            # contact sheet uses inputs; also re-export skip by only contact
            # cleanup_export renders from --contact-sheet when inputs listed
            subprocess.check_call(
                [
                    BLENDER,
                    "--background",
                    "--python",
                    str(CLEANUP),
                    "--",
                    "--contact-sheet",
                    args.contact_sheet,
                    "--output-dir",
                    str(OUT_DIR),
                ]
                + sum([["--input", str(p)] for p in fbx_ok], []),
                cwd=str(ROOT),
            )

    ok = [r for r in results if r.get("fbx")]
    bad = [r for r in results if r.get("error")]
    print(json.dumps({"ok": len(ok), "failed": len(bad), "results": results}, indent=2))
    return 1 if bad and not ok else 0


if __name__ == "__main__":
    raise SystemExit(main())
