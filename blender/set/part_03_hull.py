# -*- coding: utf-8 -*-
"""
DÍL 03 — Trup, lůžko jádra a věnec věže.

Trup je nižší a širší než Hanův — nese těžkou věž, takže je to spíš
lafeta než karoserie. Věnec věže i límec jádra jsou jeho součástí
(nerotují), proto se slepují sem.

Objekty: SET_Hull
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

PREFIXES = ("SET_Hull", "SET_Ring", "SET_Fairing")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("SET_Hull",))
    coll = nc.collection("SET_Hull", parent_collection or nc.collection("SET"))

    p = nc.p
    fwd_lo, fwd_hi = S.HULL_FWD
    up_lo, up_hi = S.HULL_UP
    length = fwd_hi - fwd_lo
    height = up_hi - up_lo

    hull = nc.box("SET_Hull", (S.HULL_RIGHT * 2, length, height),
                  loc=p((fwd_lo + fwd_hi) * 0.5, 0.0, (up_lo + up_hi) * 0.5),
                  coll=coll, material=nc.mat("body"), bevel_w=0.010)

    # zkosená příď — plamen odchází nahoru a dopředu, ať mu čelo nestojí v cestě
    c = S.HULL_NOSE_CHAMFER
    normal = nc.dir_yz(45.0)
    nc.cut(hull, nc.box("SET_HullCut_Nose", (0.9, 0.9, 0.5), rot=(45, 0, 0),
                        loc=p(fwd_hi, 0.0, up_hi - c) + normal * 0.25, coll=coll))

    # panelové spáry na bocích (boolean ještě do samotného kvádru)
    for side in (-1, 1):
        for up in (up_lo + 0.045, up_hi - 0.042):
            nc.cut(hull, nc.box("SET_HullCut_Panel",
                                (0.022, length * 0.70, 0.011),
                                loc=p((fwd_lo + fwd_hi) * 0.5, side * S.HULL_RIGHT, up),
                                coll=coll))

    # --- věnec věže ---------------------------------------------------------
    ring_lo, ring_hi = S.RING_UP
    ring = nc.cyl("SET_Ring", S.RING_R, ring_hi - ring_lo,
                  loc=p(S.RING_FWD, 0.0, (ring_lo + ring_hi) * 0.5),
                  verts=40, coll=coll, material=nc.mat("metal_dark"),
                  bevel_w=0.004)

    # --- límec pod jádrem ---------------------------------------------------
    fair_lo, fair_hi = S.FAIRING_UP
    fairing = nc.cyl("SET_Fairing", S.FAIRING_R[0], fair_hi - fair_lo,
                     loc=p(S.CORE_FWD, 0.0, (fair_lo + fair_hi) * 0.5),
                     verts=32, coll=coll, material=nc.mat("body_dark"),
                     bevel_w=0.005)
    nc.stretch(fairing, (1.0, S.FAIRING_R[1] / S.FAIRING_R[0], 1.0))

    hull = nc.join([hull, ring, fairing], "SET_Hull")

    print("[NCR] díl 03 — trup: %.2f x %.2f x %.2fu, věnec r=%.3f"
          % (S.HULL_RIGHT * 2, length, height, S.RING_R))
    return [hull]


if __name__ == "__main__":
    build()
