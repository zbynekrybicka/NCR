# -*- coding: utf-8 -*-
"""
DÍL 01 — Trup, spec §7 ("soudkovitý/válcový, R2-D2 proporce" + "černé
akcenty na žluté karoserii").

Součástí je i krční prstenec, na kterém sedí hlava. Ta je u Ila zároveň
jádrem — spec §7 říká, že právě u něj hlava s pozicí jádra splývá
nejpřirozeněji, tak se čte doslova: žádná kupole navíc, koule sedí přímo
na trupu.

Objekty: IL_Body
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
S = _ncr_import("il_spec")

PREFIXES = ("IL_Body", "IL_Rim", "IL_Stripe", "IL_Panel", "IL_Collar")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("IL_Body",))
    coll = nc.collection("IL_Body", parent_collection or nc.collection("IL"))

    p = nc.p
    up_lo, up_hi = S.BODY_UP

    body = nc.cyl("IL_Body", S.BODY_R, up_hi - up_lo,
                  loc=p(0.0, 0.0, (up_lo + up_hi) * 0.5), verts=S.BODY_SEGMENTS,
                  coll=coll, material=nc.mat("body"), bevel_w=0.010,
                  smooth_angle=22)

    pieces = [body]

    # --- obruby -------------------------------------------------------------
    for up in (up_lo + S.RIM_H * 0.5, up_hi - S.RIM_H * 0.5):
        pieces.append(nc.cyl("IL_Rim", S.BODY_R + S.RIM_GROW, S.RIM_H,
                             loc=p(0.0, 0.0, up), verts=S.BODY_SEGMENTS,
                             coll=coll, material=nc.mat("body_dark"),
                             bevel_w=0.004, smooth_angle=22))

    # --- černé pruhy --------------------------------------------------------
    for up, height in S.STRIPE_RINGS:
        pieces.append(nc.cyl("IL_Stripe", S.BODY_R + S.STRIPE_GROW, height,
                             loc=p(0.0, 0.0, up), verts=S.BODY_SEGMENTS,
                             coll=coll, material=nc.mat("accent_dark"),
                             bevel_w=0.003, smooth_angle=22))

    w, depth, height = S.PANEL_SIZE
    for angle in S.PANEL_ANGLES:
        fwd, right = _on_body(angle, S.BODY_R)
        # rot kolem Z o úhel panelu postaví desku tečně k plášti
        pieces.append(nc.box("IL_Panel", (w, depth, height),
                             loc=p(fwd, right, S.PANEL_UP),
                             rot=(0, 0, angle), coll=coll,
                             material=nc.mat("accent_dark"), bevel_w=0.004))

    # --- krční prstenec -----------------------------------------------------
    c_lo, c_hi = S.COLLAR_UP
    pieces.append(nc.cyl("IL_Collar", S.COLLAR_R, c_hi - c_lo,
                         loc=p(0.0, 0.0, (c_lo + c_hi) * 0.5),
                         verts=S.BODY_SEGMENTS, coll=coll,
                         material=nc.mat("metal_raw"), bevel_w=0.004,
                         smooth_angle=22))

    body = nc.join(pieces, "IL_Body")

    print("[NCR] díl 01 — trup: prumer %.2fu, vyska %.2fu, %d cernych panelu"
          % (S.BODY_R * 2, up_hi - up_lo, len(S.PANEL_ANGLES)))
    return [body]


def _on_body(angle_deg, radius):
    """(fwd, right) bodu na plášti trupu; úhel 0 = čelo, kladný doprava."""
    from math import radians, cos, sin
    a = radians(angle_deg)
    return (radius * cos(a), radius * sin(a))


if __name__ == "__main__":
    build()
