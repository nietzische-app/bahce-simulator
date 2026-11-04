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


def blender_cleanup(inp: Path, out_fbx: Path, name: str, height: float, max_tris: int = 5000) -> None:
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
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, cwd=str(ROOT))


def process_item(
    name: str,
    prompt: str,
    height: float,
    *,
    skip_image_gen: bool,
    skip_trellis: bool,
    input_glb: Path | None,
    max_tris: int,
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
        blender_cleanup(raw, fbx, name, height, max_tris)
        status["fbx"] = str(fbx)
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
    args = ap.parse_args()

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
