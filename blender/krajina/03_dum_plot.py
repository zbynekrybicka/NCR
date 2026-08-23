# -*- coding: utf-8 -*-
"""
Sekce A — dům (kap. 5.1) a plot s brankou (kap. 5.2).

Dům je jen průčelí a mělká hmota (hráč dovnitř nejde). Plot ohraničuje
zahradu po obvodu a navazuje na roh domu; sloupky a plaňky jsou dávková
geometrie (stovky planěk -> jedna mesh, kap. 1.3 bod 3/4), branka je
samostatný objekt otočený kolem levého sloupku (stejný trik jako klouby
u robotů: `nc.set_origin` na pant, pak rotace).

Objekty: A_dum_*, A_plot_*, A_branka
"""

import bpy
import os
import sys
import types
import importlib
import math
from math import radians


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

# --- dům (kap. 5.1) ---------------------------------------------------------

HOUSE_X = (-5.0, 5.0)
HOUSE_Y = (-6.0, 0.0)
HOUSE_EAVE_H = 4.2
HOUSE_RIDGE_H = 6.8
ROOF_OVERHANG = 0.4
DOOR_SIZE = (0.9, 2.0)
DOOR_RECESS = 0.08
CANOPY_SIZE = (1.6, 0.7, 0.08)
CANOPY_H = 2.3
WINDOW_X = (-2.8, 2.8)
WINDOW_SIZE = (1.0, 1.2)
WINDOW_SILL = 1.1
WINDOW_FRAME = 0.08

# --- plot a branka (kap. 5.2) -----------------------------------------------

FENCE_X = 12.0
FENCE_Y1 = 21.0
POST_SIZE = (0.10, 0.10)
POST_H = 1.1
POST_PITCH = 1.8
LATH_SIZE = (0.08, 0.03)
LATH_HEIGHTS = (0.35, 0.85)
PALING_SIZE = (0.10, 0.02)
PALING_H = 1.0
PALING_PITCH = 0.16       # šířka + mezera
GATE_HALF = 0.7
GATE_ANGLE = 12.0

PREFIXES = ("A_dum", "A_plot", "A_branka")


def _z0(x, y):
    return C.snap_to_ground(x, y)


# ---------------------------------------------------------------------------
# Dům
# ---------------------------------------------------------------------------

