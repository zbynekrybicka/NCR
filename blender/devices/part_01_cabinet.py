# -*- coding: utf-8 -*-
"""
DÍL 01 — Elektrická skříň (POWER_CABINET).

    CABINET_Case
    CABINET_Door
     ├─ CABINET_Hinges, CABINET_Latch
     └─ CABINET_Bolt          (výstražný blesk, § zadání "typický blesk")
    CABINET_Lamp              (kontrolka — Godot přebarvuje podle is_on/is_broken)
    CABINET_Damage            (trhlina + útržky pláště, Godot (ne)zobrazuje podle is_broken)
    CABINET_SparkAnchor       (Empty — kotva pro GPUParticles3D jisker v Godotu)

Krychle vyplňuje celou buňku jako blok WALL (design dok. §2.2.1 — zařízení
se chová jako zeď); dvířka i blesk jsou na čele, které po `godot_forward`
směřuje k `device.access_direction` (`WorldView._build_devices()`).
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
            "blender/devices i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc
S = _ncr_import("devices_spec")

PREFIXES = ("CABINET_",)


def build(parent_collection=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("CABINET",))
    coll = nc.collection("CABINET", parent_collection or nc.collection("DEVICES"))
    p = nc.p

    parts = []
    parts.append(_build_case(p, coll))
    door, door_children = _build_door(p, coll)
    parts.append(door)
    parts += door_children
    parts.append(_build_lamp(p, coll))
    parts += _build_damage(p, coll)
    parts.append(_build_spark_anchor(p, coll))

    print("[NCR] díl 01 — elektrická skříň: %d objektů" % len(parts))
    return parts


def _build_case(p, coll):
    lo, hi = S.CASE_UP
    depth = S.CAB_CASE_FRONT - S.CASE_BACK
    case = nc.box("CABINET_Case", (S.CASE_RIGHT * 2, depth, hi - lo),
                  loc=p((S.CASE_BACK + S.CAB_CASE_FRONT) * 0.5, 0.0, (lo + hi) * 0.5),
                  coll=coll, material=C.mat("case"), bevel_w=S.CASE_EDGE_BEVEL)
    return case


def _build_door(p, coll):
    lo, hi = S.CAB_DOOR_UP
    door = nc.box("CABINET_Door", (S.CAB_DOOR_RIGHT * 2, S.CAB_DOOR_THICK, hi - lo),
                  loc=p(S.CAB_CASE_FRONT + S.CAB_DOOR_THICK * 0.5, 0.0, (lo + hi) * 0.5),
                  coll=coll, material=C.mat("door"), bevel_w=0.004)

    hinges = []
    for i, up in enumerate(S.CAB_HINGE_UPS):
        hinges.append(nc.cyl("CABINET_Hinge_%d" % i, S.CAB_HINGE_R, S.CAB_HINGE_LEN,
                             loc=p(S.CAB_CASE_FRONT + S.CAB_DOOR_THICK * 0.5,
                                   S.CAB_HINGE_RIGHT, up),
                             coll=coll, material=C.mat("hinge")))
    hinge = nc.join(hinges, "CABINET_Hinges")

    latch = nc.box("CABINET_Latch", S.CAB_LATCH_SIZE,
                   loc=p(S.CAB_DOOR_FRONT + S.CAB_LATCH_SIZE[1] * 0.5,
                         S.CAB_LATCH_RIGHT, S.CAB_LATCH_UP),
                   coll=coll, material=C.mat("hinge"), bevel_w=0.004)

    bolt_points = C.lightning_bolt_points(S.CAB_BOLT_RIGHT, *S.CAB_BOLT_UP)
    bolt = C.flat_shape("CABINET_Bolt", bolt_points, S.CAB_DOOR_FRONT + 0.001,
                        S.CAB_BOLT_THICK, coll=coll, material=C.mat("warning"))

    vents = []
    for i, up in enumerate(S.CAB_VENT_UPS):
        vents.append(nc.box("CABINET_Vent_%d" % i,
                            (S.CAB_VENT_RIGHT * 2, S.CAB_VENT_DEPTH, S.CAB_VENT_THICK),
                            loc=p(S.CAB_DOOR_FRONT + S.CAB_VENT_DEPTH * 0.5, 0.0, up),
                            coll=coll, material=C.mat("case_edge")))
    vent = nc.join(vents, "CABINET_Vents")

    return door, [hinge, latch, bolt, vent]


def _build_lamp(p, coll):
    lamp = nc.cyl("CABINET_Lamp", S.CAB_LAMP_R, S.CAB_LAMP_DEPTH,
                  rot=(90.0, 0.0, 0.0),   # cyl() je defaultně svislý, lampa kouká dopředu
                  loc=p(S.CAB_CASE_FRONT + S.CAB_LAMP_DEPTH * 0.5,
                        S.CAB_LAMP_RIGHT, S.CAB_LAMP_UP),
                  coll=coll, material=C.mat("lamp_off"))
    return lamp


def _build_damage(p, coll):
    """Statická geometrie poškození — Godot uzel `CABINET_Damage` jen
    zobrazí/skryje (`DeviceView.update_cabinet`), nic víc. Skutečné jiskry
    jsou dynamické částice, viz `_build_spark_anchor`."""
    crack_pts = C.crack_points(S.CAB_CRACK_JAG, S.CAB_CRACK_RIGHT, S.CAB_CRACK_UP,
                               jag=S.CAB_CRACK_THICK)
    crack = C.flat_shape("CABINET_Crack", crack_pts, S.CAB_DOOR_FRONT + 0.002,
                         0.006, coll=coll, material=C.mat("scorched"))

    shards = []
    right_lo, right_hi = S.CAB_CRACK_RIGHT
    for i in range(S.CAB_SHARD_COUNT):
        t = (i + 0.5) / S.CAB_SHARD_COUNT
        right = right_lo + (right_hi - right_lo) * t
        shards.append(nc.box("CABINET_Shard_%d" % i, S.CAB_SHARD_SIZE,
                             rot=(0.0, 0.0, 12.0 * (1 if i % 2 == 0 else -1)),
                             loc=p(S.CAB_DOOR_FRONT + S.CAB_SHARD_SIZE[1] * 0.5,
                                   right, S.CAB_CRACK_UP - 0.08 - 0.02 * i),
                             coll=coll, material=C.mat("copper")))
    shard = nc.join(shards, "CABINET_Shards")

    damage = nc.join([crack, shard], "CABINET_Damage")
    return [damage]


def _build_spark_anchor(p, coll):
    """Prázdný uzel (Empty) — po exportu do glTF se stane obyčejným Node3D
    bez meshe, `DeviceView` na něj zavěsí `GPUParticles3D` jisker. `build()`
    už objekty s prefixem CABINET_ vyčistil (`nc.purge(PREFIXES, ...)`), tady
    se znovu nepurguje."""
    empty = bpy.data.objects.new("CABINET_SparkAnchor", None)
    empty.empty_display_type = 'PLAIN_AXES'
    empty.empty_display_size = 0.05
    fwd, right, up = S.CAB_SPARK_ANCHOR
    empty.location = p(fwd, right, up)
    nc.place(empty, coll)
    return empty


if __name__ == "__main__":
    build()
