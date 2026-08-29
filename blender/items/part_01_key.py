# -*- coding: utf-8 -*-
"""
DÍL 01 — Klíč (KEY).

    KEY_Bow      (hlava s dírou pro prsty/kroužek)
    KEY_Shank    (dřík)
    KEY_Collar   (límec mezi dříkem a čepelí)
    KEY_Blade    (plochá čepel se zuby)

Všechno se staví "na ležato" podél osy `right` u `up = CENTER_UP` (střed
buňky), zavěsí se pod `KEY_Root` a ten se nakloní o `KEY_TILT_DEG` kolem osy
`fwd` (zadání: "nakloněný 45° od vodorovné polohy") — díly samy o náklonu
nic nevědí, stejný princip jako `CTRL_Lever` u zařízení.
"""

import bpy
import os
import sys
import types
import importlib
from math import radians


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

PREFIXES = ("KEY_",)


def build(parent_collection=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("KEY",))
    coll = nc.collection("KEY", parent_collection or nc.collection("ITEMS"))
    p = nc.p

    parts = []
    parts.append(_build_bow(p, coll))
    parts.append(_build_shank(p, coll))
    parts.append(_build_collar(p, coll))
    parts.append(_build_blade(p, coll))

    root = bpy.data.objects.new("KEY_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    nc.place(root, coll)
    bpy.context.view_layer.update()
    for part in parts:
        nc.parent_to(part, root)

    # Náklon AŽ PO zavěšení dílů: `parent_to()` počítá `matrix_parent_inverse`
    # z aktuální transformace rodiče, takže rotace nastavená před zavěšením by
    # se tímhle přepočtem vyrušila (děti by zůstaly navenek ležet vodorovně).
    root.rotation_euler.y = radians(S.KEY_TILT_DEG)

    print("[NCR] díl 01 — klíč: %d objektů" % (len(parts) + 1))
    return [root] + parts


def _build_bow(p, coll):
    loc = p(0.0, S.KEY_BOW_CENTER_RIGHT, S.CENTER_UP)
    bow = nc.cyl("KEY_Bow", S.KEY_BOW_OUTER_R, S.KEY_BOW_THICK,
                 rot=(90.0, 0.0, 0.0), loc=loc, coll=coll, material=C.mat("brass"),
                 bevel_w=0.003)
    hole = nc.cyl("KEY_Bow_Hole", S.KEY_BOW_INNER_R, S.KEY_BOW_THICK * 3.0,
                  rot=(90.0, 0.0, 0.0), loc=loc, coll=coll)
    return nc.cut(bow, hole)


def _build_shank(p, coll):
    a = p(0.0, S.KEY_SHANK_RIGHT[0], S.CENTER_UP)
    b = p(0.0, S.KEY_SHANK_RIGHT[1], S.CENTER_UP)
    return nc.limb("KEY_Shank", a, b, radius=S.KEY_SHANK_R, coll=coll,
                   material=C.mat("brass"), bevel_w=0.002)


def _build_collar(p, coll):
    loc = p(0.0, S.KEY_COLLAR_RIGHT, S.CENTER_UP)
    return nc.cyl("KEY_Collar", S.KEY_COLLAR_R, S.KEY_COLLAR_THICK,
                  rot=(90.0, 0.0, 0.0), loc=loc, coll=coll,
                  material=C.mat("brass_dark"), bevel_w=0.002)


def _build_blade(p, coll):
    right_lo, right_hi = S.KEY_BLADE_RIGHT
    up_lo, up_hi = S.KEY_BLADE_UP
    blade = nc.box("KEY_Blade",
                   (right_hi - right_lo, S.KEY_BLADE_THICK, up_hi - up_lo),
                   loc=p(0.0, (right_lo + right_hi) * 0.5, (up_lo + up_hi) * 0.5),
                   coll=coll, material=C.mat("brass"), bevel_w=0.002)

    for right, depth in zip(S.KEY_TEETH_RIGHT, S.KEY_TEETH_DEPTH):
        cut_lo = up_lo - 0.02
        cut_hi = up_lo + depth
        cutter = nc.box("KEY_Tooth_Cut",
                        (S.KEY_TEETH_WIDTH, S.KEY_BLADE_THICK * 3.0, cut_hi - cut_lo),
                        loc=p(0.0, right, (cut_lo + cut_hi) * 0.5), coll=coll)
        blade = nc.cut(blade, cutter)

    blade.name = "KEY_Blade"
    blade.data.name = "KEY_Blade"
    return blade


if __name__ == "__main__":
    build()
