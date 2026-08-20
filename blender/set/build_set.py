# -*- coding: utf-8 -*-
"""
Set — kompletní sestavení.

Spustí všechny díly, svěsí je do hierarchie podle toho, co se bude
animovat, a zkontroluje, že se model vejde do jedné buňky mřížky.

    SET_Root                       (Empty ve středu buňky)
     ├─ SET_Frame / Deck / Bumper
     ├─ SET_Wheel_L0..2 / P0..2    jízda: rotace kolem X
     └─ SET_Hull
         ├─ CORE_set_*             jádro vzadu na palubě
         └─ SET_Turret             odměr: rotace kolem Z
             └─ SET_Flamer         náměr: rotace kolem X
                 ├─ SET_FlamerMuzzle
                 └─ SET_FlamerTank

Dva klouby za sebou (odměr věže, náměr hlavně) pokrývají to, co spec §3
po Setovi chce: pálit vodorovně, šikmo i svisle, a tavit led šikmo dolů.
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
            "Nenašel jsem %s.py — otevři přes Text > Open skripty ze složky "
            "robota i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")
S = _ncr_import("set_spec")

core = _ncr_import("part_00_core")
chassis = _ncr_import("part_01_chassis")
wheels = _ncr_import("part_02_wheels")
hull = _ncr_import("part_03_hull")
turret = _ncr_import("part_04_turret")
flamer = _ncr_import("part_05_flamer")


# --- co se má stát po sestavení --------------------------------------------
EXPORT_GLB = False       # True = zapsat game/assets/robots/set.glb
APPLY_ROTATIONS = False  # True = zapéct rotace do meshů (až těsně před exportem)
TURRET_YAW = None        # None = hodnota ze set_spec; jinak stupně kolem Z
ELEVATION = None         # None = hodnota ze set_spec; jinak náměr ve stupních


def obj(name):
    return bpy.data.objects.get(name)


def _parent_many(parent_name, child_names):
    parent = obj(parent_name)
    if parent is None:
        return
    # bez updatu čte parent_to zastaralou matrix_world rodiče a díl odskočí
    bpy.context.view_layer.update()
    for name in child_names:
        child = obj(name)
        if child is not None and child is not parent:
            nc.parent_to(child, parent)


def build():
    nc.prepare()
    nc.set_robot(S.ROBOT)

    set_coll = nc.collection("SET")
    parts = []
    parts += chassis.build(set_coll)
    parts += wheels.build(set_coll)
    parts += hull.build(set_coll)
    # věž i hlavice se staví v základní poloze a natočí se až po zavěšení,
    # jinak by se rodič otočil a dítě zůstalo stát
    parts += turret.build(set_coll, yaw=0.0)
    parts += flamer.build(set_coll, elevation=ELEVATION)

    # jádro je sdílený asset (spec §0.1) — stejný skript jako u Hana a Dula
    core_parts = core.build(robot=S.ROBOT, rivets=S.CORE_RIVETS,
                            name_pitch=S.CORE_NAME_PITCH,
                            at=nc.p(S.CORE_FWD, 0.0, S.CORE_UP))
    parts += core_parts

    # --- kořen -------------------------------------------------------------
    nc.purge(("SET_Root",))
    root = bpy.data.objects.new("SET_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    nc.place(root, set_coll)

    # --- hierarchie --------------------------------------------------------
    running = [o.name for o in parts if o.name.startswith("SET_Wheel_")]
    _parent_many("SET_Root", ["SET_Frame", "SET_Deck", "SET_Bumper",
                              "SET_Hull"] + running)
    _parent_many("SET_Hull", ["SET_Turret"] + [o.name for o in core_parts])
    _parent_many("SET_Turret", ["SET_Flamer"])
    _parent_many("SET_Flamer", ["SET_FlamerMuzzle", "SET_FlamerTank"])

    # až po zavěšení: odměr teď vezme hlavici s sebou
    yaw = S.TURRET_YAW if TURRET_YAW is None else TURRET_YAW
    if yaw:
        t = obj("SET_Turret")
        t.rotation_mode = 'XYZ'
        t.rotation_euler = (0.0, 0.0, nc.radians(yaw))

    if APPLY_ROTATIONS:
        apply_rotations(parts)

    report(parts)

    if EXPORT_GLB:
        export_glb()

    return [root] + parts


# ---------------------------------------------------------------------------
# Kontroly
# ---------------------------------------------------------------------------

def report(parts):
    """Vypíše obálku modelu a upozorní na díly mimo jednu buňku mřížky."""
    # Skryté objekty (stav "plná nádrž") depsgraph nevyhodnocuje, takže mají
    # zastaralou matrix_world i bound_box — na měření je musíme odkrýt.
    hidden = [o for o in parts if o.hide_viewport]
    for o in hidden:
        o.hide_viewport = False
    bpy.context.view_layer.update()

    half = nc.CELL * 0.5
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    offenders = []
    tris = 0

    for o in parts:
        if o.type != 'MESH':
            continue
        tris += sum(max(0, len(poly.vertices) - 2) for poly in o.data.polygons)
        out = False
        # Měří se přes vrcholy, ne přes o.bound_box: bound_box je LOKÁLNÍ
        # osově zarovnaný kvádr a u otočeného dílu se převodem do světa
        # nafoukne. U Netovy nohy to hlásilo 3 cm pod podlahou, které tam
        # ve skutečnosti nebyly.
        matrix = o.matrix_world
        for vert in o.data.vertices:
            world = matrix @ vert.co
            for i in range(3):
                lo[i] = min(lo[i], world[i])
                hi[i] = max(hi[i], world[i])
                if world[i] < -half - 1e-4 or world[i] > half + 1e-4:
                    out = True
        if out:
            offenders.append(o.name)

    print("\n[NCR] ---- Set: hotovo ----")
    print("[NCR] objektů: %d, trojúhelníků: %d" % (len(parts), tris))
    print("[NCR] obálka X %.3f..%.3f   Y %.3f..%.3f   Z %.3f..%.3f  (buňka je -0.5..0.5)"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("[NCR] kola dosedají na Z = %.3f (má být -0.500), čelo k -Y" % lo[2])

    if offenders:
        print("[NCR] POZOR: mimo buňku přesahuje %d dílů: %s"
              % (len(offenders), ", ".join(sorted(set(offenders))[:8])))
    else:
        print("[NCR] model se vejde do jedné buňky mřížky.")

    for o in hidden:
        o.hide_viewport = True

    if nc.find_hangul_font() is None:
        print("[NCR] POZOR: nenašel se font s hangulem, nápis na jádru je prázdný.")


def apply_rotations(parts):
    """Zapeče rotace do mesh dat; originy dílů zůstanou v čepech.
    Dělej to až těsně před exportem (import-assets.md §2.2)."""
    nc.prepare()
    for o in [o for o in parts if o.type == 'MESH']:
        try:
            with bpy.context.temp_override(object=o, active_object=o,
                                           selected_objects=[o],
                                           selected_editable_objects=[o]):
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        except (AttributeError, RuntimeError) as err:
            print("[NCR] apply rotation selhal na %s: %s" % (o.name, err))


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_glb(path=None):
    """Zapíše glTF podle konvence z docs/import-assets.md §2.2.
    Standardně se NESPOUŠTÍ — přepni `EXPORT_GLB = True` nebo zavolej ručně."""
    if path is None:
        here = os.path.dirname(os.path.abspath(__file__))
        repo = os.path.dirname(os.path.dirname(here))
        path = os.path.join(repo, "game", "assets", "robots", "set.glb")

    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        os.makedirs(folder)

    targets = [o for o in bpy.data.objects
               if o.name.startswith(("SET_", "CORE_%s_" % S.ROBOT))]
    nc.prepare()
    for o in bpy.data.objects:
        o.select_set(False)
    for o in targets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = targets[0] if targets else None

    # otočka kořene: glTF má předek na +Z, Godot na -Z (ncr_common)
    with nc.godot_forward("SET_Root"):
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                                  use_selection=True, export_yup=True,
                                  export_apply=True)
    print("[NCR] export: %s" % path)
    return path


if __name__ == "__main__":
    build()
