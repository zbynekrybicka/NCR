# -*- coding: utf-8 -*-
"""
Sekce C — rybník (kap. 7). Mísa (eliptická deprese) je vyříznutá přímo
v terénu (`common.height()`/`common._pond_offset`) a břeh je obarvený tam
materiálovou zónou (`common.terrain_zone`) — tenhle soubor staví jen
hladinu a vše, co na ní/kolem ní stojí navíc.

Objekty: C_hladina, C_ker_*, C_rakos_*, C_leknin_*, C_molo_*, C_kmen,
C_kamen_*, C_pritok_*, C_odtok_*, C_kul_*
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

OUTLINE_SIDES = 16
WATER_LEVEL = None   # dopočítá se v build_pond()

PREFIXES = ("C_hladina", "C_ker", "C_rakos", "C_leknin", "C_molo", "C_kmen",
            "C_kamen", "C_pritok", "C_odtok", "C_kul")


def _z0(x, y):
    return C.snap_to_ground(x, y)


def _pond_outline(n=OUTLINE_SIDES):
    cx, cy = C.POND_CENTER
    pts = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        base_ry = C.POND_RY_SOUTH if math.sin(a) < 0.0 else C.POND_RY_NORTH
        wobble = C.rng.uniform(-1.2, 1.2)
        rx, ry = C.POND_RX + wobble, base_ry + wobble * (base_ry / C.POND_RX)
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return pts


def _inset(points, dist):
    cx, cy = C.POND_CENTER
    out = []
    for (x, y) in points:
        dx, dy = x - cx, y - cy
        d = math.hypot(dx, dy)
        s = max(0.0, (d - dist) / d) if d > 1e-6 else 0.0
        out.append((cx + dx * s, cy + dy * s))
    return out


def _in_pond(x, y, margin=0.0):
    cx, cy = C.POND_CENTER
    dy_raw = y - cy
    ry = (C.POND_RY_SOUTH if dy_raw < 0.0 else C.POND_RY_NORTH) - margin
    rx = C.POND_RX - margin
    dx, dyv = (x - cx) / max(0.1, rx), dy_raw / max(0.1, ry)
    return dx * dx + dyv * dyv < 1.0


def build_pond(coll=None):
    global WATER_LEVEL
    nc.prepare()
    nc.purge(PREFIXES, collections=("C_Rybnik",))
    own_coll = nc.collection("C_Rybnik", coll)

    cx, cy = C.POND_CENTER
    WATER_LEVEL = C.height(cx, cy) + 1.1

    outline = _pond_outline()
    water_pts2d = _inset(outline, 0.20)
    water_verts = [(x, y, WATER_LEVEL) for (x, y) in water_pts2d]
    water = C.new_mesh_object("C_hladina", water_verts, [tuple(range(len(water_verts)))],
                              coll=own_coll, material=C.get_material("voda_rybnik"))
    parts = [water]

    bank_stone_small = C.build_rock_prototypes("C_kamen_maly", 3, (0.05, 0.10),
                                                C.get_material("kamen_balvan"), C.rng)
    bank_stone_big = C.build_rock_prototypes("C_kamen_velky", 3, (0.15, 0.28),
                                              C.get_material("kamen_balvan"), C.rng, subdiv=1)
    n_small = C.rng.randint(20, 30)
    for i in range(n_small):
        a = C.rng.uniform(0, 2 * math.pi)
        base_ry = C.POND_RY_SOUTH if math.sin(a) < 0.0 else C.POND_RY_NORTH
        r = C.rng.uniform(0.98, 1.10)
        x = cx + C.POND_RX * r * math.cos(a)
        y = cy + base_ry * r * math.sin(a)
        proto = bank_stone_small[i % len(bank_stone_small)]
        parts.append(C.link_dup("C_kamen_maly_%02d" % i, proto, (x, y, _z0(x, y)),
                                rot_z=C.rng.uniform(0, 360), coll=own_coll))
    n_big = C.rng.randint(4, 6)
    for i in range(n_big):
        a = C.rng.uniform(0, 2 * math.pi)
        base_ry = C.POND_RY_SOUTH if math.sin(a) < 0.0 else C.POND_RY_NORTH
        r = C.rng.uniform(0.95, 1.05)
        x = cx + C.POND_RX * r * math.cos(a)
        y = cy + base_ry * r * math.sin(a)
        proto = bank_stone_big[i % len(bank_stone_big)]
        parts.append(C.link_dup("C_kamen_velky_%02d" % i, proto, (x, y, _z0(x, y)),
                                rot_z=C.rng.uniform(0, 360), coll=own_coll))
    C.remove_prototypes(bank_stone_small + bank_stone_big)

    parts += _build_bushes(own_coll)
    parts += _build_vegetation(own_coll)
    parts += _build_extras(own_coll)

    tris = C.triangle_count(parts)
    print("[NCR] rybnik: %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


# ---------------------------------------------------------------------------
# 7.2 — husté křoví (jen severozápadní strana)
# ---------------------------------------------------------------------------

def _build_bushes(coll):
    parts = []
    mats = [C.get_material("listi_tmave"), C.get_material("listi_tmave")]
    n_bushes = C.rng.randint(14, 20)
    for i in range(n_bushes):
        bx = C.rng.uniform(-40.0, -30.0)
        by = C.rng.uniform(44.0, 54.0)
        bz = _z0(bx, by)
        n_blobs = C.rng.randint(3, 5)
        overhang = C.rng.random() < 0.35
        for j in range(n_blobs):
            jx, jy = C.rng.uniform(-0.4, 0.4), C.rng.uniform(-0.4, 0.4)
            r = C.rng.uniform(0.6, 1.2)
            jz = C.rng.uniform(0.4, 1.4)
            px, py = bx + jx, by + jy
            pz = bz + jz
            if overhang and j == n_blobs - 1:
                # posunout kouli nad hladinu — keře jsou na Z (x kolem -35),
                # voda je východněji (střed x=-28), takže "nad vodu" = +X
                px = px + C.rng.uniform(0.5, 1.2)
                pz = max(pz, WATER_LEVEL + C.rng.uniform(0.1, 0.4))
            parts.append(C.ico("C_ker_%02d_%d" % (i, j), r, subdiv=1, loc=(px, py, pz),
                               scale=(1.0, 1.0, 0.8), coll=coll, material=mats[j % 2]))
        if C.rng.random() < 0.15:
            tip = (bx + C.rng.uniform(-1.0, 1.0), by - C.rng.uniform(0.5, 1.5), bz + 0.3)
            parts.append(nc.limb("C_ker_vetev_%d" % i, (bx, by, bz + 0.3), tip, radius=0.02,
                                 verts=5, coll=coll, material=C.get_material("drevo_kmen")))
    return parts


# ---------------------------------------------------------------------------
# 7.3 — vodní vegetace (max 25 % plochy hladiny)
# ---------------------------------------------------------------------------

def _lily_leaf_verts(cx, cy, z, radius, rot_z, sides=8):
    verts = [(cx, cy, z)]
    a0 = math.radians(rot_z)
    for i in range(sides):
        a = a0 + 2.0 * math.pi * i / sides
        rr = radius * (0.5 if i == 0 else 1.0)   # klín vyříznutý ke středu
        verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), z))
    faces = [(0, 1 + i, 1 + (i + 1) % sides) for i in range(sides)]
    return verts, faces


def _build_vegetation(coll):
    parts = []
    cx, cy = C.POND_CENTER

    reed_protos = C.build_clump_prototypes("C_rakos_trs", 4, (7, 12), (1.2, 1.8), (0.010, 0.016),
                                            C.get_material("rakos"), C.rng, bend_range=(0.03, 0.10))
    n_reeds = C.rng.randint(12, 18)
    reed_spots = []
    for i in range(n_reeds):
        a = C.rng.uniform(-0.6, 0.6) if C.rng.random() < 0.5 else C.rng.uniform(math.pi - 0.6, math.pi + 0.6)
        base_ry = C.POND_RY_SOUTH if math.sin(a) < 0.0 else C.POND_RY_NORTH
        r = C.rng.uniform(0.85, 0.98)
        x, y = cx + C.POND_RX * r * math.cos(a), cy + base_ry * r * math.sin(a)
        reed_spots.append((x, y))
        proto = reed_protos[i % len(reed_protos)]
        parts.append(C.link_dup("C_rakos_%02d" % i, proto, (x, y, _z0(x, y)),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(reed_protos)
    for i, (x, y) in enumerate(reed_spots[:5]):
        parts.append(nc.cyl("C_rakos_palice_%d" % i, 0.015, 0.15, verts=6, smooth_angle=0,
                            loc=(x, y, _z0(x, y) + 1.5), coll=coll, material=C.get_material("rakos_palice")))

    lily_area = 0.0
    n_leaves = C.rng.randint(18, 25)
    cluster_centers = []
    for _ in range(3):
        a = C.rng.uniform(0, 2 * math.pi)
        r = C.rng.uniform(0.3, 0.7)
        base_ry = C.POND_RY_SOUTH if math.sin(a) < 0.0 else C.POND_RY_NORTH
        cluster_centers.append((cx + C.POND_RX * r * math.cos(a), cy + base_ry * r * math.sin(a)))
    batch = C.Batch()
    n_flowered = 0
    for i in range(n_leaves):
        ccx, ccy = cluster_centers[i % len(cluster_centers)]
        lx = ccx + C.rng.uniform(-1.0, 1.0)
        ly = ccy + C.rng.uniform(-1.0, 1.0)
        if not _in_pond(lx, ly, margin=0.5):
            continue
        r = C.rng.uniform(0.175, 0.275)
        lily_area += math.pi * r * r
        v, f = _lily_leaf_verts(lx, ly, WATER_LEVEL + 0.01, r, C.rng.uniform(0, 360))
        batch.add(v, f)
        if C.rng.random() < 0.25 and n_flowered < 5:
            n_flowered += 1
            fcolor = C.get_material("kvet_bila") if C.rng.random() < 0.5 else C.get_material("kvet_ruzova")
            parts.append(C.ico("C_leknin_kvet_%d" % n_flowered, 0.075, subdiv=0,
                               loc=(lx, ly, WATER_LEVEL + 0.03), scale=(1.0, 1.0, 0.4),
                               coll=coll, material=fcolor))
    parts.append(batch.build("C_leknin_listy", coll=coll, material=C.get_material("lekniny")))

    water_area = math.pi * C.POND_RX * (C.POND_RY_SOUTH + C.POND_RY_NORTH) * 0.5
    pct = lily_area / water_area * 100.0
    print("[NCR] rybnik: lekniny pokryvaji ~%.1f %% hladiny (limit 25%%)" % pct)

    return [p for p in parts if p is not None]


# ---------------------------------------------------------------------------
# 7.4 — doplňky
# ---------------------------------------------------------------------------

def _build_extras(coll):
    parts = []
    cx, cy = C.POND_CENTER

    dock_x, dock_y = cx + 2.0, cy - C.POND_RY_SOUTH * 0.9
    dock_dir = (0.4, -1.0)
    length = math.hypot(*dock_dir)
    dock_dir = (dock_dir[0] / length, dock_dir[1] / length)
    for i in range(4):
        px = dock_x + dock_dir[0] * i * 0.85
        py = dock_y + dock_dir[1] * i * 0.85
        pz = _z0(px, py)
        parts.append(nc.cyl("C_molo_kul_%d" % i, 0.05, 0.6, verts=6, smooth_angle=0,
                            loc=(px, py, pz + 0.3), coll=coll, material=C.get_material("drevo_tmave")))
    for i in range(2):   # 3. prkno chybí (kap. 7.4)
        ox = dock_dir[1] * (i - 0.5) * 0.28
        oy = -dock_dir[0] * (i - 0.5) * 0.28
        mx = dock_x + dock_dir[0] * 1.3 + ox
        my = dock_y + dock_dir[1] * 1.3 + oy
        mz = _z0(mx, my) + 0.35
        ang = math.degrees(math.atan2(dock_dir[1], dock_dir[0]))
        parts.append(nc.box("C_molo_prkno_%d" % i, (3.5, 0.28, 0.04),
                            loc=(mx, my, mz), rot=(0, 0, ang), coll=coll,
                            material=C.get_material("drevo_tmave")))

    log_x, log_y = cx - C.POND_RX * 0.7, cy + C.POND_RY_NORTH * 0.3
    parts.append(nc.cyl("C_kmen", 0.18, 3.2, rot=(90, 0, 35), verts=8, smooth_angle=0,
                        loc=(log_x, log_y, _z0(log_x, log_y) + 0.05), coll=coll,
                        material=C.get_material("drevo_kmen")))

    sit_stones = C.build_rock_prototypes("C_kamen_sed", 2, (0.3, 0.4),
                                         C.get_material("kamen_balvan"), C.rng, subdiv=1)
    for i in range(2):
        a = C.rng.uniform(0, 2 * math.pi)
        x, y = cx + C.POND_RX * 0.9 * math.cos(a), cy + C.POND_RY_SOUTH * 0.7 * math.sin(a)
        parts.append(C.link_dup("C_kamen_sed_%d" % i, sit_stones[i], (x, y, _z0(x, y)), coll=coll))
    C.remove_prototypes(sit_stones)

    inflow_x, inflow_y = -25.5, 44.0    # ústí potoka (kap. 6.3 konec CREEK_POINTS)
    inflow_stones = C.build_rock_prototypes("C_pritok_kamen", 2, (0.07, 0.12),
                                            C.get_material("kamen_balvan"), C.rng)
    for i in range(3):
        x = inflow_x + C.rng.uniform(-0.3, 0.3)
        y = inflow_y + C.rng.uniform(-0.3, 0.3)
        parts.append(C.link_dup("C_pritok_kamen_%d" % i, inflow_stones[i % len(inflow_stones)],
                                (x, y, _z0(x, y)), coll=coll))
    C.remove_prototypes(inflow_stones)

    outflow_x, outflow_y = cx + C.POND_RX * 0.85, cy - C.POND_RY_SOUTH * 0.2
    outflow_batch = C.Batch()
    for i in range(3):
        ox = outflow_x + i * 0.4
        oy = outflow_y + i * 0.1
        v, f = C.box_verts(ox, oy, _z0(ox, oy) + 0.05, 0.35, 0.30, 0.10)
        outflow_batch.add(v, f)
    parts.append(outflow_batch.build("C_odtok_hraz", coll=coll, material=C.get_material("kamen_balvan")))

    for i, side in enumerate((-1, 1)):
        px = cx - C.POND_RX * 0.3 + side * 0.6
        py = cy - C.POND_RY_SOUTH * 0.85
        pz = _z0(px, py)
        parts.append(nc.cyl("C_kul_%d" % i, 0.04, 1.0, rot=(0, side * 10, 0), verts=6,
                            smooth_angle=0, loc=(px, py, pz + 0.5), coll=coll,
                            material=C.get_material("drevo_plot")))
    a_pt = (cx - C.POND_RX * 0.3 - 0.6, cy - C.POND_RY_SOUTH * 0.85, _z0(cx - C.POND_RX * 0.3 - 0.6,
            cy - C.POND_RY_SOUTH * 0.85) + 0.8)
    b_pt = (cx - C.POND_RX * 0.3 + 0.6, cy - C.POND_RY_SOUTH * 0.85, _z0(cx - C.POND_RX * 0.3 + 0.6,
            cy - C.POND_RY_SOUTH * 0.85) + 0.6)
    parts.append(nc.limb("C_kul_provaz", a_pt, b_pt, radius=0.01, verts=5, coll=coll,
                         material=C.get_material("rez")))

    return [p for p in parts if p is not None]


if __name__ == "__main__":
    build_pond()
