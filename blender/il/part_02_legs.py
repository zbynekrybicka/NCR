# -*- coding: utf-8 -*-
"""
DÍL 02 — Nohy a kola, spec §7 ("kola (2-3, jako u referenčního droida)").

Tři: dvě boční nohy a jedna přední, jako u reference. Přední noha je
zároveň druhý ukazatel orientace vedle nápisu na hlavě.

Každé kolo je samostatný objekt s originem v ose, noha taky — kdyby se
Il někdy narovnával do dvounohého postoje, je to rotace v rameni.

Objekty: IL_Leg_L / _P / _C, IL_Wheel_L / _P / _C
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

PREFIXES = ("IL_Leg", "IL_Wheel")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("IL_Legs",))
    coll = nc.collection("IL_Legs", parent_collection or nc.collection("IL"))

    p = nc.p
    parts = []

    # --- boční nohy ---------------------------------------------------------
    sh_fwd, sh_right, sh_up = S.SIDE_SHOULDER
    ft_fwd, ft_right, ft_up = S.SIDE_FOOT
    for side, tag in ((-1, "L"), (1, "P")):
        leg = nc.limb("IL_Leg_" + tag,
                      p(sh_fwd, side * sh_right, sh_up),
                      p(ft_fwd, side * ft_right, ft_up),
                      size=S.SIDE_LEG_SIZE, coll=coll,
                      material=nc.mat("body"), bevel_w=0.008)
        shoulder = nc.cyl("IL_LegHip_" + tag, 0.052, 0.040, rot=(0, 90, 0),
                          loc=p(sh_fwd, side * sh_right, sh_up), verts=20,
                          coll=coll, material=nc.mat("body_dark"), bevel_w=0.004)
        parts.append(nc.join([leg, shoulder], "IL_Leg_" + tag))

        center = p(ft_fwd, side * ft_right, ft_up)
        tyre = nc.cyl("IL_Wheel_" + tag, S.SIDE_WHEEL_R, S.SIDE_WHEEL_WIDTH,
                      rot=(0, 90, 0), loc=center, verts=28, coll=coll,
                      material=nc.mat("rubber"), bevel_w=0.006)
        disc = nc.cyl("IL_WheelDisc_" + tag, S.SIDE_WHEEL_R * 0.52,
                      S.SIDE_WHEEL_WIDTH * 1.14, rot=(0, 90, 0), loc=center,
                      verts=20, coll=coll, material=nc.mat("metal_raw"),
                      bevel_w=0.004)
        parts.append(nc.join([tyre, disc], "IL_Wheel_" + tag))

    # --- přední noha --------------------------------------------------------
    csh_fwd, _, csh_up = S.CENTER_SHOULDER
    cft_fwd, _, cft_up = S.CENTER_FOOT
    leg = nc.limb("IL_Leg_C", p(csh_fwd, 0.0, csh_up), p(cft_fwd, 0.0, cft_up),
                  size=S.CENTER_LEG_SIZE, coll=coll,
                  material=nc.mat("body"), bevel_w=0.006)
    parts.append(leg)

    center = p(cft_fwd, 0.0, cft_up)
    tyre = nc.cyl("IL_Wheel_C", S.CENTER_WHEEL_R, S.CENTER_WHEEL_WIDTH,
                  rot=(0, 90, 0), loc=center, verts=24, coll=coll,
                  material=nc.mat("rubber"), bevel_w=0.005)
    disc = nc.cyl("IL_WheelDisc_C", S.CENTER_WHEEL_R * 0.50,
                  S.CENTER_WHEEL_WIDTH * 1.14, rot=(0, 90, 0), loc=center,
                  verts=18, coll=coll, material=nc.mat("metal_raw"),
                  bevel_w=0.003)
    parts.append(nc.join([tyre, disc], "IL_Wheel_C"))

    print("[NCR] díl 02 — podvozek: 3 kola, rozchod %.2fu, přední noha na fwd %.3f"
          % (S.SIDE_FOOT[1] * 2 + S.SIDE_WHEEL_WIDTH, S.CENTER_FOOT[0]))
    return parts


if __name__ == "__main__":
    build()
