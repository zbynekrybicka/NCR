# -*- coding: utf-8 -*-
"""
DÍL 01 — Trup, spec §2 ("torpédovitý/hladký, ~0.9u délka").

Hladkost je funkční, ne stylová: Dul po ledu klouže a plave, takže se do
pláště nic nepřilepuje — kola, sání i cisterna se do něj zapouštějí.
Trup je proto jeden loft z elipsových řezů a všechny zápustky se do něj
boolean řežou, dokud je to čistý manifold. Švy a límec jádra se přidávají
až úplně nakonec (poučení z Hana: boolean na slepenci dělá kaši).

Cisterna se do pláště NEřeže — kopule dílu 05 je do něj zapuštěná, takže
trup zůstává uzavřený a nekouká se dovnitř na rub stěn.

Objekty: DUL_Hull
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

PREFIXES = ("DUL_Hull", "DUL_Seam", "DUL_Fairing")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DUL_Hull",))
    coll = nc.collection("DUL_Hull", parent_collection or nc.collection("DUL"))

    p = nc.p

    # --- torpédo -----------------------------------------------------------
    hull = nc.hull_loft("DUL_Hull", S.HULL_SECTIONS, segments=S.HULL_SEGMENTS,
                        coll=coll, material=nc.mat("body"), smooth_angle=50)

    # --- zápustky pro kola -------------------------------------------------
    for fwd in S.WHEEL_FWD:
        for side in (-1, 1):
            well = nc.cyl("DUL_HullCut_Well", S.WHEEL_WELL_R, S.WHEEL_WELL_WIDTH,
                          rot=(0, 90, 0),
                          loc=p(fwd, side * S.WHEEL_RIGHT, S.WHEEL_R),
                          verts=24, coll=coll)
            nc.cut(hull, well)

    # --- hrdlo sání v přídi -------------------------------------------------
    # Vrtá se tady, ne v dílu 03: plášť patří tomuhle dílu a všechny zápustky
    # do něj mají jít, dokud je z něj čistý manifold. Díl 03 pak do hotové
    # díry jen posadí hrdlo a mříž.
    axis_up = S.HULL_SECTIONS[0][3]
    nc.cut(hull, nc.cyl("DUL_HullCut_Intake", S.INTAKE_R, S.INTAKE_DEPTH * 2,
                        rot=(90, 0, 0),
                        loc=p(S.HULL_BOW - S.INTAKE_DEPTH, 0.0, axis_up),
                        verts=32, coll=coll))

    # --- obvodové švy ------------------------------------------------------
    seams = []
    for i, fwd in enumerate(S.SEAM_FWD):
        band = []
        for edge in (fwd + S.SEAM_LEN * 0.5, fwd - S.SEAM_LEN * 0.5):
            r_right, r_up, up_center = S.hull_radius(edge)
            band.append((edge, r_right + S.SEAM_GROW, r_up + S.SEAM_GROW, up_center))
        seams.append(nc.hull_loft("DUL_Seam_%d" % i, band, segments=S.HULL_SEGMENTS,
                                  coll=coll, material=nc.mat("body_dark"),
                                  smooth_angle=50))

    # --- límec, kterým jádro sedí na hřbetu --------------------------------
    fair_lo, fair_hi = S.FAIRING_UP
    fairing = nc.cyl("DUL_Fairing", S.FAIRING_R[0], fair_hi - fair_lo,
                     loc=p(S.CORE_FWD, 0.0, (fair_lo + fair_hi) * 0.5),
                     verts=32, coll=coll, material=nc.mat("body_dark"),
                     bevel_w=0.005)
    nc.stretch(fairing, (1.0, S.FAIRING_R[1] / S.FAIRING_R[0], 1.0))

    hull = nc.join([hull] + seams + [fairing], "DUL_Hull")

    print("[NCR] díl 01 — trup: délka %.2fu, největší průřez %.2f x %.2fu"
          % (S.HULL_BOW - S.NOZZLE_FWD[0],
             max(s[1] for s in S.HULL_SECTIONS) * 2,
             max(s[2] for s in S.HULL_SECTIONS) * 2))
    return [hull]


if __name__ == "__main__":
    build()
