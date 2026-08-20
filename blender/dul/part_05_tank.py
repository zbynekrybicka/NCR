# -*- coding: utf-8 -*-
"""
DÍL 05 — Cisterna, spec §2 ("vnitřní objem naznačený průhledem/poklopem
nahoře").

Spec chce objem *naznačit*, ne otevřít — proto průhledná kopule na hřbetu
a v ní hladina, ne díra do trupu. První pokus vedl otvor do pláště a pod
něj vanu; jenže hřbet je zakřivený a zužuje se, takže plochý lem otvoru
na něm v jednom místě trčel a v druhém se propadal. Kopule zapuštěná pod
povrch (`TANK_SINK`) tenhle problém nemá: její pata je schovaná v plášti
všude, ať se povrch svažuje jakkoli.

Stav "plná/prázdná" je čitelný zvenku stejně jako u Hanovy korby — voda je
samostatný objekt a výchozí stav robota je prázdná cisterna.

Objekty: DUL_TankGlass (kopule), DUL_TankRim (límec), DUL_TankWater (skrytá)
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
            "Nenašel jsem %s.py — otevři přes Text > Open skripty ze složky "
            "robota i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")
S = _ncr_import("dul_spec")

PREFIXES = ("DUL_Tank",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DUL_Tank",))
    coll = nc.collection("DUL_Tank", parent_collection or nc.collection("DUL"))

    p = nc.p
    fwd_lo, fwd_hi = S.TANK_FWD
    mid = (fwd_lo + fwd_hi) * 0.5
    squash = (fwd_hi - fwd_lo) * 0.5 / S.TANK_RIGHT   # protažení dopředu/dozadu

    deck = S.hull_top(mid)                # hřbet v místě kopule
    base = deck - S.TANK_SINK             # pata kopule, schovaná v plášti
    height = S.TANK_SINK + S.TANK_RISE    # celá výška polokoule

    # --- kopule ------------------------------------------------------------
    glass = nc.hemisphere("DUL_TankGlass", S.TANK_RIGHT, up=True,
                          loc=p(mid, 0.0, base), segments=40, rings=20,
                          coll=coll, material=nc.mat("glass"))
    nc.stretch(glass, (1.0, squash, height / S.TANK_RIGHT))

    # --- límec kolem paty --------------------------------------------------
    # Sahá hluboko pod povrch, takže se o zakřivení hřbetu nemusí starat —
    # ven kouká jen tolik, kolik plášť odkryje.
    rim = nc.cyl("DUL_TankRim", S.TANK_RIGHT + S.TANK_RIM, S.TANK_SINK + 0.020,
                 loc=p(mid, 0.0, base + (S.TANK_SINK + 0.020) * 0.5 - 0.012),
                 verts=40, coll=coll, material=nc.mat("metal_raw"))
    nc.stretch(rim, (1.0, squash, 1.0))
    # Vyříznout válec by nechalo kolem kopule mezeru — plášť je zakřivený,
    # takže kopule je v úrovni hřbetu užší než její pata. Řeže se proto
    # kopií kopule, o kousek větší: límec pak k jejímu boku přilne.
    grow = 1.045
    bore = nc.hemisphere("DUL_TankCut", S.TANK_RIGHT * grow, up=True,
                         loc=p(mid, 0.0, base - 0.001), segments=40, rings=20,
                         coll=coll)
    nc.stretch(bore, (1.0, squash, height * grow / S.TANK_RIGHT))
    nc.cut(rim, bore)

    parts = [glass, rim]

    # --- hladina: stav "cisterna plná" ------------------------------------
    if S.BUILD_WATER:
        shrink = 0.94
        water = nc.hemisphere("DUL_TankWater", S.TANK_RIGHT * shrink, up=True,
                              loc=p(mid, 0.0, base), segments=32, rings=16,
                              coll=coll, material=nc.mat("water"))
        nc.stretch(water, (1.0, squash, height * shrink / S.TANK_RIGHT))
        # rovná hladina: uříznout vršek kopule vody
        level = base + height * shrink * S.WATER_FILL
        nc.cut(water, nc.box("DUL_TankCut", (0.40, 0.40, 0.40),
                             loc=p(mid, 0.0, level + 0.20), coll=coll))
        water.hide_viewport = True     # výchozí stav robota je "prázdná"
        water.hide_render = True
        parts.append(water)

    print("[NCR] díl 05 — cisterna: %d objektů, kopule %.2f x %.2fu, "
          "vyčnívá %.3fu, voda skrytá"
          % (len(parts), S.TANK_RIGHT * 2, fwd_hi - fwd_lo, S.TANK_RISE))
    return parts


if __name__ == "__main__":
    build()
