# -*- coding: utf-8 -*-
"""
DÍL 04 — Kloubové rameno, spec §1 ("2-3 segmenty, vpředu, dosah pokrývá
ahead / ahead_below / ahead_diagonal_below").

Každý článek je samostatný objekt a jeho ORIGIN sedí přesně v kloubu —
rotace objektu kolem osy X tedy ohýbá rameno tak, jak se bude animovat
v Godotu, bez jediného přepočtu.

Póza se přepíná v `han_spec.POSE` (POSE_PARKED / POSE_DIG / POSE_CARRY).
Lžíce (díl 05) se natáčí podle třetího článku řetězu.

Objekty:
    HAN_ArmYoke                       vidlice na přídi trupu (statická)
    HAN_Arm_Boom, HAN_Arm_Stick       články, origin v kloubu
    HAN_Ram_Boom_*, HAN_Ram_Stick_*   hydraulické písty (válec + pístnice)
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

PREFIXES = ("HAN_Arm", "HAN_Ram")


def _pin(name, at, width, coll, radius=None):
    """Čep kloubu — válec napříč robotem."""
    return nc.cyl(name, radius or S.PIN_R, width, rot=(0, 90, 0), loc=at,
                  verts=18, coll=coll, material=nc.mat("metal_polish"),
                  bevel_w=0.002)


def build(parent_collection=None, pose=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("HAN_Arm",))
    coll = nc.collection("HAN_Arm", parent_collection or nc.collection("HAN"))

    p = nc.p
    chain = S.arm_chain(pose)
    boom, stick = chain[0], chain[1]

    def pt(node, key):
        fwd, up = node[key]
        return p(fwd, 0.0, up)

    shoulder = pt(boom, "root")
    elbow = pt(boom, "tip")
    wrist = pt(stick, "tip")

    # --- vidlice ramenního kloubu na přídi ---------------------------------
    yoke_parts = []
    for side in (-1, 1):
        plate = nc.box("HAN_ArmYokePlate", (0.020, 0.150, 0.130),
                       loc=p(S.ARM_ROOT[0] - 0.030, side * S.ARM_YOKE_RIGHT,
                             S.ARM_ROOT[1] - 0.020),
                       coll=coll, material=nc.mat("body_dark"), bevel_w=0.006)
        yoke_parts.append(plate)
    yoke_parts.append(nc.box("HAN_ArmYokeBase", (S.ARM_YOKE_RIGHT * 2 + 0.02, 0.120, 0.050),
                             loc=p(S.ARM_ROOT[0] - 0.075, 0.0, S.ARM_ROOT[1] - 0.070),
                             coll=coll, material=nc.mat("body_dark"), bevel_w=0.006))
    yoke_parts.append(_pin("HAN_ArmYokePin", shoulder, S.ARM_YOKE_RIGHT * 2 + 0.05, coll))
    yoke = nc.join(yoke_parts, "HAN_ArmYoke")

    # --- článek 1: výložník ------------------------------------------------
    boom_obj = nc.limb("HAN_Arm_Boom", shoulder, elbow, size=S.BOOM_SIZE, coll=coll,
                       material=nc.mat("body"), bevel_w=0.006)
    boom_obj = nc.join([boom_obj,
                        _pin("HAN_Arm_BoomPin", elbow, S.BOOM_SIZE[0] + 0.030, coll)],
                       "HAN_Arm_Boom")

    # --- článek 2: násada --------------------------------------------------
    stick_obj = nc.limb("HAN_Arm_Stick", elbow, wrist, size=S.STICK_SIZE, coll=coll,
                        material=nc.mat("body"), bevel_w=0.005)
    stick_obj = nc.join([stick_obj,
                         _pin("HAN_Arm_StickPin", wrist, S.STICK_SIZE[0] + 0.028, coll,
                              radius=S.PIN_R * 0.8)],
                        "HAN_Arm_Stick")

    # --- hydraulika --------------------------------------------------------
    boom_dir = (elbow - shoulder).normalized()
    stick_dir = (wrist - elbow).normalized()

    rams = []
    rams += nc.hydraulic("HAN_Ram_Boom",
                         p(S.ARM_ROOT[0] - 0.105, 0.0, S.ARM_ROOT[1] - 0.085),
                         shoulder + boom_dir * (boom["length"] * 0.55) - nc.UP * 0.030,
                         0.022, coll)
    rams += nc.hydraulic("HAN_Ram_Stick",
                         shoulder + boom_dir * (boom["length"] * 0.30) + nc.UP * 0.040,
                         elbow + stick_dir * (stick["length"] * 0.42) + nc.UP * 0.028,
                         0.018, coll)

    parts = [yoke, boom_obj, stick_obj] + rams
    print("[NCR] díl 04 — rameno: %d objektů, póza %s, břit v (fwd %.3f, up %.3f)"
          % (len(parts), (pose if pose is not None else S.POSE),
             chain[2]["tip"][0], chain[2]["tip"][1]))
    return parts


if __name__ == "__main__":
    build()