def _build_house(coll):
    cx = (HOUSE_X[0] + HOUSE_X[1]) * 0.5
    cy = (HOUSE_Y[0] + HOUSE_Y[1]) * 0.5
    z0 = _z0(cx, cy)
    width = HOUSE_X[1] - HOUSE_X[0]
    depth = HOUSE_Y[1] - HOUSE_Y[0]

    # bez bevelu — spec (kap. 1) zakazuje bevely s víc než 1 segmentem a
    # ncr_common.box()'s výchozí bevel_seg=2 by to porušil
    walls = nc.box("A_dum_zed", (width, depth, HOUSE_EAVE_H),
                    loc=(cx, cy, z0 + HOUSE_EAVE_H * 0.5), coll=coll,
                    material=C.get_material("omitka_dum"))

    # sedlová střecha — ručně, aby měla hřeben (box to nedá)
    hw = width * 0.5 + ROOF_OVERHANG
    y_front = HOUSE_Y[1] + ROOF_OVERHANG
    y_back = HOUSE_Y[0] - ROOF_OVERHANG
    eave_z = z0 + HOUSE_EAVE_H
    ridge_z = z0 + HOUSE_RIDGE_H
    a = (-hw, y_back, eave_z)
    b = (hw, y_back, eave_z)
    cc = (hw, y_front, eave_z)
    d = (-hw, y_front, eave_z)
    r0 = (0.0, y_back, ridge_z)
    r1 = (0.0, y_front, ridge_z)
    verts = [a, b, cc, d, r0, r1]
    faces = [(0, 3, 5, 4), (4, 5, 2, 1), (0, 4, 1), (3, 2, 5)]
    roof = C.new_mesh_object("A_dum_strecha", verts, faces, coll=coll,
                              material=C.get_material("strecha"))

    # vstupní dveře, zapuštěné do stěny Y=0
    door_y = HOUSE_Y[1] - DOOR_RECESS * 0.5
    door = nc.box("A_dum_dvere", (DOOR_SIZE[0], DOOR_RECESS, DOOR_SIZE[1]),
                   loc=(0.0, door_y, z0 + DOOR_SIZE[1] * 0.5), coll=coll,
                   material=C.get_material("drevo_tmave"))

    # stříška nad dveřmi + 2 vzpěry
    canopy = nc.box("A_dum_strizka", CANOPY_SIZE,
                     loc=(0.0, HOUSE_Y[1] + CANOPY_SIZE[1] * 0.5 - 0.05, z0 + CANOPY_H),
                     coll=coll, material=C.get_material("drevo_plot"))
    struts = []
    for side in (-1, 1):
        a_pt = (side * 0.55, HOUSE_Y[1] - 0.02, z0 + CANOPY_H - 0.15)
        b_pt = (side * 0.55, HOUSE_Y[1] + CANOPY_SIZE[1] - 0.10, z0 + CANOPY_H)
        struts.append(nc.limb("A_dum_vzpera_%d" % (side > 0), a_pt, b_pt,
                               radius=0.02, verts=6, coll=coll,
                               material=C.get_material("drevo_plot")))

    # okna
    windows = []
    for i, wx in enumerate(WINDOW_X):
        win_cz = z0 + WINDOW_SILL + WINDOW_SIZE[1] * 0.5
        frame = nc.box("A_dum_okno_ram_%d" % i,
                        (WINDOW_SIZE[0], WINDOW_FRAME, WINDOW_SIZE[1]),
                        loc=(wx, HOUSE_Y[1] - WINDOW_FRAME * 0.5, win_cz),
                        coll=coll, material=C.get_material("drevo_tmave"))
        glass = nc.box("A_dum_okno_sklo_%d" % i,
                        (WINDOW_SIZE[0] - 0.10, 0.02, WINDOW_SIZE[1] - 0.10),
                        loc=(wx, HOUSE_Y[1] - 0.01, win_cz),
                        coll=coll, material=C.get_material("sklo"))
        windows.append(nc.join([frame, glass], "A_dum_okno_%d" % i))

    # okap podél okapové hrany + jeden svod
    eave_beam = nc.box("A_dum_okap", (width + 0.1, 0.08, 0.08),
                        loc=(cx, HOUSE_Y[1] + 0.04, eave_z - 0.02),
                        coll=coll, material=C.get_material("kov"))
    downspout = nc.cyl("A_dum_svod", 0.02, HOUSE_EAVE_H, verts=8, smooth_angle=0,
                        loc=(-4.6, HOUSE_Y[1] + 0.04, z0 + HOUSE_EAVE_H * 0.5),
                        coll=coll, material=C.get_material("kov"))

    # práh + dva schody z dlažby
    threshold = nc.box("A_dum_prah", (1.4, 0.5, 0.12),
                        loc=(0.0, 0.35, z0 + 0.06), coll=coll,
                        material=C.get_material("kamen_dlazba"))
    steps = []
    for i in range(2):
        sy = 0.75 + i * 0.35
        steps.append(nc.box("A_dum_schod_%d" % i, (1.2 - i * 0.2, 0.30, 0.08 - i * 0.02),
                             loc=(0.0, sy, z0 + 0.04 - i * 0.02), coll=coll,
                             material=C.get_material("kamen_dlazba")))

    parts = [walls, roof, door, canopy] + struts + windows
    parts += [eave_beam, downspout, threshold] + steps
    return parts


# ---------------------------------------------------------------------------
# Plot a branka
# ---------------------------------------------------------------------------

def _fence_edge_points():
    """Tři úseky plotu (kap. 5.2): dvě strany X=±12 od Y=0 do 21, a čelo Y=21."""
    return [
        ((-FENCE_X, 0.0), (-FENCE_X, FENCE_Y1)),
        ((FENCE_X, 0.0), (FENCE_X, FENCE_Y1)),
        ((-FENCE_X, FENCE_Y1), (FENCE_X, FENCE_Y1)),
    ]


def _lerp_pt(p0, p1, t):
    return (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t)


def _build_posts(coll):
    proto = nc.box("A_plot_sloupek_proto", (POST_SIZE[0], POST_SIZE[1], POST_H),
                    loc=(0.0, 0.0, 0.0), shift=(0.0, 0.0, POST_H * 0.5),
                    material=C.get_material("drevo_plot"))
    posts = []
    idx = 0
    for p0, p1 in _fence_edge_points():
        length = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        n = max(1, int(round(length / POST_PITCH)))
        for i in range(n + 1):
            t = i / n
            x, y = _lerp_pt(p0, p1, t)
            z = _z0(x, y)
            name = "A_plot_sloupek_%03d" % idx
            idx += 1
            post = C.link_dup(name, proto, (x, y, z), coll=coll)
            post.rotation_euler = (radians(C.rng.uniform(-2.5, 2.5)),
                                    radians(C.rng.uniform(-2.5, 2.5)), 0.0)
            posts.append(post)
    bpy.data.objects.remove(proto, do_unlink=True)
    return posts


def _build_laths(coll):
    batch = C.Batch()
    for p0, p1 in _fence_edge_points():
        length = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
        mx, my = _lerp_pt(p0, p1, 0.5)
        for h in LATH_HEIGHTS:
            mz = _z0(mx, my) + h
            verts, faces = C.box_verts(mx, my, mz, length, LATH_SIZE[0], LATH_SIZE[1],
                                        rot_z=ang)
            batch.add(verts, faces)
    return batch.build("A_plot_laty", coll=coll, material=C.get_material("drevo_plot"))


