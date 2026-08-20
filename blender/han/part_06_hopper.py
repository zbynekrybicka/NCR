# -*- coding: utf-8 -*-
"""
DÍL 06 — Korba, spec §1 ("na zádech, orientace dozadu, sklopná, čep vzadu
dole; stav prázdná vs plná musí být čitelný zvenku").

Čitelnost stavu je vyřešená obojím, co spec nabízí: v bocích i v čele korby
jsou průhledy a náklad je samostatný objekt `HAN_HopperLoad`, který se
zapíná/vypíná viditelností. Prázdná korba je proto výchozí stav.

Origin korby leží v čepu (vzadu dole), takže vyklopení je jediná rotace
kolem X — `han_spec.HOPPER_TIP_ANGLE`.

Objekty:
    HAN_Hopper          skořepina s průhledy, origin v čepu
    HAN_HopperLoad      hromada hlíny (skrytá = stav "prázdná")
    HAN_Ram_Hopper_*    zvedací píst (válec + pístnice)
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
S = _ncr_import("han_spec")

PREFIXES = ("HAN_Hopper", "HAN_Ram_Hopper")


def build(parent_collection=None, tip_angle=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("HAN_Hopper",))
    coll = nc.collection("HAN_Hopper", parent_collection or nc.collection("HAN"))

    p = nc.p
    fwd_lo, fwd_hi = S.HOPPER_FWD
    up_lo, up_hi = S.HOPPER_UP
    length = fwd_hi - fwd_lo
    height = up_hi - up_lo
    width = S.HOPPER_RIGHT * 2
    w = S.HOPPER_WALL
    fwd_mid = (fwd_lo + fwd_hi) * 0.5
    wall_mid = up_lo + w + (height - w) * 0.5

    # --- skořepina: dno, čelo, záď, boky (nahoře otevřená) -----------------
    #
    # Průhledy se řežou do JEDNOTLIVÝCH stěn, ještě než se skořepina slepí.
    # Boolean pouštěný až na slepenou skořepinu totiž naráží na spoustu
    # koincidentních stěn (dno se dotýká boků hranou na hranu) a EXACT solver
    # z toho udělá kaši — v prvním pokusu z korby zbylo pár natažených plátů.
    win_fwd, win_up = S.HOPPER_WINDOW_SIZE

    floor = nc.box("HAN_HopperFloor", (width, length, w),
                   loc=p(fwd_mid, 0.0, up_lo + w * 0.5),
                   coll=coll, material=nc.mat("body_dark"), bevel_w=0.004)
    front = nc.box("HAN_HopperFront", (width, w, height - w),
                   loc=p(fwd_hi - w * 0.5, 0.0, wall_mid),
                   coll=coll, material=nc.mat("body"), bevel_w=0.004)
    back = nc.box("HAN_HopperBack", (width, w, height - w),
                  loc=p(fwd_lo + w * 0.5, 0.0, wall_mid),
                  coll=coll, material=nc.mat("body"), bevel_w=0.004)
    nc.cut(back, nc.box("HAN_HopperCut", (0.200, w * 4, 0.120),
                        loc=p(fwd_lo, 0.0, up_lo + 0.130), coll=coll))

    pieces = [floor, front, back]
    for side in (-1, 1):
        wall = nc.box("HAN_HopperSide", (w, length - 2 * w, height - w),
                      loc=p(fwd_mid, side * (S.HOPPER_RIGHT - w * 0.5), wall_mid),
                      coll=coll, material=nc.mat("body"), bevel_w=0.004)
        for fwd, up in S.HOPPER_WINDOWS:
            nc.cut(wall, nc.box("HAN_HopperCut", (w * 4, win_fwd, win_up),
                                loc=p(fwd, side * S.HOPPER_RIGHT, up), coll=coll))
        nc.bevel(wall, 0.0025, segments=2, angle=55)
        pieces.append(wall)

    # obruba kolem ústí, aby korba nepůsobila jako krabice z papíru
    rim = 0.016
    for side in (-1, 1):
        pieces.append(nc.box("HAN_HopperRim", (w * 1.8, length, rim),
                             loc=p(fwd_mid, side * (S.HOPPER_RIGHT - w * 0.5), up_hi + rim * 0.4),
                             coll=coll, material=nc.mat("body_dark"), bevel_w=0.003))
    for fwd in (fwd_lo + w * 0.5, fwd_hi - w * 0.5):
        pieces.append(nc.box("HAN_HopperRim", (width, w * 1.8, rim),
                             loc=p(fwd, 0.0, up_hi + rim * 0.4),
                             coll=coll, material=nc.mat("body_dark"), bevel_w=0.003))

    hopper = nc.join(pieces, "HAN_Hopper")

    # --- závěs a čep -------------------------------------------------------
    pivot_fwd, pivot_up = S.HOPPER_PIVOT
    hinge = []
    for side in (-1, 1):
        hinge.append(nc.box("HAN_HopperHinge", (0.030, 0.070, 0.055),
                            loc=p(pivot_fwd + 0.020, side * (S.HOPPER_RIGHT - 0.030),
                                  pivot_up - 0.010),
                            coll=coll, material=nc.mat("metal_dark"), bevel_w=0.005))
    hinge.append(nc.cyl("HAN_HopperPin", 0.016, S.HOPPER_RIGHT * 2 - 0.020,
                        rot=(0, 90, 0), loc=p(pivot_fwd, 0.0, pivot_up),
                        verts=16, coll=coll, material=nc.mat("metal_polish")))
    hopper = nc.join([hopper] + hinge, "HAN_Hopper")

    # origin do čepu -> vyklopení je jedna rotace kolem X
    nc.set_origin(hopper, p(pivot_fwd, 0.0, pivot_up))
    angle = S.HOPPER_TIP_ANGLE if tip_angle is None else tip_angle
    if angle:
        hopper.rotation_mode = 'XYZ'
        hopper.rotation_euler = (nc.radians(angle), 0.0, 0.0)

    # --- zvedací píst ------------------------------------------------------
    ram = nc.hydraulic("HAN_Ram_Hopper",
                       p(S.RAM_FROM[0], 0.0, S.RAM_FROM[1]),
                       p(S.RAM_TO[0], 0.0, S.RAM_TO[1]),
                       S.RAM_R, coll)

    # --- náklad: stav "korba plná" ----------------------------------------
    load = None
    if S.BUILD_LOAD:
        sx, sy, sz = S.LOAD_SIZE
        load = nc.sphere("HAN_HopperLoad", 1.0, segments=32, rings=16, coll=coll,
                         material=nc.mat("dirt"), smooth_angle=60)
        load.data.transform(nc.Matrix.Diagonal(nc.Vector((sx, sy, sz))).to_4x4())
        load.location = p(S.LOAD_AT[0], 0.0, S.LOAD_AT[1])

        tex = bpy.data.textures.get("NCR_dirt_noise") or \
            bpy.data.textures.new("NCR_dirt_noise", type='CLOUDS')
        tex.noise_scale = 0.09
        disp = load.modifiers.new("ncr_dirt", 'DISPLACE')
        disp.texture = tex
        disp.texture_coords = 'LOCAL'
        disp.strength = 0.030
        disp.mid_level = 0.5
        nc.apply_modifier(load, disp.name)

        # výchozí stav robota je "korba prázdná"
        load.hide_viewport = True
        load.hide_render = True

    parts = [hopper] + ram + ([load] if load else [])
    print("[NCR] díl 06 — korba: %d objektů, čep v (fwd %.3f, up %.3f), náklad skrytý"
          % (len(parts), pivot_fwd, pivot_up))
    return parts


if __name__ == "__main__":
    build()
