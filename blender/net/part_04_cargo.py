# -*- coding: utf-8 -*-
"""
DÍL 04 — Schránka a náklad, spec §4 (úložný prostor na zádech, max. 4 kusy).

Dno schránky je vidět, jen když je krunýř otevřený. Předměty jsou čtyři
samostatné objekty a viditelné jsou podle `net_spec.CARGO_COUNT` — stejný
postup jako Hanův náklad hlíny a Dulova voda: stav robota se přepíná
viditelností, ne přestavbou modelu.

Objekty: NET_CargoFloor, NET_Cargo_0..3 (skryté podle počtu)
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

PREFIXES = ("NET_Cargo",)


def build(parent_collection=None, count=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("NET_Cargo",))
    coll = nc.collection("NET_Cargo", parent_collection or nc.collection("NET"))

    p = nc.p
    carried = S.CARGO_COUNT if count is None else count

    fwd_lo, fwd_hi = S.FLOOR_FWD
    up_lo, up_hi = S.FLOOR_UP
    floor = nc.box("NET_CargoFloor", (S.FLOOR_RIGHT * 2, fwd_hi - fwd_lo,
                                      up_hi - up_lo),
                   loc=p((fwd_lo + fwd_hi) * 0.5, 0.0, (up_lo + up_hi) * 0.5),
                   coll=coll, material=nc.mat("body_dark"), bevel_w=0.004)

    parts = [floor]
    size = S.CARGO_SIZE
    for i, (fwd, right) in enumerate(S.CARGO_AT):
        item = nc.box("NET_Cargo_%d" % i, size,
                      loc=p(fwd, right, S.CARGO_UP + size[2] * 0.5),
                      coll=coll, material=nc.mat("metal_raw"), bevel_w=0.006)
        band = nc.box("NET_CargoBand_%d" % i,
                      (size[0] * 1.04, size[1] * 0.22, size[2] * 1.04),
                      loc=p(fwd, right, S.CARGO_UP + size[2] * 0.5),
                      coll=coll, material=nc.mat("metal_dark"), bevel_w=0.003)
        item = nc.join([item, band], "NET_Cargo_%d" % i)
        if i >= carried:
            item.hide_viewport = True
            item.hide_render = True
        parts.append(item)

    print("[NCR] díl 04 — schránka: veze %d ze 4 předmětů%s"
          % (carried, ", krunýř se nedovře" if carried >= S.CARGO_OPEN_FROM else ""))
    return parts


if __name__ == "__main__":
    build()
