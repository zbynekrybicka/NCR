# -*- coding: utf-8 -*-
"""
DÍL 01 — Rám podvozku a blatníky, spec §1 ("nízko posazený, šířka ~0.7u").

Nosná část mezi pásy + deska blatníku, na které stojí trup. Pásy a kola
jsou zvlášť (díl 02), aby šly animovat.

Objekty: HAN_Frame, HAN_Fender, HAN_Hitch
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

PREFIXES = ("HAN_Frame", "HAN_Fender", "HAN_Hitch", "HAN_Axle")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("HAN_Chassis",))
    coll = nc.collection("HAN_Chassis", parent_collection or nc.collection("HAN"))

    p = nc.p
    frame_h = S.FRAME_UP[1] - S.FRAME_UP[0]
    frame_mid = (S.FRAME_UP[0] + S.FRAME_UP[1]) * 0.5

    # --- nosný rám mezi pásy ----------------------------------------------
    frame = nc.box("HAN_Frame", (S.FRAME_RIGHT * 2, S.FRAME_FWD * 2, frame_h),
                   loc=p(up=frame_mid), coll=coll,
                   material=nc.mat("body_dark"), bevel_w=0.006)

    # příčné nosníky, na kterých sedí hnací a vodicí kola pásů
    axle_z = S.TRACK_R
    beams = []
    for i, fwd in enumerate((S.DRIVE_FWD, -S.DRIVE_FWD)):
        beams.append(nc.limb("HAN_Axle_%d" % i,
                             p(fwd, -S.TRACK_RIGHT, axle_z),
                             p(fwd, S.TRACK_RIGHT, axle_z),
                             radius=0.030, verts=16, coll=coll,
                             material=nc.mat("metal_dark")))
    frame = nc.join([frame] + beams, "HAN_Frame")

    # --- blatník / paluba, na které stojí trup -----------------------------
    fender_h = S.FENDER_UP[1] - S.FENDER_UP[0]
    fender_mid = (S.FENDER_UP[0] + S.FENDER_UP[1]) * 0.5
    fender = nc.box("HAN_Fender", (S.FENDER_RIGHT * 2, S.FENDER_FWD * 2, fender_h),
                    loc=p(up=fender_mid), coll=coll,
                    material=nc.mat("body"), bevel_w=0.005)

    # technologické spáry v palubě (spec §0.3 — subtrakce jako detail).
    # Řežou se do samotné desky, teprve pak se přidají lemy: boolean na
    # slepenci dvou dotýkajících se hmot dělá u EXACT solveru neplechu.
    for fwd in (0.105, -0.105):
        groove = nc.box("HAN_FenderCut", (S.FENDER_RIGHT * 2.2, 0.010, 0.016),
                        loc=p(fwd, 0.0, S.FENDER_UP[1] - 0.003), coll=coll)
        nc.cut(fender, groove)
    nc.bevel(fender, 0.0015, segments=1, angle=60)

    # sklopené lemy po stranách, aby deska nevypadala jako prkno
    lips = []
    for side in (-1, 1):
        lips.append(nc.box("HAN_FenderLip_%d" % (side > 0),
                           (0.022, S.FENDER_FWD * 2, 0.055),
                           loc=p(0.0, side * (S.FENDER_RIGHT - 0.011), S.FENDER_UP[0] - 0.010),
                           coll=coll, material=nc.mat("body"), bevel_w=0.004))
    fender = nc.join([fender] + lips, "HAN_Fender")

    # --- tažný hák na zádi -------------------------------------------------
    hitch = nc.box("HAN_Hitch", (0.110, 0.070, 0.045),
                   loc=p(-S.FENDER_FWD - 0.020, 0.0, S.FENDER_UP[0] - 0.010),
                   coll=coll, material=nc.mat("metal_dark"), bevel_w=0.006)
    pin = nc.cyl("HAN_HitchPin", 0.014, 0.060, rot=(90, 0, 0),
                 loc=p(-S.FENDER_FWD - 0.045, 0.0, S.FENDER_UP[0] - 0.010),
                 verts=14, coll=coll, material=nc.mat("metal_polish"))
    hitch = nc.join([hitch, pin], "HAN_Hitch")

    parts = [frame, fender, hitch]
    print("[NCR] díl 01 — rám podvozku: %d objektů" % len(parts))
    return parts


if __name__ == "__main__":
    build()
