# -*- coding: utf-8 -*-
"""
ANIMACE — roztočené rotory, spec §5 ("8 rotorů ve čtyřech koaxiálních párech").

Jeden klip `rotors`, který se v Godotu pouští **ve smyčce a napořád**, ne
přes tabulku událostí: podle `docs/import-assets.md` §6.3 se smyčka hodí
jen na idle a na trvalé věci, protože roztažením přes `speed_scale` by se
u krokových klipů rozešla s pohybem po mřížce.

Každý rotor má origin na své ose (`part_02_rotors.py`), takže klip není nic
než rotace kolem lokální Z.

  * horní rotor páru se točí po směru hodinových ručiček (při pohledu shora),
  * dolní proti — koaxiální pár si tím ruší reakční moment a je na první
    pohled vidět, že rotorů je osm, ne čtyři.

Objekty: DA_Rotor_0H..3H, DA_Rotor_0D..3D
"""

import bpy
import os
import sys
import types
import importlib

from math import pi


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
na = _ncr_import("ncr_anim")
S = _ncr_import("da_spec")

CLIPS = ("rotors",)


def _rotors():
    """Rotory i s osou, kolem které se točí, a se směrem otáčení."""
    found = []
    lower_up, upper_up = S.ROTOR_UP
    for i, angle in enumerate(S.ARM_ANGLES):
        fwd, right = S.arm_tip(angle)
        for tag, up, spin in (("H", upper_up, -1.0), ("D", lower_up, 1.0)):
            obj = bpy.data.objects.get("DA_Rotor_%d%s" % (i, tag))
            if obj is not None:
                found.append((obj, nc.p(fwd, right, up), spin))
    return found


def build():
    na.scene_fps()
    rotors = _rotors()
    if not rotors:
        print("[NCR] animace rotorů: nenašel jsem DA_Rotor_* — spusť build_da.py")
        return []

    na.clear([obj for obj, _, _ in rotors])
    # klidové matice se čtou až po updatu: po zavěšení pod DA_Frame je
    # matrix_world dílů ještě nepřepočítaná
    bpy.context.view_layer.update()
    rest = {obj.name: obj.matrix_world.copy() for obj, _, _ in rotors}

    # rotor se musí klíčovat kvaternionem: euler by se mezi 180° a 240°
    # rozložil na -120° a vrtule by se ve výsledku otočila zpátky
    for obj, _, _ in rotors:
        if obj.rotation_mode != 'QUATERNION':
            obj.rotation_quaternion = obj.rotation_euler.to_quaternion()
            obj.rotation_mode = 'QUATERNION'

    clip = na.Clip("rotors", interpolation='LINEAR', loop=True)
    steps = S.ROTOR_SPIN_STEPS
    for step in range(steps + 1):
        turn = float(step) / steps
        clip.frame(turn * S.ROTOR_SPIN_FRAMES)
        for obj, pivot, spin in rotors:
            matrix = na.spin(rest[obj.name], pivot, spin * 2.0 * pi * turn)
            clip.key(obj, turn * S.ROTOR_SPIN_FRAMES, matrix)
    clip.finish()

    print("[NCR] animace — %s  (%.0f ot/min, klíč po %.0f°)"
          % (clip.describe(), 60.0 / na.seconds(S.ROTOR_SPIN_FRAMES),
             360.0 / steps))
    return [clip]


if __name__ == "__main__":
    build()
