# -*- coding: utf-8 -*-
"""
Sekce E — hora (kap. 9). Tvar (kužel, fazety, výškové zóny) i materiálová
zóna terénu jsou v `01_teren.py`/`common.py` — tady se staví jen vegetace
podle výškových pásem, suťové pole, mech a doplňky (kap. 9.2-9.4) a nakonec
vchod do jeskyně (kap. 9.5).

Zjednodušení: portál je modelovaný jako obdélníkový kamenný rám (ne přesný
nepravidelný osmiúhelník) — boční balvany a překlad nad ním siluetu stejně
rozbíjí a bez vizuální kontroly bych přesný osmiúhelníkový výřez riskoval
rozbít (díry/přesahy), zatímco rám ze 4 jednoduchých ploch je bezpečný.

Objekty: E_hranice_lesa_*, E_travnaty_*, E_kvet_*, E_sut_kamen_*, E_mech_*,
E_mohyla, E_balvan_*, E_suchy_strom, E_vez_*, E_deska, E_travnik_jeskyne,
E_jeskyne_stena, E_jeskyne_plosina, E_jeskyne_svit, E_jeskyne_odlesk_*
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

MOUNTAIN_BOUNDS = (-20.0, 112.0, 20.0, 175.0)
PATH_CLEARANCE = 1.2

PREFIXES = ("E_hranice_lesa", "E_travnaty", "E_kvet", "E_sut_kamen", "E_mech",
            "E_mohyla", "E_balvan", "E_suchy_strom", "E_vez", "E_deska",
            "E_travnik_jeskyne", "E_jeskyne_stena", "E_jeskyne_plosina",
            "E_jeskyne_svit", "E_jeskyne_odlesk")


def _z0(x, y):
    return C.snap_to_ground(x, y)


def _near_path(x, y, clearance=PATH_CLEARANCE):
    return C.dist_to_polyline(x, y, C.PATH_POINTS) < clearance


def _random_in_zone(z_lo, z_hi, tries_factor=50, target=1):
    pts = []
    tries = 0
    while len(pts) < target and tries < target * tries_factor:
        tries += 1
        x = C.rng.uniform(*MOUNTAIN_BOUNDS[0::2])
        y = C.rng.uniform(*MOUNTAIN_BOUNDS[1::2])
        z = C.height(x, y)
        if z_lo <= z < z_hi and not _near_path(x, y):
            pts.append((x, y))
    return pts


# ---------------------------------------------------------------------------
# 9.2 — horní hranice lesa (Z 13-15): poslední, zkroucené stromy
# ---------------------------------------------------------------------------

def _build_treeline(coll):
    parts = []
    trunk_proto = _build_twisted_trunk_prototype("E_hranice_lesa_kmen_proto")
    crown_proto = _build_crown_prototype("E_hranice_lesa_koruna_proto")
    wind_dir = C.rng.uniform(0, 360)

    points = _random_in_zone(13.0, 15.0, target=C.rng.randint(8, 12))
    n_dead = 3
    dead_idx = set(C.rng.sample(range(len(points)), min(n_dead, len(points))))
    for i, (x, y) in enumerate(points):
        z = _z0(x, y)
        height = C.rng.uniform(3.0, 6.0)
        rot_z = C.rng.uniform(0, 360)
        lean = C.rng.uniform(8.0, 14.0)
        lean_x = lean * math.cos(radians(wind_dir))
        lean_y = lean * math.sin(radians(wind_dir))
        t_obj = C.link_dup("E_hranice_lesa_%02d_kmen" % i, trunk_proto, (x, y, z), rot_z=rot_z,
                           scale=height, coll=coll)
        t_obj.rotation_euler = (radians(lean_x), radians(lean_y), radians(rot_z))
        parts.append(t_obj)
        if i in dead_idx:
            C.set_material_override(t_obj, C.get_material("drevo_suchy"))
            continue
        c_obj = C.link_dup("E_hranice_lesa_%02d_koruna" % i, crown_proto, (x, y, z), rot_z=rot_z,
                           scale=height, coll=coll)
        c_obj.rotation_euler = (radians(lean_x), radians(lean_y), radians(rot_z))
        parts.append(c_obj)

    C.remove_prototypes([trunk_proto, crown_proto])
    return parts


def _build_twisted_trunk_prototype(name):
    batch = C.Batch()
    top = 0.85
    for i, (z0, z1) in enumerate(((0.0, top * 0.5), (top * 0.5, top))):
        dx = C.rng.uniform(-0.06, 0.06)
        r0 = C.lerp(0.05, 0.02, z0 / top)
        r1 = C.lerp(0.05, 0.02, z1 / top)
        tmp = nc.cone("%s_tmp_%d" % (name, i), r0, r1, z1 - z0, verts=6, smooth_angle=0,
                     loc=(dx, 0.0, z0 + (z1 - z0) * 0.5))
        C.merge_into_batch(batch, tmp)
    return batch.build(name, material=C.get_material("drevo_kmen"))


def _build_crown_prototype(name):
    batch = C.Batch()
    for j in range(3):
        z = 0.60 + j * 0.10
        r = C.rng.uniform(0.18, 0.28)
        jx, jy = C.rng.uniform(-0.08, 0.08), C.rng.uniform(-0.08, 0.08)
        tmp = C.ico("%s_tmp_%d" % (name, j), r, subdiv=1, loc=(jx, jy, z), scale=(1.0, 1.0, 0.6))
        C.merge_into_batch(batch, tmp)
    return batch.build(name, material=C.get_material("jehlici_zelen"))


# ---------------------------------------------------------------------------
# 9.2 — travnatý pás (Z 15-25): řídké trsy + kvítky
# ---------------------------------------------------------------------------

def _build_sparse_grass(coll):
    protos = C.build_clump_prototypes("E_travnaty", 3, (2, 4), (0.06, 0.11), (0.005, 0.008),
                                      C.get_material("trava_ridka"), C.rng)
    points = _random_in_zone(15.0, 25.0, target=int(0.25 * 40.0 * 63.0 * 0.15))
    objs = C.scatter_instances("E_travnaty", points, protos, coll, C.rng, z_fn=_z0)
    C.remove_prototypes(protos)

    flower_batch = C.Batch()
    for _ in range(C.rng.randint(10, 15)):
        pts = _random_in_zone(15.0, 25.0, target=1)
        if not pts:
            continue
        x, y = pts[0]
        z = _z0(x, y)
        v, f = C.blade_verts(x, y, z, 0.10, 0.006, bend=0.01)
        flower_batch.add(v, f)
        v, f = C.disc_verts(x, y, z + 0.10, 0.02, 5)
        flower_batch.add(v, f)
    flower = flower_batch.build("E_kvet_horske", coll=coll, material=C.get_material("kvet_bila"))
    return objs + [flower]


# ---------------------------------------------------------------------------
# suťové pole (Z 22-30) a mech na skále (Z >= 28)
# ---------------------------------------------------------------------------

def _build_talus(coll):
    protos = C.build_rock_prototypes("E_sut_kamen", 5, (0.10, 0.60),
                                     C.get_material("kamen_balvan"), C.rng)
    target = C.rng.randint(120, 200)
    points, placed = [], []
    tries = 0
    while len(points) < target and tries < target * 60:
        tries += 1
        x = C.rng.uniform(*MOUNTAIN_BOUNDS[0::2])
        y = C.rng.uniform(*MOUNTAIN_BOUNDS[1::2])
        z = C.height(x, y)
        if not (22.0 <= z < 30.0) or _near_path(x, y, 1.0):
            continue
        if any((px - x) ** 2 + (py - y) ** 2 < 0.35 ** 2 for (px, py) in placed):
            continue
        points.append((x, y))
        placed.append((x, y))
    objs = []
    for i, (x, y) in enumerate(points):
        proto = protos[i % len(protos)]
        objs.append(C.link_dup("E_sut_kamen_%03d" % i, proto, (x, y, C.height(x, y)),
                               rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(protos)
    return objs


def _build_moss(coll):
    parts = []
    target = C.rng.randint(40, 60)
    tries = 0
    while len(parts) < target and tries < target * 50:
        tries += 1
        x = C.rng.uniform(*MOUNTAIN_BOUNDS[0::2])
        y = C.rng.uniform(112.0, 175.0)
        z = C.height(x, y)
        if z < 28.0:
            continue
        r = C.rng.uniform(0.20, 0.75)
        parts.append(C.ico("E_mech_%03d" % len(parts), r, subdiv=0, loc=(x, y, z + 0.02),
                           scale=(1.0, 1.0, 0.10), rot_z=C.rng.uniform(0, 360), coll=coll,
                           material=C.get_material("mech")))
    return parts


# ---------------------------------------------------------------------------
# 9.4 — doplňky
# ---------------------------------------------------------------------------

def _build_extras(coll):
    parts = []

    mx, my = 2.0, 148.0
    mz = _z0(mx, my)
    z = mz
    for i in range(C.rng.randint(7, 9)):
        r = C.rng.uniform(0.35, 0.5) * (1.0 - i * 0.06)
        th = 0.9 / 8.0
        v, f = C.disc_verts(mx + C.rng.uniform(-0.06, 0.06), my + C.rng.uniform(-0.06, 0.06),
                            z, r, 7, rot_z=C.rng.uniform(0, 60))
        parts.append(C.new_mesh_object("E_mohyla_%d" % i, v, f, coll=coll,
                                       material=C.get_material("kamen_balvan")))
        z += th

    big_protos = C.build_rock_prototypes("E_balvan", 3, (1.25, 2.0),
                                         C.get_material("kamen_balvan"), C.rng, subdiv=1)
    for i, (bx, by) in enumerate(((-8.0, 120.0), (10.0, 135.0), (1.5, 129.0))):
        bz = _z0(bx, by)
        lift = -0.3 if i < 2 else 0.4    # jeden zaklíněný nad cestou
        parts.append(C.link_dup("E_balvan_%d" % i, big_protos[i], (bx, by, bz + lift),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(big_protos)

    dx, dy = -6.0, 150.0
    dz = _z0(dx, dy)
    dead_trunk = _build_twisted_trunk_prototype("E_suchy_strom")
    nc.set_material(dead_trunk, C.get_material("drevo_suchy"))
    dead = C.link_dup("E_suchy_strom_inst", dead_trunk, (dx, dy, dz), scale=4.0, coll=coll)
    C.remove_prototypes([dead_trunk])
    parts.append(dead)

    for i, (tx, ty) in enumerate(((-4.0, 128.0), (4.5, 128.0))):
        tz = _z0(tx, ty)
        tower = C.ico("E_vez_%d" % i, 1.0, subdiv=1, loc=(tx, ty, tz + 2.0),
                     scale=(0.6, 0.6, 2.2), coll=coll, material=C.get_material("kamen_skala"))
        C.jitter_verts(tower, 0.3, C.rng)
        parts.append(tower)

    sx, sy = -3.0, 155.0
    sz = _z0(sx, sy)
    parts.append(nc.box("E_deska", (1.6, 0.15, 2.2), loc=(sx, sy, sz + 1.0), rot=(15, 0, 20),
                        coll=coll, material=C.get_material("kamen_skala")))

    gx, gy = C.CAVE_PORTAL[0] - 1.5, C.CAVE_PORTAL[1] - 0.5
    grass_proto = C.build_clump_prototypes("E_travnik_jeskyne", 1, (4, 6), (0.10, 0.15),
                                           (0.006, 0.010), C.get_material("trava_ridka"), C.rng)
    parts.append(C.link_dup("E_travnik_jeskyne_1", grass_proto[0], (gx, gy, _z0(gx, gy)), coll=coll))
    C.remove_prototypes(grass_proto)

    return [p for p in parts if p is not None]


# ---------------------------------------------------------------------------
# 9.5 — vchod do jeskyně
# ---------------------------------------------------------------------------

def _build_portal(coll):
    parts = []
    px, py = C.CAVE_PORTAL
    wall_y = py + 0.05
    base_z = C.height(px, py)
    hw, hh = 6.0, 4.0
    ow, oh = 1.7, 1.5

    left_x, right_x = px - hw, px + hw
    open_left, open_right = px - ow, px + ow
    bottom_z, top_z = base_z, base_z + 2 * hh
    open_bottom, open_top = base_z + (hh - oh), base_z + (hh + oh)

    batch = C.Batch()

    def quad(x0, z0, x1, z1):
        batch.add([(x0, wall_y, z0), (x1, wall_y, z0), (x1, wall_y, z1), (x0, wall_y, z1)],
                  [(0, 1, 2, 3)])

    quad(left_x, bottom_z, open_left, top_z)
    quad(open_right, bottom_z, right_x, top_z)
    quad(open_left, bottom_z, open_right, open_bottom)
    quad(open_left, open_top, open_right, top_z)
    parts.append(batch.build("E_jeskyne_stena", coll=coll, material=C.get_material("kamen_skala")))

    plaz_batch = C.Batch()
    v, f = C.box_verts(px, py - 2.5, base_z - 0.02, 5.0, 4.0, 0.04)
    plaz_batch.add(v, f)
    parts.append(plaz_batch.build("E_jeskyne_plosina", coll=coll, material=C.get_material("hlina_holy")))

    side_protos = C.build_rock_prototypes("E_jeskyne_balvan", 3, (0.5, 0.9),
                                          C.get_material("kamen_balvan"), C.rng, subdiv=1)
    positions = [(open_left - 0.5, bottom_z + 0.5), (open_left - 0.9, bottom_z + 1.4),
                (open_right + 0.5, bottom_z + 0.5), (open_right + 0.9, bottom_z + 1.4),
                (px - 0.6, open_top + 0.3), (px + 0.6, open_top + 0.3)]
    for i, (bx, bz) in enumerate(positions):
        proto = side_protos[i % len(side_protos)]
        parts.append(C.link_dup("E_jeskyne_balvan_%d" % i, proto, (bx, wall_y, bz),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(side_protos)

    glow_batch = C.Batch()
    gy = wall_y - 0.02
    v = [(px - 1.6, gy, open_bottom + 0.1), (px + 1.6, gy, open_bottom + 0.1),
         (px + 1.6, gy, open_top - 0.1), (px - 1.6, gy, open_top - 0.1)]
    glow_batch.add(v, [(0, 1, 2, 3)])
    parts.append(glow_batch.build("E_jeskyne_svit", coll=coll, material=C.get_material("lava_portal")))

    for i in range(4):
        ox = px + C.rng.uniform(-2.0, 2.0)
        oy = py + C.rng.uniform(-1.5, -0.3)
        oz = _z0(ox, oy) + 0.005
        r = C.rng.uniform(0.15, 0.35)
        v, f = C.disc_verts(ox, oy, oz, r, 6, rot_z=C.rng.uniform(0, 360))
        parts.append(C.new_mesh_object("E_jeskyne_odlesk_%d" % i, v, f, coll=coll,
                                       material=C.get_material("lava_odlesk")))

    return [p for p in parts if p is not None]


def build_mountain(coll=None):
    nc.prepare()
    nc.purge(PREFIXES, collections=("E_Hora",))
    own_coll = nc.collection("E_Hora", coll)

    parts = _build_treeline(own_coll)
    parts += _build_sparse_grass(own_coll)
    parts += _build_talus(own_coll)
    parts += _build_moss(own_coll)
    parts += _build_extras(own_coll)
    parts += _build_portal(own_coll)

    tris = C.triangle_count([p for p in parts if p is not None])
    print("[NCR] hora: %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


if __name__ == "__main__":
    build_mountain()
