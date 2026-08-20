# -*- coding: utf-8 -*-
"""
DÍL 01 — Rám a senzor, spec §5 ("X-konfigurace, 4 ramena").

Ramena míří do rohů buňky, protože po úhlopříčce je nejvíc místa —
disk rotoru se tak vejde největší. Gondoly motorů sedí na koncích ramen
a jsou dost vysoké, aby mezi ně šel koaxiální pár rotorů.

Senzor je samostatný objekt: podle spec §5 nese čitelnou orientaci
a klidně se může na gimbalu natáčet.

Objekty: DA_Frame (trup + ramena + gondoly), DA_Sensor
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

PREFIXES = ("DA_Frame", "DA_Arm", "DA_Motor", "DA_Sensor", "DA_Fairing")


def build(parent_collection=None):
    nc.prepare()
    nc.set_robot(S.ROBOT)
    nc.purge(PREFIXES, collections=("DA_Frame",))
    coll = nc.collection("DA_Frame", parent_collection or nc.collection("DA"))

    p = nc.p
    hub_lo, hub_hi = S.HUB_UP

    # --- centrální trup -----------------------------------------------------
    hub = nc.cone("DA_Frame", S.HUB_R, S.HUB_R * S.HUB_TAPER, hub_hi - hub_lo,
                  loc=p(0.0, 0.0, (hub_lo + hub_hi) * 0.5), verts=32, coll=coll,
                  material=nc.mat("body"), bevel_w=0.008, smooth_angle=26)

    pieces = [hub]

    # --- ramena a gondoly ---------------------------------------------------
    mot_lo, mot_hi = S.MOTOR_UP
    for i, angle in enumerate(S.ARM_ANGLES):
        fwd, right = S.arm_tip(angle)
        root_fwd, root_right = S.arm_tip(angle, S.HUB_R * 0.70)

        pieces.append(nc.limb("DA_Arm_%d" % i,
                              p(root_fwd, root_right, S.ARM_UP),
                              p(fwd, right, S.ARM_UP),
                              size=S.ARM_SIZE, coll=coll,
                              material=nc.mat("body"), bevel_w=0.006))
        pieces.append(nc.cyl("DA_Motor_%d" % i, S.MOTOR_R, mot_hi - mot_lo,
                             loc=p(fwd, right, (mot_lo + mot_hi) * 0.5),
                             verts=24, coll=coll, material=nc.mat("body_dark"),
                             bevel_w=0.005))
        # chladicí prstenec, ať gondola není holý válec
        pieces.append(nc.cyl("DA_Motor_%dR" % i, S.MOTOR_R * 1.18, 0.012,
                             loc=p(fwd, right, (mot_lo + mot_hi) * 0.5),
                             verts=24, coll=coll, material=nc.mat("metal_dark")))

    # --- lůžko jádra --------------------------------------------------------
    fair_lo, fair_hi = S.FAIRING_UP
    pieces.append(nc.cyl("DA_Fairing", S.FAIRING_R[0], fair_hi - fair_lo,
                         loc=p(0.0, 0.0, (fair_lo + fair_hi) * 0.5),
                         verts=32, coll=coll, material=nc.mat("body_dark"),
                         bevel_w=0.005))

    frame = nc.join(pieces, "DA_Frame")

    # --- senzor na přídi ----------------------------------------------------
    # Staví se v lokálním rámu (+Z podél pohledu) a natočí se najednou —
    # stejný postup jako Hanova lžíce nebo Setova hlavice.
    w, d, h = S.SENSOR_BODY
    pod = nc.box("DA_Sensor", (w, h, d), shift=(0, 0, d * 0.5), coll=coll,
                 material=nc.mat("body_dark"), bevel_w=0.008)
    barrel = nc.cyl("DA_SensorBarrel", S.LENS_R * 1.20, S.LENS_LEN,
                    shift=(0, 0, d + S.LENS_LEN * 0.5), verts=24, coll=coll,
                    material=nc.mat("metal_dark"), bevel_w=0.003)
    lens = nc.cyl("DA_SensorLens", S.LENS_R, 0.010,
                  shift=(0, 0, d + S.LENS_LEN), verts=24, coll=coll,
                  material=nc.mat("glass"))
    sensor = nc.join([pod, barrel, lens], "DA_Sensor")
    nc.align_to(sensor, p(S.SENSOR_FWD, 0.0, S.SENSOR_UP),
                nc.dir_yz(S.SENSOR_PITCH))

    print("[NCR] díl 01 — rám: rozpětí %.2fu, 4 ramena v X-konfiguraci"
          % (S.reach() * 2))
    return [frame, sensor]


if __name__ == "__main__":
    build()
