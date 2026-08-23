# -*- coding: utf-8 -*-
"""
Terén — jedna souvislá mřížka `T_teren_hlavni` (kap. 3).

Rozlišení jednotné 1.0 m (dokument to výslovně povoluje jako zjednodušení
místo 1.0/1.5 m). Výška a materiálová zóna se počítají analyticky přes
`common.height()` / `common.terrain_zone()`, stejné funkce jako
`snap_to_ground()`, takže vše, co se staví později, sedí na stejný povrch.

Objekty: T_teren_hlavni
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
            "blender/krajina i z blender/common." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


C = _ncr_import("common")
nc = C.nc

RES = 1.0                 # rozlišení mřížky, jednotné (kap. 3 to povoluje)

# Hora se v mřížce navíc "zhrubne" na fazety (kap. 9.1: rozlišení 3 m, vrcholy
# ±0.8 m). Jednodušší než stavět dvě mřížky s jinou hustotou a šít je k sobě:
# mřížka zůstává 1.0 m všude (stejná topologie, stejný počet trojúhelníků),
# ale výška vzorku se pro Y > ~105 vezme z hodnoty zaokrouhlené na 3m mřížku
# a rozhodí jitterem — sousední vrcholy tak sdílí plošinky a vznikne hranatý,
# fazetovaný vzhled bez přestavby sítě.
FACET_STEP = 3.0
FACET_START = 105.0
FACET_FULL = 118.0

ZONE_KEYS = ("trava_zahrada", "trava_louka", "jehlici_zeme",
             "trava_ridka", "kamen_balvan", "kamen_skala", "hlina_holy")

PREFIXES = ("T_teren",)


def _mountain_facet_height(x, y):
    xs = round(x / FACET_STEP) * FACET_STEP
    ys = round(y / FACET_STEP) * FACET_STEP
    zf = C.height(xs, ys)
    j = (C.value_noise(x, y, scale=1.7, seed=21) * 2.0 - 1.0) * 0.8
    return zf + j


def terrain_height(x, y):
    z = C.height(x, y)
    if y > FACET_START:
        t = C.smoothstep(FACET_START, FACET_FULL, y)
        if t > 0.0:
            z = C.lerp(z, _mountain_facet_height(x, y), t)
    return z


def build_terrain(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("T_Teren",))
    own_coll = nc.collection("T_Teren", coll)

    x0, y0, x1, y1 = C.TERRAIN_BOUNDS
    nx = int(round((x1 - x0) / RES)) + 1
    ny = int(round((y1 - y0) / RES)) + 1

    verts = []
    idx = {}
    for iy in range(ny):
        y = y0 + iy * RES
        for ix in range(nx):
            x = x0 + ix * RES
            idx[(ix, iy)] = len(verts)
            verts.append((x, y, terrain_height(x, y)))

    portal_x, portal_y = C.CAVE_PORTAL
    hole_hw = C.CAVE_PORTAL_SIZE[0] * 0.5
    hole_hh = C.CAVE_PORTAL_SIZE[1] * 0.5

    faces = []
    face_zone = []
    for iy in range(ny - 1):
        for ix in range(nx - 1):
            cx = x0 + (ix + 0.5) * RES
            cy = y0 + (iy + 0.5) * RES
            # otvor v terénu pro ústí jeskyně (kap. 10 hlavička) — jeskyně se
            # staví samostatně v 09_jeskyne.py, ale souřadnice portálu jsou
            # pevné v common.py, takže díra vzniká vždy nezávisle na pořadí buildu
            if (C.CAVE_PORTAL_HOLE and abs(cx - portal_x) < hole_hw
                    and abs(cy - portal_y) < hole_hh):
                continue
            a = idx[(ix, iy)]
            b = idx[(ix + 1, iy)]
            cc = idx[(ix + 1, iy + 1)]
            d = idx[(ix, iy + 1)]
            cz = (verts[a][2] + verts[b][2] + verts[cc][2] + verts[d][2]) * 0.25
            faces.append((a, b, cc, d))
            face_zone.append(C.terrain_zone(cx, cy, cz))

    mesh = bpy.data.meshes.new("T_teren_hlavni")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    for poly in mesh.polygons:
        poly.use_smooth = False   # flat shading (kap. 1)

    zone_slot = {}
    for key in ZONE_KEYS:
        zone_slot[key] = len(mesh.materials)
        mesh.materials.append(C.get_material(key))

    for poly, zone in zip(mesh.polygons, face_zone):
        poly.material_index = zone_slot.get(zone, 0)

    obj = bpy.data.objects.new("T_teren_hlavni", mesh)
    bpy.context.scene.collection.objects.link(obj)
    nc.place(obj, own_coll)

    tris = C.triangle_count([obj])
    print("[NCR] teren: %d vrcholu, %d ploch (%d trojuhelniku)" % (len(verts), len(faces), tris))
    return [obj]


if __name__ == "__main__":
    build_terrain()
