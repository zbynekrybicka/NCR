# -*- coding: utf-8 -*-
"""
DÍL 02 — Kanystr na palivo (CANISTER, `ItemType.FUEL`).

    CANISTER_Body
    CANISTER_Neck, CANISTER_Cap
    CANISTER_Handle_0..2   (tři madla nahoře)
    CANISTER_Braces        (zkřížené výztuhy na čele i zádi)
    CANISTER_Label         (cejchovací štítek)

Stojí rovně — na rozdíl od klíče žádný náklon, svislá osa je přímo `up`.
Vejde se celý pod `CANISTER_Root` (Empty), aby měl stejnou uzlovou strukturu
jako ostatní předměty (`build_items.py`), i když sám žádnou rotaci nenese.
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

PREFIXES = ("CANISTER_",)


def build(parent_collection=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("CANISTER",))
    coll = nc.collection("CANISTER", parent_collection or nc.collection("ITEMS"))
    p = nc.p

    parts = []
    parts.append(_build_body(p, coll))
    parts.append(_build_neck(p, coll))
    parts.append(_build_cap(p, coll))
    parts += _build_handles(p, coll)
    parts.append(_build_braces(p, coll))
    parts.append(_build_label(p, coll))

    root = bpy.data.objects.new("CANISTER_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    nc.place(root, coll)
    bpy.context.view_layer.update()
    for part in parts:
        nc.parent_to(part, root)

    print("[NCR] díl 02 — kanystr: %d objektů" % (len(parts) + 1))
    return [root] + parts


def _build_body(p, coll):
    up_lo, up_hi = S.CAN_BODY_UP
    return nc.box("CANISTER_Body",
                  (S.CAN_BODY_RIGHT * 2.0, S.CAN_BODY_FWD * 2.0, up_hi - up_lo),
                  loc=p(0.0, 0.0, (up_lo + up_hi) * 0.5),
                  coll=coll, material=C.mat("olive"), bevel_w=S.CAN_BEVEL)


def _build_neck(p, coll):
    lo, hi = S.CAN_NECK_UP
    return nc.cyl("CANISTER_Neck", S.CAN_NECK_R, hi - lo,
                  loc=p(S.CAN_NECK_FWD, S.CAN_NECK_RIGHT, (lo + hi) * 0.5),
                  coll=coll, material=C.mat("canister_metal"))


def _build_cap(p, coll):
    top = S.CAN_NECK_UP[1]
    return nc.cyl("CANISTER_Cap", S.CAN_CAP_R, S.CAN_CAP_HEIGHT,
                  loc=p(S.CAN_NECK_FWD, S.CAN_NECK_RIGHT, top + S.CAN_CAP_HEIGHT * 0.5),
                  coll=coll, material=C.mat("canister_metal"), bevel_w=0.002)


def _build_handles(p, coll):
    fwd_front, fwd_back = S.CAN_HANDLE_FWD
    top = S.CAN_BODY_UP[1]
    arch = S.CAN_HANDLE_ARCH_UP
    handles = []
    for i, right in enumerate(S.CAN_HANDLE_RIGHTS):
        leg_front = nc.limb("CANISTER_Handle_%d_LegF" % i,
                            p(fwd_front, right, top), p(fwd_front, right, arch),
                            radius=S.CAN_HANDLE_BAR_R, coll=coll,
                            material=C.mat("canister_metal"))
        leg_back = nc.limb("CANISTER_Handle_%d_LegB" % i,
                           p(fwd_back, right, top), p(fwd_back, right, arch),
                           radius=S.CAN_HANDLE_BAR_R, coll=coll,
                           material=C.mat("canister_metal"))
        bar = nc.limb("CANISTER_Handle_%d_Bar" % i,
                      p(fwd_front, right, arch), p(fwd_back, right, arch),
                      radius=S.CAN_HANDLE_BAR_R, coll=coll,
                      material=C.mat("canister_metal"))
        handles.append(nc.join([leg_front, leg_back, bar], "CANISTER_Handle_%d" % i))
    return handles


def _build_braces(p, coll):
    strips = []
    for face_fwd in S.CAN_BRACE_FWDS:
        sign = 1.0 if face_fwd > 0.0 else -1.0
        outward = face_fwd + sign * S.CAN_BRACE_DEPTH * 0.5
        for angle in (S.CAN_BRACE_ANGLE, -S.CAN_BRACE_ANGLE):
            strips.append(nc.box("CANISTER_Brace",
                                 (S.CAN_BRACE_LEN, S.CAN_BRACE_DEPTH, S.CAN_BRACE_THICK),
                                 rot=(0.0, angle, 0.0), loc=p(outward, 0.0, S.CENTER_UP),
                                 coll=coll, material=C.mat("canister_metal"),
                                 bevel_w=0.002))
    return nc.join(strips, "CANISTER_Braces")


def _build_label(p, coll):
    lo, hi = S.CAN_LABEL_UP
    return nc.box("CANISTER_Label",
                  (S.CAN_LABEL_RIGHT * 2.0, S.CAN_LABEL_DEPTH, hi - lo),
                  loc=p(S.CAN_BODY_FWD + S.CAN_LABEL_DEPTH * 0.5, 0.0, (lo + hi) * 0.5),
                  coll=coll, material=C.mat("stencil"))


if __name__ == "__main__":
    build()
