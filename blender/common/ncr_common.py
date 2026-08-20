# -*- coding: utf-8 -*-
"""
NCR / Blender — sdílená knihovna pro stavbu robotů.

Tohle NENÍ skript ke spuštění. Importují si ho jednotlivé díly (`part_*.py`)
a `build_han.py`. Obsahuje:

  * konvence souřadnic (§ Konvence níže)
  * barvy robotů a knihovnu materiálů (spec §0.2)
  * tenkou vrstvu nad `bpy` — primitiva, boolean, bevel, origin, join, decal

--------------------------------------------------------------------------
Konvence souřadnic
--------------------------------------------------------------------------
Vychází z `docs/import-assets.md` §2.2–2.3, aby model šel exportovat do
glTF bez jediné dodatečné rotace:

    1 buňka mřížky = 1.0 Blender unit (= 1 m)
    origin modelu  = STŘED buňky, model se vejde do [-0.5, 0.5]^3
    podlaha buňky  = z = -0.5   (robot stojí na FLOOR)
    předek robota  = -Y         (po exportu z toho bude Direction.NORTH)
    +X             = doprava (z pohledu robota)
    +Z             = nahoru

Protože se v "-Y dopředu" špatně počítá, všechny rozměry v `han_spec.py`
jsou psané v čitelném *návrhovém rámci*:

    fwd   = jak daleko dopředu (kladné = k čelu robota)
    right = jak daleko doprava
    up    = výška NAD PODLAHOU buňky (0.0 = podlaha, 1.0 = strop)

a překládá je funkce `p(fwd, right, up)` do skutečných Blender souřadnic.
Nikde v dílech tedy nepiš souřadnice ručně — vždycky přes `p()`.
"""

import bpy
import bmesh
import os
from math import radians, degrees, sin, cos, pi
from mathutils import Vector, Matrix, Euler

# ---------------------------------------------------------------------------
# Konvence
# ---------------------------------------------------------------------------

CELL = 1.0                    # 1 grid cube = 1 u
FLOOR = -0.5 * CELL           # z podlahy buňky
FORWARD = Vector((0.0, -1.0, 0.0))
RIGHT = Vector((1.0, 0.0, 0.0))
UP = Vector((0.0, 0.0, 1.0))

CORE_DIAMETER = 0.30          # spec §0.1 — fixní pro všech 7 robotů


def p(fwd=0.0, right=0.0, up=0.0):
    """Návrhový rámec -> Blender souřadnice. Viz hlavička modulu."""
    return Vector((right, -fwd, FLOOR + up))


def dir_yz(pitch_deg):
    """Jednotkový směr v svislé rovině robota.

    pitch 0   = vodorovně dopředu
    pitch +90 = svisle nahoru
    pitch -90 = svisle dolů
    """
    a = radians(pitch_deg)
    return Vector((0.0, -cos(a), sin(a)))


# ---------------------------------------------------------------------------
# Barvy a jména (spec §0.1, §0.2)
# ---------------------------------------------------------------------------

# Linear RGB (Blender base color je lineární, ne sRGB).
ROBOT_COLORS = {
    "han": (0.130, 0.055, 0.018),   # hnědá
    "dul": (0.022, 0.078, 0.265),   # modrá
    "set": (0.235, 0.026, 0.018),   # červená
    "net": (0.034, 0.145, 0.048),   # zelená
    "da":  (0.026, 0.168, 0.205),   # azurová
    "yeo": (0.620, 0.660, 0.700),   # bílá
    "il":  (0.235, 0.118, 0.006),   # žlutá
}

# Fonetický přepis jmen do hangulu. POZOR — spec §0.1 explicitně žádá
# ověření, než se to vypálí do 7 modelů. Jména odpovídají korejským
# číslovkám 1-7 (하나/한, 둘, 셋, 넷, 다섯, 여섯, 일곱), proto tahle volba;
# potvrzení od rodilého mluvčího zatím NEPROBĚHLO.
ROBOT_HANGUL = {
    "han": "한",   # alternativa: 하나
    "dul": "둘",
    "set": "셋",
    "net": "넷",
    "da":  "다",   # alternativa: 다섯
    "yeo": "여",   # alternativa: 여섯
    "il":  "일",   # alternativa: 일곱
}

