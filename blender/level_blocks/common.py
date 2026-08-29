# -*- coding: utf-8 -*-
"""
Modely bloků herní mřížky (zatím jen šikmina) — sdílená knihovna.

Na rozdíl od `blender/devices/common.py` (plochá PBR paleta bez textur) tenhle
modul poprvé v `blender/` nese **obrázkovou texturu**: šikmina má podle
zadání nést stejnou ocelovou texturu jako blok WALL
(`game/assets/level_blocks/textures/zed_ocel.jpg`, viz
`docs/zadani_textury_kostky_urovne_dalle.md`) — bloky samotné (WALL, DIRT, …)
žádný Blender model nemají, jsou to ploché `BoxMesh` v Godotu s texturou
přímo na materiálu (`WorldView.BLOCK_TEXTURES`), šikmina je zatím jediná
výjimka, protože nejde o kvádr.

Stejný souřadný rámec jako roboti/zařízení: `ncr_common.p(fwd, right, up)`,
1 buňka = 1 unit, origin ve středu buňky, podlaha na `up = 0`, čelo modelu
k `-Y` (po exportu `godot_forward` z toho udělá `Direction.NORTH`).
"""

import bpy
import bmesh
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
            "blender/level_blocks i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")   # p(), primitiva, prepare/collection/place/purge/godot_forward

# ---------------------------------------------------------------------------
# Cesta k texturám bloků mřížky — stejný soubor, který ve hře používá
# `WorldView.BLOCK_TEXTURES[GridTypes.BlockType.WALL]`, aby šikmina a zeď
# viditelně patřily ke stejné "ocelové" rodině (§ zadání).
# ---------------------------------------------------------------------------

def _textures_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(os.path.dirname(here))   # .../blender/level_blocks -> .../NCR
    return os.path.join(repo, "game", "assets", "level_blocks", "textures")


def block_texture_material(key, texture_filename, metallic=0.10, rough=0.60):
    """Materiál s obrázkovou texturou na Base Color — `key` je název v
    `bpy.data.materials` (`LVLBLK_<key>`), `texture_filename` soubor ve
    `game/assets/level_blocks/textures/`. Textura se načítá jednou a znovu
    použije při opakovaném běhu skriptu (stejný vzor jako `mat()` jinde)."""
    name = "LVLBLK_%s" % key
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing

    path = os.path.join(_textures_dir(), texture_filename)
    image = bpy.data.images.load(path, check_existing=True)

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')

    tex_node = nt.nodes.new("ShaderNodeTexImage")
    tex_node.image = image
    tex_node.location = (bsdf.location.x - 300, bsdf.location.y)
    nt.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough

    material.diffuse_color = (0.5, 0.5, 0.5, 1.0)   # jen viewport solid mode
    return material


# ---------------------------------------------------------------------------
# Klínová šikmina — bokorys pravoúhlého trojúhelníku (design dok. §2.1.4:
# "objem jedné kostky"), vysoká/svislá strana na `fwd = +0.5` (= Blender -Y =
# model čelo), nízká na `fwd = -0.5`. Pravý úhel je vpředu-dole, přepona
# (pochozí plocha) jde z nízké zadní hrany do vrcholu vysoké přední stěny.
# ---------------------------------------------------------------------------

def ramp_wedge(name, coll, material, uv_scale=1.0):
    p = nc.p

    # (fwd, right, up) rohy klínu.
    lo_l = p(-0.5, -0.5, 0.0)   # nízká hrana, vlevo
    lo_r = p(-0.5, 0.5, 0.0)    # nízká hrana, vpravo
    hi_bl = p(0.5, -0.5, 0.0)   # pravý úhel dole, vlevo
    hi_br = p(0.5, 0.5, 0.0)    # pravý úhel dole, vpravo
    hi_tl = p(0.5, -0.5, 1.0)   # vrchol svislé stěny, vlevo
    hi_tr = p(0.5, 0.5, 1.0)    # vrchol svislé stěny, vpravo

    verts = [tuple(v) for v in (lo_l, lo_r, hi_bl, hi_br, hi_tl, hi_tr)]
    LO_L, LO_R, HI_BL, HI_BR, HI_TL, HI_TR = range(6)

    slope_len = ((1.0) ** 2 + (1.0) ** 2) ** 0.5   # délka přepony v jednotkách buňky

    # Každá dvojice (vrchol, UV) — UV v reálných jednotkách buňky (ne 0..1),
    # ať textura drží stejnou hustotu jako na sousední kostce WALL (ta má
    # výchozí UV krychle 0..1 na jednotku), viz `uv_scale`.
    faces = []

    def quad(a, b, c, d, uv_a, uv_b, uv_c, uv_d):
        faces.append(((a, b, c, d), (uv_a, uv_b, uv_c, uv_d)))

    def tri(a, b, c, uv_a, uv_b, uv_c):
        faces.append(((a, b, c), (uv_a, uv_b, uv_c)))

    s = uv_scale
    # Podlaha klínu (fwd -0.5..0.5, right -0.5..0.5), normála dolů.
    quad(LO_L, HI_BL, HI_BR, LO_R,
         (0.0, 0.0), (s, 0.0), (s, s), (0.0, s))
    # Svislá vysoká stěna (fwd = 0.5, up 0..1), normála dopředu (-Y).
    quad(HI_BR, HI_BL, HI_TL, HI_TR,
         (0.0, 0.0), (s, 0.0), (s, s), (0.0, s))
    # Přepona — pochozí plocha (normála šikmo nahoru-dozadu).
    quad(LO_R, LO_L, HI_TL, HI_TR,
         (0.0, 0.0), (s, 0.0), (s, s * slope_len), (0.0, s * slope_len))
    # Boční trojúhelníkové stěny (right = ±0.5).
    tri(LO_L, HI_BL, HI_TL, (0.0, 0.0), (s, 0.0), (s, s))
    tri(HI_BR, LO_R, HI_TR, (0.0, 0.0), (s, 0.0), (s, s))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [f[0] for f in faces])
    mesh.validate()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        _, uvs = faces[poly.index]
        for loop_index, uv in zip(poly.loop_indices, uvs):
            uv_layer.data[loop_index].uv = uv

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    obj.name = name
    obj.data.name = name
    nc.place(obj, coll)
    if material is not None:
        nc.set_material(obj, material)
    return obj
