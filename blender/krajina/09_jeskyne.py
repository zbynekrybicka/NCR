# -*- coding: utf-8 -*-
"""
Sekce F — jeskyně (kap. 10). Samostatný objekt/kolekce `F_Jeskyne`, napojený
na terén jen otvorem, který už udělal `01_teren.py` (kap. 10 hlavička).

Zjednodušení oproti spec (viz README): čtyři enklávy (10.2) nejsou
samostatné krabicové místnosti se ručně poskládanými stěnami — bez
možnosti render kontroly v tomhle session je riziko děravé/neprůchozí
geometrie příliš vysoké. Místo toho jsou realizované jako boční vydutí
HLAVNÍHO tunelu (větší poloměr a boční posun řezů kolem dané Y), do kterých
se postaví jejich charakteristický obsah (jezírko, stalaktity, puklina,
obsidián) — princip "enkláva je jiná než chodba" zůstává, jen bez rizikové
ruční topologie zvlášť stavěné místnosti. Lávová "puklina" v E3 je pak
zjednodušená na stejný tvar jako jezírko (nepravidelný mnohoúhelník),
ne klikatou trhlinu.

Objekty: F_jeskyne_tunel, F_jeskyne_podlaha, F_lava_*, F_stalaktit_*,
F_stalagmit_*, F_kamen_*, F_obsidian, F_zaval_balvan_*, F_zaslepovaci_plocha,
X_helper_empty_ZaZavalem, X_helper_svetlo_*
"""

import bpy
import os
import sys
import types
import importlib
import math
from mathutils import Vector


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

PORTAL_Z = None   # dopočítá se v build_cave()

ENCLAVES = (
    dict(key="E1", y=164.0, side=-1.0, r=2.4, h=2.5, kind="jezirko"),
    dict(key="E2", y=171.0, side=1.0, r=1.9, h=7.0, kind="komin"),
    dict(key="E3", y=179.0, side=-1.0, r=3.2, h=4.0, kind="puklina"),
    dict(key="E4", y=187.0, side=1.0, r=1.6, h=3.0, kind="obsidian"),
)

COLLAPSE_Y = 196.0

PREFIXES = ("F_jeskyne", "F_lava", "F_stalaktit", "F_stalagmit", "F_kamen",
            "F_obsidian", "F_zaval", "F_zaslepovaci", "X_helper_empty_ZaZavalem",
            "X_helper_svetlo")


def _centerline_z(y):
    pts = C.CAVE_POINTS
    for (x0, y0, z0), (x1, y1, z1) in zip(pts, pts[1:]):
        lo, hi = min(y0, y1), max(y0, y1)
        if lo - 1e-6 <= y <= hi + 1e-6:
            t = 0.0 if abs(y1 - y0) < 1e-9 else (y - y0) / (y1 - y0)
            return PORTAL_Z + z0 + (z1 - z0) * t
    return PORTAL_Z + pts[-1][2]


def _resample_3d(points, step=2.0):
    out = [points[0]]
    for (x0, y0, z0), (x1, y1, z1) in zip(points, points[1:]):
        d = math.dist((x0, y0, z0), (x1, y1, z1))
        n = max(1, int(round(d / step)))
        for k in range(1, n + 1):
            t = k / n
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t))
    return out


def _enclave_bulge(y):
    x_off, extra_r, extra_h = 0.0, 0.0, 0.0
    for enc in ENCLAVES:
        span = enc["r"] * 2.0 + 1.0
        d = abs(y - enc["y"])
        if d < span:
            t = 1.0 - C.smoothstep(0.0, span, d)
            x_off += enc["side"] * enc["r"] * t
            extra_r += enc["r"] * t
            extra_h = max(extra_h, enc["h"] * t)
    return x_off, extra_r, extra_h


