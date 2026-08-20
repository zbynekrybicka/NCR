# -*- coding: utf-8 -*-
"""
DÍL 02 — Rotory, spec §5 ("2 na rameno (koaxiální pár) = 8 celkem").

Osm samostatných objektů, každý s originem na své ose — roztočení je tedy
jedna rotace kolem Z. Dolní rotor páru je natočený vůči hornímu, aby byly
z pohledu shora vidět oba disky.

Objekty: DA_Rotor_0H..3H (horní), DA_Rotor_0D..3D (dolní)
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
S = _ncr_import("da_spec")

PREFIXES = ("DA_Rotor",)


def _rotor(name, center, twist, coll):
    span = (S.HUB_CAP_R + S.ROTOR_R) * 0.5
    cap = nc.cone(name, S.HUB_CAP_R, S.HUB_CAP_R * 0.55, 0.026, loc=center,
                  verts=20, coll=coll, material=nc.mat("body"),
                  smooth_angle=30)
    blade = nc.box(name + "_Blade",
                   (S.ROTOR_R - S.HUB_CAP_R, S.BLADE_CHORD, S.BLADE_THICK),
                   loc=center + nc.Vector((span, 0.0, 0.0)),
                   rot=(S.BLADE_PITCH, 0, 0), coll=coll,
                   material=nc.mat("accent_dark"), bevel_w=0.003)
    blades = nc.radial(blade, S.ROTOR_BLADES, axis='Z', center=center)
    rotor = nc.join([cap, blades], name)
    if twist:
        rotor.rotation_mode = 'XYZ'
        rotor.rotation_euler = (0.0, 0.0, nc.radians(twist))
    return rotor


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DA_Rotors",))
    coll = nc.collection("DA_Rotors", parent_collection or nc.collection("DA"))

    lower_up, upper_up = S.ROTOR_UP
    parts = []
    for i, angle in enumerate(S.ARM_ANGLES):
        fwd, right = S.arm_tip(angle)
        parts.append(_rotor("DA_Rotor_%dH" % i, nc.p(fwd, right, upper_up),
                            0.0, coll))
        parts.append(_rotor("DA_Rotor_%dD" % i, nc.p(fwd, right, lower_up),
                            S.ROTOR_OFFSET, coll))

    print("[NCR] díl 02 — rotory: %d kusů, průměr %.2fu, %d listy"
          % (len(parts), S.ROTOR_R * 2, S.ROTOR_BLADES))
    return parts


if __name__ == "__main__":
    build()
