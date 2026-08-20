# -*- coding: utf-8 -*-
"""
Da — kompletní sestavení.

Spustí všechny díly, svěsí je do hierarchie podle toho, co se bude
animovat, a zkontroluje, že se model vejde do jedné buňky mřížky.

    DA_Root                         (Empty ve středu buňky)
     └─ DA_Frame                    trup + ramena + gondoly
         ├─ CORE_da_*               jádro na vrcholu trupu
         ├─ DA_Sensor               kamera, čitelná orientace
         ├─ DA_Rotor_0H..3H         horní rotory: rotace kolem Z
         ├─ DA_Rotor_0D..3D         dolní rotory: rotace kolem Z
         ├─ DA_Gear_0..3            přistávací nohy
         └─ DA_Hook                 hák pro nesený předmět

Da se staví PŘISTÁLÝ — chodidla na podlaze buňky. Vznášení je podle
`docs/import-assets.md` §2.3 věc idle animace, ne pozice modelu.
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
S = _ncr_import("da_spec")

core = _ncr_import("part_00_core")
frame = _ncr_import("part_01_frame")
rotors = _ncr_import("part_02_rotors")
gear = _ncr_import("part_03_gear")
hook = _ncr_import("part_04_hook")
rotor_anim = _ncr_import("anim_rotors")


# --- co se má stát po sestavení --------------------------------------------
EXPORT_GLB = False       # True = zapsat game/assets/robots/da.glb
ANIMATE = True           # True = přidat klip `rotors` (anim_rotors.py)
APPLY_ROTATIONS = False  # True = zapéct rotace do meshů (až těsně před exportem)
# Da nemá žádný stav k přepnutí — rotory se točí, ale model je jeden.


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

    da_coll = nc.collection("DA")

    parts = []
    parts += frame.build(da_coll)
    parts += rotors.build(da_coll)
    parts += gear.build(da_coll)
    parts += hook.build(da_coll)

    # jádro je sdílený asset (spec §0.1) — stejný skript jako u ostatních
    core_parts = core.build(robot=S.ROBOT, rivets=S.CORE_RIVETS,
                            name_pitch=S.CORE_NAME_PITCH,
                            at=nc.p(S.CORE_FWD, 0.0, S.CORE_UP))
    parts += core_parts

    # --- kořen -------------------------------------------------------------
    nc.purge(("DA_Root",))
    root = bpy.data.objects.new("DA_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    nc.place(root, da_coll)

    # --- hierarchie --------------------------------------------------------
    hangers = [o.name for o in parts
               if o.name.startswith(("DA_Rotor_", "DA_Gear_", "DA_Hook",
                                     "DA_Sensor"))]
    _parent_many("DA_Root", ["DA_Frame"])
    _parent_many("DA_Frame", hangers + [o.name for o in core_parts])

    if APPLY_ROTATIONS:
        apply_rotations(parts)

    report(parts)

    # animace až po kontrole obálky: ta měří model tak, jak stojí, a
    # rozkročený robot by ji zbytečně nafoukl
    if ANIMATE:
        rotor_anim.build()

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

    print("\n[NCR] ---- Da: hotovo ----")
    print("[NCR] objektů: %d, trojúhelníků: %d" % (len(parts), tris))
    print("[NCR] obálka X %.3f..%.3f   Y %.3f..%.3f   Z %.3f..%.3f  (buňka je -0.5..0.5)"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("[NCR] chodidla dosedají na Z = %.3f (má být -0.500), příď k -Y" % lo[2])

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
        path = os.path.join(repo, "game", "assets", "robots", "da.glb")

    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        os.makedirs(folder)

    targets = [o for o in bpy.data.objects
               if o.name.startswith(("DA_", "CORE_%s_" % S.ROBOT))]
    nc.prepare()
    for o in bpy.data.objects:
        o.select_set(False)
    for o in targets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = targets[0] if targets else None

    options = dict(filepath=path, export_format='GLB', use_selection=True,
                   export_yup=True, export_apply=True)
    # klipy jsou odložené v NLA stopách — bez tohohle režimu by se do .glb
    # nedostaly (ncr_anim.py, hlavička)
    anim = _ncr_import("ncr_anim")
    options.update(anim.gltf_animation_options())

    bpy.ops.export_scene.gltf(**options)
    print("[NCR] export: %s" % path)
    return path


if __name__ == "__main__":
    build()
