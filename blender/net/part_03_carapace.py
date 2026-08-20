# -*- coding: utf-8 -*-
"""
DÍL 03 — Krunýř, spec §4 ("sklopný/otevírací krunýř jako úložný prostor —
vizuálně odlišit 'nese 0-2' vs 'nese 3-4' předměty").

Klenutá skořepina na zádech, čep vpředu — zvedá se tedy vzadu a odkryje
schránku. Rozdíl 0-2 vs 3-4 předměty se čte právě z toho, jestli dosedne,
nebo zůstane pootevřený (`net_spec.CARGO_COUNT`).

Skořepina vzniká jako plný loft a spodek se odřízne — díky tomu má krunýř
rovnou dosedací rovinu a nikde neprosvítá do těla.

Objekty: NET_Carapace
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

PREFIXES = ("NET_Carapace",)


def build(parent_collection=None, open_angle=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("NET_Carapace",))
    coll = nc.collection("NET_Carapace", parent_collection or nc.collection("NET"))

    p = nc.p

    shell = nc.hull_loft("NET_Carapace", S.CARAPACE_SECTIONS,
                         segments=S.CARAPACE_SEGMENTS, coll=coll,
                         material=nc.mat("body"), smooth_angle=48)
    _flatten(shell, coll)

    # --- příčná žebra -------------------------------------------------------
    ribs = []
    for i, fwd in enumerate(S.CARAPACE_RIBS):
        band = []
        for edge in (fwd + S.CARAPACE_RIB_LEN * 0.5, fwd - S.CARAPACE_RIB_LEN * 0.5):
            r_right, r_up = _section_at(edge)
            band.append((edge, r_right + S.CARAPACE_RIB_GROW,
                         r_up + S.CARAPACE_RIB_GROW, S.CARAPACE_BASE))
        rib = nc.hull_loft("NET_CarapaceRib_%d" % i, band,
                           segments=S.CARAPACE_SEGMENTS, coll=coll,
                           material=nc.mat("body_dark"), smooth_angle=48)
        _flatten(rib, coll)
        ribs.append(rib)

    # --- závěs --------------------------------------------------------------
    hinge_fwd, hinge_up = S.CARAPACE_HINGE
    lugs = []
    for side in (-1, 1):
        lugs.append(nc.box("NET_CarapaceLug", (0.024, 0.052, 0.030),
                           loc=p(hinge_fwd - 0.010, side * 0.075, hinge_up + 0.008),
                           coll=coll, material=nc.mat("body_dark"), bevel_w=0.004))
    lugs.append(nc.cyl("NET_CarapacePin", 0.013, 0.190, rot=(0, 90, 0),
                       loc=p(hinge_fwd, 0.0, hinge_up), verts=14, coll=coll,
                       material=nc.mat("metal_polish")))

    shell = nc.join([shell] + ribs + lugs, "NET_Carapace")
    nc.set_origin(shell, p(hinge_fwd, 0.0, hinge_up))

    angle = S.CARAPACE_OPEN if open_angle is None else open_angle
    if angle:
        shell.rotation_mode = 'XYZ'
        shell.rotation_euler = (nc.radians(angle), 0.0, 0.0)

    print("[NCR] díl 03 — krunýř: čep v (fwd %.3f, up %.3f), otevření %.0f deg"
          % (hinge_fwd, hinge_up, angle))
    return [shell]


def _flatten(obj, coll):
    """Odřízne všechno pod dosedací rovinou krunýře."""
    nc.cut(obj, nc.box("NET_CarapaceCut", (1.2, 1.2, 0.60),
                       loc=nc.p(0.0, 0.0, S.CARAPACE_BASE - 0.300), coll=coll))


def _section_at(fwd):
    secs = S.CARAPACE_SECTIONS
    if fwd >= secs[0][0]:
        return secs[0][1], secs[0][2]
    if fwd <= secs[-1][0]:
        return secs[-1][1], secs[-1][2]
    for a, b in zip(secs, secs[1:]):
        if b[0] <= fwd <= a[0]:
            t = (fwd - a[0]) / (b[0] - a[0])
            return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
    return secs[-1][1], secs[-1][2]


if __name__ == "__main__":
    build()
