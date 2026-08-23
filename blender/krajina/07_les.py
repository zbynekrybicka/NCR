# -*- coding: utf-8 -*-
"""
Sekce D — les (kap. 8). Materiálová zóna terénu (louka -> jehličí) už řeší
`common.terrain_zone()`; tady jen jehličí/tráva v přechodu, borovice a podrost.

Strom je kmen (materiál `drevo_kmen`) a koruna (materiál `jehlici_zelen`)
jako DVA samostatné linked-duplicate objekty se stejnou pozicí/rotací/scale
(kap. 1.3 bod 4 chce jeden materiál na "kus" — strom se dvěma barvami tedy
musí být dva kusy, ne jeden). Prototypy jsou postavené v "jednotkové" výšce
1.0 a scale při scatteru = požadovaná výška stromu v metrech.

Objekty: D_borovice_*, D_jehlici_*, D_mraveniste, D_ker_*, D_parez_*,
D_kmen_*, D_klesti_*, D_houba_*, D_kamen_*, D_balvan_mech, D_znacka
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

FOREST_BOUNDS = (-22.0, 70.0, 22.0, 112.0)
PINE_MIN_DIST = 2.2
PINE_PATH_CLEARANCE = 1.6
PINE_COUNT_RANGE = (55, 70)
PINE_HEIGHT_RANGE = (9.0, 17.0)
SAPLING_HEIGHT_RANGE = (2.0, 4.0)

ANTHILL_POS = (2.5, 88.0)

PREFIXES = ("D_borovice", "D_jehlici", "D_mraveniste", "D_ker", "D_parez",
            "D_kmen", "D_klesti", "D_houba", "D_kamen", "D_balvan_mech", "D_znacka")


def _z0(x, y):
    return C.snap_to_ground(x, y)


def _forest_exclude(x, y):
    return C.dist_to_polyline(x, y, C.PATH_POINTS) < PINE_PATH_CLEARANCE


# ---------------------------------------------------------------------------
# 8.2 — borovice (jednotkové prototypy, scale = výška ve stupních)
# ---------------------------------------------------------------------------

def _build_trunk_prototype(name):
    batch = C.Batch()
    trunk_top = 0.60
    kink = C.rng.uniform(-0.02, 0.02)
    for (z0, z1, dx0) in ((0.0, trunk_top * 0.5, 0.0), (trunk_top * 0.5, trunk_top, kink)):
        rr0 = C.lerp(0.017, 0.007, z0 / trunk_top)
        rr1 = C.lerp(0.017, 0.007, z1 / trunk_top)
        tmp = nc.cone("%s_tmp" % name, rr0, rr1, z1 - z0, verts=7, smooth_angle=0,
                     loc=(dx0, 0.0, z0 + (z1 - z0) * 0.5))
        C.merge_into_batch(batch, tmp)
    for i in range(C.rng.randint(4, 6)):    # pahýly odlomených větví
        z = C.rng.uniform(0.10, trunk_top - 0.05)
        a = C.rng.uniform(0, 360)
        tmp = nc.cone("%s_stub_tmp" % name, 0.012, 0.002, 0.03, verts=5, smooth_angle=0,
                     loc=(0.0, 0.0, z), rot=(70, 0, a))
        C.merge_into_batch(batch, tmp)
    return batch.build(name, material=C.get_material("drevo_kmen"))


def _build_crown_prototype(name, material_key, n_crown=4):
    batch = C.Batch()
    trunk_top = 0.60
    for j in range(n_crown):
        t = j / max(1, n_crown - 1)
        z = trunk_top + (1.0 - trunk_top) * t * 0.75 + 0.10
        r = C.rng.uniform(0.20, 0.30) * (1.0 - t * 0.25)
        jx, jy = C.rng.uniform(-0.05, 0.05), C.rng.uniform(-0.05, 0.05)
        tmp = C.ico("%s_tmp_%d" % (name, j), r, subdiv=1, loc=(jx, jy, z), scale=(1.0, 1.0, 0.6))
        C.merge_into_batch(batch, tmp)
    return batch.build(name, material=C.get_material(material_key))


def _build_forest_trees(coll):
    parts = []
    trunk_protos = [_build_trunk_prototype("D_borovice_kmen_proto_%d" % i) for i in range(3)]
    crown_protos = [_build_crown_prototype("D_borovice_koruna_proto_%d" % i,
                                           "jehlici_zelen", n_crown=C.rng.randint(3, 5))
                    for i in range(3)]
    dead_trunk = _build_trunk_prototype("D_borovice_suchy_proto")
    nc.set_material(dead_trunk, C.get_material("drevo_suchy"))

    points = C.scatter(FOREST_BOUNDS, 0.045, PINE_MIN_DIST, C.rng, exclude_fn=_forest_exclude)
    count = min(len(points), C.rng.randint(*PINE_COUNT_RANGE))
    points = points[:count]

    n_dead = 2
    n_saplings = min(8, max(0, count // 9))
    n_leaning = C.rng.randint(4, 6)
    dead_idx = set(C.rng.sample(range(count), min(n_dead, count)))
    remaining = [i for i in range(count) if i not in dead_idx]
    sapling_idx = set(C.rng.sample(remaining, min(n_saplings, len(remaining))))
    remaining2 = [i for i in remaining if i not in sapling_idx]
    leaning_idx = set(C.rng.sample(remaining2, min(n_leaning, len(remaining2))))

    for i, (x, y) in enumerate(points):
        z = _z0(x, y)
        rot_z = C.rng.uniform(0, 360)
        lean_x = lean_y = 0.0
        if i in leaning_idx:
            a = radians(C.rng.uniform(0, 360))
            mag = C.rng.uniform(5.0, 8.0)
            lean_x, lean_y = mag * math.cos(a), mag * math.sin(a)

        if i in dead_idx:
            height = C.rng.uniform(*PINE_HEIGHT_RANGE) * 0.7
            obj = C.link_dup("D_borovice_%03d_kmen" % i, dead_trunk, (x, y, z), rot_z=rot_z,
                             scale=height, coll=coll)
            obj.rotation_euler = (radians(lean_x), radians(lean_y), radians(rot_z))
            parts.append(obj)
            continue

        height = C.rng.uniform(*SAPLING_HEIGHT_RANGE) if i in sapling_idx \
            else C.rng.uniform(*PINE_HEIGHT_RANGE)
        trunk = trunk_protos[i % len(trunk_protos)]
        crown = crown_protos[i % len(crown_protos)]
        t_obj = C.link_dup("D_borovice_%03d_kmen" % i, trunk, (x, y, z), rot_z=rot_z,
                           scale=height, coll=coll)
        c_obj = C.link_dup("D_borovice_%03d_koruna" % i, crown, (x, y, z), rot_z=rot_z,
                           scale=height, coll=coll)
        t_obj.rotation_euler = (radians(lean_x), radians(lean_y), radians(rot_z))
        c_obj.rotation_euler = (radians(lean_x), radians(lean_y), radians(rot_z))
        parts += [t_obj, c_obj]

    C.remove_prototypes(trunk_protos + crown_protos + [dead_trunk])
    return parts


# ---------------------------------------------------------------------------
# 8.1 — přechod (jehličí/tráva) a jehličí po podlaze lesa
# ---------------------------------------------------------------------------

def _needle_flake_verts(x, y, z, r, rot_z):
    a0 = radians(rot_z)
    p0 = (x, y, z)
    p1 = (x + r * math.cos(a0), y + r * math.sin(a0), z)
    p2 = (x + r * 0.4 * math.cos(a0 + 2.4), y + r * 0.4 * math.sin(a0 + 2.4), z)
    return [p0, p1, p2], [(0, 1, 2)]


def _build_needle_litter(coll):
    batch = C.Batch()
    n = C.rng.randint(30, 40)
    for _ in range(n):
        x = C.rng.uniform(-20.0, 20.0)
        y = C.rng.uniform(68.0, 78.0)
        r = C.rng.uniform(0.05, 0.10)
        v, f = _needle_flake_verts(x, y, _z0(x, y) + 0.005, r, C.rng.uniform(0, 360))
        batch.add(v, f)
    for _ in range(160):
        x = C.rng.uniform(*FOREST_BOUNDS[0::2])
        y = C.rng.uniform(78.0, FOREST_BOUNDS[3])
        r = C.rng.uniform(0.04, 0.08)
        v, f = _needle_flake_verts(x, y, _z0(x, y) + 0.005, r, C.rng.uniform(0, 360))
        batch.add(v, f)
    return batch.build("D_jehlici_podlaha", coll=coll, material=C.get_material("jehlici_zeme"))


def _build_transition_grass(coll):
    protos = C.build_clump_prototypes("D_jehlici_travnik", 3, (3, 5), (0.10, 0.20), (0.006, 0.010),
                                      C.get_material("trava_louka"), C.rng)

    def _thin_exclude(x, y):
        if _forest_exclude(x, y):
            return True
        # řídnutí směrem do lesa — pravděpodobnost výskytu klesá s Y
        edge = C.smoothstep(68.0, 78.0, y)
        return C.rng.random() < edge

    points = C.scatter((-20.0, 66.0, 20.0, 78.0), 0.5, 0.35, C.rng, exclude_fn=_thin_exclude)
    objs = C.scatter_instances("D_jehlici_travnik", points, protos, coll, C.rng, z_fn=_z0)
    C.remove_prototypes(protos)
    return objs


# ---------------------------------------------------------------------------
# 8.3 — mraveniště
# ---------------------------------------------------------------------------

def _build_anthill(coll):
    x, y = ANTHILL_POS
    z = _z0(x, y)
    obj = nc.cone("D_mraveniste", 1.2, 0.15, 1.3, verts=10, smooth_angle=0,
                 loc=(x, y, z + 0.65), shift=(0.15, 0.05, 0.0), coll=coll,
                 material=C.get_material("jehlici_zeme"))
    C.jitter_verts(obj, 0.08, C.rng)
    parts = [obj]
    litter = C.Batch()
    for _ in range(35):
        a = C.rng.uniform(0, 2 * math.pi)
        r = C.rng.uniform(1.3, 2.2)
        nx, ny = x + r * math.cos(a), y + r * math.sin(a)
        v, f = _needle_flake_verts(nx, ny, _z0(nx, ny) + 0.005, C.rng.uniform(0.05, 0.09),
                                   C.rng.uniform(0, 360))
        litter.add(v, f)
    parts.append(litter.build("D_mraveniste_jehlici", coll=coll, material=C.get_material("jehlici_zeme")))
    for i in range(4):
        a = C.rng.uniform(0, 2 * math.pi)
        tx, ty = x + 0.9 * math.cos(a), y + 0.9 * math.sin(a)
        parts.append(nc.cyl("D_mraveniste_vetvicka_%d" % i, 0.01, 0.25, rot=(75, 0, math.degrees(a)),
                            verts=5, smooth_angle=0, loc=(tx, ty, z + 0.1), coll=coll,
                            material=C.get_material("drevo_kmen")))
    return parts


# ---------------------------------------------------------------------------
# 8.4 — podrost
# ---------------------------------------------------------------------------

def _build_undergrowth(coll):
    parts = []

    n_shrubs = C.rng.randint(35, 50)
    for i in range(n_shrubs):
        x = C.rng.uniform(-21.0, 21.0)
        y = C.rng.uniform(72.0, 111.0)
        z = _z0(x, y)
        n_blobs = C.rng.randint(3, 4)
        centers = []
        for j in range(n_blobs):
            jx, jy = C.rng.uniform(-0.2, 0.2), C.rng.uniform(-0.2, 0.2)
            r = C.rng.uniform(0.20, 0.35)
            jz = 0.15 + j * 0.08
            parts.append(C.ico("D_ker_%02d_%d" % (i, j), r, subdiv=1, loc=(x + jx, y + jy, z + jz),
                               scale=(1.0, 1.0, 0.8), coll=coll, material=C.get_material("listi_tmave")))
            centers.append((x + jx, y + jy, z + jz + r * 0.6))
        if C.rng.random() < 0.6:
            for _ in range(C.rng.randint(5, 12)):
                cx_, cy_, cz_ = centers[C.rng.randrange(len(centers))]
                a = C.rng.uniform(0, 2 * math.pi)
                r2 = C.rng.uniform(0.05, 0.20)
                parts.append(C.ico("D_ker_%02d_plod_%d" % (i, len(parts)), 0.02, subdiv=1,
                                   loc=(cx_ + r2 * math.cos(a), cy_ + r2 * math.sin(a), cz_),
                                   coll=coll, material=C.get_material("plody")))

    for i in range(C.rng.randint(8, 10)):
        x = C.rng.uniform(-20.0, 20.0)
        y = C.rng.uniform(72.0, 110.0)
        z = _z0(x, y)
        r = C.rng.uniform(0.15, 0.30)
        parts.append(nc.cyl("D_parez_%02d" % i, r, r * 1.3, verts=8, smooth_angle=0,
                            loc=(x, y, z + r * 0.65), coll=coll, material=C.get_material("drevo_kmen")))

    for i in range(C.rng.randint(4, 5)):
        x = C.rng.uniform(-18.0, 18.0)
        y = C.rng.uniform(74.0, 108.0)
        z = _z0(x, y)
        length = C.rng.uniform(3.0, 6.0)
        r = C.rng.uniform(0.15, 0.25)
        ang = C.rng.uniform(0, 180)
        on_path = C.dist_to_polyline(x, y, C.PATH_POINTS) < length * 0.5 + 0.5
        parts.append(nc.cyl("D_kmen_%d" % i, r, length, rot=(90, 0, ang), verts=8, smooth_angle=0,
                            loc=(x, y, z + r * (0.3 if on_path else 0.7)), coll=coll,
                            material=C.get_material("drevo_kmen")))

    for i in range(3):
        x = C.rng.uniform(-19.0, 19.0)
        y = C.rng.uniform(73.0, 109.0)
        z = _z0(x, y)
        batch = C.Batch()
        for _ in range(C.rng.randint(12, 20)):
            bx = x + C.rng.uniform(-0.4, 0.4)
            by = y + C.rng.uniform(-0.4, 0.4)
            bz = z + C.rng.uniform(0.05, 0.3)
            length = C.rng.uniform(0.8, 1.6)
            ang = C.rng.uniform(0, 180)
            v, f = C.box_verts(bx, by, bz, 0.05, 0.05, length, rot_x=90, rot_z=ang)
            batch.add(v, f)
        parts.append(batch.build("D_klesti_%d" % i, coll=coll, material=C.get_material("drevo_kmen")))

    mush_mats = [C.get_material("houba_hneda"), C.get_material("houba_cervena")]
    n_groups = C.rng.randint(6, 8)
    for g in range(n_groups):
        gx = C.rng.uniform(-19.0, 19.0)
        gy = C.rng.uniform(73.0, 109.0)
        gz = _z0(gx, gy)
        mat = mush_mats[g % 2]
        for i in range(C.rng.randint(2, 5)):
            x = gx + C.rng.uniform(-0.2, 0.2)
            y = gy + C.rng.uniform(-0.2, 0.2)
            z = _z0(x, y)
            h = C.rng.uniform(0.04, 0.08)
            parts.append(nc.cyl("D_houba_stopka_%d_%d" % (g, i), 0.008, h, verts=5, smooth_angle=0,
                                loc=(x, y, z + h * 0.5), coll=coll, material=C.get_material("drevo_plot")))
            parts.append(nc.cone("D_houba_klobouk_%d_%d" % (g, i), 0.05, 0.01, 0.035, verts=7,
                                 smooth_angle=0, loc=(x, y, z + h + 0.017), coll=coll, material=mat))

    stone_protos = C.build_rock_prototypes("D_kamen", 4, (0.08, 0.22),
                                           C.get_material("kamen_balvan"), C.rng)
    for i in range(C.rng.randint(12, 18)):
        x = C.rng.uniform(-20.0, 20.0)
        y = C.rng.uniform(72.0, 110.0)
        proto = stone_protos[i % len(stone_protos)]
        parts.append(C.link_dup("D_kamen_%02d" % i, proto, (x, y, _z0(x, y)),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(stone_protos)

    bx, by = -4.0, 96.0
    bz = _z0(bx, by)
    balvan = C.ico("D_balvan_mech", 0.9, subdiv=1, loc=(bx, by, bz + 0.5),
                  scale=(1.0, 1.0, 0.7), coll=coll, material=C.get_material("kamen_balvan"))
    C.jitter_verts(balvan, 0.12, C.rng)
    parts.append(balvan)
    for i in range(4):
        a = C.rng.uniform(0, 2 * math.pi)
        r = C.rng.uniform(0.4, 0.7)
        mx, my = bx + r * math.cos(a), by + r * math.sin(a) * 0.7
        parts.append(C.ico("D_balvan_mech_skvrna_%d" % i, C.rng.uniform(0.12, 0.22), subdiv=0,
                           loc=(mx, my, bz + 0.55), scale=(1.0, 1.0, 0.15), coll=coll,
                           material=C.get_material("mech")))

    sx, sy = -0.8, 92.0
    sz = _z0(sx, sy)
    marker_trunk = nc.cyl("D_znacka_kmen", 0.12, 3.0, verts=8, smooth_angle=0,
                          loc=(sx, sy, sz + 1.5), coll=coll, material=C.get_material("drevo_kmen"))
    marker_white = nc.box("D_znacka_bila", (0.12, 0.02, 0.10), loc=(sx + 0.13, sy, sz + 1.55),
                          coll=coll, material=C.get_material("kvet_bila"))
    marker_red = nc.box("D_znacka_cervena", (0.12, 0.02, 0.04), loc=(sx + 0.13, sy, sz + 1.5),
                        coll=coll, material=C.get_material("kvet_cervena"))
    parts += [marker_trunk, marker_white, marker_red]

    return [p for p in parts if p is not None]


def build_forest(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("D_Les",))
    own_coll = nc.collection("D_Les", coll)

    parts = _build_forest_trees(own_coll)
    parts.append(_build_needle_litter(own_coll))
    parts += _build_transition_grass(own_coll)
    parts += _build_anthill(own_coll)
    parts += _build_undergrowth(own_coll)

    tris = C.triangle_count([p for p in parts if p is not None])
    print("[NCR] les: %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


if __name__ == "__main__":
    build_forest()
