# -*- coding: utf-8 -*-
"""
DÍL 03 — Výsuvná ramena, spec §7 ("Rameno 1 výsuvné, pájecí špička na
konci — tenký, přesný nástroj" a "Rameno 2 výsuvné, USB konektor").

Dvě různé ruce, každá na svou práci: oprava skříně a ovládání panelu.
Pouzdro je pevná část na trupu, tyč s nástrojem je samostatný objekt
s originem v ústí pouzdra — zasunutí je posun podél lokálního Z
(`il_spec.EXTEND`, 0 = zasunuto, 1 = vysunuto).

Objekty: IL_ArmSolder / IL_ArmUSB (tyče), IL_ArmHousing (obě pouzdra)
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
S = _ncr_import("il_spec")

PREFIXES = ("IL_Arm",)


def build(parent_collection=None, extend=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("IL_Arms",))
    coll = nc.collection("IL_Arms", parent_collection or nc.collection("IL"))

    p = nc.p
    out = S.EXTEND if extend is None else extend
    w, h, d = S.ARM_HOUSING

    housings = []
    arms = []

    for tag, right, up, length in (("Solder", -S.ARM_RIGHT, S.SOLDER_UP, S.SOLDER_LEN),
                                   ("USB", S.ARM_RIGHT, S.USB_UP, S.USB_LEN)):
        face = S.body_face(right)
        housings.append(nc.box("IL_ArmHousing_" + tag, (w, d, h),
                               loc=p(face - d * 0.35, right, up), coll=coll,
                               material=nc.mat("body_dark"), bevel_w=0.006))

        # tyč se staví v lokálním rámu (+Z ven z pouzdra) a nakonec se natočí
        if tag == "Solder":
            rod = nc.cyl("IL_ArmSolder", S.SOLDER_R, length,
                         shift=(0, 0, length * 0.5), verts=18, coll=coll,
                         material=nc.mat("metal_raw"), bevel_w=0.003)
            heater = nc.cyl("IL_ArmHeater", S.SOLDER_R * 1.5, 0.026,
                            shift=(0, 0, length - 0.030), verts=18, coll=coll,
                            material=nc.mat("metal_dark"), bevel_w=0.003)
            tip = nc.limb("IL_ArmTip", (0, 0, length), (0, 0, length + 0.034),
                          taper=S.SOLDER_TIP, verts=12, coll=coll,
                          material=nc.mat("worn_edge"))
            rod = nc.join([rod, heater, tip], "IL_ArmSolder")
        else:
            rod = nc.cyl("IL_ArmUSB", S.USB_R, length,
                         shift=(0, 0, length * 0.5), verts=18, coll=coll,
                         material=nc.mat("metal_raw"), bevel_w=0.003)
            pw, pt, pl = S.USB_PLUG
            shell = nc.box("IL_ArmPlug", (pw, pt, pl),
                           shift=(0, 0, length + pl * 0.5), coll=coll,
                           material=nc.mat("metal_polish"), bevel_w=0.002)
            core_bar = nc.box("IL_ArmPlugCore", (pw * 0.66, pt * 0.34, pl * 0.72),
                              shift=(0, 0, length + pl * 0.5), coll=coll,
                              material=nc.mat("accent_dark"))
            rod = nc.join([rod, shell, core_bar], "IL_ArmUSB")

        # Vysunutí je posun podél osy ramene: při out=0 tyč couvne o celou
        # svou délku zpátky do pouzdra, při out=1 stojí v ústí.
        mouth = p(face - d * 0.15, right, up)
        forward = nc.dir_yz(0.0)
        nc.align_to(rod, mouth + forward * (length * (out - 1.0)), forward)
        arms.append(rod)

    housing = nc.join(housings, "IL_ArmHousing")

    print("[NCR] díl 03 — ramena: pájecí a USB, vysunutí %.0f%%" % (out * 100))
    return [housing] + arms


if __name__ == "__main__":
    build()
