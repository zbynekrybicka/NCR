# -*- coding: utf-8 -*-
"""
Cesta — páteř scény (kap. 4). Dvě geometrie v kolekci `P_Cesta`:

  * `P_cesta_dlazba` — kamenná dlažba v zahradě (Y 0..21), nepravidelné
    pláty jako jedna dávková mesh (žádné `bpy.ops` na stovky objektů).
  * `P_cesta_hlina`  — ušlapaná hlína od Y=21 dál, souvislý pás kopírující
    terén, zužující se a mizející na hoře.

Kap. 1.2 vyjmenovává kolekce jen pro sedm sekcí + terén + helpery — cesta
mezi ně organizačně nezapadá (probíhá skrz všechny), proto má vlastní
kolekci `P_Cesta` navěšenou vedle nich pod `Krajina` (viz README).

Objekty: P_cesta_dlazba, P_cesta_hlina
"""

import bpy
import os
import sys
import types
import importlib
import math


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

GARDEN_END = 21.0
PAVERS_PER_METER = (5, 7)
PAVER_RADIUS = (0.16, 0.24)
PAVER_THICKNESS = 0.06

VANISH_START = 150.0        # od tady se náhodně vynechávají úseky hlíny
VANISH_PROB = 0.30

PREFIXES = ("P_cesta",)


def _path_width(y):
    if y < 70.0:
        return 1.2      # zahrada + louka
    if y < 112.0:
        return 1.0       # les
    if y < 140.0:
        return 0.9       # přechod do hory
    return 0.8            # hora — dál mizí (viz VANISH_START)


def _tangent(points, i):
    if i == 0:
        dx, dy = points[1][0] - points[0][0], points[1][1] - points[0][1]
    elif i == len(points) - 1:
        dx, dy = points[-1][0] - points[-2][0], points[-1][1] - points[-2][1]
    else:
        dx, dy = points[i + 1][0] - points[i - 1][0], points[i + 1][1] - points[i - 1][1]
    length = math.hypot(dx, dy)
    if length < 1e-6:
        return (0.0, 1.0)
    return (dx / length, dy / length)


def _make_paver(batch, cx, cy, cz, radius, sides, rot_deg):
    verts_top = []
    a0 = math.radians(rot_deg)
    for i in range(sides):
        a = a0 + 2.0 * math.pi * i / sides
        rr = radius * (0.75 + 0.35 * C.rng.random())   # nepravidelný obrys
        verts_top.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz))
    verts_bottom = [(x, y, cz - PAVER_THICKNESS) for (x, y, _) in verts_top]
    all_verts = verts_top + verts_bottom
    n = sides
    top_face = tuple(range(n))
    bottom_face = tuple(reversed(range(n, 2 * n)))
    side_faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    batch.add(all_verts, [top_face, bottom_face] + side_faces)


def _build_pavers(batch):
    """Cesta v zahradě je téměř přesně rovná (PATH_POINTS: (0,0) -> (0,21)),
    takže pláty stačí rozptýlit po metrových úsecích podél X=0."""
    width = _path_width(1.0)
    for meter in range(int(GARDEN_END)):
        count = C.rng.randint(*PAVERS_PER_METER)
        for _ in range(count):
            px = C.rng.uniform(-width * 0.5 + 0.12, width * 0.5 - 0.12)
            py = C.rng.uniform(meter + 0.05, meter + 0.95)
            radius = C.rng.uniform(*PAVER_RADIUS)
            sides = C.rng.choice((5, 6))
            rot = C.rng.uniform(0.0, 360.0)
            sunken = C.rng.uniform(-0.015, 0.005)   # některé kameny lehce zapadlé
            z = C.snap_to_ground(px, py) + sunken
            _make_paver(batch, px, py, z, radius, sides, rot)


def _build_dirt_ribbon(batch):
    raw = [p for p in C.PATH_POINTS if p[1] >= GARDEN_END - 1.0]
    samples = C.resample_polyline(raw, step=1.0)
    samples = [p for p in samples if p[1] >= GARDEN_END - 1e-6]

    for i in range(len(samples) - 1):
        x0, y0 = samples[i]
        x1, y1 = samples[i + 1]

        if y0 >= VANISH_START and C.rng.random() < VANISH_PROB:
            continue

        tx, ty = _tangent(samples, i)
        nx, ny = -ty, tx
        w0, w1 = _path_width(y0), _path_width(y1)
        j0 = C.rng.uniform(-0.12, 0.12)
        j1 = C.rng.uniform(-0.12, 0.12)

        lx0, ly0 = x0 + nx * (w0 * 0.5 + j0), y0 + ny * (w0 * 0.5 + j0)
        rx0, ry0 = x0 - nx * (w0 * 0.5 + j0), y0 - ny * (w0 * 0.5 + j0)
        lx1, ly1 = x1 + nx * (w1 * 0.5 + j1), y1 + ny * (w1 * 0.5 + j1)
        rx1, ry1 = x1 - nx * (w1 * 0.5 + j1), y1 - ny * (w1 * 0.5 + j1)

        zl0 = C.snap_to_ground(lx0, ly0) + 0.03
        zr0 = C.snap_to_ground(rx0, ry0) + 0.03
        zl1 = C.snap_to_ground(lx1, ly1) + 0.03
        zr1 = C.snap_to_ground(rx1, ry1) + 0.03

        batch.add([(lx0, ly0, zl0), (rx0, ry0, zr0), (rx1, ry1, zr1), (lx1, ly1, zl1)],
                  [(0, 1, 2, 3)])


def build_path(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("P_Cesta",))
    own_coll = nc.collection("P_Cesta", coll)

    dlazba_batch = C.Batch()
    _build_pavers(dlazba_batch)
    dlazba_obj = dlazba_batch.build("P_cesta_dlazba", coll=own_coll,
                                     material=C.get_material("kamen_dlazba"))

    hlina_batch = C.Batch()
    _build_dirt_ribbon(hlina_batch)
    hlina_obj = hlina_batch.build("P_cesta_hlina", coll=own_coll,
                                   material=C.get_material("hlina_cesta"))

    objs = [o for o in (dlazba_obj, hlina_obj) if o is not None]
    tris = C.triangle_count(objs)
    print("[NCR] cesta: %d objektu, %d trojuhelniku" % (len(objs), tris))
    return objs


if __name__ == "__main__":
    build_path()
