# -*- coding: utf-8 -*-
"""
DÍL 04 — Chladicí hlavice, spec §6 ("velký žebrovaný chladič/radiátor,
umístěný jako hlava, dominantní prvek siluety") + jinovatka na žebrech.

Hlavice je nejvýraznější věc na robotovi — devět žeber mezi dvěma krycími
deskami, po stranách nosníky. Led na žebrech je samostatný objekt
s vlastním materiálem, takže jde jinovatku zesílit nebo úplně vypnout,
aniž se sahá na chladič.

Objekty: YEO_Radiator, YEO_Frost
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

PREFIXES = ("YEO_Radiator", "YEO_Frost")


def build(parent_collection=None, frost=True):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("YEO_Radiator",))
    coll = nc.collection("YEO_Radiator", parent_collection or nc.collection("YEO"))

    p = nc.p
    up_lo, up_hi = S.RAD_UP

    # --- krycí desky --------------------------------------------------------
    pieces = []
    for up in (up_lo + S.PLATE_H * 0.5, up_hi - S.PLATE_H * 0.5):
        pieces.append(nc.box("YEO_RadiatorPlate", (S.RAD_RIGHT * 2, S.RAD_DEPTH * 2,
                                                   S.PLATE_H),
                             loc=p(S.RAD_FWD, 0.0, up), coll=coll,
                             material=nc.mat("body"), bevel_w=0.006))

    # --- rohové sloupky -----------------------------------------------------
    for side in (-1, 1):
        for front in (-1, 1):
            pieces.append(nc.box("YEO_RadiatorPost",
                                 (S.POST_SIZE, S.POST_SIZE, up_hi - up_lo),
                                 loc=p(S.RAD_FWD + front * (S.RAD_DEPTH - S.POST_SIZE * 0.5),
                                       side * (S.RAD_RIGHT - S.POST_SIZE * 0.5),
                                       (up_lo + up_hi) * 0.5),
                                 coll=coll, material=nc.mat("body"), bevel_w=0.005))

    # --- žebra --------------------------------------------------------------
    fin_right = S.RAD_RIGHT - S.FIN_INSET
    for up in S.fin_heights():
        pieces.append(nc.box("YEO_RadiatorFin",
                             (fin_right * 2, (S.RAD_DEPTH - S.FIN_INSET) * 2,
                              S.FIN_THICK),
                             loc=p(S.RAD_FWD, 0.0, up), coll=coll,
                             material=nc.mat("metal_raw"), bevel_w=0.003))

    radiator = nc.join(pieces, "YEO_Radiator")

    parts = [radiator]

    # --- jinovatka na žebrech ----------------------------------------------
    if frost:
        import random
        rng = random.Random(S.FROST_SEED)
        chunks = []
        w, d, h = S.FROST_SIZE
        for up in S.fin_heights():
            for _ in range(S.FROST_PER_FIN):
                depth = S.RAD_DEPTH - S.FIN_INSET
                if rng.random() < 0.6:      # na čele nebo na zádi žebra
                    right = rng.uniform(-fin_right + w, fin_right - w)
                    fwd = S.RAD_FWD + rng.choice((-1.0, 1.0)) * depth
                else:                        # na boku žebra
                    right = rng.choice((-1.0, 1.0)) * fin_right
                    fwd = S.RAD_FWD + rng.uniform(-depth + w, depth - w)
                chunks.append(nc.box("YEO_Frost",
                                     (w * rng.uniform(0.7, 1.3), d,
                                      h * rng.uniform(0.7, 1.3)),
                                     loc=p(fwd, right, up + rng.uniform(-0.004, 0.004)),
                                     rot=(rng.uniform(-14, 14), rng.uniform(-10, 10),
                                          rng.uniform(-14, 14)),
                                     coll=coll, material=nc.mat("ice"),
                                     bevel_w=0.004, bevel_seg=1))
        parts.append(nc.join(chunks, "YEO_Frost"))

    print("[NCR] díl 04 — chladič: %d žeber, hlavice %.2f x %.2f x %.2fu%s"
          % (S.FIN_COUNT, S.RAD_RIGHT * 2, S.RAD_DEPTH * 2, up_hi - up_lo,
             ", s jinovatkou" if frost else ""))
    return parts


if __name__ == "__main__":
    build()
