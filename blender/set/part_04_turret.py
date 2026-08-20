# -*- coding: utf-8 -*-
"""
DÍL 04 — Otočná věž, spec §3 ("hlavice montovaná na rotující věži").

Origin věže leží v ose věnce, takže otáčení je jedna rotace kolem Z.
Líce věže drží čep náměru — hlavice (díl 05) se na něj věší.

Objekty: SET_Turret
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

PREFIXES = ("SET_Turret",)


def build(parent_collection=None, yaw=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("SET_Turret",))
    coll = nc.collection("SET_Turret", parent_collection or nc.collection("SET"))

    p = nc.p
    up_lo, up_hi = S.TURRET_UP
    pivot = p(S.RING_FWD, 0.0, S.RING_UP[0])

    body = nc.cone("SET_Turret", S.TURRET_R[0], S.TURRET_R[1], up_hi - up_lo,
                   loc=p(S.RING_FWD, 0.0, (up_lo + up_hi) * 0.5), verts=32,
                   coll=coll, material=nc.mat("body"), bevel_w=0.008,
                   smooth_angle=25)

    # líce s čepem náměru
    cheeks = []
    ch_lo, ch_hi = S.CHEEK_UP
    cf_lo, cf_hi = S.CHEEK_FWD
    for side in (-1, 1):
        cheeks.append(nc.box("SET_TurretCheek",
                             (S.CHEEK_THICK, cf_hi - cf_lo, ch_hi - ch_lo),
                             loc=p((cf_lo + cf_hi) * 0.5, side * S.TRUNNION_RIGHT,
                                   (ch_lo + ch_hi) * 0.5),
                             coll=coll, material=nc.mat("body_dark"), bevel_w=0.008))
        # ložiskový nálitek okolo čepu, ať je vidět, co drží náměr
        cheeks.append(nc.cyl("SET_TurretBoss", 0.046, S.CHEEK_THICK + 0.010,
                             rot=(0, 90, 0),
                             loc=p(S.RING_FWD, side * S.TRUNNION_RIGHT, S.TRUNNION_UP),
                             verts=24, coll=coll, material=nc.mat("body_dark"),
                             bevel_w=0.004))
    cheeks.append(nc.cyl("SET_TurretPin", 0.022, S.TRUNNION_RIGHT * 2 + 0.030,
                         rot=(0, 90, 0), loc=p(S.RING_FWD, 0.0, S.TRUNNION_UP),
                         verts=18, coll=coll, material=nc.mat("metal_polish")))

    # poklop a průzor, ať věž není hladká placka
    hatch = nc.cyl("SET_TurretHatch", 0.062, 0.016,
                   loc=p(S.RING_FWD - 0.062, 0.0, up_hi + 0.004),
                   verts=24, coll=coll, material=nc.mat("body_dark"),
                   bevel_w=0.003)
    vision = nc.box("SET_TurretVision", (0.070, 0.018, 0.026),
                    loc=p(S.RING_FWD + 0.118, 0.0, up_hi - 0.030),
                    coll=coll, material=nc.mat("accent_dark"), bevel_w=0.003)

    turret = nc.join([body] + cheeks + [hatch, vision], "SET_Turret")
    nc.set_origin(turret, pivot)

    angle = S.TURRET_YAW if yaw is None else yaw
    if angle:
        turret.rotation_mode = 'XYZ'
        turret.rotation_euler = (0.0, 0.0, nc.radians(angle))

    print("[NCR] díl 04 — věž: osa v (fwd %.3f, up %.3f), natočení %.0f deg"
          % (S.RING_FWD, S.RING_UP[0], angle))
    return [turret]


if __name__ == "__main__":
    build()
