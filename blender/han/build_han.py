# -*- coding: utf-8 -*-
"""
Han — kompletní sestavení.

Spustí všech sedm dílů v pořadí, svěsí je do hierarchie podle kloubů
a zkontroluje, že se model vejde do jedné buňky mřížky.

Hierarchie odpovídá tomu, co se bude animovat:

    HAN_Root                         (Empty ve středu buňky)
     ├─ HAN_Frame / Fender / Hitch
     ├─ HAN_Track_* / Sprocket_* / Idler_* / Wheel_*
     └─ HAN_Hull
         ├─ HAN_Neck ─ CORE_han_*                 jádro
         ├─ HAN_Exhaust
         ├─ HAN_ArmYoke                           Akce 1: hrábnutí
         │   └─ HAN_Arm_Boom
         │       └─ HAN_Arm_Stick
         │           └─ HAN_Bucket, HAN_BucketEdge
         └─ HAN_Hopper                            Akce 2: vyklopení korby
             └─ HAN_HopperLoad

Písty jsou vždy rozdělené na válec a pístnici a každá půlka visí na svém
článku, takže se při ohnutí kloubu roztáhnou samy.
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
S = _ncr_import("han_spec")

core = _ncr_import("part_00_core")
chassis = _ncr_import("part_01_chassis")
tracks = _ncr_import("part_02_tracks")
hull = _ncr_import("part_03_hull")
arm = _ncr_import("part_04_arm")
bucket = _ncr_import("part_05_bucket")
hopper = _ncr_import("part_06_hopper")


# --- co se má stát po sestavení --------------------------------------------
EXPORT_GLB = False     # True = zapsat game/assets/robots/han.glb (viz export_glb)
APPLY_ROTATIONS = False  # True = zapéct rotace do meshů (dělej až těsně před exportem)


def obj(name):
    return bpy.data.objects.get(name)


def _parent_many(parent_name, child_names):
    parent = obj(parent_name)
    if parent is None:
        return
    # bez tohohle čte parent_to zastaralou matrix_world rodiče (ta se
    # přepočítá až s depsgraph updatem) a díl odskočí
    bpy.context.view_layer.update()
    for name in child_names:
        child = obj(name)
        if child is not None and child is not parent:
            nc.parent_to(child, parent)


def build():
    nc.prepare()
    nc.set_robot(S.ROBOT)

    han = nc.collection("HAN")
    parts = []
    parts += chassis.build(han)
    parts += tracks.build(han)
    parts += hull.build(han)
    parts += arm.build(han)
    parts += bucket.build(han)
    parts += hopper.build(han)

    # jádro je sdílený asset (spec §0.1) — žije ve vlastní kolekci
    core_parts = core.build(robot=S.ROBOT, rivets=S.CORE_RIVETS,
                            name_pitch=S.CORE_NAME_PITCH,
                            at=nc.p(S.CORE_FWD, 0.0, S.CORE_UP))
    parts += core_parts

    # --- kořen -------------------------------------------------------------
    nc.purge(("HAN_Root",))
    root = bpy.data.objects.new("HAN_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    nc.place(root, han)

    # --- hierarchie --------------------------------------------------------
    running = [o.name for o in parts
               if o.name.startswith(("HAN_Track", "HAN_Sprocket", "HAN_Idler",
                                     "HAN_Wheel"))]
    _parent_many("HAN_Root", ["HAN_Frame", "HAN_Fender", "HAN_Hitch", "HAN_Hull"] + running)
    _parent_many("HAN_Hull", ["HAN_Neck", "HAN_Exhaust", "HAN_ArmYoke", "HAN_Hopper",
                              "HAN_Ram_Hopper_Barrel"])
    _parent_many("HAN_Neck", [o.name for o in core_parts])
    _parent_many("HAN_ArmYoke", ["HAN_Arm_Boom", "HAN_Ram_Boom_Barrel"])
    _parent_many("HAN_Arm_Boom", ["HAN_Arm_Stick", "HAN_Ram_Boom_Rod",
                                  "HAN_Ram_Stick_Barrel"])
    _parent_many("HAN_Arm_Stick", ["HAN_Bucket", "HAN_BucketEdge", "HAN_Ram_Stick_Rod"])
    _parent_many("HAN_Hopper", ["HAN_HopperLoad", "HAN_Ram_Hopper_Rod"])

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

    print("\n[NCR] ---- Han: hotovo ----")
    print("[NCR] objektů: %d, trojúhelníků: %d" % (len(parts), tris))
    print("[NCR] obálka X %.3f..%.3f   Y %.3f..%.3f   Z %.3f..%.3f  (buňka je -0.5..0.5)"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("[NCR] chodidla na Z = %.3f (má být -0.500), předek k -Y" % lo[2])

    if offenders:
        print("[NCR] POZOR: mimo buňku přesahuje %d dílů: %s"
              % (len(offenders), ", ".join(sorted(set(offenders))[:8])))
        print("[NCR]        u POSE_DIG je to v pořádku — rameno záměrně sahá "
              "do sousední buňky. U POSE_PARKED to je chyba proporcí.")
    else:
        print("[NCR] model se vejde do jedné buňky mřížky.")

    for o in hidden:
        o.hide_viewport = True

    if nc.find_hangul_font() is None:
        print("[NCR] POZOR: nenašel se font s hangulem, nápis na jádru je prázdný.")


def apply_rotations(parts):
    """Zapeče rotace do mesh dat. Origin každého dílu zůstává v kloubu,
    takže se tím nic nerozbije — ale dělej to až těsně před exportem
    (import-assets.md §2.2 chce applied transform)."""
    nc.prepare()
    meshes = [o for o in parts if o.type == 'MESH']
    for o in meshes:
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

    Cesta se hledá relativně k tomuhle skriptu (blender/han -> repo root).
    Standardně se NESPOUŠTÍ — přepni `EXPORT_GLB = True` nebo zavolej ručně.
    """
    if path is None:
        here = os.path.dirname(os.path.abspath(__file__))
        repo = os.path.dirname(os.path.dirname(here))
        path = os.path.join(repo, "game", "assets", "robots", "han.glb")

    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        os.makedirs(folder)

    targets = [o for o in bpy.data.objects
               if o.name.startswith(("HAN_", "CORE_%s_" % S.ROBOT))]
    nc.prepare()
    for o in bpy.data.objects:
        o.select_set(False)
    for o in targets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = targets[0] if targets else None

    # otočka kořene: glTF má předek na +Z, Godot na -Z (ncr_common)
    with nc.godot_forward("HAN_Root"):
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                                  use_selection=True, export_yup=True,
                                  export_apply=True)
    print("[NCR] export: %s" % path)
    return path


if __name__ == "__main__":
    build()
