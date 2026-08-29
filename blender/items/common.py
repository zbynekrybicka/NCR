# -*- coding: utf-8 -*-
"""
Předměty (klíč, kanystr, service kit) — sdílená knihovna.

Stejný rámec jako roboti a zařízení: `ncr_common.p(fwd, right, up)`, 1 buňka
= 1 unit, origin ve středu buňky. Na rozdíl od nich ale předměty nestojí na
podlaze a nemají čelo — leží/vznáší se u `up = 0.5` (střed buňky po výšce,
tj. Blender `z = 0`), protože přesně tam je dnes staví placeholder
(`world_view.gd:refresh_items()` — `node.position = cell_to_position(cell)`,
tedy střed buňky) a stejné místo čeká `ItemView` i s reálným modelem
(`docs/import-assets.md` §4.2). Otáčení kolem svislé osy a pohupování nahoru
dolů dělá až `ItemView` za běhu — v modelu proto není žádná animace, jen
jeho klidová (pro klíč nakloněná) póza.
"""

import bpy
import os
import sys
import types
import importlib
from math import radians
from mathutils import Vector, Matrix, Euler


def _ncr_import(module_name):
    """Načte modul ze složky `blender/items` nebo ze sousední `blender/common`."""
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
            "blender/items i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")   # p(), primitiva box/cyl/..., prepare/collection/place/purge/godot_forward

# ---------------------------------------------------------------------------
# Materiály — vlastní paleta na předmět, ne robotí tint/wear systém
# ---------------------------------------------------------------------------

MATERIALS = {
    # klíč — mosaz, žlutá dle zadání
    "brass":        dict(color=(0.620, 0.460, 0.060), metallic=0.85, rough=0.32),
    "brass_dark":   dict(color=(0.280, 0.200, 0.030), metallic=0.80, rough=0.42),
    # kanystr — vojenská olivová, plechové víčko/madlo tmavším kovem
    "olive":        dict(color=(0.072, 0.092, 0.036), metallic=0.05, rough=0.62),
    "olive_dark":   dict(color=(0.040, 0.052, 0.022), metallic=0.05, rough=0.68),
    "canister_metal": dict(color=(0.120, 0.115, 0.100), metallic=0.75, rough=0.42),
    "stencil":      dict(color=(0.520, 0.480, 0.380), metallic=0.0, rough=0.70),
    # service kit — drát, pozink kleštičky, plastová rukojeť pájky
    "wire_copper":  dict(color=(0.480, 0.220, 0.080), metallic=0.70, rough=0.38),
    "tool_steel":   dict(color=(0.300, 0.310, 0.320), metallic=0.85, rough=0.30),
    "tool_grip":    dict(color=(0.760, 0.180, 0.060), metallic=0.0, rough=0.55),
    "iron_tip":     dict(color=(0.050, 0.048, 0.045), metallic=0.40, rough=0.55),
}


def mat(key):
    name = "ITEM_%s" % key
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing
    spec = MATERIALS[key]
    color = spec["color"]

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.5)

    material.diffuse_color = (color[0], color[1], color[2], 1.0)
    return material


# ---------------------------------------------------------------------------
# Cívka (service kit — "stočený drát") přes Screw modifikátor: malý kruhový
# profil posazený ve vzdálenosti `coil_r` od osy Z, ovinutý `turns`-krát se
# stoupáním `pitch` na otáčku. Řeší se modifikátorem, ne bmesh spinem, ať se
# dá poloměr/stoupání/počet závitů doladit jedním číslem každý (spec §0.3
# princip — čísla na jednom místě, primitivum jen skládá).
# ---------------------------------------------------------------------------

def coil(name, coil_r, wire_r, pitch, turns, loc=(0, 0, 0), rot=None,
         segments_per_turn=24, coll=None, material=None):
    bpy.ops.mesh.primitive_circle_add(radius=wire_r, fill_type='NGON',
                                       vertices=10, location=(0.0, 0.0, 0.0))
    profile = bpy.context.object
    # kruh leží v rovině XY (normála podél Z) — natočit tak, aby normála
    # mířila po obvodu, pak teprve odsunout na poloměr `coil_r`. Musí se to
    # udělat v tomhle pořadí a v mesh datech (ne přes object.location): Screw
    # spíná kolem LOKÁLNÍ osy Z objektu, takže dokud profil sedí v počátku,
    # otáčel by se kolem sebe sama místo opisování kružnice o poloměru coil_r.
    profile.rotation_euler = (radians(90.0), 0.0, 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    profile.data.transform(Matrix.Translation((coil_r, 0.0, 0.0)))

    mod = profile.modifiers.new("ncr_screw", 'SCREW')
    mod.axis = 'Z'
    mod.angle = radians(360.0) * turns
    mod.screw_offset = pitch          # posun za JEDNU otáčku; celkem = pitch * turns
    mod.steps = max(3, int(segments_per_turn))
    mod.render_steps = mod.steps
    mod.use_merge_vertices = True

    nc.apply_modifier(profile, mod.name)
    # cívka ať visí středem otáčení kolem vlastního počátku, ne kolem
    # spodního závitu, kde ji Screw modifikátor začal navíjet
    profile.data.transform(Matrix.Translation((0.0, 0.0, -pitch * turns * 0.5)))
    if rot is not None:
        profile.data.transform(Euler([radians(a) for a in rot], 'XYZ').to_matrix().to_4x4())

    profile.location = Vector(loc)
    profile.name = name
    profile.data.name = name
    nc.place(profile, coll)
    if material is not None:
        nc.set_material(profile, material)
    nc.smooth(profile, 25)
    return profile


def place_group(obj, rot_deg, loc):
    """Otočí a přesune už poskládanou (`nc.join`nutou) sestavu jako celek —
    kleštičky a pájku skládá `part_03_service_kit.py` z dílů, které všechny
    sedí u společného počátku (`loc=(0, 0, 0)`, vzájemně odsazené jen přes
    `shift`), takže rotace mesh dat kolem tohoto počátku otočí sestavu kolem
    jejího vlastního středu — stejný princip jako `rot`/`shift` u jednotlivých
    primitiv v `ncr_common`, jen aplikovaný až po `join()`."""
    if rot_deg is not None:
        obj.data.transform(Euler([radians(a) for a in rot_deg], 'XYZ').to_matrix().to_4x4())
    obj.location = Vector(loc)
    return obj
