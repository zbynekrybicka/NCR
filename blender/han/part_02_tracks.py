# -*- coding: utf-8 -*-
"""
DÍL 02 — Pásy a kola, spec §1 + §0.3 ("kola/nohy jsou vždy samostatné
objekty kvůli budoucí animaci").

Pás je uzavřený prstenec s dírou uprostřed, takže skrz něj jsou vidět
pojezdová kola — proto se vyplatí kola modelovat pořádně. Ostruhy tvoří
vnější povrch pásu a spodní z nich se dotýkají podlahy buňky (z = -0.5).

Objekty (pro každou stranu L/R):
    HAN_Track_L / _R          plášť pásu s ostruhami
    HAN_Sprocket_L / _R       hnací řetězka vzadu
    HAN_Idler_L / _R          napínací kolo vpředu
    HAN_Wheel_L0..3 / _R0..3  pojezdová kola
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

PREFIXES = ("HAN_Track", "HAN_Sprocket", "HAN_Idler", "HAN_Wheel")


def _belt(side, tag, coll):
    """Plášť pásu: prstencový profil vytlačený napříč + ostruhy."""
    outer = nc.stadium(S.TRACK_LEN - 2 * S.GROUSER_H, S.BELT_OUTER_R, arc_steps=12)
    inner = nc.stadium(S.TRACK_LEN - 2 * S.GROUSER_H - 2 * S.BELT_THICK,
                       S.BELT_INNER_R, arc_steps=12)

    belt = nc.ring_band("HAN_Track_" + tag, outer, inner, S.TRACK_WIDTH,
                        loc=nc.p(0.0, side * S.TRACK_RIGHT, S.TRACK_R),
                        coll=coll, material=nc.mat("rubber"))
    nc.bevel(belt, 0.003, segments=1, angle=50)

    # ostruhy na rovných úsecích — dolní řada tvoří dosedací plochu
    run_len = (S.GROUSER_COUNT - 1) * S.GROUSER_FWD
    for name, up in (("Lo", S.GROUSER_H * 0.5),
                     ("Hi", S.TRACK_HEIGHT - S.GROUSER_H * 0.5)):
        row = nc.box("HAN_TrackGrouser_%s_%s" % (tag, name),
                     (S.TRACK_WIDTH, S.GROUSER_LEN, S.GROUSER_H),
                     loc=nc.p(-run_len * 0.5, side * S.TRACK_RIGHT, up),
                     coll=coll, material=nc.mat("rubber"), bevel_w=0.002)
        # -Y = dopředu, takže pole musí růst v záporném Y
        nc.array(row, S.GROUSER_COUNT, (0.0, -S.GROUSER_FWD, 0.0))
        belt = nc.join([belt, row], "HAN_Track_" + tag)

    return belt


def _sprocket(name, radius, fwd, side, teeth, coll):
    """Kolo ležící na ose X (napříč robotem); teeth=0 => hladké kolo."""
    center = nc.p(fwd, side * S.TRACK_RIGHT, S.TRACK_R)
    disc = nc.cyl(name, radius, S.TRACK_WIDTH * 0.62, rot=(0, 90, 0), loc=center,
                  verts=28, coll=coll, material=nc.mat("metal_dark"), bevel_w=0.003)
    hub = nc.cyl(name + "_Hub", radius * 0.34, S.TRACK_WIDTH * 0.82, rot=(0, 90, 0),
                 loc=center, verts=16, coll=coll, material=nc.mat("metal_raw"),
                 bevel_w=0.002)
    parts = [disc, hub]

    if teeth:
        tooth = nc.box(name + "_Tooth", (S.TRACK_WIDTH * 0.5, 0.014, 0.020),
                       loc=center + nc.Vector((0.0, 0.0, radius + 0.006)),
                       coll=coll, material=nc.mat("metal_dark"), bevel_w=0.002)
        parts.append(nc.radial(tooth, teeth, axis='X', center=center))

    return nc.join(parts, name)


def _road_wheel(name, fwd, side, coll):
    center = nc.p(fwd, side * S.TRACK_RIGHT, S.ROAD_UP)
    tyre = nc.cyl(name, S.ROAD_R, S.TRACK_WIDTH * 0.52, rot=(0, 90, 0), loc=center,
                  verts=24, coll=coll, material=nc.mat("rubber"), bevel_w=0.003)
    hub = nc.cyl(name + "_Hub", S.ROAD_R * 0.46, S.TRACK_WIDTH * 0.66, rot=(0, 90, 0),
                 loc=center, verts=16, coll=coll, material=nc.mat("metal_raw"),
                 bevel_w=0.002)
    return nc.join([tyre, hub], name)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("HAN_Tracks",))
    coll = nc.collection("HAN_Tracks", parent_collection or nc.collection("HAN"))

    parts = []
    for side, tag in ((-1, "L"), (1, "R")):
        parts.append(_belt(side, tag, coll))
        parts.append(_sprocket("HAN_Sprocket_" + tag, S.DRIVE_R, -S.DRIVE_FWD, side,
                               S.DRIVE_TEETH, coll))
        parts.append(_sprocket("HAN_Idler_" + tag, S.DRIVE_R * 0.92, S.DRIVE_FWD, side,
                               0, coll))
        for i, fwd in enumerate(S.ROAD_FWD):
            parts.append(_road_wheel("HAN_Wheel_%s%d" % (tag, i), fwd, side, coll))

    print("[NCR] díl 02 — pásy a kola: %d objektů" % len(parts))
    return parts


if __name__ == "__main__":
    build()
