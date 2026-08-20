# -*- coding: utf-8 -*-
"""
DÍL 02 — Podvozek, spec §2 ("zatažitelná/nízkoprofilová kola pro souš —
nesmí rušit hydrodynamickou siluetu").

Kola sedí v zápustkách v břiše (vyřezal je díl 01) a drží je kyvná ramena.
Origin ramene je v jeho čepu, takže zatažení podvozku je jedna rotace
kolem X — stejná konvence jako u všech kloubů Hana.

Objekty: DUL_Wheel_FL/FP/RL/RP, DUL_WheelArm_FL/FP/RL/RP
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

PREFIXES = ("DUL_Wheel",)


def build(parent_collection=None, retract=0.0):
    """`retract` má smysl jen při samostatném spuštění dílu. Ze sestavení
    se zatažení nastavuje až po zavěšení kol na ramena (jinak by se rameno
    otočilo a kolo zůstalo viset ve vzduchu) — viz build_dul.RETRACT_WHEELS."""
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DUL_Wheels",))
    coll = nc.collection("DUL_Wheels", parent_collection or nc.collection("DUL"))

    p = nc.p
    parts = []

    for fwd, fwd_tag in zip(S.WHEEL_FWD, ("F", "R")):
        # čep ramene je blíž ke středu robota, kolo od něj visí ven a dolů
        pivot_fwd = fwd - S.ARM_LEN * (1.0 if fwd > 0 else -1.0)
        for side, side_tag in ((-1, "L"), (1, "P")):
            tag = fwd_tag + side_tag
            hub = p(fwd, side * S.WHEEL_RIGHT, S.WHEEL_R)
            pivot = p(pivot_fwd, side * S.WHEEL_RIGHT, S.ARM_UP)

            arm = nc.limb("DUL_WheelArm_" + tag, pivot, hub, size=S.ARM_SIZE,
                          coll=coll, material=nc.mat("metal_dark"), bevel_w=0.004)
            tyre = nc.cyl("DUL_Wheel_" + tag, S.WHEEL_R, S.WHEEL_WIDTH,
                          rot=(0, 90, 0), loc=hub, verts=28, coll=coll,
                          material=nc.mat("rubber"), bevel_w=0.006)
            disc = nc.cyl("DUL_WheelDisc_" + tag, S.WHEEL_R * 0.55,
                          S.WHEEL_WIDTH * 1.12, rot=(0, 90, 0), loc=hub,
                          verts=20, coll=coll, material=nc.mat("metal_raw"),
                          bevel_w=0.003)
            parts += [arm, nc.join([tyre, disc], "DUL_Wheel_" + tag)]

    if retract:
        for o in parts:
            if o.name.startswith("DUL_WheelArm_"):
                o.rotation_mode = 'XYZ'
                o.rotation_euler = (nc.radians(retract), 0.0, 0.0)

    print("[NCR] díl 02 — podvozek: %d objektů, kola r=%.3f v zápustkách"
          % (len(parts), S.WHEEL_R))
    return parts


if __name__ == "__main__":
    build()
