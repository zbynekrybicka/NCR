# -*- coding: utf-8 -*-
"""
Klíč, kanystr, service kit — kompletní sestavení a export.

    blender --background --factory-startup --python blender/items/build_items.py -- --export

Staví všechny tři v jednom běhu (stejný důvod jako `build_devices.py`: nesdílí
mezi sebou žádný stav jako roboti per-robot barvu/tint).

Zapisuje:
    game/assets/items/key.glb
    game/assets/items/canister.glb
    game/assets/items/service_kit.glb

Na rozdíl od robotů a zařízení předměty nemají "čelo" — vznáší se a otáčí se
kolem svislé osy pořád dokola (`ItemView` za běhu, docs/import-assets.md
§4.2), takže na tom, kterým směrem model při exportu kouká, nezáleží. Export
proto přeskakuje `nc.godot_forward()` (na rozdíl od `build_devices.py`).
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
            "blender/items i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc

key = _ncr_import("part_01_key")
canister = _ncr_import("part_02_canister")
kit = _ncr_import("part_03_service_kit")

EXPORT_GLB = False   # True = zapsat game/assets/items/*.glb


def build():
    nc.prepare()
    items_coll = nc.collection("ITEMS")

    key_root, key_parts = _split(key.build(items_coll))
    can_root, can_parts = _split(canister.build(items_coll))
    kit_root, kit_parts = _split(kit.build(items_coll))

    report("Klíč", [key_root] + key_parts)
    report("Kanystr", [can_root] + can_parts)
    report("Service kit", [kit_root] + kit_parts)

    if EXPORT_GLB:
        export_glb("KEY_", "key.glb")
        export_glb("CANISTER_", "canister.glb")
        export_glb("KIT_", "service_kit.glb")

    return (key_root, key_parts), (can_root, can_parts), (kit_root, kit_parts)


def _split(built):
    return built[0], built[1:]


# ---------------------------------------------------------------------------
# Kontroly — obálka buňky, stejný vzor jako `build_devices.py:report()`
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

def export_glb(prefix, filename):
    """Zapíše glTF podle konvence z docs/import-assets.md §2.2 — bez
    `godot_forward()`, viz hlavička modulu (předměty nemají čelo)."""
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(os.path.dirname(here))   # .../NCR/blender/items -> .../NCR
    out_dir = os.path.join(repo, "game", "assets", "items")
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