# Fonty s podporou hangulu — bere se první existující.
HANGUL_FONTS = [
    "C:/Windows/Fonts/malgun.ttf",
    "C:/Windows/Fonts/malgunbd.ttf",
    "C:/Windows/Fonts/NanumGothic.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
]

_ACTIVE_ROBOT = "han"


def set_robot(name):
    """Nastaví, kterého robota barvu vrací `mat('body')` a spol."""
    global _ACTIVE_ROBOT
    assert name in ROBOT_COLORS, "neznámý robot: %s" % name
    _ACTIVE_ROBOT = name


def robot():
    return _ACTIVE_ROBOT


# ---------------------------------------------------------------------------
# Kontext / úklid
# ---------------------------------------------------------------------------

def prepare():
    """Uvede Blender do stavu, ve kterém jsou `bpy.ops` volání spolehlivá."""
    ob = bpy.context.view_layer.objects.active
    if ob is not None and ob.mode != 'OBJECT':
        try:
            bpy.ops.object.mode_set(mode='OBJECT')
        except RuntimeError:
            pass
    # nové objekty ať padají do kořene scény, ne do náhodně aktivní kolekce
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection


def collection(name, parent=None):
    """Vrátí (a v případě potřeby založí) kolekci pod `parent`."""
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
    parent = parent if parent is not None else bpy.context.scene.collection
    if name not in parent.children:
        try:
            parent.children.link(coll)
        except RuntimeError:
            pass  # už visí jinde ve stromu, to nevadí
    return coll


def place(obj, coll=None):
    """Přelinkuje objekt výhradně do dané kolekce."""
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    (coll if coll is not None else bpy.context.scene.collection).objects.link(obj)
    return obj


def purge(prefixes, collections=()):
    """Smaže objekty podle prefixu jména — díky tomu je každý díl
    spustitelný opakovaně a nevrší se kopie."""
    if isinstance(prefixes, str):
        prefixes = [prefixes]
    for obj in list(bpy.data.objects):
        if any(obj.name.startswith(pre) for pre in prefixes):
            bpy.data.objects.remove(obj, do_unlink=True)
    for name in collections:
        coll = bpy.data.collections.get(name)
        if coll is not None and not coll.objects and not coll.children:
            bpy.data.collections.remove(coll)
    purge_orphans()


def purge_orphans():
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.textures):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


# ---------------------------------------------------------------------------
# Materiály (spec §0.2: barva = plášť, mechanismy zůstávají neutrální kov)
# ---------------------------------------------------------------------------

# tint = násobek barvy robota; color = pevná barva nezávislá na robotovi
_MAT_SPECS = {
    "body":          dict(tint=1.00, metallic=0.05, rough=0.42, wear=0.20),
    "body_dark":     dict(tint=0.42, metallic=0.15, rough=0.52, wear=0.22),
    "core_paint":    dict(tint=1.15, metallic=0.25, rough=0.16, wear=0.35),
    "core_engrave":  dict(tint=0.32, metallic=0.20, rough=0.60, wear=0.08),
    "metal_dark":    dict(color=(0.042, 0.043, 0.048), metallic=1.0, rough=0.46, wear=0.18),
    "metal_raw":     dict(color=(0.360, 0.370, 0.390), metallic=1.0, rough=0.34, wear=0.22),
    "metal_polish":  dict(color=(0.680, 0.690, 0.720), metallic=1.0, rough=0.09, wear=0.05),
    "rubber":        dict(color=(0.020, 0.020, 0.022), metallic=0.0, rough=0.78, wear=0.12),
    "worn_edge":     dict(color=(0.210, 0.115, 0.048), metallic=0.80, rough=0.66, wear=0.45),
    "dirt":          dict(color=(0.075, 0.048, 0.026), metallic=0.0, rough=0.94, wear=0.00),
    "accent_dark":   dict(color=(0.018, 0.018, 0.018), metallic=0.20, rough=0.48, wear=0.10),
    "soot":          dict(color=(0.012, 0.010, 0.009), metallic=0.15, rough=0.86,
                          wear=0.30),
    "ice":           dict(color=(0.520, 0.740, 0.880), metallic=0.0, rough=0.16,
                          wear=0.15, transmission=0.45),
    "glass":         dict(color=(0.760, 0.860, 0.920), metallic=0.0, rough=0.05,
                          wear=0.0, transmission=1.00),
    "water":         dict(color=(0.055, 0.230, 0.310), metallic=0.0, rough=0.12,
                          wear=0.0, transmission=0.60),
}


