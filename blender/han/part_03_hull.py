# -*- coding: utf-8 -*-
"""
DÍL 03 — Trup a krk jádra.

Nosí rameno (vpředu), korbu (vzadu) a jádro (nahoře uprostřed, spec §1:
"na vrcholu těla, mezi ramenem a korbou"). Čelní horní hrana je zkosená,
aby rameno ve složené póze mělo kam sednout a silueta nebyla kvádr.

Objekty: HAN_Hull, HAN_Neck, HAN_Exhaust
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
            "Nenašel jsem %s.py — otevři přes Text > Open skripty ze složky "
            "robota i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")
S = _ncr_import("han_spec")

PREFIXES = ("HAN_Hull", "HAN_Neck", "HAN_Exhaust")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("HAN_Hull",))
    coll = nc.collection("HAN_Hull", parent_collection or nc.collection("HAN"))

    p = nc.p
    fwd_lo, fwd_hi = S.HULL_FWD
    up_lo, up_hi = S.HULL_UP
    length = fwd_hi - fwd_lo
    height = up_hi - up_lo

    # --- hlavní hmota ------------------------------------------------------
    hull = nc.box("HAN_Hull", (S.HULL_RIGHT * 2, length, height),
                  loc=p((fwd_lo + fwd_hi) * 0.5, 0.0, (up_lo + up_hi) * 0.5),
                  coll=coll, material=nc.mat("body"), bevel_w=0.008)

    # zkosení čelní horní hrany pod 45° (spec §0.3 — hrubá hmota - subtrakce)
    c = S.HULL_NOSE_CHAMFER
    normal = nc.dir_yz(45.0)
    corner = p(fwd_hi, 0.0, up_hi - c)
    nc.cut(hull, nc.box("HAN_HullCut_Nose", (0.9, 0.9, 0.5), rot=(45, 0, 0),
                        loc=corner + normal * 0.25, coll=coll))

    # --- motorová paluba s žaluziemi --------------------------------------
    deck = nc.box("HAN_HullDeck", (0.300, 0.120, 0.045),
                  loc=p(-0.090, 0.0, up_hi + 0.014), coll=coll,
                  material=nc.mat("body_dark"), bevel_w=0.004)
    louver = nc.box("HAN_HullCut_Louver", (0.320, 0.008, 0.020),
                    loc=p(-0.135, 0.0, up_hi + 0.032), coll=coll)
    nc.array(louver, 5, (0.0, -0.018, 0.0))   # -Y = dopředu
    nc.cut(deck, louver)

    # --- panelové spáry na bocích -----------------------------------------
    for side in (-1, 1):
        for up in (up_lo + 0.055, up_hi - 0.050):
            groove = nc.box("HAN_HullCut_Panel", (0.020, length * 0.72, 0.010),
                            loc=p((fwd_lo + fwd_hi) * 0.5, side * S.HULL_RIGHT, up),
                            coll=coll)
            nc.cut(hull, groove)

    hull = nc.join([hull, deck], "HAN_Hull")
    nc.bevel(hull, 0.0015, segments=1, angle=60)

    # --- krk pod jádro -----------------------------------------------------
    neck_lo, neck_hi = S.NECK_UP
    neck = nc.cyl("HAN_Neck", S.NECK_R, neck_hi - neck_lo,
                  loc=p(S.CORE_FWD, 0.0, (neck_lo + neck_hi) * 0.5),
                  verts=24, coll=coll, material=nc.mat("metal_dark"), bevel_w=0.004)
    flange = nc.cyl("HAN_NeckFlange", S.NECK_R * 1.38, 0.016,
                    loc=p(S.CORE_FWD, 0.0, neck_lo + 0.014),
                    verts=24, coll=coll, material=nc.mat("metal_raw"), bevel_w=0.003)
    neck = nc.join([neck, flange], "HAN_Neck")

    # --- výfuk -------------------------------------------------------------
    ex_right, ex_fwd = S.EXHAUST_AT
    pipe_lo = up_hi - 0.020
    pipe = nc.cyl("HAN_Exhaust", S.EXHAUST_R, S.EXHAUST_TOP - pipe_lo,
                  loc=p(ex_fwd, ex_right, (pipe_lo + S.EXHAUST_TOP) * 0.5),
                  verts=18, coll=coll, material=nc.mat("metal_dark"))
    # šikmo seříznuté ústí
    nc.cut(pipe, nc.box("HAN_ExhaustCut", (0.12, 0.12, 0.12), rot=(35, 0, 0),
                        loc=p(ex_fwd, ex_right, S.EXHAUST_TOP) +
                            nc.dir_yz(35.0) * 0.058, coll=coll))
    shield = nc.cyl("HAN_ExhaustShield", S.EXHAUST_R * 1.9, 0.030,
                    loc=p(ex_fwd, ex_right, pipe_lo + 0.050),
                    verts=18, coll=coll, material=nc.mat("metal_raw"), bevel_w=0.003)
    pipe = nc.join([pipe, shield], "HAN_Exhaust")

    parts = [hull, neck, pipe]
    print("[NCR] díl 03 — trup: %d objektů" % len(parts))
    return parts


if __name__ == "__main__":
    build()
