# -*- coding: utf-8 -*-
"""
DÍL 01 — Rám a blatníky.

Nosná část mezi koly a deska, na které stojí trup. Kola jsou zvlášť
(díl 02), aby šla animovat.

Objekty: SET zde nic — YEO_Frame, YEO_Fender
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

PREFIXES = ("YEO_Frame", "YEO_Fender", "YEO_Axle")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("YEO_Chassis",))
    coll = nc.collection("YEO_Chassis", parent_collection or nc.collection("YEO"))

    p = nc.p
    lo, hi = S.FRAME_UP
    frame = nc.box("YEO_Frame", (S.FRAME_RIGHT * 2, S.FRAME_FWD * 2, hi - lo),
                   loc=p(0.0, 0.0, (lo + hi) * 0.5), coll=coll,
                   material=nc.mat("body_dark"), bevel_w=0.008)

    beams = []
    for i, fwd in enumerate(S.WHEEL_FWD):
        beams.append(nc.limb("YEO_Axle_%d" % i,
                             p(fwd, -S.WHEEL_RIGHT, S.WHEEL_R),
                             p(fwd, S.WHEEL_RIGHT, S.WHEEL_R),
                             radius=0.032, verts=16, coll=coll,
                             material=nc.mat("metal_dark")))
    frame = nc.join([frame] + beams, "YEO_Frame")

    f_lo, f_hi = S.FENDER_UP
    fender = nc.box("YEO_Fender", (S.FENDER_RIGHT * 2, S.FENDER_FWD * 2, f_hi - f_lo),
                    loc=p(0.0, 0.0, (f_lo + f_hi) * 0.5), coll=coll,
                    material=nc.mat("body"), bevel_w=0.006)
    for fwd in (0.140, -0.140):
        nc.cut(fender, nc.box("YEO_FenderCut", (S.FENDER_RIGHT * 2.2, 0.011, 0.018),
                              loc=p(fwd, 0.0, f_hi - 0.004), coll=coll))
    nc.bevel(fender, 0.0015, segments=1, angle=60)

    lips = []
    for side in (-1, 1):
        lips.append(nc.box("YEO_FenderLip", (0.024, S.FENDER_FWD * 2, 0.058),
                           loc=p(0.0, side * (S.FENDER_RIGHT - 0.012), f_lo - 0.012),
                           coll=coll, material=nc.mat("body"), bevel_w=0.004))
    fender = nc.join([fender] + lips, "YEO_Fender")

    print("[NCR] díl 01 — podvozek: rozchod %.2fu"
          % ((S.WHEEL_RIGHT + S.WHEEL_WIDTH * 0.5) * 2))
    return [frame, fender]


if __name__ == "__main__":
    build()
