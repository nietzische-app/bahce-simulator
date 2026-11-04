#!/usr/bin/env python3
"""Blender cleanup / decimate / scale / material / export for bahce assets.

Run headless:
  blender --background --python art/blender/cleanup_export.py -- \
      --input assets/models/raw/SunBloom_mature.glb \
      --output assets/models/SunBloom_mature.fbx \
      --name SunBloom_mature --max-tris 5000 --target-height 2.0

Also accepts a directory of .glb/.obj and writes FBX (+ optional OBJ) next to
--output-dir. Contact sheet render optional via --contact-sheet.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path


def parse_args(argv: list[str]) -> argparse.Namespace:
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", action="append", default=[], help="GLB/OBJ/FBX path (repeatable)")
    ap.add_argument("--input-dir", default="", help="Directory of meshes")
    ap.add_argument("--output", default="", help="Single output FBX path")
    ap.add_argument("--output-dir", default="assets/models")
    ap.add_argument("--name", default="")
    ap.add_argument("--max-tris", type=int, default=5000)
    ap.add_argument("--target-height", type=float, default=2.0, help="Studs / meters height")
    ap.add_argument("--also-obj", action="store_true")
    ap.add_argument("--contact-sheet", default="", help="PNG path for flat-lit preview grid")
    ap.add_argument("--render-size", type=int, default=256)
    return ap.parse_args(argv)


def import_mesh(path: Path):
    import bpy

    before = set(bpy.data.objects)
    suffix = path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        raise RuntimeError(f"unsupported: {path}")
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


def join_meshes(objs):
    import bpy

    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def ground_and_scale(obj, target_height: float):
    import bpy
    from mathutils import Vector

    bpy.context.view_layer.update()
    bbox = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    height = max(zs) - min(zs)
    if height < 1e-6:
        height = 1.0
    scale = target_height / height
    obj.scale = (obj.scale[0] * scale, obj.scale[1] * scale, obj.scale[2] * scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.update()
    bbox = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    zs = [v.z for v in bbox]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    obj.location.x -= cx
    obj.location.y -= cy
    obj.location.z -= min(zs)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


def decimate(obj, max_tris: int):
    import bpy

    # Collapse can stall on dense scanned rocks; fall back to voxel remesh.
    for i in range(8):
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        if tris <= max_tris:
            return tris
        prev = tris
        mod = obj.modifiers.new(f"DecimateArtPass{i}", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.15, min(0.5, max_tris / max(tris, 1)))
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mesh.calc_loop_triangles()
        if len(mesh.loop_triangles) >= prev * 0.95:
            break
    mesh = obj.data
    mesh.calc_loop_triangles()
    if len(mesh.loop_triangles) <= max_tris:
        return len(mesh.loop_triangles)
    # Voxel remesh then collapse to budget
    bbox = obj.bound_box
    xs = [v[0] for v in bbox]
    ys = [v[1] for v in bbox]
    zs = [v[2] for v in bbox]
    extent = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), 0.5)
    voxel = max(0.02, extent / 28.0)
    rem = obj.modifiers.new("VoxelArtPass", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = voxel
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=rem.name)
    for i in range(8):
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        if tris <= max_tris:
            return tris
        mod = obj.modifiers.new(f"DecimateVoxel{i}", "DECIMATE")
        mod.ratio = max(0.15, min(0.5, max_tris / max(tris, 1)))
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def ensure_material(obj):
    import bpy

    if obj.data.materials:
        return
    mat = bpy.data.materials.new(name=f"{obj.name}_Mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.45, 0.75, 0.35, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55
    obj.data.materials.append(mat)


def export_fbx(obj, path: Path):
    import bpy

    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=str(path),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )


def export_obj(obj, path: Path):
    import bpy

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.wm.obj_export(filepath=str(path), export_selected_objects=True)


def clear_scene():
    import bpy

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(block):
            block.remove(b)


def process_one(path: Path, out_fbx: Path, name: str, max_tris: int, target_height: float, also_obj: bool):
    import bpy

    clear_scene()
    meshes = import_mesh(path)
    obj = join_meshes(meshes)
    if obj is None:
        raise RuntimeError(f"no mesh in {path}")
    obj.name = name or path.stem
    ground_and_scale(obj, target_height)
    tris = decimate(obj, max_tris)
    ensure_material(obj)
    export_fbx(obj, out_fbx)
    if also_obj:
        export_obj(obj, out_fbx.with_suffix(".obj"))
    print(f"OK {obj.name} tris={tris} -> {out_fbx}")
    return obj.name, tris


def render_contact_sheet(fbx_paths: list[Path], out_png: Path, size: int):
    import bpy
    from mathutils import Vector

    clear_scene()
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    # Flat friendly lighting
    world = bpy.data.worlds.new("FlatWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.92, 0.94, 0.96, 1)
    bg.inputs[1].default_value = 1.0

    light_data = bpy.data.lights.new(name="Key", type="AREA")
    light_data.energy = 80
    light_data.size = 5
    light = bpy.data.objects.new(name="Key", object_data=light_data)
    scene.collection.objects.link(light)
    light.location = (3, -3, 6)

    fill_data = bpy.data.lights.new(name="Fill", type="AREA")
    fill_data.energy = 40
    fill_data.size = 5
    fill = bpy.data.objects.new(name="Fill", object_data=fill_data)
    scene.collection.objects.link(fill)
    fill.location = (-4, 2, 4)

    n = len(fbx_paths)
    cols = max(1, math.ceil(math.sqrt(n)))
    rows = max(1, math.ceil(n / cols))
    spacing = 4.0
    cam_data = bpy.data.cameras.new("ContactCam")
    cam = bpy.data.objects.new("ContactCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    for i, path in enumerate(fbx_paths):
        meshes = import_mesh(path)
        obj = join_meshes(meshes)
        if not obj:
            continue
        ground_and_scale(obj, 2.0)
        r, c = divmod(i, cols)
        obj.location = (c * spacing, -r * spacing, 0)

    # Frame all
    bpy.ops.object.select_all(action="DESELECT")
    for o in scene.objects:
        if o.type == "MESH":
            o.select_set(True)
    bpy.ops.view3d.camera_to_view_selected() if False else None
    # Manual framing
    cam.location = ((cols - 1) * spacing / 2, -((rows - 1) * spacing / 2) - 8, 7)
    cam.rotation_euler = (math.radians(55), 0, math.radians(0))
    cam_data.lens = 35

    scene.render.resolution_x = size * cols
    scene.render.resolution_y = size * rows
    scene.render.filepath = str(out_png)
    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print("contact sheet", out_png)


def main():
    args = parse_args(sys.argv)
    inputs: list[Path] = [Path(p) for p in args.input]
    if args.input_dir:
        d = Path(args.input_dir)
        for ext in ("*.glb", "*.gltf", "*.obj", "*.fbx"):
            inputs.extend(sorted(d.glob(ext)))
    if not inputs and not args.contact_sheet:
        print("no inputs", file=sys.stderr)
        sys.exit(2)

    out_dir = Path(args.output_dir)
    results = []
    for path in inputs:
        name = args.name if (args.name and len(inputs) == 1) else path.stem
        out_fbx = Path(args.output) if (args.output and len(inputs) == 1) else out_dir / f"{name}.fbx"
        height = args.target_height
        low = name.lower()
        if "seedling" in low:
            height = min(height, 1.2)
        elif any(k in low for k in ("stall", "stand", "shop")):
            height = max(height, 3.5)
        elif "plot" in low or "garden" in low:
            height = max(height, 1.0)
            height = min(height, 1.5)
        name, tris = process_one(path, out_fbx, name, args.max_tris, height, args.also_obj)
        results.append((out_fbx, tris))

    if args.contact_sheet:
        fbx_list = [p for p, _ in results] if results else sorted(out_dir.glob("*.fbx"))
        if fbx_list:
            render_contact_sheet(fbx_list, Path(args.contact_sheet), args.render_size)
    print("DONE", results)


if __name__ == "__main__":
    main()
