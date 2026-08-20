# -*- coding: utf-8 -*-
"""
DÍL 01 — Rám, blatníky a čelní deska, spec §3 ("kola, robustnější než Han
— statická pozice při palbě").

Robustnost se dělá proporcemi, ne detaily: těžký rám nízko u země, široký
rozchod, blatník přes celá kola a čelní deska. Silueta má působit zapřeně.

Objekty: SET_Frame, SET_Deck, SET_Bumper
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

PREFIXES = ("SET_Frame", "SET_Deck", "SET_Bumper", "SET_Axle")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("SET_Chassis",))
    coll = nc.collection("SET_Chassis", parent_collection or nc.collection("SET"))

    p = nc.p
    frame_lo, frame_hi = S.FRAME_UP

    # --- nosný rám mezi koly ----------------------------------------------
    frame = nc.box("SET_Frame", (S.FRAME_RIGHT * 2, S.FRAME_FWD * 2,
                                 frame_hi - frame_lo),
                   loc=p(0.0, 0.0, (frame_lo + frame_hi) * 0.5), coll=coll,
                   material=nc.mat("body_dark"), bevel_w=0.008)

    # nápravy — u šesti kol jsou tři a jsou vidět, tak ať nejsou z ničeho
    beams = []
    for i, fwd in enumerate(S.WHEEL_FWD):
        beams.append(nc.limb("SET_Axle_%d" % i,
                             p(fwd, -S.WHEEL_RIGHT, S.WHEEL_R),
                             p(fwd, S.WHEEL_RIGHT, S.WHEEL_R),
                             radius=0.034, verts=16, coll=coll,
                             material=nc.mat("metal_dark")))
    frame = nc.join([frame] + beams, "SET_Frame")

    # --- blatník ------------------------------------------------------------
    deck_lo, deck_hi = S.DECK_UP
    deck = nc.box("SET_Deck", (S.DECK_RIGHT * 2, S.DECK_FWD * 2, deck_hi - deck_lo),
                  loc=p(0.0, 0.0, (deck_lo + deck_hi) * 0.5), coll=coll,
                  material=nc.mat("body"), bevel_w=0.006)
    for fwd in (0.150, -0.150):
        nc.cut(deck, nc.box("SET_DeckCut", (S.DECK_RIGHT * 2.2, 0.011, 0.018),
                            loc=p(fwd, 0.0, deck_hi - 0.004), coll=coll))
    nc.bevel(deck, 0.0015, segments=1, angle=60)

    lips = []
    for side in (-1, 1):
        lips.append(nc.box("SET_DeckLip", (0.024, S.DECK_FWD * 2, 0.062),
                           loc=p(0.0, side * (S.DECK_RIGHT - 0.012), deck_lo - 0.012),
                           coll=coll, material=nc.mat("body"), bevel_w=0.004))
    deck = nc.join([deck] + lips, "SET_Deck")

    # --- čelní deska --------------------------------------------------------
    b_lo, b_hi = S.BUMPER_FWD
    bu_lo, bu_hi = S.BUMPER_UP
    bumper = nc.box("SET_Bumper", (S.BUMPER_RIGHT * 2, b_hi - b_lo, bu_hi - bu_lo),
                    loc=p((b_lo + b_hi) * 0.5, 0.0, (bu_lo + bu_hi) * 0.5),
                    coll=coll, material=nc.mat("body_dark"), bevel_w=0.010)
    ribs = []
    for side in (-1, 1):
        for r in (0.090, 0.210):
            ribs.append(nc.box("SET_BumperRib", (0.030, b_hi - b_lo + 0.018, 0.030),
                               loc=p((b_lo + b_hi) * 0.5, side * r,
                                     (bu_lo + bu_hi) * 0.5),
                               coll=coll, material=nc.mat("metal_dark"),
                               bevel_w=0.004))
    bumper = nc.join([bumper] + ribs, "SET_Bumper")

    parts = [frame, deck, bumper]
    print("[NCR] díl 01 — podvozek: rozchod %.2fu, rám %.2fu nad zemí"
          % ((S.WHEEL_RIGHT + S.WHEEL_WIDTH * 0.5) * 2, S.FRAME_UP[0]))
    return parts


if __name__ == "__main__":
    build()
