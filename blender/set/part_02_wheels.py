# -*- coding: utf-8 -*-
"""
DÍL 02 — Kola, spec §3 + §0.3 ("kola jsou vždy samostatné objekty").

Šest velkých terénních kol. Každé je samostatný objekt s originem v ose,
takže jízda je rotace kolem X.

Objekty: SET_Wheel_L0..L2, SET_Wheel_P0..P2
"""

import bpy
import os
import sys
import types
import importlib


def _ncr_import(module_name):
    """Načte modul ze složky robota nebo ze sousední `blender/common`.
    Funguje v Text Editoru i přes `blender --python`."""
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
            "Nenasel jsem %s.py - otevri pres Text > Open skripty ze slozky "
            "robota i z blender/common, at k sobe navzajem vidi." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")
S = _ncr_import("set_spec")

PREFIXES = ("SET_Wheel",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("SET_Wheels",))
    coll = nc.collection("SET_Wheels", parent_collection or nc.collection("SET"))

    parts = []
    for side, side_tag in ((-1, "L"), (1, "P")):
        for i, fwd in enumerate(S.WHEEL_FWD):
            name = "SET_Wheel_%s%d" % (side_tag, i)
            center = nc.p(fwd, side * S.WHEEL_RIGHT, S.WHEEL_R)

            tyre = nc.cyl(name, S.TYRE_R, S.WHEEL_WIDTH, rot=(0, 90, 0),
                          loc=center, verts=32, coll=coll,
                          material=nc.mat("rubber"), bevel_w=0.008)
            hub = nc.cyl(name + "_Hub", S.HUB_R, S.WHEEL_WIDTH * 1.10,
                         rot=(0, 90, 0), loc=center, verts=20, coll=coll,
                         material=nc.mat("metal_raw"), bevel_w=0.004)
            # terénní vzorek — u "robustnějšího než Han" se vyplatí
            lug = nc.box(name + "_Lug",
                         (S.WHEEL_WIDTH * 0.92, 0.024, S.LUG_H),
                         loc=center + nc.Vector((0.0, 0.0,
                                                 S.TYRE_R + S.LUG_H * 0.5)),
                         coll=coll, material=nc.mat("rubber"), bevel_w=0.003)
            lugs = nc.radial(lug, S.WHEEL_LUGS, axis='X', center=center)

            parts.append(nc.join([tyre, hub, lugs], name))

    print("[NCR] díl 02 — kola: %d kusů, r=%.3f" % (len(parts), S.WHEEL_R))
    return parts


if __name__ == "__main__":
    build()
