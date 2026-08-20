# -*- coding: utf-8 -*-
"""
DÍL 02 — Kola s hroty, spec §6 ("terénní kola nebo hroty — kontrast vůči
Dulově hladkému podvozku").

Kontrast je tu záměr, ne náhoda: Dul má kola zatažená do břicha a hladká,
Yeo je má vystrčená a zubatá. Dvě řady hrotů po obvodu tvoří vnějšek kola,
takže plášť má poloměr `WHEEL_R - SPIKE_H` a robot dosedá hroty přesně na
podlahu buňky.

Objekty: YEO_Wheel_L0/L1, YEO_Wheel_P0/P1
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
S = _ncr_import("yeo_spec")

PREFIXES = ("YEO_Wheel",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("YEO_Wheels",))
    coll = nc.collection("YEO_Wheels", parent_collection or nc.collection("YEO"))

    parts = []
    for side, tag in ((-1, "L"), (1, "P")):
        for i, fwd in enumerate(S.WHEEL_FWD):
            name = "YEO_Wheel_%s%d" % (tag, i)
            center = nc.p(fwd, side * S.WHEEL_RIGHT, S.WHEEL_R)

            tyre = nc.cyl(name, S.TYRE_R, S.WHEEL_WIDTH, rot=(0, 90, 0),
                          loc=center, verts=32, coll=coll,
                          material=nc.mat("rubber"), bevel_w=0.006)
            hub = nc.cyl(name + "_Hub", S.HUB_R, S.WHEEL_WIDTH * 1.12,
                         rot=(0, 90, 0), loc=center, verts=20, coll=coll,
                         material=nc.mat("metal_raw"), bevel_w=0.004)
            pieces = [tyre, hub]

            for row, offset in enumerate(S.SPIKE_ROWS):
                spike = nc.limb("%s_Spike%d" % (name, row),
                                center + nc.Vector((offset, 0.0, S.TYRE_R - 0.004)),
                                center + nc.Vector((offset, 0.0, S.WHEEL_R)),
                                taper=(0.020, 0.009), verts=6, coll=coll,
                                material=nc.mat("metal_dark"))
                pieces.append(nc.radial(spike, S.SPIKES, axis='X', center=center))

            parts.append(nc.join(pieces, name))

    print("[NCR] díl 02 — kola: %d kusů, r=%.3f, %d hrotů ve 2 řadách"
          % (len(parts), S.WHEEL_R, S.SPIKES))
    return parts


if __name__ == "__main__":
    build()
