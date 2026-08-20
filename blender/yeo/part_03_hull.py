# -*- coding: utf-8 -*-
"""
DÍL 03 — Trup, hrudní jádro a krk chladiče.

Spec §6 chce jádro "níž na hrudi", aby nekolidovalo s chladičem. Střed
koule proto leží uvnitř trupu a z čelní stěny se vyklenuje jen její přední
část. Límec kolem ní je prstenec na čele, ne na hřbetu jako u ostatních.

Objekty: YEO_Hull
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

PREFIXES = ("YEO_Hull", "YEO_Fairing", "YEO_Neck")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("YEO_Hull",))
    coll = nc.collection("YEO_Hull", parent_collection or nc.collection("YEO"))

    p = nc.p
    fwd_lo, fwd_hi = S.HULL_FWD
    up_lo, up_hi = S.HULL_UP
    length = fwd_hi - fwd_lo
    height = up_hi - up_lo

    hull = nc.box("YEO_Hull", (S.HULL_RIGHT * 2, length, height),
                  loc=p((fwd_lo + fwd_hi) * 0.5, 0.0, (up_lo + up_hi) * 0.5),
                  coll=coll, material=nc.mat("body"), bevel_w=0.010)

    for side in (-1, 1):
        for up in (up_lo + 0.055, up_hi - 0.055):
            nc.cut(hull, nc.box("YEO_HullCut", (0.022, length * 0.70, 0.011),
                                loc=p((fwd_lo + fwd_hi) * 0.5,
                                      side * S.HULL_RIGHT, up),
                                coll=coll))

    # --- límec kolem hrudní koule ------------------------------------------
    # Leží na čelní stěně, takže je to prstenec s osou dopředu.
    fairing = nc.cyl("YEO_Fairing", S.FAIRING_R, S.FAIRING_LEN, rot=(90, 0, 0),
                     loc=p(fwd_hi - S.FAIRING_LEN * 0.3, 0.0, S.CORE_UP),
                     verts=32, coll=coll, material=nc.mat("body_dark"),
                     bevel_w=0.005)
    nc.cut(fairing, nc.cyl("YEO_FairingCut", S.FAIRING_R * 0.80, S.FAIRING_LEN * 3,
                           rot=(90, 0, 0),
                           loc=p(fwd_hi, 0.0, S.CORE_UP), verts=32, coll=coll))

    # --- krk pod chladičem --------------------------------------------------
    neck_lo, neck_hi = S.NECK_UP
    neck = nc.cyl("YEO_Neck", S.NECK_R, neck_hi - neck_lo,
                  loc=p(S.RAD_FWD, 0.0, (neck_lo + neck_hi) * 0.5),
                  verts=24, coll=coll, material=nc.mat("metal_dark"),
                  bevel_w=0.004)

    hull = nc.join([hull, fairing, neck], "YEO_Hull")

    print("[NCR] díl 03 — trup: %.2f x %.2f x %.2fu, hrudní koule na fwd %.3f"
          % (S.HULL_RIGHT * 2, length, height, S.CORE_FWD))
    return [hull]


if __name__ == "__main__":
    build()
