# -*- coding: utf-8 -*-
"""
DÍL 01 — Tělo, spec §4 ("nízké těžiště, chitinózní krunýř").

Jeden hladký loft z elipsových řezů, členěný vystouplými segmentovými
páskami. Nejnižší robot ze všech — celková výška 0.43u.

POZOR (zadání autora, viz net_spec.py): příď je JEN zúžená. Žádné oči,
žádná tykadla, žádná kusadla, nic, co by šlo přečíst jako obličej.
Orientaci nese zúžení přídě, sklon nohou a nápis na jádru.

Objekty: NET_Body
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
S = _ncr_import("net_spec")

PREFIXES = ("NET_Body", "NET_Seam", "NET_Fairing", "NET_Hip")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("NET_Body",))
    coll = nc.collection("NET_Body", parent_collection or nc.collection("NET"))

    p = nc.p

    body = nc.hull_loft("NET_Body", S.BODY_SECTIONS, segments=S.BODY_SEGMENTS,
                        coll=coll, material=nc.mat("body"), smooth_angle=48)

    # --- segmentové pásky ---------------------------------------------------
    seams = []
    for i, fwd in enumerate(S.SEAM_FWD):
        band = []
        for edge in (fwd + S.SEAM_LEN * 0.5, fwd - S.SEAM_LEN * 0.5):
            r_right, r_up, up_center = _section_at(edge)
            band.append((edge, r_right + S.SEAM_GROW, r_up + S.SEAM_GROW, up_center))
        seams.append(nc.hull_loft("NET_Seam_%d" % i, band, segments=S.BODY_SEGMENTS,
                                  coll=coll, material=nc.mat("body_dark"),
                                  smooth_angle=48))

    # --- kyčelní nálitky ----------------------------------------------------
    hips = []
    for index in range(3):
        for side in (-1, 1):
            fwd, right, up = S.hip_point(index, side)
            hips.append(nc.sphere("NET_Hip_%d%d" % (index, side > 0), 0.034,
                                  loc=p(fwd, right, up), segments=18, rings=10,
                                  coll=coll, material=nc.mat("body_dark")))

    # --- lůžko jádra --------------------------------------------------------
    fair_lo, fair_hi = S.FAIRING_UP
    fairing = nc.cyl("NET_Fairing", S.FAIRING_R[0], fair_hi - fair_lo,
                     loc=p(S.CORE_FWD, 0.0, (fair_lo + fair_hi) * 0.5),
                     verts=32, coll=coll, material=nc.mat("body_dark"),
                     bevel_w=0.005)
    nc.stretch(fairing, (1.0, S.FAIRING_R[1] / S.FAIRING_R[0], 1.0))

    body = nc.join([body] + seams + hips + [fairing], "NET_Body")

    print("[NCR] díl 01 — tělo: délka %.2fu, šířka %.2fu, hřbet v %.3f"
          % (S.BODY_BOW - S.BODY_STERN,
             max(s[1] for s in S.BODY_SECTIONS) * 2,
             max(s[2] + s[3] for s in S.BODY_SECTIONS)))
    return [body]


def _section_at(fwd):
    """Lineárně interpolovaný řez těla — na posazení pásků přesně na plášť."""
    secs = S.BODY_SECTIONS
    if fwd >= secs[0][0]:
        return secs[0][1], secs[0][2], secs[0][3]
    if fwd <= secs[-1][0]:
        return secs[-1][1], secs[-1][2], secs[-1][3]
    for a, b in zip(secs, secs[1:]):
        if b[0] <= fwd <= a[0]:
            t = (fwd - a[0]) / (b[0] - a[0])
            return (a[1] + (b[1] - a[1]) * t,
                    a[2] + (b[2] - a[2]) * t,
                    a[3] + (b[3] - a[3]) * t)
    return secs[-1][1], secs[-1][2], secs[-1][3]


if __name__ == "__main__":
    build()
