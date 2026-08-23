# -*- coding: utf-8 -*-
"""
Sekce A — zbytek zahrady (kap. 5.3-5.6): trávník, záhonky, studna, kůlna
a doplňkové prvky.

Zjednodušení oproti spec (viz README): květina je stonek + jeden plochý
okvětní disk bez odděleného žlutého středu; studniční lano je rovný úsek
bez naznačených závitů; kůlnina střecha má 2 přeložená prkna místo 6-7
(detail pod rozlišením scény, princip "posunuté prkno = mezera" zůstává).

Objekty: A_travnik_*, A_zahon_*, A_studna_*, A_kulna_*, A_sud, A_kolecko,
A_drevo_*, A_kompost, A_susak_*, A_budka, A_ker_*, A_slapak_*, A_narad_*,
A_parez
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

GARDEN_BOUNDS = (-12.0, -6.0, 12.0, 21.0)
HOUSE_RECT = (-5.3, -6.3, 5.3, 0.3)
SHED_CENTER = (-7.5, 14.5)
SHED_SIZE = (2.4, 2.0)
SHED_ROT_Z = 6.0
SHED_TILT_X = 2.0
WELL_CENTER = (-4.0, 12.0)

BEDS = (
    dict(name="Z1", center=(5.0, 6.0), size=(3.0, 1.8)),
    dict(name="Z2", center=(6.5, 13.0), size=(2.2, 2.2)),
    dict(name="Z3", center=(-6.0, 5.0), size=(2.6, 1.4)),
)

PREFIXES = ("A_travnik", "A_zahon", "A_studna", "A_kulna", "A_sud", "A_kolecko",
            "A_drevo", "A_kompost", "A_susak", "A_budka", "A_ker", "A_slapak",
            "A_narad", "A_parez", "A_kvet")


def _z0(x, y):
    return C.snap_to_ground(x, y)


def _in_rect(x, y, rect):
    x0, y0, x1, y1 = rect
    return x0 <= x <= x1 and y0 <= y <= y1


def _in_ellipse(x, y, cx, cy, rx, ry):
    dx, dy = (x - cx) / rx, (y - cy) / ry
    return dx * dx + dy * dy < 1.0


def _garden_exclude(x, y):
    if C.dist_to_polyline(x, y, [p for p in C.PATH_POINTS if p[1] <= 22.0]) < 0.75:
        return True
    if _in_rect(x, y, HOUSE_RECT):
        return True
    sx, sy = SHED_CENTER
    # kůlna + 30cm halo + ~1m vyšlapaná stopa k cestě (kap. 5.5)
    if _in_rect(x, y, (sx - SHED_SIZE[0] * 0.5 - 1.3, sy - SHED_SIZE[1] * 0.5 - 0.4,
                        sx + SHED_SIZE[0] * 0.5 + 0.4, sy + SHED_SIZE[1] * 0.5 + 0.4)):
        return True
    if _in_ellipse(x, y, WELL_CENTER[0], WELL_CENTER[1], 1.4, 1.4):
        return True
    for bed in BEDS:
        cx, cy = bed["center"]
        rx, ry = bed["size"][0] * 0.5 + 0.3, bed["size"][1] * 0.5 + 0.3
        if _in_ellipse(x, y, cx, cy, rx, ry):
            return True
    return False


# ---------------------------------------------------------------------------
# 5.3 — trávník a záhonky
# ---------------------------------------------------------------------------

def _build_lawn(coll):
    protos = C.build_clump_prototypes("A_travnik", 4, (4, 6), (0.08, 0.14), (0.006, 0.010),
                                       C.get_material("trava_zahrada"), C.rng)
    points = C.scatter(GARDEN_BOUNDS, 1.2, 0.30, C.rng, exclude_fn=_garden_exclude)
    objs = C.scatter_instances("A_travnik", points, protos, coll, C.rng, z_fn=_z0)
    C.remove_prototypes(protos)
    return objs


def _build_bed_mound(cx, cy, rx, ry, sides=14):
    outer, mid = [], []
    for i in range(sides):
        a = 2.0 * math.pi * i / sides
        ox, oy = cx + rx * math.cos(a), cy + ry * math.sin(a)
        outer.append((ox, oy, _z0(ox, oy)))
        mx, my = cx + rx * 0.55 * math.cos(a), cy + ry * 0.55 * math.sin(a)
        mid.append((mx, my, _z0(mx, my) + 0.045))
    center = (cx, cy, _z0(cx, cy) + 0.06)
    verts = outer + mid + [center]
    n = sides
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    cidx = 2 * n
    faces += [(n + i, n + (i + 1) % n, cidx) for i in range(n)]
    return verts, faces


FLOWER_STEM_H = (0.20, 0.35)
FLOWER_PETAL_R = (0.04, 0.06)


def _build_flower_prototypes():
    protos = {}
    for key in C.KVET_KEYS:
        batch = C.Batch()
        stem_h = C.rng.uniform(*FLOWER_STEM_H)
        v, f = C.blade_verts(0.0, 0.0, 0.0, stem_h, 0.012, bend=0.02)
        batch.add(v, f)
        v, f = C.disc_verts(0.0, 0.0, stem_h, C.rng.uniform(*FLOWER_PETAL_R), 6,
                            rot_z=C.rng.uniform(0.0, 60.0))
        batch.add(v, f)
        protos[key] = batch.build("A_kvet_proto_%s" % key, material=C.get_material(key))
    return protos


def _bed_flower_points(cx, cy, rx, ry, count):
    pts = []
    tries = 0
    while len(pts) < count and tries < count * 20:
        tries += 1
        x, y = cx + C.rng.uniform(-rx, rx), cy + C.rng.uniform(-ry, ry)
        if _in_ellipse(x, y, cx, cy, rx * 0.92, ry * 0.92):
            pts.append((x, y))
    return pts


def _build_beds(coll):
    objs = []
    flower_protos = _build_flower_prototypes()
    stone_protos = C.build_rock_prototypes("A_zahon_kamen", 3, (0.06, 0.09),
                                            C.get_material("kamen_balvan"), C.rng)
    for bed in BEDS:
        cx, cy = bed["center"]
        rx, ry = bed["size"][0] * 0.5, bed["size"][1] * 0.5
        v, f = _build_bed_mound(cx, cy, rx, ry)
        objs.append(C.new_mesh_object("A_zahon_%s_zem" % bed["name"], v, f, coll=coll,
                                       material=C.get_material("hlina_holy")))

        n_stones = C.rng.randint(8, 12)
        for i in range(n_stones):
            a = 2.0 * math.pi * i / n_stones + C.rng.uniform(-0.1, 0.1)
            sx, sy = cx + rx * 1.05 * math.cos(a), cy + ry * 1.05 * math.sin(a)
            proto = stone_protos[C.rng.randrange(len(stone_protos))]
            objs.append(C.link_dup("A_zahon_%s_obruba_%02d" % (bed["name"], i), proto,
                                    (sx, sy, _z0(sx, sy)), rot_z=C.rng.uniform(0, 360), coll=coll))

        n_flowers = C.rng.randint(18, 30)
        for i, (fx, fy) in enumerate(_bed_flower_points(cx, cy, rx, ry, n_flowers)):
            key = C.KVET_KEYS[C.rng.randrange(len(C.KVET_KEYS))]
            objs.append(C.link_dup("A_zahon_%s_kvet_%03d" % (bed["name"], i),
                                    flower_protos[key], (fx, fy, _z0(fx, fy) + 0.055),
                                    rot_z=C.rng.uniform(0, 360), coll=coll))

    C.remove_prototypes(list(flower_protos.values()) + stone_protos)
    return objs


# ---------------------------------------------------------------------------
# 5.4 — studna s rumpálem
# ---------------------------------------------------------------------------

def _build_well(coll):
    cx, cy = WELL_CENTER
    z0 = _z0(cx, cy)
    parts = []

    ring = nc.cyl("A_studna_skruz", 0.6, 0.8, verts=8, smooth_angle=0,
                  loc=(cx, cy, z0 + 0.4), coll=coll, material=C.get_material("beton"))
    inner_cut = nc.cyl("A_studna_skruz_rez", 0.45, 0.9, verts=8, smooth_angle=0,
                       loc=(cx, cy, z0 + 0.4))
    nc.cut(ring, inner_cut)
    parts.append(ring)

    for side in (-1, 1):
        px = cx + side * 0.5
        parts.append(nc.box("A_studna_vzpera_%d" % (side > 0), (0.08, 0.08, 1.6),
                             loc=(px, cy, z0 + 0.8 + 0.8), coll=coll,
                             material=C.get_material("drevo_tmave")))
    parts.append(nc.box("A_studna_tram", (1.2, 0.08, 0.08),
                        loc=(cx, cy, z0 + 0.8 + 1.6), coll=coll,
                        material=C.get_material("drevo_tmave")))

    parts.append(nc.cyl("A_studna_rumpal", 0.09, 1.0, rot=(90, 0, 0), verts=10,
                        smooth_angle=0, loc=(cx, cy, z0 + 1.3), coll=coll,
                        material=C.get_material("drevo_tmave")))
    parts.append(nc.box("A_studna_klika_a", (0.03, 0.03, 0.18),
                        loc=(cx + 0.55, cy, z0 + 1.3 + 0.09), coll=coll,
                        material=C.get_material("kov")))
    parts.append(nc.cyl("A_studna_klika_rukojet", 0.015, 0.12, rot=(90, 0, 0), verts=8,
                        smooth_angle=0, loc=(cx + 0.55, cy, z0 + 1.3 + 0.18), coll=coll,
                        material=C.get_material("drevo_tmave")))

    parts.append(nc.limb("A_studna_lano", (cx, cy, z0 + 1.3), (cx, cy, z0 + 0.1),
                         radius=0.01, verts=6, coll=coll, material=C.get_material("drevo_tmave")))
    parts.append(nc.cone("A_studna_kbelik", 0.13, 0.11, 0.28, verts=8, smooth_angle=0,
                         loc=(cx, cy, z0 + 0.14), coll=coll, material=C.get_material("drevo_tmave")))

    v = [(cx - 0.8, cy - 0.7, z0 + 2.4), (cx + 0.8, cy - 0.7, z0 + 2.4),
         (cx + 0.8, cy + 0.7, z0 + 2.4), (cx - 0.8, cy + 0.7, z0 + 2.4),
         (cx, cy - 0.7, z0 + 2.7), (cx, cy + 0.7, z0 + 2.7)]
    f = [(0, 3, 5, 4), (4, 5, 2, 1), (0, 4, 1), (3, 2, 5)]
    parts.append(C.new_mesh_object("A_studna_strizka", v, f, coll=coll,
                                    material=C.get_material("drevo_plot")))

    hose_pts = [(cx + 0.6, cy, z0 + 0.5), (cx + 0.75, cy, z0 + 0.3),
                (cx + 0.9, cy + 0.3, z0 + 0.05), (cx + 1.0, cy + 0.6, z0 + 0.05),
                (cx + 0.7, cy + 0.9, z0 + 0.05), (cx + 1.0, cy + 1.0, z0 + 0.05)]
    for i in range(len(hose_pts) - 1):
        parts.append(nc.limb("A_studna_hadice_%d" % i, hose_pts[i], hose_pts[i + 1],
                             radius=0.0125, verts=6, coll=coll,
                             material=C.get_material("guma_hadice")))
    parts.append(nc.box("A_studna_cerpadlo", (0.12, 0.08, 0.20),
                        loc=(cx + 0.55, cy - 0.05, z0 + 0.6), coll=coll,
                        material=C.get_material("kov")))
    return parts


# ---------------------------------------------------------------------------
# 5.5 — kůlna na nářadí (schválně křivá — viz akceptační kritérium 8)
# ---------------------------------------------------------------------------

def _shed_to_world(cx, cy, z0, lx, ly, lz):
    a, b = radians(SHED_ROT_Z), radians(SHED_TILT_X)
    ly2 = ly * math.cos(b) - lz * math.sin(b)
    lz2 = ly * math.sin(b) + lz * math.cos(b)
    wx = lx * math.cos(a) - ly2 * math.sin(a)
    wy = lx * math.sin(a) + ly2 * math.cos(a)
    return (cx + wx, cy + wy, z0 + lz2)


def _shed_wall_planks(batch, cx, cy, z0, ax, ay, bx, by, h_a, h_b):
    length = math.hypot(bx - ax, by - ay)
    ang = math.atan2(by - ay, bx - ax)
    dx, dy = math.cos(ang), math.sin(ang)
    n = max(1, int(length / 0.205))
    for i in range(n):
        t = (i + 0.5) / n
        lx, ly = ax + dx * length * t, ay + dy * length * t
        h = h_a + (h_b - h_a) * t
        lean = C.rng.uniform(-1.5, 1.5)
        h += C.rng.uniform(0.0, 0.08)              # horní hrana nerovná
        gap = C.rng.uniform(-0.02, 0.04)            # 0-4cm mezera, místy zapuštěná
        # sx=šířka prkna (podél stěny), sy=tloušťka (kolmo na stěnu)
        verts, faces = C.box_verts(lx, ly, gap + h * 0.5, 0.18, 0.02, h,
                                    rot_z=math.degrees(ang), rot_x=lean)
        world = [_shed_to_world(cx, cy, z0, vx, vy, vz) for (vx, vy, vz) in verts]
        batch.add(world, faces)


def _build_shed(coll):
    cx, cy = SHED_CENTER
    z0 = _z0(cx, cy)
    hx, hy = SHED_SIZE[0] * 0.5, SHED_SIZE[1] * 0.5
    h_front, h_back = 2.0, 2.25   # vpředu nižší (kap. 5.5)

    batch = C.Batch()
    # stěny: přední/zadní mají konstantní výšku, boční interpolují
    _shed_wall_planks(batch, cx, cy, z0, -hx, -hy, hx, -hy, h_front, h_front)
    _shed_wall_planks(batch, cx, cy, z0, -hx, hy, hx, hy, h_back, h_back)
    _shed_wall_planks(batch, cx, cy, z0, -hx, -hy, -hx, hy, h_front, h_back)
    _shed_wall_planks(batch, cx, cy, z0, hx, -hy, hx, hy, h_front, h_back)
    walls = batch.build("A_kulna_steny", coll=coll, material=C.get_material("drevo_plot"))

    posts = C.Batch()
    for (lx, ly, h) in ((-hx, -hy, h_front), (hx, -hy, h_front),
                        (-hx, hy, h_back), (hx, hy, h_back)):
        v, f = C.box_verts(lx, ly, h * 0.5, 0.08, 0.08, h)
        posts.add([_shed_to_world(cx, cy, z0, *p) for p in v], f)
    # šikmé vzpěry: dva body v lokálním rámu kůlny, nc.limb je spojí bez
    # ohledu na rovinu (na rozdíl od box_verts umí libovolný směr)
    for (a_l, b_l) in (((-hx, -hy, 0.0), (-hx + 0.35, -hy, h_front - 0.2)),
                       ((hx, -hy, 0.0), (hx - 0.35, -hy, h_front - 0.2))):
        wa = _shed_to_world(cx, cy, z0, *a_l)
        wb = _shed_to_world(cx, cy, z0, *b_l)
        strut = nc.limb("A_kulna_vzpera_tmp", wa, wb, size=(0.05, 0.05),
                        material=C.get_material("drevo_tmave"))
        C.merge_into_batch(posts, strut)
    posts_obj = posts.build("A_kulna_sloupky", coll=coll, material=C.get_material("drevo_tmave"))

    roof_batch = C.Batch()
    for i, (ly0, ly1, lift) in enumerate(((-hy - 0.12, hy * 0.05, 0.0), (-hy * 0.05, hy + 0.12, 0.03))):
        v, f = C.box_verts(0.0, (ly0 + ly1) * 0.5, 0.0, hx * 2 + 0.16, ly1 - ly0, 0.03)
        v = [(vx, vy, h_front + (h_back - h_front) * ((vy - (-hy)) / (hy * 2)) + lift + vz)
             for (vx, vy, vz) in v]
        roof_batch.add([_shed_to_world(cx, cy, z0, *p) for p in v], f)
    roof = roof_batch.build("A_kulna_strecha", coll=coll, material=C.get_material("drevo_plot"))

    stone_protos = C.build_rock_prototypes("A_kulna_strkam", 2, (0.09, 0.13),
                                            C.get_material("kamen_balvan"), C.rng)
    wind_stones = []
    for i, (lx, ly) in enumerate(((-0.4, 0.2), (0.5, -0.1))):
        wx, wy, wz = _shed_to_world(cx, cy, z0, lx, ly, h_front + 0.15)
        proto = stone_protos[i % len(stone_protos)]
        wind_stones.append(C.link_dup("A_kulna_strkam_%d" % i, proto, (wx, wy, wz), coll=coll))
    C.remove_prototypes(stone_protos)

    fhx, fhy = 1.3, 1.1
    base_pts = [(-fhx, -fhy), (0, -fhy), (fhx, -fhy), (fhx, 0), (fhx, fhy),
                (0, fhy), (-fhx, fhy), (-fhx, 0)]
    fverts = []
    for (lx, ly) in base_pts:
        wx, wy = cx + lx + C.rng.uniform(-0.15, 0.15), cy + ly + C.rng.uniform(-0.15, 0.15)
        fverts.append((wx, wy, _z0(wx, wy) - 0.02))
    floor = C.new_mesh_object("A_kulna_podlaha", fverts, [tuple(range(len(base_pts)))],
                               coll=coll, material=C.get_material("hlina_holy"))

    rake_handle = nc.cyl("A_narad_hrabe_drzadlo", 0.02, 1.4, rot=(70, 0, 20), verts=6,
                         smooth_angle=0, loc=(cx + 1.0, cy + 0.3, z0 + 0.6), coll=coll,
                         material=C.get_material("drevo_tmave"))
    rake_head = nc.box("A_narad_hrabe_hlava", (0.30, 0.02, 0.05),
                       loc=(cx + 1.35, cy + 0.35, z0 + 0.06), coll=coll,
                       material=C.get_material("kov"))
    shovel_handle = nc.cyl("A_narad_lopata_drzadlo", 0.018, 1.2, rot=(65, 0, -10), verts=6,
                           smooth_angle=0, loc=(cx + 0.9, cy - 0.3, z0 + 0.55), coll=coll,
                           material=C.get_material("drevo_tmave"))
    can = nc.cyl("A_narad_konev", 0.09, 0.22, verts=8, smooth_angle=0,
                loc=(cx - 0.4, cy + 0.6, z0 + 0.11), coll=coll, material=C.get_material("kov"))
    bench = nc.box("A_narad_ponk", (1.2, 0.5, 0.05),
                   loc=(cx - 0.5, cy + 0.7, z0 + 0.78), coll=coll,
                   material=C.get_material("drevo_tmave"))
    bench_legs = []
    for lx, ly in ((-0.5, -0.2), (0.5, -0.2), (-0.5, 0.2), (0.5, 0.2)):
        bench_legs.append(nc.box("A_narad_ponk_noha_%d_%d" % (lx > 0, ly > 0), (0.05, 0.05, 0.75),
                                 loc=(cx - 0.5 + lx, cy + 0.7 + ly, z0 + 0.375), coll=coll,
                                 material=C.get_material("drevo_tmave")))

    parts = [o for o in (walls, posts_obj, roof, floor, rake_handle, rake_head,
                         shovel_handle, can, bench) if o is not None]
    parts += wind_stones + bench_legs
    return parts


# ---------------------------------------------------------------------------
# 5.6 — ostatní prvky zahrady
# ---------------------------------------------------------------------------

def _build_extras(coll):
    parts = []

    barrel_pos = (-4.6, 0.8)
    z = _z0(*barrel_pos)
    barrel = nc.cyl("A_sud", 0.35, 0.9, verts=10, smooth_angle=0,
                    loc=(barrel_pos[0], barrel_pos[1], z + 0.45), coll=coll,
                    material=C.get_material("drevo_tmave"))
    parts.append(barrel)
    for hz in (0.2, 0.5, 0.8):
        parts.append(nc.torus("A_sud_obruc_%.1f" % hz, 0.36, 0.012, major_seg=10, minor_seg=5,
                              smooth_angle=0, loc=(barrel_pos[0], barrel_pos[1], z + hz),
                              coll=coll, material=C.get_material("kov")))
    water = nc.cyl("A_sud_voda", 0.32, 0.02, verts=10, smooth_angle=0,
                   loc=(barrel_pos[0], barrel_pos[1], z + 0.78), coll=coll,
                   material=C.get_material("voda_potok"))
    parts.append(water)

    wb_pos = (-6.0, 12.0)
    wz = _z0(*wb_pos)
    parts.append(nc.cone("A_kolecko_korba", 0.28, 0.18, 0.30, verts=6, rot=(0, 90, 20),
                         smooth_angle=0, loc=(wb_pos[0], wb_pos[1], wz + 0.35), coll=coll,
                         material=C.get_material("kov")))
    parts.append(nc.cyl("A_kolecko_kolo", 0.13, 0.05, rot=(90, 0, 0), verts=10, smooth_angle=0,
                        loc=(wb_pos[0] + 0.35, wb_pos[1], wz + 0.13), coll=coll,
                        material=C.get_material("kov")))
    for side in (-1, 1):
        parts.append(nc.cyl("A_kolecko_drzadlo_%d" % (side > 0), 0.015, 0.6, rot=(75, 0, side * 8),
                            verts=6, smooth_angle=0,
                            loc=(wb_pos[0] - 0.35, wb_pos[1] + side * 0.18, wz + 0.25), coll=coll,
                            material=C.get_material("drevo_tmave")))

    wood_pos = (3.8, 1.5)
    log_proto = nc.cyl("A_drevo_polena_proto", 0.06, 0.35, rot=(90, 0, 0), verts=6,
                       smooth_angle=0, material=C.get_material("drevo_kmen"))
    logs = []
    n_logs = 26
    for i in range(n_logs):
        layer = i % 4
        col = i // 4
        lx = wood_pos[0] + col * 0.12 - 0.6
        ly = wood_pos[1]
        lz = _z0(lx, ly) + 0.06 + layer * 0.11
        logs.append(C.link_dup("A_drevo_poleno_%02d" % i, log_proto, (lx, ly, lz),
                               rot_z=C.rng.uniform(-4, 4), coll=coll))
    bpy.data.objects.remove(log_proto, do_unlink=True)
    parts += logs
    for i in range(3):
        lx = wood_pos[0] + C.rng.uniform(-0.5, 0.9)
        ly = wood_pos[1] + C.rng.uniform(0.3, 0.6)
        parts.append(nc.cyl("A_drevo_poleno_volne_%d" % i, 0.06, 0.35, rot=(90, 0, C.rng.uniform(0, 180)),
                            verts=6, smooth_angle=0, loc=(lx, ly, _z0(lx, ly) + 0.06),
                            coll=coll, material=C.get_material("drevo_kmen")))

    comp_pos = (-10.5, 18.5)
    cz = _z0(*comp_pos)
    comp_batch = C.Batch()
    for (lx, ly, sx_, sy_, sz_) in ((0, -0.6, 1.2, 0.05, 0.8), (0, 0.6, 1.2, 0.05, 0.8),
                                    (-0.6, 0, 0.05, 1.2, 0.8), (0.6, 0, 0.05, 1.2, 0.8)):
        v, f = C.box_verts(comp_pos[0] + lx, comp_pos[1] + ly, cz + sz_ * 0.5, sx_, sy_, sz_)
        comp_batch.add(v, f)
    parts.append(comp_batch.build("A_kompost_bedna", coll=coll, material=C.get_material("drevo_tmave")))
    parts.append(nc.box("A_kompost_hmota", (1.0, 1.0, 0.3),
                        loc=(comp_pos[0], comp_pos[1], cz + 0.65), coll=coll,
                        material=C.get_material("hlina_holy")))

    for i, py in enumerate((8.0, 14.0)):
        pz = _z0(8.0, py)
        parts.append(nc.cyl("A_susak_kul_%d" % i, 0.04, 1.2, verts=6, smooth_angle=0,
                            loc=(8.0, py, pz + 0.6), coll=coll, material=C.get_material("drevo_plot")))
    for i, h in enumerate((1.0, 1.1)):
        line = nc.limb("A_susak_snura_%d" % i, (8.0, 8.0, _z0(8.0, 8.0) + h),
                       (8.0, 14.0, _z0(8.0, 14.0) + h), radius=0.006, verts=4,
                       coll=coll, material=C.get_material("kov"))
        parts.append(line)
    for i in range(3):
        cy_ = 9.0 + i * 2.0
        parts.append(nc.box("A_susak_pradlo_%d" % i, (0.5, 0.01, 0.7),
                            loc=(8.0, cy_, _z0(8.0, cy_) + 1.05), rot=(0, 0, C.rng.uniform(-8, 8)),
                            coll=coll, material=C.get_material("kvet_bila")))

    budka_pos = (10.0, 16.0)
    bz = _z0(*budka_pos)
    parts.append(nc.cyl("A_budka_kul", 0.04, 2.2, verts=6, smooth_angle=0,
                        loc=(budka_pos[0], budka_pos[1], bz + 1.1), coll=coll,
                        material=C.get_material("drevo_plot")))
    parts.append(nc.box("A_budka_domek", (0.16, 0.16, 0.22),
                        loc=(budka_pos[0], budka_pos[1], bz + 2.1), coll=coll,
                        material=C.get_material("drevo_tmave")))
    parts.append(nc.cyl("A_budka_bidylko", 0.008, 0.06, rot=(90, 0, 0), verts=5, smooth_angle=0,
                        loc=(budka_pos[0], budka_pos[1] - 0.09, bz + 2.03), coll=coll,
                        material=C.get_material("drevo_tmave")))

    for kx in (-3.0, 3.0):
        kz = _z0(kx, 1.2)
        crown = C.ico("A_ker_%d" % int(kx), 0.45, subdiv=1, loc=(kx, 1.2, kz + 0.35),
                     scale=(1.0, 1.0, 0.75), coll=coll, material=C.get_material("listi_tmave"))
        trunk = nc.cyl("A_ker_kmen_%d" % int(kx), 0.03, 0.15, verts=6, smooth_angle=0,
                       loc=(kx, 1.2, kz + 0.075), coll=coll, material=C.get_material("drevo_kmen"))
        parts += [crown, trunk]

    step_batch = C.Batch()
    step_targets = [(-1.5, 4.0), (-2.2, 6.0), (-3.0, 8.5),
                    (-6.0, 8.0), (-6.6, 10.0), (-7.0, 12.4)]
    for i, (tx, ty) in enumerate(step_targets):
        tz = _z0(tx, ty)
        r = 0.16
        n = 6
        outer = []
        for k in range(n):
            a = 2.0 * math.pi * k / n
            outer.append((tx + r * math.cos(a), ty + r * math.sin(a), tz))
        step_batch.add(outer, [tuple(range(n))])
    parts.append(step_batch.build("A_slapak", coll=coll, material=C.get_material("kamen_dlazba")))

    rake2 = nc.cyl("A_narad_hrabe_zahon", 0.015, 1.2, rot=(70, 0, 40), verts=6, smooth_angle=0,
                   loc=(BEDS[0]["center"][0] - 1.0, BEDS[0]["center"][1] + 0.5,
                        _z0(BEDS[0]["center"][0] - 1.0, BEDS[0]["center"][1] + 0.5) + 0.5),
                   coll=coll, material=C.get_material("drevo_tmave"))
    can2 = nc.cyl("A_narad_konev_zahon", 0.08, 0.20, verts=8, smooth_angle=0,
                 loc=(BEDS[1]["center"][0] + 0.8, BEDS[1]["center"][1] - 0.3,
                      _z0(BEDS[1]["center"][0] + 0.8, BEDS[1]["center"][1] - 0.3) + 0.10),
                 coll=coll, material=C.get_material("kov"))
    parts += [rake2, can2]

    stump_pos = (-11.0, 3.0)
    sz = _z0(*stump_pos)
    parts.append(nc.cyl("A_parez", 0.225, 0.30, verts=10, smooth_angle=0,
                        loc=(stump_pos[0], stump_pos[1], sz + 0.15), coll=coll,
                        material=C.get_material("drevo_kmen")))
    v, f = C.disc_verts(stump_pos[0], stump_pos[1], sz + 0.301, 0.14, 10)
    parts.append(C.new_mesh_object("A_parez_letokruh", v, f, coll=coll,
                                   material=C.get_material("drevo_tmave")))

    return [p for p in parts if p is not None]


def build_garden_details(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("A_Zahrada",))
    own_coll = nc.collection("A_Zahrada", coll)

    parts = _build_lawn(own_coll)
    parts += _build_beds(own_coll)
    parts += _build_well(own_coll)
    parts += _build_shed(own_coll)
    parts += _build_extras(own_coll)

    tris = C.triangle_count(parts)
    print("[NCR] zahrada (detail): %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


if __name__ == "__main__":
    build_garden_details()