def mat(key):
    """Vrátí materiál z knihovny; barevné varianty jsou per-robot."""
    spec = _MAT_SPECS[key]
    tinted = "tint" in spec
    name = "NCR_%s_%s" % (_ACTIVE_ROBOT, key) if tinted else "NCR_%s" % key

    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing

    if tinted:
        base = ROBOT_COLORS[_ACTIVE_ROBOT]
        color = tuple(min(1.0, c * spec["tint"]) for c in base)
    else:
        color = spec["color"]

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    _set_input(bsdf, "Base Color", (color[0], color[1], color[2], 1.0))
    _set_input(bsdf, "Metallic", spec["metallic"])
    _set_input(bsdf, "Roughness", spec["rough"])

    if spec.get("transmission", 0.0) > 0.0:
        # 4.x přejmenovalo vstup na "Transmission Weight", 3.x měl "Transmission"
        _set_input(bsdf, "Transmission Weight", spec["transmission"])
        _set_input(bsdf, "Transmission", spec["transmission"])
        material.blend_method = 'BLEND'

    if spec.get("wear", 0.0) > 0.0:
        _add_wear_nodes(nt, bsdf, spec["rough"], spec["wear"])

    material.diffuse_color = (color[0], color[1], color[2], 1.0)  # viewport solid mode
    return material


def _set_input(node, name, value):
    if name in node.inputs:
        node.inputs[name].default_value = value


def _add_wear_nodes(nt, bsdf, rough, amount, scale=26.0):
    """Jemné škrábance / use-wear (spec §0.1) — proceduralní rozptyl drsnosti.
    Žádné textury, nic k zabalení, přežije to export do glTF jako baked
    hodnota (nebo se to před exportem prostě odpojí)."""
    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    map_range = nt.nodes.new("ShaderNodeMapRange")

    tex_coord.location = (-780, -200)
    noise.location = (-580, -200)
    map_range.location = (-360, -200)

    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 9.0
    _set_input(noise, "Roughness", 0.62)

    map_range.inputs["From Min"].default_value = 0.30
    map_range.inputs["From Max"].default_value = 0.72
    map_range.inputs["To Min"].default_value = max(0.02, rough - amount * 0.35)
    map_range.inputs["To Max"].default_value = min(1.0, rough + amount * 0.70)

    nt.links.new(tex_coord.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], map_range.inputs["Value"])
    nt.links.new(map_range.outputs["Result"], bsdf.inputs["Roughness"])


def set_material(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


# ---------------------------------------------------------------------------
# Primitiva
#
# Všechna vrací objekt s jednotkovým měřítkem a nulovou rotací — geometrie
# je zapečená v mesh datech. Díky tomu není co "applyovat" před exportem
# (import-assets §2.2) a modifikátory (bevel, boolean) se chovají předvídatelně.
#
#   size/r/h  rozměry
#   loc       kam přijde ORIGIN objektu (Vector nebo tuple)
#   shift     posun geometrie vůči originu (např. válec s originem v patě)
#   rot       rotace geometrie kolem originu, ve stupních
# ---------------------------------------------------------------------------

def _post(obj, name, loc, rot, shift, coll, material, smooth_angle, bevel_w, bevel_seg):
    if shift is not None:
        obj.data.transform(Matrix.Translation(Vector(shift)))
    if rot is not None:
        obj.data.transform(Euler([radians(a) for a in rot], 'XYZ').to_matrix().to_4x4())
    obj.location = Vector(loc)
    obj.name = name
    obj.data.name = name
    place(obj, coll)
    if material is not None:
        set_material(obj, material)
    if bevel_w:
        bevel(obj, bevel_w, bevel_seg)
    if smooth_angle:
        smooth(obj, smooth_angle)
    return obj


def box(name, size, loc=(0, 0, 0), rot=None, shift=None, coll=None,
        material=None, bevel_w=0.0, bevel_seg=2, smooth_angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    obj = bpy.context.object
    obj.data.transform(Matrix.Diagonal(Vector(size)).to_4x4())
    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, bevel_w, bevel_seg)


def cyl(name, r, h, loc=(0, 0, 0), rot=None, shift=None, verts=32, coll=None,
        material=None, bevel_w=0.0, bevel_seg=2, smooth_angle=30):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(0, 0, 0))
    obj = bpy.context.object
    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, bevel_w, bevel_seg)


