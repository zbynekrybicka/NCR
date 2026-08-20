# -*- coding: utf-8 -*-
"""
DÍL 03 — Přistávací nohy, spec §5 ("drobné, pod trupem — funkčně nutné,
musí umět stát na pevném podkladu").

Da se modeluje PŘISTÁLÝ: chodidla dosedají na podlahu buňky (up = 0).
Vznášení je podle `docs/import-assets.md` §2.3 věc idle animace, ne
pozice modelu — jinak by se rozešel s kamerou a s ostatními roboty.

Nohy jsou pod rameny, aby se zatížení neslo do rámu, a jsou samostatné
objekty s originem v místě, kde vycházejí z trupu — kdyby se někdy
zatahovaly, je to jedna rotace.

Objekty: DA_Gear_0..3
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
S = _ncr_import("da_spec")

PREFIXES = ("DA_Gear",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DA_Gear",))
    coll = nc.collection("DA_Gear", parent_collection or nc.collection("DA"))

    p = nc.p
    parts = []
    for i, angle in enumerate(S.GEAR_ANGLES):
        top_fwd, top_right = S.arm_tip(angle, S.GEAR_TOP_R)
        foot_fwd, foot_right = S.arm_tip(angle, S.GEAR_FOOT_R)

        leg = nc.limb("DA_Gear_%d" % i,
                      p(top_fwd, top_right, S.HUB_UP[0] + 0.010),
                      p(foot_fwd, foot_right, S.FOOT_H),
                      size=S.GEAR_SIZE, coll=coll,
                      material=nc.mat("metal_dark"), bevel_w=0.004)
        pad = nc.cyl("DA_GearPad_%d" % i, S.FOOT_R, S.FOOT_H,
                     loc=p(foot_fwd, foot_right, S.FOOT_H * 0.5),
                     verts=20, coll=coll, material=nc.mat("rubber"),
                     bevel_w=0.004)
        parts.append(nc.join([leg, pad], "DA_Gear_%d" % i))

    print("[NCR] díl 03 — podvozek: %d nohy, rozkročení %.2fu, chodidla na 0.000"
          % (len(parts), S.GEAR_FOOT_R * 2))
    return parts


if __name__ == "__main__":
    build()
