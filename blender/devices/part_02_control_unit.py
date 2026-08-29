# -*- coding: utf-8 -*-
"""
DÍL 02 — Řídicí jednotka (CONTROL_UNIT).

    CTRL_Case
    CTRL_Panel
     └─ CTRL_Screws
    CTRL_Housing
    CTRL_LeverBase        (pevný objímka, nerotuje)
    CTRL_Lever             (páka — Godot ji naklápí kolem lokální X,
                             viz DeviceView.update_control_unit a
                             devices_spec.LEVER_POSE_DEG)

Tlačítko i přepínač (design dok. §2.2.1) jsou týž fyzický panel — liší se
jen `control_mode` a tím, jak Godot páku natočí (dvě polohy pro SWITCH,
jedna klidová pro BUTTON). Stejná krychle vyplňující buňku jako u
`part_01_cabinet.py`, aby obě zařízení vypadala jako jedna rodina.
"""

import bpy
import os
import sys
import types
import importlib
from mathutils import Vector


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
            "blender/devices i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc
S = _ncr_import("devices_spec")

PREFIXES = ("CTRL_",)


def build(parent_collection=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("CONTROL_UNIT",))
    coll = nc.collection("CONTROL_UNIT", parent_collection or nc.collection("DEVICES"))
    p = nc.p

    parts = []
    parts.append(_build_case(p, coll))
    parts.append(_build_panel(p, coll))
    parts.append(_build_housing(p, coll))
    base, lever = _build_lever(p, coll)
    parts.append(base)
    parts.append(lever)

    print("[NCR] díl 02 — řídicí jednotka: %d objektů" % len(parts))
    return parts


def _build_case(p, coll):
    lo, hi = S.CASE_UP
    depth = S.CTRL_CASE_FRONT - S.CASE_BACK
    return nc.box("CTRL_Case", (S.CASE_RIGHT * 2, depth, hi - lo),
                 loc=p((S.CASE_BACK + S.CTRL_CASE_FRONT) * 0.5, 0.0, (lo + hi) * 0.5),
                 coll=coll, material=C.mat("case"), bevel_w=S.CASE_EDGE_BEVEL)


def _build_panel(p, coll):
    lo, hi = S.CTRL_PANEL_UP
    panel = nc.box("CTRL_Panel", (S.CTRL_PANEL_RIGHT * 2, S.CTRL_PANEL_THICK, hi - lo),
                   loc=p(S.CTRL_CASE_FRONT + S.CTRL_PANEL_THICK * 0.5, 0.0, (lo + hi) * 0.5),
                   coll=coll, material=C.mat("door"), bevel_w=0.003)

    screws = []
    corners = [
        (S.CTRL_PANEL_RIGHT - S.CTRL_SCREW_INSET, lo + S.CTRL_SCREW_INSET),
        (-(S.CTRL_PANEL_RIGHT - S.CTRL_SCREW_INSET), lo + S.CTRL_SCREW_INSET),
        (S.CTRL_PANEL_RIGHT - S.CTRL_SCREW_INSET, hi - S.CTRL_SCREW_INSET),
        (-(S.CTRL_PANEL_RIGHT - S.CTRL_SCREW_INSET), hi - S.CTRL_SCREW_INSET),
    ]
    for i, (right, up) in enumerate(corners):
        screws.append(nc.cyl("CTRL_Screw_%d" % i, S.CTRL_SCREW_R, 0.012,
                             rot=(90.0, 0.0, 0.0),
                             loc=p(S.CTRL_PANEL_FRONT + 0.006, right, up),
                             coll=coll, material=C.mat("hinge")))
    screw = nc.join(screws, "CTRL_Screws")

    return nc.join([panel, screw], "CTRL_Panel")


def _build_housing(p, coll):
    lo, hi = S.CTRL_HOUSING_UP
    depth = S.CTRL_HOUSING_FRONT - S.CTRL_PANEL_FRONT
    return nc.box("CTRL_Housing", (S.CTRL_HOUSING_RIGHT * 2, depth, hi - lo),
                 loc=p((S.CTRL_PANEL_FRONT + S.CTRL_HOUSING_FRONT) * 0.5, 0.0, (lo + hi) * 0.5),
                 coll=coll, material=C.mat("lever_base"), bevel_w=0.005)


def _build_lever(p, coll):
    """Páka je postavená rovně "nahoru" z pivotu (lokální +Z, nulová baked
    rotace) — Godot na ni pak aplikuje `rotation_degrees = Vector3(deg,0,0)`
    beze zbytku (viz devices_spec.LEVER_POSE_DEG), takže žádná rotace
    zamíchaná do mesh dat by se s tím prala."""
    lo, hi = S.CTRL_HOUSING_UP
    pivot_up = (lo + hi) * 0.5
    pivot = p(S.CTRL_HOUSING_FRONT, 0.0, pivot_up)

    base = nc.cyl("CTRL_LeverBase", S.CTRL_LEVER_BASE_R, S.CTRL_LEVER_BASE_LEN,
                  rot=(90.0, 0.0, 0.0), loc=pivot,
                  coll=coll, material=C.mat("lever_base"))

    tip = pivot + Vector((0.0, 0.0, S.CTRL_LEVER_LEN))
    lever = nc.limb("CTRL_Lever", pivot, tip, radius=S.CTRL_LEVER_R, verts=14,
                    coll=coll, material=C.mat("lever"), bevel_w=0.003)
    knob = nc.sphere("CTRL_LeverKnob", S.CTRL_LEVER_R * 1.35,
                     loc=pivot + Vector((0.0, 0.0, S.CTRL_LEVER_LEN)),
                     coll=coll, material=C.mat("lever"))
    lever = nc.join([lever, knob], "CTRL_Lever")

    return base, lever


if __name__ == "__main__":
    build()