def _tunnel_ring(cx, cy, cz, nx, ny, radius, floor_z, ceil_h, n=8):
    verts = []
    for i in range(n):
        a = -math.pi / 2 + 2.0 * math.pi * i / n
        rr = radius * C.rng.uniform(0.85, 1.15)
        local_h, local_v = rr * math.cos(a), rr * math.sin(a)
        verts.append([cx + nx * local_h, cy + ny * local_h, cz + local_v])
    verts[0][2] = floor_z + C.rng.uniform(-0.10, 0.10)
    for j in (1, n - 1):
        verts[j][2] = verts[j][2] * 0.3 + floor_z * 0.7
    top_idx = n // 2
    lift = (floor_z + ceil_h) - verts[top_idx][2]
    for v in verts:
        if v[2] > cz:
            v[2] += lift
    return [tuple(v) for v in verts]


def _finalize_interior(obj):
    """Recalc dá normály ven (jako by šlo o plný váleček), pak je otočíme
    dovnitř — jeskyně je dutina, kamera je uvnitř."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def _build_tunnel(coll):
    pts3d = [(x, y, PORTAL_Z + z) for (x, y, z) in C.CAVE_POINTS]
    samples = _resample_3d(pts3d, step=2.0)
    rings = []
    centers = []
    for i, (cx, cy, cz) in enumerate(samples):
        if i == 0:
            tx, ty = samples[1][0] - cx, samples[1][1] - cy
        elif i == len(samples) - 1:
            tx, ty = cx - samples[i - 1][0], cy - samples[i - 1][1]
        else:
            tx, ty = samples[i + 1][0] - samples[i - 1][0], samples[i + 1][1] - samples[i - 1][1]
        length = math.hypot(tx, ty)
        tx, ty = (tx / length, ty / length) if length > 1e-6 else (0.0, 1.0)
        nx, ny = -ty, tx

        x_off, extra_r, extra_h = _enclave_bulge(cy)
        ring_cx, ring_cy = cx + nx * x_off, cy + ny * x_off
        base_r = C.rng.uniform(1.8, 3.2) + extra_r
        narrow = C.rng.random() < 0.12 and extra_r == 0.0
        ceil_h = (2.2 if narrow else C.rng.uniform(3.5, 5.0)) + extra_h
        floor_z = cz - base_r * 0.65
        rings.append(_tunnel_ring(ring_cx, ring_cy, cz, nx, ny, base_r, floor_z, ceil_h))
        centers.append((ring_cx, ring_cy, cz, floor_z, base_r))

    batch = C.Batch()
    n = 8
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            batch.add([a[k], a[j], b[j], b[k]], [(0, 1, 2, 3)])
    tunnel = batch.build("F_jeskyne_tunel", coll=coll, material=C.get_material("skala_jeskyne"))
    _finalize_interior(tunnel)
    return tunnel, centers


def _enclave_center(key):
    for enc in ENCLAVES:
        if enc["key"] == key:
            y = enc["y"]
            x = enc["side"] * enc["r"] * 0.9
            z = _centerline_z(y) - enc["r"] * 0.65 + 0.05
            return (x, y, z)
    return (0.0, 0.0, PORTAL_Z)


def _lava_lake(coll, name, cx, cy, cz, radius):
    n = C.rng.randint(8, 14)
    outer = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        rr = radius * C.rng.uniform(0.7, 1.15)
        outer.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz))
    lava_batch, krusta_batch = C.Batch(), C.Batch()
    for i in range(n):
        j = (i + 1) % n
        tri = [(cx, cy, cz), outer[i], outer[j]]
        (krusta_batch if C.rng.random() < 0.6 else lava_batch).add(tri, [(0, 1, 2)])
    objs = [lava_batch.build("%s_zar" % name, coll=coll, material=C.get_material("lava")),
           krusta_batch.build("%s_kura" % name, coll=coll, material=C.get_material("lava_kura"))]
    return [o for o in objs if o is not None]


def _build_lava(coll, helpers_coll):
    parts = []
    lights = []

    e1 = _enclave_center("E1")
    parts += _lava_lake(coll, "F_lava_jezirko_e1", e1[0], e1[1], e1[2] + 0.05, 0.9)
    lights.append(e1)

    x2, z2 = 0.0, _centerline_z(176.0) - 2.4 + 0.05
    parts += _lava_lake(coll, "F_lava_jezirko_hlavni", 2.5, 176.0, z2, 0.7)
    lights.append((2.5, 176.0, z2))

    e3 = _enclave_center("E3")
    parts += _lava_lake(coll, "F_lava_puklina_e3", e3[0], e3[1], e3[2] + 0.05, 1.1)
    lights.append(e3)

    slag_positions = []
    for i in range(C.rng.randint(6, 10)):
        y = C.rng.uniform(158.0, 194.0)
        cz = _centerline_z(y)
        x = C.rng.uniform(-1.2, 1.2)
        z = cz - 1.5
        r = C.rng.uniform(0.10, 0.30)
        parts += _lava_lake(coll, "F_lava_slitek_%02d" % i, x, y, z, r)
        slag_positions.append((x, y, z))

    light_specs = lights[:3] + slag_positions[:2]
    for i, (lx, ly, lz) in enumerate(light_specs[:5]):
        light_data = bpy.data.lights.get("X_helper_svetlo_lava_%02d" % i) or \
            bpy.data.lights.new("X_helper_svetlo_lava_%02d" % i, type="POINT")
        light_data.color = C.hex_to_linear("#FF6A18")
        light_data.energy = C.rng.uniform(300.0, 800.0)
        light_data.shadow_soft_size = 0.5
        lobj = bpy.data.objects.new("X_helper_svetlo_lava_%02d" % i, light_data)
        lobj.location = Vector((lx, ly, lz + 0.20))
        nc.place(lobj, helpers_coll)
        parts.append(lobj)

    return parts


def _build_details(coll):
    parts = []

    stone_protos = C.build_rock_prototypes("F_kamen", 5, (0.05, 0.25),
                                           C.get_material("kamen_balvan"), C.rng)
    n_stones = C.rng.randint(40, 60)
    for i in range(n_stones):
        y = C.rng.uniform(160.0, 194.0)
        cz = _centerline_z(y)
        x = C.rng.uniform(-2.2, 2.2)
        z = cz - 1.5
        proto = stone_protos[i % len(stone_protos)]
        parts.append(C.link_dup("F_kamen_%03d" % i, proto, (x, y, z),
                                rot_z=C.rng.uniform(0, 360), coll=coll))
    C.remove_prototypes(stone_protos)

    e2 = _enclave_center("E2")
    n_stalac = C.rng.randint(20, 30)
    for i in range(n_stalac):
        by = e2[1] if i < 10 else C.rng.uniform(158.0, 194.0)
        bx = e2[0] + C.rng.uniform(-1.2, 1.2) if i < 10 else C.rng.uniform(-1.8, 1.8)
        cz = _centerline_z(by) + (4.0 if i < 10 else C.rng.uniform(1.8, 3.0))
        length = C.rng.uniform(0.3, 1.5)
        r = C.rng.uniform(0.05, 0.175)
        # cone(r1, r2): r1 je konec na -Z (dole), r2 na +Z (nahoře).
        # Krápník visí ze stropu — dole hrot (0.0), nahoře napojení na strop (r).
        parts.append(nc.cone("F_stalaktit_%02d" % i, 0.0, r, length, verts=6, smooth_angle=0,
                             loc=(bx, by, cz - length * 0.5), coll=coll,
                             material=C.get_material("skala_jeskyne")))
    n_stalag = C.rng.randint(12, 18)
    for i in range(n_stalag):
        y = C.rng.uniform(158.0, 194.0)
        cz = _centerline_z(y) - 1.4
        x = C.rng.uniform(-1.8, 1.8)
        length = C.rng.uniform(0.3, 1.1)
        r = C.rng.uniform(0.05, 0.15)
        # krápník roste z podlahy — dole široká báze (r), nahoře hrot (0.0)
        parts.append(nc.cone("F_stalagmit_%02d" % i, r, 0.0, length, verts=6, smooth_angle=0,
                             loc=(x, y, cz + length * 0.5), coll=coll,
                             material=C.get_material("skala_jeskyne")))

    e4 = _enclave_center("E4")
    e4_sign = 1.0 if e4[0] >= 0.0 else -1.0
    obs = nc.box("F_obsidian", (1.2, 0.05, 1.6), loc=(e4[0] + e4_sign * 0.3, e4[1], e4[2] + 1.0),
                coll=coll, material=C.get_material("obsidian"))
    parts.append(obs)

    for i in range(3):
        y = C.rng.uniform(157.0, 159.5)
        cz = _centerline_z(y) - 1.3
        parts.append(C.ico("F_jeskyne_mech_%d" % i, C.rng.uniform(0.08, 0.15), subdiv=0,
                           loc=(C.rng.uniform(-1.5, 1.5), y, cz + 0.05), scale=(1.0, 1.0, 0.2),
                           coll=coll, material=C.get_material("mech")))

    return [p for p in parts if p is not None]


def _build_collapse(coll, parent_coll):
    zaval_coll = nc.collection("F_Zaval", parent_coll)
    behind_coll = nc.collection("F_ZaZavalem", parent_coll)
    behind_coll.hide_viewport = True
    behind_coll.hide_render = True

    cy = COLLAPSE_Y
    fz = _centerline_z(cy) - 1.3
    n = C.rng.randint(18, 26)
    cols = 5
    rows = math.ceil(n / cols)

    boulders = []
    idx = 0
    for r in range(rows):
        for c in range(cols):
            if idx >= n:
                break
            bx = -1.4 + c * (2.8 / max(1, cols - 1)) + C.rng.uniform(-0.15, 0.15)
            bz = fz + 0.3 + r * (2.3 / max(1, rows - 1)) + C.rng.uniform(-0.15, 0.15)
            by = cy + C.rng.uniform(-0.3, 0.3)
            radius = C.rng.uniform(0.25, 0.9)
            obj = C.ico("F_zaval_balvan_%02d" % (idx + 1), radius, subdiv=1, loc=(bx, by, bz),
                       scale=(C.rng.uniform(0.8, 1.2), C.rng.uniform(0.8, 1.2), C.rng.uniform(0.7, 1.0)),
                       coll=zaval_coll, material=C.get_material("kamen_balvan"))
            C.jitter_verts(obj, radius * 0.15, C.rng)
            centroid_local = sum((v.co for v in obj.data.vertices), Vector((0.0, 0.0, 0.0)))
            centroid_local /= len(obj.data.vertices)
            nc.set_origin(obj, obj.matrix_world @ centroid_local)
            boulders.append(obj)
            idx += 1

    gaps = []
    for i in range(C.rng.randint(2, 3)):
        gx = C.rng.uniform(-1.0, 1.0)
        gz = fz + C.rng.uniform(0.5, 2.0)
        gap = nc.box("F_zaval_skvira_%d" % i, (0.10, 0.03, 0.20), loc=(gx, cy - 0.1, gz),
                    coll=zaval_coll, material=C.get_material("svetlo_zaval"))
        gaps.append(gap)

    empty = bpy.data.objects.new("X_helper_empty_ZaZavalem", None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.4
    empty.location = Vector((0.0, 199.0, fz))
    nc.place(empty, behind_coll)

    seal = nc.box("F_zaslepovaci_plocha", (4.0, 0.05, 3.5), loc=(0.0, 199.5, fz + 1.75),
                  coll=behind_coll, material=C.get_material("zaslepovaci_plocha"))

    return boulders + gaps + [empty, seal]


def build_cave(coll=None):
    global PORTAL_Z
    nc.prepare()
    nc.purge(PREFIXES, collections=("F_Jeskyne", "F_Zaval", "F_ZaZavalem"))

    PORTAL_Z = C.height(*C.CAVE_PORTAL)

    root = coll if coll is not None else nc.collection("Krajina")
    own_coll = nc.collection("F_Jeskyne", root)
    helpers_coll = nc.collection("X_Helpers", root)

    tunnel, centers = _build_tunnel(own_coll)
    parts = [tunnel]
    parts += _build_lava(own_coll, helpers_coll)
    parts += _build_details(own_coll)
    parts += _build_collapse(own_coll, own_coll)

    tris = C.triangle_count([p for p in parts if p is not None and p.type == "MESH"])
    print("[NCR] jeskyne: %d objektu, %d trojuhelniku" % (len(parts), tris))
    return parts


if __name__ == "__main__":
    build_cave()
