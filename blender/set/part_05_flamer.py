# -*- coding: utf-8 -*-
"""
DÍL 05 — Plamenomet, spec §3 ("viditelná tryska/ústí jako hlavní
silueta-definující prvek", "vlastní nádrž na hlavici", "ohořelé/začouzené
akcenty kolem ústí hlavně").

Celá hlavice se staví v lokálním rámu, kde počátek je čep náměru a +Z míří
podél hlavně — díky tomu je origin přesně v čepu a náměr je jedna rotace
kolem X. Stejný postup jako u Hanovy lžíce.

Vlastní nádrž je ta malá na hlavici; kanystr, který Set spotřebovává, je
předmět inventáře a s modelem robota nemá nic společného.

Objekty: SET_Flamer (hlaveň + plášť), SET_FlamerMuzzle (ústí, saze),
         SET_FlamerTank (vlastní nádrž)
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

PREFIXES = ("SET_Flamer",)


def build(parent_collection=None, elevation=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("SET_Flamer",))
    coll = nc.collection("SET_Flamer", parent_collection or nc.collection("SET"))

    # --- hlaveň v lokálním rámu (+Z podél hlavně) --------------------------
    barrel = nc.cyl("SET_Flamer", S.BARREL_R, S.BARREL_LEN,
                    shift=(0, 0, S.BARREL_LEN * 0.5), verts=24, coll=coll,
                    material=nc.mat("metal_dark"))
    breech = nc.cyl("SET_FlamerBreech", S.BARREL_R * 1.5, 0.056,
                    shift=(0, 0, 0.020), verts=24, coll=coll,
                    material=nc.mat("body"), bevel_w=0.004)
    j_lo, j_hi = S.JACKET_AT
    jacket = nc.cyl("SET_FlamerJacket", S.JACKET_R, j_hi - j_lo,
                    shift=(0, 0, (j_lo + j_hi) * 0.5), verts=24, coll=coll,
                    material=nc.mat("body"), bevel_w=0.004)
    for i in range(4):    # chladicí prstence
        jacket = nc.join([jacket,
                          nc.cyl("SET_FlamerFin", S.JACKET_R * 1.12, 0.008,
                                 shift=(0, 0, j_lo + 0.018 + i * 0.030),
                                 verts=24, coll=coll, material=nc.mat("body"))],
                         "SET_FlamerJacket")
    pin = nc.cyl("SET_FlamerPin", 0.020, S.TRUNNION_RIGHT * 2 + 0.010,
                 rot=(0, 90, 0), verts=16, coll=coll,
                 material=nc.mat("metal_polish"))

    # Zapalovací hořáček vede POD hlavní a končí až za ústím. Vedle osy by
    # prošel rozšířenou tryskou a vypadal jako propíchnuté ústí.
    pil_lo, pil_hi = S.PILOT_AT
    pilot = nc.cyl("SET_FlamerPilot", S.PILOT_R, pil_hi - pil_lo,
                   loc=(0.0, -S.PILOT_UNDER, 0.0),
                   shift=(0, 0, (pil_lo + pil_hi) * 0.5), verts=12, coll=coll,
                   material=nc.mat("metal_raw"))
    strut = nc.box("SET_FlamerStrut", (0.016, S.PILOT_UNDER, 0.016),
                   loc=(0.0, -S.PILOT_UNDER * 0.5, pil_lo + 0.020),
                   coll=coll, material=nc.mat("metal_raw"), bevel_w=0.002)

    flamer = nc.join([barrel, breech, jacket, pin, pilot, strut], "SET_Flamer")

    # --- ústí: use-wear (spec §3) -----------------------------------------
    muzzle = nc.cone("SET_FlamerMuzzle", S.MUZZLE_R[0], S.MUZZLE_R[1], S.MUZZLE_LEN,
                     shift=(0, 0, S.BARREL_LEN + S.MUZZLE_LEN * 0.5), verts=28,
                     coll=coll, material=nc.mat("soot"), smooth_angle=30)
    nc.cut(muzzle, nc.cyl("SET_FlamerCut", S.MUZZLE_R[1] * 0.62, S.MUZZLE_LEN * 2.4,
                          shift=(0, 0, S.BARREL_LEN + S.MUZZLE_LEN), verts=28,
                          coll=coll))
    scorch = nc.cyl("SET_FlamerScorch", S.BARREL_R * 1.10, 0.030,
                    shift=(0, 0, S.SCORCH_AT), verts=24, coll=coll,
                    material=nc.mat("soot"))
    muzzle = nc.join([muzzle, scorch], "SET_FlamerMuzzle")

    # --- vlastní nádrž na hlavici -----------------------------------------
    up_off, along = S.TANK_OFFSET
    tank = nc.cyl("SET_FlamerTank", S.TANK_R, S.TANK_LEN,
                  loc=(0.0, up_off, along + S.TANK_LEN * 0.5), verts=24,
                  coll=coll, material=nc.mat("body"), bevel_w=0.006)
    for z in (along + 0.028, along + S.TANK_LEN - 0.028):
        tank = nc.join([tank,
                        nc.cyl("SET_FlamerStrap", S.TANK_R * 1.10, 0.012,
                               loc=(0.0, up_off, z), verts=24, coll=coll,
                               material=nc.mat("metal_dark"))],
                       "SET_FlamerTank")
    # konzoly k hlavni + hadice do závěru
    for z in (along + 0.026, along + S.TANK_LEN - 0.026):
        tank = nc.join([tank,
                        nc.box("SET_FlamerBracket",
                               (0.014, up_off - S.TANK_R * 0.5, 0.020),
                               loc=(0.0, up_off - (up_off - S.TANK_R * 0.5) * 0.5 
                                    - S.TANK_R * 0.5 * 0.0, z),
                               coll=coll, material=nc.mat("metal_dark"),
                               bevel_w=0.002)],
                       "SET_FlamerTank")
    tank = nc.join([tank,
                    nc.limb("SET_FlamerHose", (0.0, up_off - 0.020, along + 0.008),
                            (0.0, 0.012, 0.034), radius=0.012, verts=10,
                            coll=coll, material=nc.mat("metal_dark"))],
                   "SET_FlamerTank")

    # --- posadit na čep a natočit -----------------------------------------
    angle = S.ELEVATION if elevation is None else elevation
    trunnion = nc.p(S.RING_FWD, 0.0, S.TRUNNION_UP)
    direction = nc.dir_yz(angle)
    for o in (flamer, muzzle, tank):
        nc.align_to(o, trunnion, direction)

    tip = S.muzzle_tip(angle)
    print("[NCR] díl 05 — plamenomet: náměr %.0f deg, ústí v (fwd %.3f, up %.3f)"
          % (angle, tip[0], tip[1]))
    return [flamer, muzzle, tank]


if __name__ == "__main__":
    build()
