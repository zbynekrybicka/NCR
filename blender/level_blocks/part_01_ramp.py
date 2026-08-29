# -*- coding: utf-8 -*-
"""
DÍL 01 — Šikmina (RAMP_Wedge).

Jediný díl: klínová geometrie z `common.ramp_wedge()` s ocelovou texturou
(`ramp_spec.RAMP_TEXTURE_FILE`, stejný soubor jako blok WALL). Vysoká svislá
stěna leží na `fwd = +0.5`, tedy na modelovém čele (Blender −Y) — po exportu
(`nc.godot_forward`) z toho bude `Direction.NORTH`, přesně jak čte
`WorldState.is_ramp_rising_toward()`: šikmina s `orientation == NORTH` má
vysokou stranu na severní hraně buňky.
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
            "blender/level_blocks i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc
S = _ncr_import("ramp_spec")

PREFIXES = ("RAMP_",)


def build(parent_collection=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("RAMP",))
    coll = nc.collection("RAMP", parent_collection or nc.collection("LEVEL_BLOCKS"))

    material = C.block_texture_material("ramp_steel", S.RAMP_TEXTURE_FILE,
                                         metallic=S.RAMP_METALLIC, rough=S.RAMP_ROUGHNESS)
    wedge = C.ramp_wedge("RAMP_Wedge", coll, material, uv_scale=S.RAMP_UV_SCALE)

    print("[NCR] díl 01 — šikmina: 1 objekt")
    return [wedge]


if __name__ == "__main__":
    build()