def _plank_verts(cx, cy, cz, rot_z, height):
    """Plaňka s hrotem — 4 spodní vrcholy + jeden vrchol jako špička."""
    hx, hy = PALING_SIZE[0] * 0.5, PALING_SIZE[1] * 0.5
    local_bottom = [(-hx, -hy, 0.0), (hx, -hy, 0.0), (hx, hy, 0.0), (-hx, hy, 0.0)]
    apex_local = (0.0, 0.0, height + 0.05)
    a = math.radians(rot_z)
    cz_, sz_ = math.cos(a), math.sin(a)
    verts = []
    for (x, y, z) in local_bottom:
        verts.append((cx + x * cz_ - y * sz_, cy + x * sz_ + y * cz_, cz))
    ax, ay, az = apex_local
    verts.append((cx + ax * cz_ - ay * sz_, cy + ax * sz_ + ay * cz_, cz + az))
    faces = [(0, 1, 2, 3), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    return verts, faces


def _build_palings(coll):
    batch = C.Batch()
    missing = 0
    leaning = 0
    for p0, p1 in _fence_edge_points():
        length = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
        n = int(length / PALING_PITCH)
        for i in range(n):
            t = (i + 0.5) / n
            x, y = _lerp_pt(p0, p1, t)
            # branka na Y=21, X in <-0.7, 0.7> — plaňky tam vynechat
            if abs(y - FENCE_Y1) < 0.01 and abs(x) < GATE_HALF:
                continue
            r = C.rng.random()
            if r < 0.012 and missing < 5:      # 3-5 chybí (kap. 5.2)
                missing += 1
                continue
            lean = 0.0
            if r > 0.988 and leaning < 6:       # 4-6 nakloněných
                leaning += 1
                lean = C.rng.uniform(-4.0, 4.0)
            z = _z0(x, y)
            verts, faces = _plank_verts(x, y, z, ang + lean, PALING_H)
            batch.add(verts, faces)
    return batch.build("A_plot_planky", coll=coll, material=C.get_material("drevo_plot"))


def _build_gate(coll):
    hinge_x, hinge_y = -GATE_HALF, FENCE_Y1
    hinge = (hinge_x, hinge_y, _z0(hinge_x, hinge_y))
    z0 = hinge[2]

    frame_top = nc.box("A_branka_ram_horni", (GATE_HALF * 2, LATH_SIZE[0], LATH_SIZE[1]),
                        loc=(0.0, FENCE_Y1, z0 + 1.05 - 0.03), coll=coll,
                        material=C.get_material("drevo_plot"))
    frame_bottom = nc.box("A_branka_ram_dolni", (GATE_HALF * 2, LATH_SIZE[0], LATH_SIZE[1]),
                           loc=(0.0, FENCE_Y1, z0 + 0.10), coll=coll,
                           material=C.get_material("drevo_plot"))
    planks = []
    n = 6
    for i in range(n):
        t = (i + 0.5) / n
        x = -GATE_HALF + 2 * GATE_HALF * t
        verts, faces = _plank_verts(x, FENCE_Y1, z0, 0.0, 1.05)
        planks.append(C.new_mesh_object("A_branka_planka_%d" % i, verts, faces,
                                         material=C.get_material("drevo_plot")))
    hinges = []
    for hz in (0.20, 0.85):
        hinges.append(nc.box("A_branka_pant_%.2f" % hz, (0.12, 0.02, 0.04),
                              loc=(hinge_x, FENCE_Y1, z0 + hz), coll=coll,
                              material=C.get_material("kov")))
    latch = nc.box("A_branka_zapadka", (0.10, 0.03, 0.03),
                    loc=(GATE_HALF, FENCE_Y1, z0 + 0.6), coll=coll,
                    material=C.get_material("kov"))

    gate = nc.join([frame_top, frame_bottom] + planks + hinges + [latch], "A_branka")
    nc.place(gate, coll)
    nc.set_origin(gate, hinge)
    gate.rotation_euler.z = radians(GATE_ANGLE)
    return gate


def build_house_and_fence(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("A_Zahrada",))
    own_coll = nc.collection("A_Zahrada", coll)

    parts = _build_house(own_coll)
    parts += _build_posts(own_coll)
    lath = _build_laths(own_coll)
    if lath is not None:
        parts.append(lath)
    paling = _build_palings(own_coll)
    if paling is not None:
        parts.append(paling)
    parts.append(_build_gate(own_coll))

    tris = C.triangle_count(parts)
    print("[NCR] dum + plot: %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


if __name__ == "__main__":
    build_house_and_fence()
