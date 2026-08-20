# -*- coding: utf-8 -*-
"""
DÍL 05 — Hrabací lžíce, spec §1 ("otevřená nahoru, use-wear barva —
hlína/rez na hraně").

Korýtko je otevřený profil vytlačený napříč robotem, ústí míří zpátky
k robotovi (hrábne a přitáhne — proto ta orientace). Břit a zuby jsou
samostatné objekty s obnošeným materiálem, aby se rez dala měnit nezávisle
na barvě pláště.

Celá lžíce se staví kolem počátku v lokálním rámu a až nakonec se posadí
na zápěstí — origin objektu proto sedí přesně v čepu a animace zavření
lžíce je jediná rotace kolem X.

Objekty: HAN_Bucket (korýtko + oka), HAN_BucketEdge (břit + zuby)
"""

import bpy
import os
import sys
import types
import importlib
from math import radians, sin, cos


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
            "Nenašel jsem %s.py — otevři přes Text > Open skripty ze složky "
            "robota i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")
S = _ncr_import("han_spec")

PREFIXES = ("HAN_Bucket",)


def _arc_point(radius, angle_deg):
    """Bod na oblouku korýtka v lokálních (y, z); úhel 0 = pryč od čepu."""
    cy, cz = S.BUCKET_CENTER
    a = radians(angle_deg)
    return (cy + radius * cos(a), cz + radius * sin(a))


def build(parent_collection=None, pose=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("HAN_Bucket",))
    coll = nc.collection("HAN_Bucket", parent_collection or nc.collection("HAN"))

    # --- korýtko -----------------------------------------------------------
    start = S.BUCKET_GAP_DIR + S.BUCKET_GAP * 0.5           # břit
    span = 360.0 - S.BUCKET_GAP
    steps = 22
    angles = [start + span * i / steps for i in range(steps + 1)]

    outer = [_arc_point(S.BUCKET_R, a) for a in angles]
    inner = [_arc_point(S.BUCKET_R - S.BUCKET_WALL, a) for a in angles]
    shell = nc.ring_band("HAN_Bucket", outer, inner, S.BUCKET_WIDTH,
                         coll=coll, material=nc.mat("body"),
                         closed=False, smooth_angle=32)

    # --- oka, kterými lžíce visí na zápěstním čepu -------------------------
    lugs = []
    back = _arc_point(S.BUCKET_R - S.BUCKET_WALL * 0.5, 180.0)
    for side in (-1, 1):
        x = side * S.BUCKET_LUG_RIGHT
        lugs.append(nc.limb("HAN_BucketLug", (x, back[0], back[1]), (x, 0.0, 0.0),
                            size=(0.020, 0.052), coll=coll,
                            material=nc.mat("metal_dark"), bevel_w=0.004))
    pin = nc.cyl("HAN_BucketPin", S.PIN_R * 0.7, S.BUCKET_LUG_RIGHT * 2 + 0.04,
                 rot=(0, 90, 0), verts=16, coll=coll,
                 material=nc.mat("metal_polish"))
    shell = nc.join([shell] + lugs + [pin], "HAN_Bucket")

    # --- břit a zuby (use-wear) -------------------------------------------
    lip_y, lip_z = _arc_point(S.BUCKET_R - S.BUCKET_WALL * 0.5, start)
    tangent = (sin(radians(start)), -cos(radians(start)))   # ven z korýtka

    # rot kolem X o (start + 180) postaví břit tečně k oblouku: lokální +Z
    # míří po tečně ven, lokální +Y radiálně dovnitř (tam je tloušťka)
    edge = nc.box("HAN_BucketEdge", (S.BUCKET_WIDTH, S.BUCKET_WALL * 1.6, 0.026),
                  loc=(0.0, lip_y, lip_z),
                  rot=(start + 180.0, 0, 0), coll=coll,
                  material=nc.mat("worn_edge"), bevel_w=0.003)

    teeth = []
    spread = S.BUCKET_WIDTH - S.BUCKET_TOOTH_W * 1.6
    for i in range(S.BUCKET_TEETH):
        t = (i / (S.BUCKET_TEETH - 1.0)) - 0.5
        x = t * spread
        root = (x, lip_y, lip_z)
        tip = (x,
               lip_y + tangent[0] * S.BUCKET_TOOTH_LEN,
               lip_z + tangent[1] * S.BUCKET_TOOTH_LEN)
        teeth.append(nc.limb("HAN_BucketTooth", root, tip,
                             taper=(S.BUCKET_TOOTH_W * 0.6, S.BUCKET_TOOTH_W * 0.22),
                             verts=6, coll=coll, material=nc.mat("worn_edge")))
    edge = nc.join([edge] + teeth, "HAN_BucketEdge")

    # --- posadit na zápěstí a natočit podle řetězu ------------------------
    chain = S.arm_chain(pose)
    link = chain[2]
    wrist = nc.p(link["root"][0], 0.0, link["root"][1])
    direction = nc.dir_yz(link["angle"])
    for obj in (shell, edge):
        nc.align_to(obj, wrist, direction)

    parts = [shell, edge]
    print("[NCR] díl 05 — lžíce: %d objektů, čep v (fwd %.3f, up %.3f), sklon %.0f deg"
          % (len(parts), link["root"][0], link["root"][1], link["angle"]))
    return parts


if __name__ == "__main__":
    build()
