# -*- coding: utf-8 -*-
"""
DÍL 02 — Nohy, spec §4 ("6x článkované, přísavky nebo hroty na koncích").

Přísavky, ne hroty: na svislou stěnu sedí líp a nevypadají výhrůžně
(zadání autora — Net nemá působit strašidelně).

Každý článek je samostatný objekt a jeho origin sedí v kloubu, takže
chůze i šplhání jsou rotace kolem kloubů bez jediného přepočtu. Přední
pár míří dopředu a zadní dozadu — tenhle sklon nese orientaci robota
místo obličeje.

Objekty: NET_LegFemur_L0..L2 / _P0..P2, NET_LegTibia_L0..L2 / _P0..P2
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

PREFIXES = ("NET_Leg",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("NET_Legs",))
    coll = nc.collection("NET_Legs", parent_collection or nc.collection("NET"))

    p = nc.p
    parts = []

    for index in range(3):
        for side, tag in ((-1, "L"), (1, "P")):
            name = "%s%d" % (tag, index)
            hip = p(*S.hip_point(index, side))
            knee = p(*S.knee_point(index, side))
            foot = p(*S.foot_point(index, side))

            # --- stehno: kyčel -> koleno --------------------------------
            femur = nc.limb("NET_LegFemur_" + name, hip, knee,
                            size=S.FEMUR_SIZE, coll=coll,
                            material=nc.mat("body"), bevel_w=0.006)
            femur = nc.join([femur,
                             nc.sphere("NET_LegKnee_" + name, S.JOINT_R, loc=knee,
                                       segments=16, rings=10, coll=coll,
                                       material=nc.mat("body_dark"))],
                            "NET_LegFemur_" + name)

            # --- holeň: koleno -> chodidlo ------------------------------
            tibia = nc.limb("NET_LegTibia_" + name, knee, foot,
                            taper=S.TIBIA_R, verts=14, coll=coll,
                            material=nc.mat("body_dark"), smooth_angle=30)

            # --- přísavka -----------------------------------------------
            pad = nc.cyl("NET_LegPad_" + name, S.PAD_R, S.PAD_H,
                         loc=p(S.LEG_FEET[index][0],
                               side * S.LEG_FEET[index][1], S.PAD_H * 0.5),
                         verts=24, coll=coll, material=nc.mat("rubber"),
                         bevel_w=0.005)
            lip = nc.cyl("NET_LegPadLip_" + name, S.PAD_R * 1.14, S.PAD_H * 0.45,
                         loc=p(S.LEG_FEET[index][0],
                               side * S.LEG_FEET[index][1], S.PAD_H * 0.30),
                         verts=24, coll=coll, material=nc.mat("rubber"),
                         bevel_w=0.004)
            tibia = nc.join([tibia, pad, lip], "NET_LegTibia_" + name)

            parts += [femur, tibia]

    print("[NCR] díl 02 — nohy: %d článků (6 nohou), rozkročení %.2fu"
          % (len(parts), max(f[1] for f in S.LEG_FEET) * 2 + S.PAD_R * 2))
    return parts


if __name__ == "__main__":
    build()
