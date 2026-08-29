# -*- coding: utf-8 -*-
"""
DÍL 03 — Service kit (KIT, `ItemType.SERVICE_KIT`): stočený drát, kleštičky
a mikropájecí souprava volně vedle sebe (design dok. §2.1.3).

    KIT_Coil     (stočený drát — Screw modifikátor, viz `common.coil()`)
    KIT_Pliers   (dvě zkřížená ramena + čep)
    KIT_Iron     (rukojeť + hrot mikropájky)

Kleště a pájka se skládají u společného počátku (`loc=(0, 0, 0)`, odsazení
jen přes `shift`) a na místo v bundlu je posouvá `common.place_group()` až
po `nc.join()` — stejný princip jako `rot`/`shift` u jednotlivých primitiv,
jen na celé sestavě naráz.
"""

import bpy
import os
import sys
import types
import importlib


def _ncr_import(module_name):
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
            "blender/items i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc
S = _ncr_import("items_spec")

PREFIXES = ("KIT_",)


def build(parent_collection=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("KIT",))
    coll = nc.collection("KIT", parent_collection or nc.collection("ITEMS"))
    p = nc.p

    parts = [_build_coil(p, coll), _build_pliers(coll), _build_iron(coll)]

    root = bpy.data.objects.new("KIT_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    nc.place(root, coll)
    bpy.context.view_layer.update()
    for part in parts:
        nc.parent_to(part, root)

    print("[NCR] díl 03 — service kit: %d objektů" % (len(parts) + 1))
    return [root] + parts


def _build_coil(p, coll):
    return C.coil("KIT_Coil", S.KIT_COIL_R, S.KIT_COIL_WIRE_R, S.KIT_COIL_PITCH,
                  S.KIT_COIL_TURNS, loc=p(*S.KIT_COIL_POS), rot=S.KIT_COIL_ROT,
                  coll=coll, material=C.mat("wire_copper"))


def _build_pliers(coll):
    length = S.KIT_PLIER_JAW_LEN + S.KIT_PLIER_HANDLE_LEN
    pivot_shift = (S.KIT_PLIER_HANDLE_LEN - S.KIT_PLIER_JAW_LEN) * 0.5
    size = (length, S.KIT_PLIER_ARM_WIDTH, S.KIT_PLIER_ARM_THICK)
    half_angle = S.KIT_PLIER_CROSS_ANGLE * 0.5

    arm_a = nc.box("KIT_Plier_ArmA", size, shift=(pivot_shift, 0.0, 0.0),
                   rot=(0.0, 0.0, half_angle), coll=coll, material=C.mat("tool_steel"),
                   bevel_w=0.002)
    arm_b = nc.box("KIT_Plier_ArmB", size, shift=(pivot_shift, 0.0, 0.0),
                   rot=(0.0, 0.0, -half_angle), coll=coll, material=C.mat("tool_steel"),
                   bevel_w=0.002)
    pivot = nc.cyl("KIT_Plier_Pivot", S.KIT_PLIER_PIVOT_R, S.KIT_PLIER_PIVOT_THICK,
                   coll=coll, material=C.mat("tool_steel"), bevel_w=0.001)

    pliers = nc.join([arm_a, arm_b, pivot], "KIT_Pliers")
    return C.place_group(pliers, S.KIT_PLIER_ROT_DEG, nc.p(*S.KIT_PLIER_POS))


def _build_iron(coll):
    grip_end = S.KIT_IRON_GRIP_LEN
    shaft_end = grip_end + S.KIT_IRON_SHAFT_LEN
    tip_end = shaft_end + S.KIT_IRON_TIP_LEN

    grip = nc.cyl("KIT_Iron_Grip", S.KIT_IRON_GRIP_R, S.KIT_IRON_GRIP_LEN,
                  shift=(0.0, 0.0, grip_end * 0.5), coll=coll,
                  material=C.mat("tool_grip"), bevel_w=0.002)
    shaft = nc.cyl("KIT_Iron_Shaft", S.KIT_IRON_SHAFT_R, S.KIT_IRON_SHAFT_LEN,
                   shift=(0.0, 0.0, (grip_end + shaft_end) * 0.5), coll=coll,
                   material=C.mat("tool_steel"))
    tip = nc.cone("KIT_Iron_Tip", S.KIT_IRON_TIP_R1, S.KIT_IRON_TIP_R2, S.KIT_IRON_TIP_LEN,
                  shift=(0.0, 0.0, (shaft_end + tip_end) * 0.5), coll=coll,
                  material=C.mat("iron_tip"))

    iron = nc.join([grip, shaft, tip], "KIT_Iron")
    return C.place_group(iron, S.KIT_IRON_ROT_DEG, nc.p(*S.KIT_IRON_POS))


if __name__ == "__main__":
    build()
