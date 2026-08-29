# -*- coding: utf-8 -*-
"""
Bloky mřížky (zatím jen šikmina) — kompletní sestavení a export.

    blender --background --factory-startup --python blender/level_blocks/build_level_blocks.py -- --export

Zapisuje:
    game/assets/level_blocks/ramp.glb

Konvence exportu (`docs/import-assets.md` §2.2, §2.5) jsou shodné s roboty
a zařízeními: 1 buňka = 1 unit, origin ve středu buňky, čelo po
`godot_forward` k `Direction.NORTH` — `WorldView` na to natočí instanci podle
`world.orientation_at(cell)`, stejně jako roboty podle `robot.facing`.
"""

import bpy
import os
import sys
import types
import importlib


def _ncr_import(module_name):
    roots = []
    try:
        roots.append(os.path.dirname(os.path.abspath(__file__)))
    except NameError:
        pass
    for text in bpy.data.texts:
        if text.filepath:
            roots.append(os.path.dirname(bpy.path.abspath(text.filepath)))
    folders = []
    for root in roots:
        folders += [root, os.path.join(os.path.dirname(root), "common")]
    folder = next((d for d in folders
                   if os.path.isfile(os.path.join(d, module_name + ".py"))), None)
    if folder:
        if folder not in sys.path:
            sys.path.insert(0, folder)
        return importlib.reload(importlib.import_module(module_name))
    text = bpy.data.texts.get(module_name + ".py")
    if text is None:
        raise RuntimeError(
            "Nenašel jsem %s.py — otevři přes Text > Open skripty ze složky "
            "blender/level_blocks i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc

ramp = _ncr_import("part_01_ramp")

EXPORT_GLB = False   # True = zapsat game/assets/level_blocks/*.glb


def obj(name):
    return bpy.data.objects.get(name)


def _parent_many(parent_name, child_names):
    parent = obj(parent_name)
    if parent is None:
        return
    bpy.context.view_layer.update()
    for name in child_names:
        child = obj(name)
        if child is not None and child is not parent:
            nc.parent_to(child, parent)


def build():
    nc.prepare()
    blocks_coll = nc.collection("LEVEL_BLOCKS")

    ramp_parts = ramp.build(blocks_coll)
    nc.purge(("RAMP_Root",))
    ramp_root = bpy.data.objects.new("RAMP_Root", None)
    ramp_root.empty_display_type = 'PLAIN_AXES'
    ramp_root.empty_display_size = 0.5
    nc.place(ramp_root, blocks_coll)
    _parent_many("RAMP_Root", [o.name for o in ramp_parts])

    report("Šikmina", [ramp_root] + ramp_parts)

    if EXPORT_GLB:
        export_glb("RAMP_", "ramp.glb", "RAMP_Root")

    return ramp_root, ramp_parts


# ---------------------------------------------------------------------------
# Kontroly — obálka buňky, stejný vzor jako `build_<robot>.py:report()`
# ---------------------------------------------------------------------------

def report(label, parts):
    hidden = [o for o in parts if o.hide_viewport]
    for o in hidden:
        o.hide_viewport = False
    bpy.context.view_layer.update()

    half = nc.CELL * 0.5
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    offenders = []
    tris = 0

    for o in parts:
        if o.type != 'MESH':
            continue
        tris += sum(max(0, len(poly.vertices) - 2) for poly in o.data.polygons)
        matrix = o.matrix_world
        for vert in o.data.vertices:
            world = matrix @ vert.co
            for i in range(3):
                lo[i] = min(lo[i], world[i])
                hi[i] = max(hi[i], world[i])
                if world[i] < -half - 1e-4 or world[i] > half + 1e-4:
                    offenders.append(o.name)

    print("\n[NCR] ---- %s: hotovo ----" % label)
    print("[NCR] objektů: %d, trojúhelníků: %d" % (len(parts), tris))
    print("[NCR] obálka X %.3f..%.3f   Y %.3f..%.3f   Z %.3f..%.3f  (buňka je -0.5..0.5)"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    if offenders:
        print("[NCR] POZOR: mimo buňku přesahuje %d dílů: %s"
              % (len(offenders), ", ".join(sorted(set(offenders))[:8])))
    else:
        print("[NCR] model se vejde do jedné buňky mřížky.")

    for o in hidden:
        o.hide_viewport = True


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_glb(prefix, filename, root_name):
    """Zapíše glTF podle konvence z docs/import-assets.md §2.2."""
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(os.path.dirname(here))   # .../NCR/blender/level_blocks -> .../NCR
    out_dir = os.path.join(repo, "game", "assets", "level_blocks")
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    path = os.path.join(out_dir, filename)

    targets = [o for o in bpy.data.objects if o.name.startswith(prefix)]
    nc.prepare()
    for o in bpy.data.objects:
        o.select_set(False)
    for o in targets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = targets[0] if targets else None

    with nc.godot_forward(root_name):
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                                  use_selection=True, export_yup=True,
                                  export_apply=True)
    print("[NCR] export: %s" % path)
    return path


if __name__ == "__main__":
    _argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--export" in _argv:
        EXPORT_GLB = True
    build()
