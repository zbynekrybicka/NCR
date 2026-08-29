# -*- coding: utf-8 -*-
"""
Zařízení (elektrická skříň, řídicí jednotka) — sdílená knihovna.

Na rozdíl od `blender/krajina/common.py` (world-space scenérie) používá
stejný rámec jako roboti: `ncr_common.p(fwd, right, up)`, 1 buňka = 1 unit,
origin ve středu buňky, podlaha na `up = 0`, čelo zařízení k `-Y` (po
exportu `godot_forward` z toho udělá `Direction.NORTH` — viz
`docs/import-assets.md` §2.5). Zařízení ale nejsou roboti: žádné barvy podle
`ROBOT_COLORS`, žádný hangul nápis, žádné otěrové (wear) materiály — jen
plochá průmyslová paleta definovaná tady.
"""

import bpy
import bmesh
import os
import sys
import types
import importlib


def _ncr_import(module_name):
    """Načte modul ze složky `blender/devices` nebo ze sousední `blender/common`."""
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
            "blender/devices i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")   # p(), primitiva box/cyl/..., prepare/collection/place/purge/godot_forward

# ---------------------------------------------------------------------------
# Materiály — plochá průmyslová paleta (ne robotí tint/wear systém)
# ---------------------------------------------------------------------------

MATERIALS = {
    # skříň/pouzdro: tmavě šedý lakovaný plech
    "case":       dict(color=(0.048, 0.052, 0.058), metallic=0.35, rough=0.55),
    "case_edge":  dict(color=(0.022, 0.024, 0.026), metallic=0.40, rough=0.45),
    # dvířka o odstín světlejší, ať jsou v panelu rozeznatelná
    "door":       dict(color=(0.075, 0.078, 0.085), metallic=0.30, rough=0.48),
    "hinge":      dict(color=(0.140, 0.145, 0.150), metallic=0.85, rough=0.30),
    # výstražný žlutý blesk — mezinárodní symbol "pozor, elektřina"
    "warning":    dict(color=(0.620, 0.420, 0.010), metallic=0.0, rough=0.35),
    "warning_dark": dict(color=(0.010, 0.010, 0.010), metallic=0.0, rough=0.55),
    # kontrolka — Godot za běhu přepisuje emission/albedo podle stavu (DeviceView)
    "lamp_off":   dict(color=(0.05, 0.05, 0.05), metallic=0.1, rough=0.25),
    "lamp_lens":  dict(color=(0.7, 0.7, 0.7), metallic=0.0, rough=0.10, transmission=0.2),
    # poškození: začernalý, ohořelý kov + obnažená měď vodičů
    "scorched":   dict(color=(0.012, 0.010, 0.009), metallic=0.15, rough=0.85),
    "copper":     dict(color=(0.420, 0.170, 0.060), metallic=0.85, rough=0.35),
    # páka přepínače — kontrastní červená rukojeť, dobře čitelná z dálky
    "lever":      dict(color=(0.380, 0.020, 0.015), metallic=0.05, rough=0.30),
    "lever_base": dict(color=(0.140, 0.145, 0.150), metallic=0.70, rough=0.35),
}


def mat(key):
    name = "DEV_%s" % key
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing
    spec = MATERIALS[key]
    color = spec["color"]

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.5)

    transmission = spec.get("transmission", 0.0)
    if transmission > 0.0:
        for tname in ("Transmission Weight", "Transmission"):
            if tname in bsdf.inputs:
                bsdf.inputs[tname].default_value = transmission
        material.blend_method = 'BLEND'

    material.diffuse_color = (color[0], color[1], color[2], 1.0)
    return material


# ---------------------------------------------------------------------------
# Plochý vytlačený tvar (blesk na dvířkách, trhlina poškození) — 2D obrys v
# rovině dvířek (right, up), vytlačený o `thickness` směrem k -fwd (dovnitř),
# přední stěna leží přesně na `front`. Bez shrinkwrapu/textu — na rovné
# ploše dvířek stačí přímá extruze.
# ---------------------------------------------------------------------------

def flat_shape(name, points_ru, front, thickness, coll=None, material=None):
    """`points_ru` = seznam (right, up) bodů profilu (libovolný pořadí, ne
    nutně konvexní — jde o jeden uzavřený obrys, typicky blesk nebo trhlina)."""
    n = len(points_ru)
    assert n >= 3

    front_verts = [nc.p(front, r, u) for (r, u) in points_ru]
    back_verts = [nc.p(front - thickness, r, u) for (r, u) in points_ru]
    verts = [tuple(v) for v in front_verts] + [tuple(v) for v in back_verts]

    faces = [tuple(range(n))]                              # přední víčko
    faces.append(tuple(reversed(range(n, 2 * n))))          # zadní víčko
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))                  # bok

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    obj.name = name
    obj.data.name = name
    nc.place(obj, coll)
    if material is not None:
        nc.set_material(obj, material)
    return obj


def lightning_bolt_points(right=0.11, up_lo=0.30, up_hi=0.72):
    """Obrys bleskového symbolu (7 bodů, typický zigzag) v rámci `right`
    (poloviční šířka) a výškového rozsahu `up_lo..up_hi`."""
    height = up_hi - up_lo
    return [
        (0.28 * right, up_lo + 1.00 * height),
        (-0.62 * right, up_lo + 0.42 * height),
        (-0.05 * right, up_lo + 0.42 * height),
        (-0.28 * right, up_lo + 0.00 * height),
        (0.62 * right, up_lo + 0.58 * height),
        (0.05 * right, up_lo + 0.58 * height),
        (0.28 * right, up_lo + 1.00 * height),
    ]


def crack_points(seed_offsets, right_span, up_center, jag=0.028):
    """Cikcak trhlina jako tenký vytlačený proužek — obrys "klikaté" úsečky
    o nulové referenční tloušťce `jag*2`, zprava doleva a zpátky."""
    xs = [right_span[0] + (right_span[1] - right_span[0]) * t / (len(seed_offsets) - 1)
          for t in range(len(seed_offsets))]
    top = [(x, up_center + o + jag) for x, o in zip(xs, seed_offsets)]
    bottom = [(x, up_center + o - jag) for x, o in zip(xs, seed_offsets)]
    return top + list(reversed(bottom))
