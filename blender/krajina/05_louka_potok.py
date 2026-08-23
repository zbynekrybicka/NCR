# -*- coding: utf-8 -*-
"""
Sekce B — louka a potok (kap. 6). Koryto potoka je vyříznuté přímo v terénu
(`common.height()`), tady se staví jen hladina a okolní detaily.

Zjednodušení oproti spec (viz README): luční tráva/květiny mají hustotu
sníženou pod literální hodnotu z dokumentu, aby se vešly do rozpočtu
150-250k trojúhelníků společně se zbytkem scény (les, hora, jeskyně).
Kompoziční pravidlo (potok teče z kopce, příčný sklon, hustota "ostrůvků")
zůstává zachované, jen s méně instancemi na m².

Objekty: B_strom_*, B_travnik_*, B_kvet_*, B_potok_*, B_balvan_*, B_sena_*,
B_ohrada_*, B_parez_*, B_kmen_*, B_kopriva_*, B_odbocka
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

MEADOW_BOUNDS = (-24.0, 21.0, 20.0, 70.0)
MEADOW_GRASS_DENSITY = 0.9        # spec 1.8/m2, sníženo kvůli rozpočtu (viz hlavička)
FLOWER_TARGET = 500               # spec 400-600

BIG_TREE_POS = (9.0, 24.0)
BIG_TREE_CLEARING_R = 1.5

PREFIXES = ("B_strom", "B_travnik", "B_kvet", "B_potok", "B_balvan", "B_sena",
            "B_ohrada", "B_parez", "B_kmen", "B_kopriva", "B_odbocka")


def _z0(x, y):
    return C.snap_to_ground(x, y)


def _in_ellipse(x, y, cx, cy, rx, ry):
    dx, dy = (x - cx) / rx, (y - cy) / ry
    return dx * dx + dy * dy < 1.0


def _meadow_exclude(x, y):
    if C.dist_to_polyline(x, y, C.PATH_POINTS) < 0.75:
        return True
    if C.dist_to_polyline(x, y, C.CREEK_POINTS) < 0.5:
        return True
    if _in_ellipse(x, y, C.POND_CENTER[0], C.POND_CENTER[1], C.POND_RX + 2.0, C.POND_RY_SOUTH + 2.0):
        return True
    if _in_ellipse(x, y, BIG_TREE_POS[0], BIG_TREE_POS[1], BIG_TREE_CLEARING_R, BIG_TREE_CLEARING_R):
        return True
    return False


# ---------------------------------------------------------------------------
# 6.1 — velký strom
# ---------------------------------------------------------------------------

def _build_big_tree(coll):
    cx, cy = BIG_TREE_POS
    z0 = _z0(cx, cy)
    parts = []

    trunk_lo = nc.cone("B_strom_kmen_dolni", 0.55, 0.40, 2.5, verts=7, smooth_angle=0,
                       loc=(cx, cy, z0 + 1.25), coll=coll, material=C.get_material("drevo_kmen"))
    kink_x, kink_y = cx + 0.15, cy + 0.08
    trunk_hi = nc.cone("B_strom_kmen_horni", 0.40, 0.20, 2.5, verts=7, smooth_angle=0,
                       loc=(kink_x, kink_y, z0 + 3.75), coll=coll, material=C.get_material("drevo_kmen"))
    parts += [trunk_lo, trunk_hi]

    root_protos = []
    for i in range(5):
        a = 2.0 * math.pi * i / 5 + C.rng.uniform(-0.2, 0.2)
        rx, ry = cx + 0.9 * math.cos(a), cy + 0.9 * math.sin(a)
        parts.append(nc.cone("B_strom_koren_%d" % i, 0.08, 0.32, 0.55, verts=5, smooth_angle=0,
                             loc=(rx, ry, z0 + 0.20), rot=(0, 0, math.degrees(a)), coll=coll,
                             material=C.get_material("drevo_kmen")))

    branch_tips = []
    top = (kink_x, kink_y, z0 + 5.0)
    for i in range(4):
        a = 2.0 * math.pi * i / 4 + C.rng.uniform(-0.3, 0.3)
        mid = (top[0] + 1.6 * math.cos(a), top[1] + 1.6 * math.sin(a), top[2] + 1.6)
        parts.append(nc.limb("B_strom_vetev_%d" % i, top, mid, radius=0.10, verts=8, coll=coll,
                             material=C.get_material("drevo_kmen")))
        for j in range(2):
            a2 = a + C.rng.uniform(-0.9, 0.9)
            tip = (mid[0] + 1.0 * math.cos(a2), mid[1] + 1.0 * math.sin(a2), mid[2] + 0.9)
            parts.append(nc.limb("B_strom_vetev_%d_%d" % (i, j), mid, tip, radius=0.05, verts=6,
                                 coll=coll, material=C.get_material("drevo_kmen")))
            branch_tips.append(tip)

    crown_mats = [C.get_material("listi_svetle")]
    for i in range(min(7, max(5, len(branch_tips)))):
        tip = branch_tips[i % len(branch_tips)]
        jx, jy, jz = C.rng.uniform(-0.6, 0.6), C.rng.uniform(-0.6, 0.6), C.rng.uniform(-0.3, 0.5)
        r = C.rng.uniform(1.75, 2.75)
        parts.append(C.ico("B_strom_koruna_%d" % i, r, subdiv=1,
                           loc=(tip[0] + jx, tip[1] + jy, tip[2] + jz),
                           scale=(1.0, 1.0, 0.85), coll=coll, material=crown_mats[0]))

    swing_branch = branch_tips[0]
    rope_len = swing_branch[2] - z0 - 0.6
    for side in (-1, 1):
        a_pt = (swing_branch[0] + side * 0.10, swing_branch[1], swing_branch[2])
        b_pt = (swing_branch[0] + side * 0.10, swing_branch[1], swing_branch[2] - rope_len)
        parts.append(nc.limb("B_strom_houpacka_lano_%d" % (side > 0), a_pt, b_pt,
                             radius=0.012, verts=5, coll=coll, material=C.get_material("drevo_tmave")))
    seat_z = swing_branch[2] - rope_len
    parts.append(nc.box("B_strom_houpacka_prkno", (0.35, 0.14, 0.03),
                        loc=(swing_branch[0], swing_branch[1], seat_z), coll=coll,
                        material=C.get_material("drevo_plot")))

    clearing_rocks = C.build_rock_prototypes("B_strom_placek", 3, (0.05, 0.10),
                                              C.get_material("kamen_balvan"), C.rng)
    for i in range(6):
        a = C.rng.uniform(0, 2 * math.pi)
        r = C.rng.uniform(0.8, 1.4)
        rx, ry = cx + r * math.cos(a), cy + r * math.sin(a)
        proto = clearing_rocks[i % len(clearing_rocks)]
        parts.append(C.link_dup("B_strom_placek_%d" % i, proto, (rx, ry, _z0(rx, ry)),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(clearing_rocks)

    return parts


# ---------------------------------------------------------------------------
# 6.2 — luční tráva a květiny
# ---------------------------------------------------------------------------

def _build_meadow_grass(coll):
    protos = C.build_clump_prototypes("B_travnik", 4, (4, 6), (0.15, 0.30), (0.007, 0.012),
                                       C.get_material("trava_louka"), C.rng, bend_range=(0.02, 0.07))
    points = C.scatter(MEADOW_BOUNDS, MEADOW_GRASS_DENSITY, 0.35, C.rng, exclude_fn=_meadow_exclude)
    objs = C.scatter_instances("B_travnik", points, protos, coll, C.rng,
                               scale_range=(0.8, 1.3), z_fn=_z0)
    C.remove_prototypes(protos)
    return objs


def _stem_batch(height, width=0.010, bend=0.02):
    b = C.Batch()
    v, f = C.blade_verts(0.0, 0.0, 0.0, height, width, bend=bend)
    b.add(v, f)
    return b


def _build_meadow_flower_prototypes():
    protos = {}

    b = _stem_batch(0.40)
    v, f = C.disc_verts(0.0, 0.0, 0.40, 0.05, 8)
    b.add(v, f)
    protos["kopretina"] = b.build("B_kvet_proto_kopretina", material=C.get_material("kvet_bila"))

    b = _stem_batch(0.45)
    v, f = C.disc_verts(0.0, 0.0, 0.45, 0.045, 6)
    b.add(v, f)
    protos["mak"] = b.build("B_kvet_proto_mak", material=C.get_material("kvet_cervena"))

    b = _stem_batch(0.35)
    v, f = C.disc_verts(0.0, 0.0, 0.35, 0.035, 6)
    b.add(v, f)
    protos["chrpa"] = b.build("B_kvet_proto_chrpa", material=C.get_material("kvet_fialova"))

    b = _stem_batch(0.30)
    ball = nc.sphere("B_kvet_proto_pampeliska_zluta_tmp", 0.025, loc=(0.0, 0.0, 0.30),
                     segments=8, rings=5, smooth_angle=0)
    C.merge_into_batch(b, ball)
    protos["pampeliska_zluta"] = b.build("B_kvet_proto_pampeliska_zluta",
                                        material=C.get_material("kvet_zluta"))

    b = _stem_batch(0.30)
    ball = nc.sphere("B_kvet_proto_pampeliska_bila_tmp", 0.025, loc=(0.0, 0.0, 0.30),
                     segments=8, rings=5, smooth_angle=0)
    C.merge_into_batch(b, ball)
    protos["pampeliska_bila"] = b.build("B_kvet_proto_pampeliska_bila",
                                        material=C.get_material("kvet_bila"))

    b = _stem_batch(0.32)
    bell = nc.cone("B_kvet_proto_zvonek_tmp", 0.0, 0.035, 0.05, verts=6, smooth_angle=0,
                   loc=(0.0, 0.0, 0.32 + 0.025))
    C.merge_into_batch(b, bell)
    protos["zvonek"] = b.build("B_kvet_proto_zvonek", material=C.get_material("kvet_fialova"))

    return protos


def _build_meadow_flowers(coll):
    protos = _build_meadow_flower_prototypes()
    keys = list(protos.keys())
    per_type = FLOWER_TARGET // len(keys)
    objs = []
    idx = 0
    for key in keys:
        points = C.cluster_scatter(MEADOW_BOUNDS, per_type, (8, 20),
                                   cluster_count=max(3, per_type // 12), spread=2.2,
                                   rng_=C.rng, exclude_fn=_meadow_exclude)
        for (x, y) in points:
            objs.append(C.link_dup("B_kvet_%04d" % idx, protos[key], (x, y, _z0(x, y)),
                                   rot_z=C.rng.uniform(0, 360), coll=coll))
            idx += 1
    C.remove_prototypes(list(protos.values()))
    return objs


# ---------------------------------------------------------------------------
# 6.3 — potůček (koryto je v common.height(); tady jen hladina a detaily)
# ---------------------------------------------------------------------------

def _tangent(points, i):
    if i == 0:
        dx, dy = points[1][0] - points[0][0], points[1][1] - points[0][1]
    elif i == len(points) - 1:
        dx, dy = points[-1][0] - points[-2][0], points[-1][1] - points[-2][1]
    else:
        dx, dy = points[i + 1][0] - points[i - 1][0], points[i + 1][1] - points[i - 1][1]
    length = math.hypot(dx, dy)
    return (dx / length, dy / length) if length > 1e-6 else (1.0, 0.0)


def _build_creek(coll):
    parts = []
    samples = C.resample_polyline(C.CREEK_POINTS, step=1.0)

    batch = C.Batch()
    for i in range(len(samples) - 1):
        x0, y0 = samples[i]
        x1, y1 = samples[i + 1]
        tx, ty = _tangent(samples, i)
        nx, ny = -ty, tx
        w0, w1 = C.rng.uniform(0.25, 0.40), C.rng.uniform(0.25, 0.40)
        z0_ = C.height(x0, y0) + 0.05
        z1_ = C.height(x1, y1) + 0.05
        batch.add([(x0 + nx * w0 * 0.5, y0 + ny * w0 * 0.5, z0_),
                  (x0 - nx * w0 * 0.5, y0 - ny * w0 * 0.5, z0_),
                  (x1 - nx * w1 * 0.5, y1 - ny * w1 * 0.5, z1_),
                  (x1 + nx * w1 * 0.5, y1 + ny * w1 * 0.5, z1_)], [(0, 1, 2, 3)])
    parts.append(batch.build("B_potok_hladina", coll=coll, material=C.get_material("voda_potok")))

    stone_protos = C.build_rock_prototypes("B_potok_kamen", 3, (0.04, 0.10),
                                            C.get_material("kamen_balvan"), C.rng)
    n_stones = C.rng.randint(25, 40)
    for i in range(n_stones):
        t = C.rng.random()
        seg = min(len(samples) - 2, int(t * (len(samples) - 1)))
        x, y = samples[seg]
        offset = C.rng.uniform(-0.30, 0.30)
        tx, ty = _tangent(samples, seg)
        nx, ny = -ty, tx
        x, y = x + nx * offset, y + ny * offset
        proto = stone_protos[i % len(stone_protos)]
        lift = 0.05 if i < 3 else -0.02   # 3 vyčnívají nad hladinu
        z = C.height(x, y) + 0.05 + lift
        parts.append(C.link_dup("B_potok_kamen_%02d" % i, proto, (x, y, z),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(stone_protos)

    grass_protos = C.build_clump_prototypes("B_potok_tmava_trava", 3, (4, 6), (0.18, 0.28),
                                            (0.008, 0.012), C.get_material("trava_louka"), C.rng)
    for i in range(7):
        t = C.rng.uniform(0.1, 0.9)
        seg = min(len(samples) - 2, int(t * (len(samples) - 1)))
        x, y = samples[seg]
        tx, ty = _tangent(samples, seg)
        nx, ny = -ty, tx
        offset = C.rng.choice((-1, 1)) * C.rng.uniform(0.35, 0.55)
        x, y = x + nx * offset, y + ny * offset
        proto = grass_protos[i % len(grass_protos)]
        parts.append(C.link_dup("B_potok_trs_%d" % i, proto, (x, y, _z0(x, y)), coll=coll))
    C.remove_prototypes(grass_protos)

    # brod na (0, 46): ploché kameny + lávka
    ford_x, ford_y = 0.0, 46.0
    ford_batch = C.Batch()
    for i in range(5):
        fx = ford_x + (i - 2) * 0.20
        fz = C.height(fx, ford_y) + 0.06
        v, f = C.disc_verts(fx, ford_y, fz, 0.16, 6, rot_z=C.rng.uniform(0, 60))
        ford_batch.add(v, f)
    parts.append(ford_batch.build("B_potok_brod_kameny", coll=coll, material=C.get_material("kamen_dlazba")))
    for i, side in enumerate((-1, 1)):
        pz = C.height(ford_x + side * 0.18, ford_y) + 0.10
        # prkna leží podélně přes potok (délka podél Y, kolmo na tok) —
        # rotace jen malá, jedno prkno "mírně pootočené" (kap. 6.3)
        parts.append(nc.box("B_potok_lavka_%d" % i, (0.25, 2.2, 0.05),
                            loc=(ford_x + side * 0.18, ford_y, pz), rot=(0, 0, side * 3),
                            coll=coll, material=C.get_material("drevo_tmave")))

    # pramen na (22, 52)
    spring_x, spring_y = 22.0, 52.0
    sz = C.height(spring_x, spring_y)
    parts.append(nc.hemisphere("B_potok_pramen_misa", 0.30, up=False, loc=(spring_x, spring_y, sz + 0.05),
                               segments=10, rings=6, coll=coll, material=C.get_material("kamen_skala"),
                               smooth_angle=0))
    spring_rocks = C.build_rock_prototypes("B_potok_pramen_kamen", 3, (0.07, 0.12),
                                           C.get_material("kamen_balvan"), C.rng)
    for i in range(7):
        a = 2.0 * math.pi * i / 7
        rx, ry = spring_x + 0.32 * math.cos(a), spring_y + 0.32 * math.sin(a)
        proto = spring_rocks[i % len(spring_rocks)]
        parts.append(C.link_dup("B_potok_pramen_kamen_%d" % i, proto, (rx, ry, C.height(rx, ry)),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(spring_rocks)

    return [p for p in parts if p is not None]


# ---------------------------------------------------------------------------
# 6.4 — doplňky louky
# ---------------------------------------------------------------------------

def _build_meadow_extras(coll):
    parts = []

    boulder_protos = C.build_rock_prototypes("B_balvan", 4, (0.35, 1.1),
                                              C.get_material("kamen_balvan"), C.rng, subdiv=1)
    boulder_points = C.scatter(MEADOW_BOUNDS, 0.006, 3.0, C.rng, exclude_fn=_meadow_exclude)
    for i, (x, y) in enumerate(boulder_points[:12]):
        proto = boulder_protos[i % len(boulder_protos)]
        z = _z0(x, y) - 0.15
        parts.append(C.link_dup("B_balvan_%02d" % i, proto, (x, y, z),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(boulder_protos)

    for i, (hx, hy) in enumerate(((-4.0, 30.0), (-10.0, 55.0))):
        hz = _z0(hx, hy)
        parts.append(nc.cone("B_sena_%d" % i, 1.25, 0.35, 1.8, verts=10, smooth_angle=0,
                             loc=(hx, hy, hz + 0.9), coll=coll, material=C.get_material("sena")))
        parts.append(nc.limb("B_sena_vidle_%d" % i, (hx + 1.1, hy, hz),
                             (hx + 1.1, hy + 0.3, hz + 1.3), radius=0.02, verts=6, coll=coll,
                             material=C.get_material("drevo_tmave")))

    fence_pts = [(-15.0 + i * 4.0, 40.0 + i * 1.5) for i in range(6)]
    for i, (fx, fy) in enumerate(fence_pts):
        fz = _z0(fx, fy)
        parts.append(nc.cyl("B_ohrada_kul_%d" % i, 0.035, 0.9, rot=(0, 0, 0), verts=6,
                            smooth_angle=0, loc=(fx, fy, fz + 0.45), coll=coll,
                            material=C.get_material("drevo_plot")))
    a, b = fence_pts[2], fence_pts[3]
    parts.append(nc.limb("B_ohrada_drat", (a[0], a[1], _z0(*a) + 0.6), (b[0], b[1], _z0(*b) + 0.55),
                         radius=0.004, verts=4, coll=coll, material=C.get_material("rez")))

    for i, (px, py) in enumerate(((-8.0, 35.0), (14.0, 48.0), (-2.0, 62.0))):
        pz = _z0(px, py)
        parts.append(nc.cyl("B_parez_%d" % i, 0.22, 0.3, verts=8, smooth_angle=0,
                            loc=(px, py, pz + 0.15), coll=coll, material=C.get_material("drevo_kmen")))
    for i, (lx, ly, ang) in enumerate(((6.0, 58.0, 30.0), (-12.0, 62.0, -20.0))):
        lz = _z0(lx, ly)
        parts.append(nc.cyl("B_kmen_%d" % i, 0.20, 3.5, rot=(90, 0, ang), verts=8, smooth_angle=0,
                            loc=(lx, ly, lz + 0.20), coll=coll, material=C.get_material("drevo_kmen")))

    branch_batch = C.Batch()
    branch_start = C.PATH_POINTS[3]   # (-0.5, 46) — brod, odbočka pokračuje k rybníku
    branch_pts = [branch_start, (-8.0, 44.5), (-16.0, 44.0), (-22.0, 44.0)]
    for i in range(len(branch_pts) - 1):
        x0, y0 = branch_pts[i]
        x1, y1 = branch_pts[i + 1]
        tx, ty = _tangent(branch_pts, i)
        nx, ny = -ty, tx
        w = 0.6 * (1.0 - i / (len(branch_pts) - 1) * 0.5)
        z0_, z1_ = _z0(x0, y0) + 0.02, _z0(x1, y1) + 0.02
        branch_batch.add([(x0 + nx * w * 0.5, y0 + ny * w * 0.5, z0_),
                          (x0 - nx * w * 0.5, y0 - ny * w * 0.5, z0_),
                          (x1 - nx * w * 0.5, y1 - ny * w * 0.5, z1_),
                          (x1 + nx * w * 0.5, y1 + ny * w * 0.5, z1_)], [(0, 1, 2, 3)])
    parts.append(branch_batch.build("B_odbocka", coll=coll, material=C.get_material("hlina_cesta")))

    nettle_protos = C.build_clump_prototypes("B_kopriva", 3, (5, 8), (0.25, 0.40), (0.010, 0.015),
                                              C.get_material("listi_tmave"), C.rng, bend_range=(0.0, 0.02))
    for i in range(7):
        proto = nettle_protos[i % len(nettle_protos)]
        bx, by = boulder_points[i % max(1, len(boulder_points))] if boulder_points else (0.0, 30.0)
        nx_, ny_ = bx + C.rng.uniform(-0.6, 0.6), by + C.rng.uniform(-0.6, 0.6)
        parts.append(C.link_dup("B_kopriva_%d" % i, proto, (nx_, ny_, _z0(nx_, ny_)),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(nettle_protos)

    return [p for p in parts if p is not None]


def build_meadow_and_creek(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("B_Louka",))
    own_coll = nc.collection("B_Louka", coll)

    parts = _build_big_tree(own_coll)
    parts += _build_meadow_grass(own_coll)
    parts += _build_meadow_flowers(own_coll)
    parts += _build_creek(own_coll)
    parts += _build_meadow_extras(own_coll)

    tris = C.triangle_count(parts)
    print("[NCR] louka + potok: %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


if __name__ == "__main__":
    build_meadow_and_creek()
