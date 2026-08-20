# -*- coding: utf-8 -*-
"""
DÍL 00 — Centrální jednotka ("jádro"), spec §0.1.

Jediný geometricky identický prvek napříč všemi 7 roboty, proto je tenhle
skript parametrizovaný jménem robota a modeluje se jednou. Až přijde druhý
robot, tenhle soubor (a `ncr_common.py`) se přesunou do `blender/common/`
a Han si je jen naimportuje.

    2x polokoule spojené rovníkovým švem, průměr 0.30u (fixní)
    prstenec 14 nýtů na švu
    šedý kov + lesklý lak barvy robota + jemné škrábance
    nápis v hangulu na horní polokouli, čelem k předku robota

Spouštění samostatně: postaví jádro v počátku scény jako samostatný asset.
Volané z `build_han.py`: dostane `at=` a posadí se na krk Hana.
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


# ---------------------------------------------------------------------------

JOIN_SHELL = True     # slepit skořepinu (polokoule + šev + nýty) do 1 objektu


def build(robot="han", hangul=None, rivets=14, name_pitch=38.0,
          at=(0, 0, 0), collection_name="NCR_Core"):
    nc.prepare()
    nc.set_robot(robot)

    prefix = "CORE_%s_" % robot
    nc.purge(prefix)
    coll = nc.collection(collection_name)

    r = nc.CORE_DIAMETER * 0.5          # 0.150
    seam_h = 0.020
    seam_r = r + 0.004
    half_gap = seam_h * 0.5

    # --- dvě polokoule -----------------------------------------------------
    upper = nc.hemisphere(prefix + "Dome_Upper", r, up=True,
                          shift=(0, 0, half_gap), coll=coll,
                          material=nc.mat("core_paint"))
    lower = nc.hemisphere(prefix + "Dome_Lower", r, up=False,
                          shift=(0, 0, -half_gap), coll=coll,
                          material=nc.mat("core_paint"))

    # --- rovníkový šev -----------------------------------------------------
    seam = nc.cyl(prefix + "Seam", seam_r, seam_h, verts=48, coll=coll,
                  material=nc.mat("metal_raw"), bevel_w=0.002, smooth_angle=25)

    # --- prstenec nýtů -----------------------------------------------------
    rivet_r = 0.0095
    shaft = nc.limb(prefix + "Rivet", (seam_r - 0.004, 0, 0), (seam_r + 0.008, 0, 0),
                    radius=rivet_r, verts=10, coll=coll,
                    material=nc.mat("metal_raw"), smooth_angle=35)
    cap = nc.sphere(prefix + "RivetCap", rivet_r, loc=(seam_r + 0.008, 0, 0),
                    segments=10, rings=6, coll=coll, material=nc.mat("metal_raw"))
    one_rivet = nc.join([shaft, cap], prefix + "Rivets")
    rivet_ring = nc.radial(one_rivet, rivets, axis='Z')

    shell = [upper, lower, seam, rivet_ring]
    if JOIN_SHELL:
        # pořadí: skořepina se nikdy neanimuje po částech, tak ať je to 1 mesh
        shell = [nc.join([upper, lower, seam, rivet_ring], prefix + "Shell")]

    # --- nápis v hangulu ---------------------------------------------------
    # Míří dopředu (-Y) a nahoru, tedy na horní polokouli čelem k předku.
    body = hangul if hangul is not None else nc.ROBOT_HANGUL[robot]
    target = shell[0] if JOIN_SHELL else upper
    name = nc.decal_text(prefix + "Name", body, target,
                         center=(0, 0, half_gap),
                         direction=nc.dir_yz(name_pitch),
                         size=0.085, thickness=0.0025,
                         coll=coll, material=nc.mat("core_engrave"))

    parts = shell + [name]
    for obj in parts:                      # posadit na místo (build_han předá `at`)
        obj.location = obj.location + nc.Vector(at)

    print("[NCR] jádro '%s' hotové — %d objektů, průměr %.3fu"
          % (robot, len(parts), nc.CORE_DIAMETER))
    return parts


if __name__ == "__main__":
    build()