def cone(name, r1, r2, h, loc=(0, 0, 0), rot=None, shift=None, verts=32, coll=None,
         material=None, bevel_w=0.0, bevel_seg=2, smooth_angle=30):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h,
                                    location=(0, 0, 0))
    obj = bpy.context.object
    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, bevel_w, bevel_seg)


def sphere(name, r, loc=(0, 0, 0), rot=None, shift=None, segments=48, rings=24,
           coll=None, material=None, smooth_angle=45):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=r,
                                         location=(0, 0, 0))
    obj = bpy.context.object
    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, 0.0, 0)


def torus(name, major_r, minor_r, loc=(0, 0, 0), rot=None, shift=None,
          major_seg=48, minor_seg=12, coll=None, material=None, smooth_angle=45):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=minor_r,
                                     major_segments=major_seg, minor_segments=minor_seg,
                                     location=(0, 0, 0))
    obj = bpy.context.object
    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, 0.0, 0)


def hemisphere(name, r, up=True, loc=(0, 0, 0), rot=None, shift=None,
               segments=48, rings=32, coll=None, material=None, smooth_angle=45):
    """Polokoule s rovnou podstavou v z = 0 (spec §0.1 — jádro jsou 2 polokoule)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=r,
                                         location=(0, 0, 0))
    obj = bpy.context.object

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [v for v in bm.verts if (v.co.z < -1e-6 if up else v.co.z > 1e-6)]
    bmesh.ops.delete(bm, geom=doomed, context='VERTS')
    border = [e for e in bm.edges if e.is_boundary]
    if border:
        bmesh.ops.edgeloop_fill(bm, edges=border)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()

    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, 0.0, 0)


def ring_band(name, outer, inner, width, loc=(0, 0, 0), rot=None, shift=None,
              coll=None, material=None, smooth_angle=0, closed=True):
    """Pás dané tloušťky z 2D profilu, vytlačený podél osy X.

    `outer` a `inner` jsou seznamy bodů (y, z) obcházející profil ve stejném
    pořadí. `closed=True` udělá prstenec (pásy podvozku — díra uvnitř nechá
    prosvítat kola), `closed=False` otevřené korýtko zavíčkované na koncích
    (lžíce).
    """
    n = len(outer)
    assert n == len(inner) and n >= 3
    half = width * 0.5
    verts = []
    for x in (-half, half):
        verts += [(x, y, z) for (y, z) in outer]
        verts += [(x, y, z) for (y, z) in inner]

    o0, i0, o1, i1 = 0, n, 2 * n, 3 * n
    faces = []
    for k in range(n if closed else n - 1):
        j = (k + 1) % n
        faces.append((o0 + k, o0 + j, i0 + j, i0 + k))   # čelo -X
        faces.append((o1 + k, i1 + k, i1 + j, o1 + j))   # čelo +X
        faces.append((o0 + k, o1 + k, o1 + j, o0 + j))   # vnější plášť
        faces.append((i0 + k, i0 + j, i1 + j, i1 + k))   # vnitřní plášť
    if not closed:                                       # víčka na koncích profilu
        faces.append((o0, i0, i1, o1))
        faces.append((o0 + n - 1, i0 + n - 1, i1 + n - 1, o1 + n - 1))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    return _post(obj, name, loc, rot, shift, coll, material, smooth_angle, 0.0, 0)


def hull_loft(name, sections, segments=24, coll=None, material=None,
              smooth_angle=40, loc=(0, 0, 0)):
    """Trup navlečený na elipsové řezy podél podélné osy (fwd).

    `sections` je seznam `(fwd, r_right, r_up, up_center)` seřazený podle fwd.
    Řez s nulovými poloměry je špička (jediný vrchol), takže se torpédo dá
    zakončit hrotem i uříznout do kruhového ústí.

    Souřadnice se překládají přes `p()`, takže se sekce píšou v návrhovém
    rámci stejně jako všechno ostatní.
    """
    verts = []
    rings = []
    for fwd, r_right, r_up, up_center in sections:
        if r_right <= 1e-6 and r_up <= 1e-6:
            rings.append([len(verts)])
            verts.append(tuple(p(fwd, 0.0, up_center)))
            continue
        ring = []
        for i in range(segments):
            a = 2.0 * pi * i / segments
            ring.append(len(verts))
            verts.append(tuple(p(fwd, r_right * cos(a), up_center + r_up * sin(a))))
        rings.append(ring)

    faces = []
    for near, far in zip(rings, rings[1:]):
        if len(near) == 1:
            faces += [(near[0], far[i], far[(i + 1) % segments]) for i in range(segments)]
        elif len(far) == 1:
            faces += [(near[i], near[(i + 1) % segments], far[0]) for i in range(segments)]
        else:
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((near[i], near[j], far[j], far[i]))
    for cap in (rings[0], rings[-1]):          # ploché konce zavíčkovat
        if len(cap) > 1:
            faces.append(tuple(cap))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    return _post(obj, name, loc, None, None, coll, material, smooth_angle, 0.0, 0)


def stadium(length, radius, arc_steps=10):
    """Body obrysu 'stadionu' (obdélník zakončený půlkruhy) v rovině YZ,
    střed v (0, 0), delší osa podél Y. Vrací seznam (y, z) proti směru hodin."""
    straight = max(0.0, length - 2.0 * radius) * 0.5
    pts = []
    for i in range(arc_steps + 1):           # přední oblouk
        a = -pi / 2 + pi * i / arc_steps
        pts.append((straight + radius * cos(a), radius * sin(a)))
    for i in range(arc_steps + 1):           # zadní oblouk
        a = pi / 2 + pi * i / arc_steps
        pts.append((-straight + radius * cos(a), radius * sin(a)))
    return pts


# ---------------------------------------------------------------------------
# Operace nad objekty
# ---------------------------------------------------------------------------

def _override(obj, extra=None):
    ctx = dict(object=obj, active_object=obj,
               selected_objects=[obj], selected_editable_objects=[obj])
    if extra:
        ctx.update(extra)
    return ctx


def apply_modifier(obj, name):
    prepare()
    obj.hide_set(False)
    try:
        with bpy.context.temp_override(**_override(obj)):
            bpy.ops.object.modifier_apply(modifier=name)
    except (AttributeError, RuntimeError):
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=name)
    return obj


def bevel(obj, width=0.004, segments=2, angle=40.0, apply=True, clamp=True):
    mod = obj.modifiers.new("ncr_bevel", 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    mod.angle_limit = radians(angle)
    mod.use_clamp_overlap = clamp
    if apply:
        apply_modifier(obj, mod.name)
    return obj


def cut(target, cutter, operation='DIFFERENCE', apply=True, solver='EXACT'):
    """Boolean. Cutter se po aplikaci smaže (spec §0.3 — CSG přístup)."""
    mod = target.modifiers.new("ncr_bool", 'BOOLEAN')
    mod.object = cutter
    mod.operation = operation
    try:
        mod.solver = solver
    except TypeError:
        pass
    cutter.display_type = 'WIRE'
    cutter.hide_render = True
    if apply:
        apply_modifier(target, mod.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def array(obj, count, offset, apply=True):
    """Konstantní pole (např. ostruhy pásu, panelové spáry)."""
    mod = obj.modifiers.new("ncr_array", 'ARRAY')
    mod.use_relative_offset = False
    mod.use_constant_offset = True
    mod.constant_offset_displace = Vector(offset)
    mod.count = count
    if apply:
        apply_modifier(obj, mod.name)
    return obj


def radial(obj, count, axis='Z', center=(0, 0, 0)):
    """Rozkopíruje objekt dokola (nýty jádra, zuby řetězky) a spojí v jeden.

    Update na začátku je nutný: kopie se počítají z `obj.matrix_world`, a ta
    je u čerstvě natočeného objektu (`align_to` nastavuje kvaternion) ještě
    nepřepočítaná. Bez toho se kopie rozletí kolem počátku scény —
    u Yeoových hrotů to vyhodilo kola 0.35u pod podlahu.
    """
    bpy.context.view_layer.update()
    pivot = Vector(center)
    copies = [obj]
    for i in range(1, count):
        dup = obj.copy()
        dup.data = obj.data.copy()
        place(dup, obj.users_collection[0] if obj.users_collection else None)
        rot = Matrix.Rotation(2 * pi * i / count, 4, axis)
        dup.matrix_world = (Matrix.Translation(pivot) @ rot @
                            Matrix.Translation(-pivot) @ obj.matrix_world)
        copies.append(dup)
    return join(copies, obj.name)


def join(objects, name=None):
    """Spojí objekty do prvního z nich."""
    objects = [o for o in objects if o is not None]
    if len(objects) == 1:
        if name:
            objects[0].name = name
            objects[0].data.name = name
        return objects[0]

    prepare()
    head = objects[0]
    ctx = dict(object=head, active_object=head,
               selected_objects=objects, selected_editable_objects=objects)
    try:
        with bpy.context.temp_override(**ctx):
            bpy.ops.object.join()
    except (AttributeError, RuntimeError):
        bpy.context.view_layer.objects.active = head
        for o in objects:
            o.select_set(True)
        bpy.ops.object.join()

    if name:
        head.name = name
        head.data.name = name
    return head


def smooth(obj, angle=30.0):
    """Smooth shading s ostrou hranou nad daným úhlem — napříč Blender 4.x."""
    for poly in obj.data.polygons:
        poly.use_smooth = True
    prepare()
    for op_name in ("shade_smooth_by_angle", "shade_auto_smooth"):
        op = getattr(bpy.ops.object, op_name, None)
        if op is None:
            continue
        try:
            with bpy.context.temp_override(**_override(obj)):
                op(angle=radians(angle))
            return obj
        except (AttributeError, RuntimeError, TypeError):
            continue
    try:                                   # Blender < 4.1
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = radians(angle)
    except AttributeError:
        pass
    return obj


def stretch(obj, factors):
    """Nerovnoměrně roztáhne geometrii kolem originu — z válce udělá eliptický
    válec, z koule elipsoid. Měřítko objektu zůstane jednotkové, takže není
    co applyovat před exportem."""
    obj.data.transform(Matrix.Diagonal(Vector(factors)).to_4x4())
    return obj


def set_origin(obj, point):
    """Přesune origin objektu na daný světový bod, geometrie zůstane na místě.
    Používá se u dílů, které se budou animovat rotací (korba, klouby ramene).

    Počítá se přes matrix_world, ne přes location: u objektu s rotací (což je
    každý díl posazený přes `align_to`) by rozdíl poloh vyšel v jiném prostoru
    než posun mesh dat a geometrie by odletěla.
    """
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    local = world.inverted() @ Vector(point)
    obj.data.transform(Matrix.Translation(-local))
    obj.matrix_world = world @ Matrix.Translation(local)
    return obj


def parent_to(child, parent):
    """Rodičovství se zachováním světové transformace (bez bpy.ops)."""
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    return child


def align_to(obj, origin, direction, roll=0.0):
    """Natočí objekt tak, aby jeho lokální +Z mířilo podél `direction`.

    Používá se na segmenty, které se modelují podél osy Z a pak se posadí
    mezi dva klouby — díky tomu nikde nepočítáme Eulery ručně.
    """
    quat = Vector((0.0, 0.0, 1.0)).rotation_difference(Vector(direction).normalized())
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = quat
    if roll:
        obj.rotation_quaternion = quat @ Euler((0.0, 0.0, radians(roll))).to_quaternion()
    obj.location = Vector(origin)
    return obj


def limb(name, a, b, radius=None, size=None, coll=None, material=None,
         verts=16, bevel_w=0.0, smooth_angle=0, taper=None):
    """Článek mezi dvěma body — hranol (`size=(w, d)`) nebo válec (`radius`).

    Origin sedí v bodě `a`, tedy v kloubu: rotací objektu se článek ohýbá
    přesně kolem něj (spec §0.3 — mechanismus jako samostatný objekt na kloubu).
    """
    a, b = Vector(a), Vector(b)
    vec = b - a
    length = vec.length

    if size is not None:
        obj = box(name, (size[0], size[1], length), shift=(0, 0, length * 0.5),
                  coll=coll, material=material, bevel_w=bevel_w,
                  smooth_angle=smooth_angle)
    elif taper is not None:
        obj = cone(name, taper[0], taper[1], length, shift=(0, 0, length * 0.5),
                   verts=verts, coll=coll, material=material, bevel_w=bevel_w,
                   smooth_angle=smooth_angle or 30)
    else:
        obj = cyl(name, radius, length, shift=(0, 0, length * 0.5), verts=verts,
                  coll=coll, material=material, bevel_w=bevel_w,
                  smooth_angle=smooth_angle or 30)

    return align_to(obj, a, vec)


def hydraulic(name, a, b, radius, coll=None, material=None, rod_material=None,
              barrel_ratio=0.58, verts=16):
    """Hydraulický píst mezi dvěma body: válec + pístnice.

    Vrací dva objekty. Válec má origin v `a`, pístnice v `b` — každý z nich
    tedy patří jinému článku a při animaci se píst sám natáhne.
    """
    a, b = Vector(a), Vector(b)
    barrel = limb(name + "_Barrel", a, a + (b - a) * barrel_ratio, radius=radius,
                  verts=verts, coll=coll,
                  material=material if material is not None else mat("metal_dark"),
                  bevel_w=0.003)
    rod = limb(name + "_Rod", b, a + (b - a) * max(0.0, barrel_ratio - 0.06),
               radius=radius * 0.45, verts=max(8, verts - 2), coll=coll,
               material=rod_material if rod_material is not None else mat("metal_polish"))
    return [barrel, rod]


# ---------------------------------------------------------------------------
# Nápis v hangulu (spec §0.1)
# ---------------------------------------------------------------------------

def find_hangul_font():
    for path in HANGUL_FONTS:
        if os.path.isfile(path):
            return path
    return None


def decal_text(name, body, target, center, direction, size=0.085, thickness=0.0035,
               coll=None, material=None, font_path=None, roll=0.0, lift=0.0012):
    """Nalepí text na zakřivený povrch `target` (shrinkwrap projekcí) a udělá
    z něj tenkou samostatnou skořepinu — "vypálený" nápis odlišným odstínem.

    `center`    střed objektu, na který se promítá
    `direction` kam nápis kouká (normála povrchu v místě nápisu)
    """
    prepare()
    direction = Vector(direction).normalized()

    font_path = font_path or find_hangul_font()
    bpy.ops.object.text_add(location=(0, 0, 0))
    txt = bpy.context.object
    txt.name = name
    txt.data.body = body
    txt.data.size = size
    txt.data.align_x = 'CENTER'
    txt.data.align_y = 'CENTER'
    txt.data.extrude = 0.0

    if font_path:
        txt.data.font = bpy.data.fonts.load(font_path, check_existing=True)
    else:
        print("[NCR] VAROVÁNÍ: nenašel jsem font s hangulem (%s). "
              "Nápis '%s' se vykreslí výchozím fontem jako prázdné rámečky — "
              "nastav cestu k fontu v ncr_common.HANGUL_FONTS."
              % (", ".join(HANGUL_FONTS[:2]) + ", ...", body))

    # postav text před povrch a promítni ho zpět na něj
    align_to(txt, Vector(center) + direction * 0.4, direction, roll=roll)
    with bpy.context.temp_override(**_override(txt)):
        bpy.ops.object.convert(target='MESH')
    txt = bpy.context.view_layer.objects.get(name) or txt

    shrink = txt.modifiers.new("ncr_wrap", 'SHRINKWRAP')
    shrink.target = target
    shrink.wrap_method = 'PROJECT'
    shrink.use_project_z = True
    shrink.use_negative_direction = True
    shrink.use_positive_direction = False
    shrink.offset = 0.0
    apply_modifier(txt, shrink.name)

    # Druhý průchod po normále povrchu. Samotná projekce položí písmo na kouli,
    # ale solidify pak tlačí do jednoho směru, takže okraje glyfu se při
    # zakřivení utopí pod povrchem (průhyb je u 0.085 znaku na r=0.15 asi 0.006,
    # tedy víc než tloušťka). Tenhle krok nadzvedne každý vrchol kolmo.
    lift_mod = txt.modifiers.new("ncr_lift", 'SHRINKWRAP')
    lift_mod.target = target
    lift_mod.wrap_method = 'NEAREST_SURFACEPOINT'
    lift_mod.offset = lift
    apply_modifier(txt, lift_mod.name)

    solid = txt.modifiers.new("ncr_solid", 'SOLIDIFY')
    solid.thickness = thickness
    solid.offset = 1.0
    apply_modifier(txt, solid.name)

    place(txt, coll)
    if material is not None:
        set_material(txt, material)
    set_origin(txt, center)
    return txt
