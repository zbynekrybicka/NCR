# -*- coding: utf-8 -*-
"""
DÍL 04 — Tryska na zádi, spec §2.

Spec je tu explicitní: "vizuálně stejný prvek slouží jako pohon i jako
vypouštěcí ústí". Proto ne lodní šroub na hřídeli, ale pumpjet — kužel
trysky, v něm rotor a za ním statorové lopatky. Když Dul plave, žene vodu;
když vypouští cisternu, teče stejným ústím ven.

Rotor je samostatný objekt s originem na ose, takže se roztočí jednou
rotací kolem osy Y.

Objekty: DUL_Nozzle (kryt + stator), DUL_Impeller (rotor)
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
S = _ncr_import("dul_spec")

PREFIXES = ("DUL_Nozzle", "DUL_Impeller", "DUL_Stator")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DUL_Nozzle",))
    coll = nc.collection("DUL_Nozzle", parent_collection or nc.collection("DUL"))

    p = nc.p
    axis_up = S.HULL_SECTIONS[-1][3]
    aft, fore = S.NOZZLE_FWD
    length = fore - aft
    r_aft, r_fore = S.NOZZLE_R_OUT

    # --- kryt trysky -------------------------------------------------------
    shroud = nc.cone("DUL_Nozzle", r_aft, r_fore, length, rot=(90, 0, 0),
                     loc=p((aft + fore) * 0.5, 0.0, axis_up), verts=32,
                     coll=coll, material=nc.mat("body"), smooth_angle=45)
    nc.cut(shroud, nc.cyl("DUL_NozzleCut", S.NOZZLE_R_IN, length * 1.8,
                          rot=(90, 0, 0), loc=p((aft + fore) * 0.5, 0.0, axis_up),
                          verts=32, coll=coll))

    # --- statorové lopatky za rotorem -------------------------------------
    vane = nc.box("DUL_Stator", (S.NOZZLE_R_IN - S.IMPELLER_HUB_R, 0.020, 0.008),
                  loc=p(S.STATOR_FWD,
                        (S.NOZZLE_R_IN + S.IMPELLER_HUB_R) * 0.5, axis_up),
                  coll=coll, material=nc.mat("metal_dark"), bevel_w=0.002)
    vanes = nc.radial(vane, S.STATOR_VANES, axis='Y',
                      center=p(S.STATOR_FWD, 0.0, axis_up))
    nozzle = nc.join([shroud, vanes], "DUL_Nozzle")

    # --- rotor -------------------------------------------------------------
    center = p(S.IMPELLER_FWD, 0.0, axis_up)
    hub = nc.cone("DUL_Impeller", S.IMPELLER_HUB_R, S.IMPELLER_HUB_R * 0.55, 0.058,
                  rot=(90, 0, 0), loc=center, verts=20, coll=coll,
                  material=nc.mat("metal_raw"), smooth_angle=40)
    blade = nc.box("DUL_ImpellerBlade",
                   (S.NOZZLE_R_IN - S.IMPELLER_HUB_R - 0.006, 0.044, 0.007),
                   loc=center + nc.Vector(((S.NOZZLE_R_IN + S.IMPELLER_HUB_R) * 0.5,
                                           0.0, 0.0)),
                   rot=(0, S.IMPELLER_PITCH, 0),
                   coll=coll, material=nc.mat("metal_raw"), bevel_w=0.002)
    blades = nc.radial(blade, S.IMPELLER_BLADES, axis='Y', center=center)
    impeller = nc.join([hub, blades], "DUL_Impeller")
    nc.set_origin(impeller, center)

    parts = [nozzle, impeller]
    print("[NCR] díl 04 — tryska: ústí %.3fu, rotor %d lopatek"
          % (S.NOZZLE_R_IN * 2, S.IMPELLER_BLADES))
    return parts


if __name__ == "__main__":
    build()
