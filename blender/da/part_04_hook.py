# -*- coding: utf-8 -*-
"""
DÍL 04 — Hák, spec §5 ("hák/gripper na spodní straně trupu, visí dolů,
pro nesený předmět"; "sbírá předmět jen shora").

Visí na ose robota, takže se nabírá svisle dolů — přesně jak spec chce.
Oblouk je prstenec s vyříznutým ústím, ne ohýbaná trubka: boolean na
čistém torusu je spolehlivější než skládání oblouku z článků.

Spodek háku zůstává nad podlahou i po přistání, aby se Da nepostavil
na náklad.

Objekty: DA_Hook
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

PREFIXES = ("DA_Hook",)


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DA_Hook",))
    coll = nc.collection("DA_Hook", parent_collection or nc.collection("DA"))

    p = nc.p
    lo, hi = S.HOOK_SHAFT_UP

    shaft = nc.cyl("DA_Hook", S.HOOK_SHAFT_R, hi - lo,
                   loc=p(0.0, 0.0, (lo + hi) * 0.5), verts=20, coll=coll,
                   material=nc.mat("metal_dark"), bevel_w=0.004)

    # oblouk v svislé rovině robota; rot kolem Y postaví torus "na hranu"
    curve = nc.torus("DA_HookCurve", S.HOOK_MAJOR_R, S.HOOK_MINOR_R,
                     loc=p(0.0, 0.0, S.HOOK_CURVE_UP), rot=(0, 90, 0),
                     major_seg=32, minor_seg=12, coll=coll,
                     material=nc.mat("metal_polish"))

    # ústí háku: vyříznout výseč vpředu nahoře, aby se předmět dal navléct
    gap = nc.box("DA_HookCut", (0.30, S.HOOK_MAJOR_R * 2.4, S.HOOK_MAJOR_R * 2.4),
                 loc=p(-S.HOOK_MAJOR_R * 0.6, 0.0,
                       S.HOOK_CURVE_UP + S.HOOK_MAJOR_R * 0.6),
                 rot=(S.HOOK_GAP * 0.5 - 45.0, 0, 0), coll=coll)
    nc.cut(curve, gap)

    hook = nc.join([shaft, curve], "DA_Hook")

    print("[NCR] díl 04 — hák: visí na ose, spodek v %.3f (nad podlahou)"
          % (S.HOOK_CURVE_UP - S.HOOK_MAJOR_R - S.HOOK_MINOR_R))
    return [hook]


if __name__ == "__main__":
    build()
