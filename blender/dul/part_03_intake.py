# -*- coding: utf-8 -*-
"""
DÍL 03 — Sání na přídi, spec §2 ("mřížka/otvor vepředu, napojené na Akci 1").

Hrdlo je vyvrtané do přídě, ne přilepené, aby silueta zůstala hladká.
Mříž je samostatný objekt — kdyby se někdy animovala clona nebo se měnila
hustota prutů, nesahá se do trupu.

Objekty: DUL_Intake (náběhový prstenec + hrdlo), DUL_IntakeGrille (mříž)
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

PREFIXES = ("DUL_Intake",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DUL_Intake",))
    coll = nc.collection("DUL_Intake", parent_collection or nc.collection("DUL"))

    p = nc.p
    axis_up = S.HULL_SECTIONS[0][3]
    mouth = S.HULL_BOW

    # --- náběhový prstenec ústí -------------------------------------------
    lip = nc.cone("DUL_Intake", S.INTAKE_LIP_R, S.INTAKE_LIP_R * 0.90, 0.026,
                  rot=(90, 0, 0), loc=p(mouth - 0.010, 0.0, axis_up),
                  verts=32, coll=coll, material=nc.mat("metal_raw"))
    nc.cut(lip, nc.cyl("DUL_IntakeCut", S.INTAKE_R, 0.200, rot=(90, 0, 0),
                       loc=p(mouth, 0.0, axis_up), verts=32, coll=coll))

    # hrdlo vedoucí do trupu; vyrábí si ho díl sám, ať je nezávislý na dílu 01
    duct = nc.cyl("DUL_IntakeDuct", S.INTAKE_R * 0.99, S.INTAKE_DEPTH,
                  rot=(90, 0, 0),
                  loc=p(mouth - S.INTAKE_DEPTH * 0.5, 0.0, axis_up),
                  verts=32, coll=coll, material=nc.mat("metal_dark"))
    nc.cut(duct, nc.cyl("DUL_IntakeCut", S.INTAKE_R * 0.86, S.INTAKE_DEPTH * 1.2,
                        rot=(90, 0, 0),
                        loc=p(mouth - S.INTAKE_DEPTH * 0.5 - 0.012, 0.0, axis_up),
                        verts=32, coll=coll))
    intake = nc.join([lip, duct], "DUL_Intake")

    # --- mříž --------------------------------------------------------------
    bars = []
    for i in range(S.INTAKE_BARS):
        t = (i / (S.INTAKE_BARS - 1.0)) - 0.5
        offset = t * S.INTAKE_R * 1.24
        half = (S.INTAKE_R ** 2 - offset ** 2) ** 0.5
        bars.append(nc.box("DUL_IntakeBar", (half * 2.0, 0.012, S.INTAKE_BAR_H),
                           loc=p(mouth - 0.014, 0.0, axis_up + offset), coll=coll,
                           material=nc.mat("metal_raw"), bevel_w=0.002))
    bars.append(nc.box("DUL_IntakeBar", (S.INTAKE_BAR_H, 0.012, S.INTAKE_R * 1.9),
                       loc=p(mouth - 0.014, 0.0, axis_up), coll=coll,
                       material=nc.mat("metal_raw"), bevel_w=0.002))
    grille = nc.join(bars, "DUL_IntakeGrille")

    parts = [intake, grille]
    print("[NCR] díl 03 — sání: světlost %.3fu, mříž %d prutů"
          % (S.INTAKE_R * 2, S.INTAKE_BARS + 1))
    return parts


if __name__ == "__main__":
    build()
