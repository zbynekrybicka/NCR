# -*- coding: utf-8 -*-
"""
Krajina — sdílená knihovna specifická pro sekci "Cesta robotů".

Tohle NENÍ skript ke spuštění. Importují si ho jednotlivé sekce (`NN_*.py`)
a `build_krajina.py`. Na rozdíl od `blender/common/ncr_common.py` (roboti,
jedna buňka mřížky, rámec `fwd/right/up`) pracuje krajina přímo ve světových
souřadnicích metrů — viz `docs/zadani_krajina_lowpoly_bpy.md` kap. 1.

Obsahuje:
  * `SEED` / `rng` — jediný zdroj náhody pro celou krajinu (determinismus)
  * `MATERIALS` + `get_material()` — materiálová paleta (kap. 2)
  * `height()` / `snap_to_ground()` — analytický terén (kap. 3)
  * `terrain_zone()` — materiálová zóna terénu podle polohy/výšky
  * hash-based value noise (bez numpy, pořadí-nezávislý)
  * `scatter()`, `link_dup()`, `jitter_verts()`, `new_mesh_object()`, `Batch`
  * `PATH_POINTS`, `CREEK_POINTS`, `CAVE_POINTS` — sdílené trasy (kap. 4/6.3/10.1)
  * `nc` — reexport `ncr_common` (loader shodný s roboty, viz `_ncr_import`)
"""

import bpy
import os
import sys
import types
import importlib
import math
import random
from math import radians
from mathutils import Vector, Matrix


# ---------------------------------------------------------------------------
# Loader (shodný vzor jako `build_han.py` — funguje z Text Editoru i CLI)
# ---------------------------------------------------------------------------

def _ncr_import(module_name):
    """Načte modul ze složky `blender/krajina` nebo ze sousední `blender/common`."""
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
            "blender/krajina i z blender/common, ať k sobě navzájem vidí." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")   # primitiva box/cyl/cone/sphere/..., prepare/collection/place/purge


# ---------------------------------------------------------------------------
# Determinismus (kap. 1.3 bod 1)
# ---------------------------------------------------------------------------

SEED = 12345
rng = random.Random(SEED)


# ---------------------------------------------------------------------------
# Matematické pomůcky
# ---------------------------------------------------------------------------

def clamp(x, lo=0.0, hi=1.0):
    return lo if x < lo else hi if x > hi else x


def smoothstep(edge0, edge1, x):
    if edge0 == edge1:
        return 0.0 if x < edge0 else 1.0
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def dist_point_segment(px, py, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    length2 = dx * dx + dy * dy
    if length2 < 1e-9:
        t = 0.0
    else:
        t = clamp(((px - x0) * dx + (py - y0) * dy) / length2)
    cx, cy = x0 + t * dx, y0 + t * dy
    return math.hypot(px - cx, py - cy)


def dist_to_polyline(x, y, points):
    best = float("inf")
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        best = min(best, dist_point_segment(x, y, x0, y0, x1, y1))
    return best


def _catmull_rom_point(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
               + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
               + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
    y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
               + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
               + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
    return (x, y)


def resample_polyline(points, step=2.0):
    """Catmull-Rom přes zadané body (kap. 4), vrátí hustší polyline (krok ~`step` m)."""
    points = list(points)
    if len(points) < 2:
        return points
    pts = [points[0]] + points + [points[-1]]
    out = [points[0]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        seg_len = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
        n = max(1, int(round(seg_len / step)))
        for k in range(1, n + 1):
            out.append(_catmull_rom_point(p0, p1, p2, p3, k / n))
    return out


# ---------------------------------------------------------------------------
# Hash-based value noise — deterministický podle (x, y, seed), NE podle
# volání `rng`: `height()`/`terrain_zone()` se volají tisíckrát na terénu
# v pořadí, které závisí na iteraci mřížky, a `random.Random` by tak dávalo
# jinou hodnotu podle toho, odkud se zavolá dřív. Hash lattice je nezávislý
# na pořadí volání, závisí jen na souřadnicích.
# ---------------------------------------------------------------------------

def _hash01(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 2147483647) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    n = (n ^ (n >> 16)) & 0xffffffff
    return n / 4294967295.0


def value_noise(x, y, scale=1.0, seed=0):
    """Bilinear-interpolovaný hash noise s smoothstep, vrací 0..1."""
    xs, ys = x / scale, y / scale
    x0, y0 = math.floor(xs), math.floor(ys)
    x1, y1 = x0 + 1, y0 + 1
    tx = smoothstep(0.0, 1.0, xs - x0)
    ty = smoothstep(0.0, 1.0, ys - y0)
    v00 = _hash01(x0, y0, seed)
    v10 = _hash01(x1, y0, seed)
    v01 = _hash01(x0, y1, seed)
    v11 = _hash01(x1, y1, seed)
    a = v00 + (v10 - v00) * tx
    b = v01 + (v11 - v01) * tx
    return a + (b - a) * ty


def _zone_jitter(x, y, seed, amp=2.0, scale=9.0):
    """Prostorový jitter pro "zubaté" hranice materiálových zón (kap. 3)."""
    return (value_noise(x, y, scale=scale, seed=seed) * 2.0 - 1.0) * amp


# ---------------------------------------------------------------------------
# Sdílené trasy (kap. 4, 6.3, 10.1) — patří sem, protože je používá víc sekcí
# ---------------------------------------------------------------------------

PATH_POINTS = [
    (0.0, 0.0), (0.0, 21.0), (0.5, 30.0), (-0.5, 46.0),
    (0.0, 60.0), (0.8, 72.0), (-1.5, 88.0), (0.5, 104.0),
    (0.0, 116.0), (2.0, 130.0), (-3.0, 142.0), (2.5, 150.0), (0.0, 156.0),
]

CREEK_POINTS = [
    (22.0, 52.0), (16.0, 50.5), (11.0, 49.0), (6.0, 48.0), (0.0, 46.0),
    (-6.0, 45.5), (-13.0, 45.0), (-20.0, 44.5), (-25.5, 44.0),
]

# (x, y, z relativně k úrovni portálu) — kap. 10.1
CAVE_POINTS = [
    (0.0, 156.0, 0.0), (1.5, 162.0, -0.4), (-1.0, 168.0, -1.0),
    (0.5, 174.0, -1.2), (2.0, 182.0, -0.8), (0.0, 190.0, -0.5),
    (0.0, 198.0, -0.5),
]

TERRAIN_BOUNDS = (-45.0, -10.0, 35.0, 185.0)   # x0, y0, x1, y1 — kap. 3

CAVE_PORTAL = (0.0, 156.0)          # kap. 9.5 / 10
CAVE_PORTAL_SIZE = (4.0, 3.0)       # otvor v terénu (x šířka, y hloubka) — kap. 10 hlavička
CAVE_PORTAL_HOLE = True             # terén otvor dělá vždycky, jeskyně se staví později (viz README)


# ---------------------------------------------------------------------------
# Terén — analytická výška (kap. 3) + zóny
# ---------------------------------------------------------------------------

POND_CENTER = (-28.0, 44.0)          # kap. 6.2 / 7.1
POND_RX = 11.0                       # poloosa X (elipsa 22 m)
POND_RY_SOUTH = 9.5                  # poloosa k -Y: mělký, pozvolný břeh
POND_RY_NORTH = 6.0                  # poloosa k +Y: strmý břeh
POND_DEPTH = 1.3

CREEK_EDGE_WIDTH = 0.35              # půlšířka koryta na hraně (0.7 m/2)
CREEK_BOTTOM_HALF = 0.15             # půlšířka dna (0.3 m/2)
CREEK_DEPTH = 0.18

MOUNTAIN_AXIS = (0.0, 178.0)         # kap. 9.1


def _pond_offset(x, y):
    dx = (x - POND_CENTER[0]) / POND_RX
    dy_raw = y - POND_CENTER[1]
    ry = POND_RY_SOUTH if dy_raw < 0.0 else POND_RY_NORTH
    dy = dy_raw / ry
    r2 = dx * dx + dy * dy
    if r2 >= 1.0:
        return 0.0
    return -POND_DEPTH * (1.0 - r2) ** 1.4


def _creek_offset(x, y):
    d = dist_to_polyline(x, y, CREEK_POINTS)
    if d >= CREEK_EDGE_WIDTH:
        return 0.0
    if d <= CREEK_BOTTOM_HALF:
        return -CREEK_DEPTH
    t = (d - CREEK_BOTTOM_HALF) / (CREEK_EDGE_WIDTH - CREEK_BOTTOM_HALF)
    return -CREEK_DEPTH * (1.0 - smoothstep(0.0, 1.0, t))


def _mountain_offset(y):
    """Kužel hory (kap. 9.1): pozvolna u paty, strmě uprostřed, skalní stěna
    nahoře. `smoothstep` sám o sobě dává zvon (nejstrmější uprostřed) — mocnina
    > 1 posune nejstrmější úsek k vršku, což odpovídá "gentle/steep/cliff"."""
    t = clamp((y - 112.0) / (172.0 - 112.0))
    t_eased = t ** 1.6
    return 42.0 * t_eased


def height(x, y):
    z = 0.0
    # B) louka — příčný sklon (vrstevnice ve směru Y), viz kap. 3 pseudokód
    if y >= 21.0:
        z += 0.08 * x * smoothstep(21.0, 26.0, y)
    # C) mírné stoupání k lesu
    z += lerp(0.0, 4.0, smoothstep(70.0, 112.0, y))
    # D) hora
    z += _mountain_offset(y)
    # nízkofrekvenční zvlnění hory (kap. 9.1), fade-in před Y=112 ať nejde o skok
    wobble_t = smoothstep(100.0, 130.0, y)
    if wobble_t > 0.0:
        z += wobble_t * 2.5 * (value_noise(x, y, scale=20.0, seed=2) * 2.0 - 1.0)
    # E) mísa rybníka
    z += _pond_offset(x, y)
    # F) koryto potoka
    z += _creek_offset(x, y)
    # G) mikrošum
    z += (value_noise(x, y, scale=6.0, seed=3) * 2.0 - 1.0) * 0.12
    return z


def snap_to_ground(x, y):
    """Stejná analytická funkce jako terén — žádný raycast (kap. 1.3 bod 7)."""
    return height(x, y)


def terrain_zone(x, y, z):
    """Materiálová zóna terénu podle polohy/výšky, s jitterem ±2 m (kap. 3, 8.1, 9.2)."""
    # břeh rybníka — blízko elipsy, ale nízko (ne pod hladinou uprostřed lesa/hory)
    dx = (x - POND_CENTER[0]) / (POND_RX + 1.5)
    dy_raw = y - POND_CENTER[1]
    ry = (POND_RY_SOUTH if dy_raw < 0.0 else POND_RY_NORTH) + 1.5
    dy = dy_raw / ry
    if dx * dx + dy * dy < 1.0 and z < 0.05:
        return "hlina_holy"

    garden_edge = 21.0 + _zone_jitter(x, y, 10, 2.0)
    if y < garden_edge:
        return "trava_zahrada"

    forest_center = 72.0 + _zone_jitter(x, y, 11, 4.0)   # kap. 8.1: y > 68 + rng(0,8)
    mountain_start = 110.0 + _zone_jitter(x, y, 12, 2.0)

    if y < mountain_start:
        return "jehlici_zeme" if y > forest_center else "trava_louka"

    # hora — výškové zóny (kap. 9.2), hranice s jitterem ±2 m
    j = _zone_jitter(x, y, 13, 2.0)
    if z < 12.0 + j:
        return "jehlici_zeme"
    if z < 25.0 + j:
        return "trava_ridka"
    if z < 28.0 + j:
        return "kamen_balvan"
    return "kamen_skala"


# ---------------------------------------------------------------------------
# Materiálová paleta (kap. 2)
# ---------------------------------------------------------------------------

MATERIALS = {
    "trava_zahrada":  dict(color="#6FA83C"),
    "trava_louka":    dict(color="#7FB84A"),
    "trava_ridka":    dict(color="#8B9A5B"),
    "hlina_cesta":    dict(color="#9A7A53"),
    "hlina_holy":     dict(color="#6B5539"),
    "kamen_dlazba":   dict(color="#9C9891"),
    "kamen_skala":    dict(color="#7D7A76"),
    "kamen_balvan":   dict(color="#8A8681"),
    "mech":           dict(color="#5C7A3E", roughness=0.95),
    "drevo_plot":     dict(color="#A87C4E"),
    "drevo_tmave":    dict(color="#6E4E2E"),
    "drevo_kmen":     dict(color="#5A4632"),
    "beton":          dict(color="#B4B0A6"),
    "guma_hadice":    dict(color="#3E6B4C", roughness=0.5),
    "kov":            dict(color="#8C8F94", metallic=0.9, roughness=0.35),
    "omitka_dum":     dict(color="#E4D9C3"),
    "strecha":        dict(color="#A8443A"),
    "jehlici_zeme":   dict(color="#7A5B3A"),
    "jehlici_zelen":  dict(color="#3F6B3A"),
    "listi_tmave":    dict(color="#3E7A46"),
    "listi_svetle":   dict(color="#5FA05A"),
    "voda_rybnik":    dict(color="#3D7A8C", alpha=0.75, roughness=0.08, transmission=0.3),
    "voda_potok":     dict(color="#5AA0AE", alpha=0.7, roughness=0.05),
    "lekniny":        dict(color="#4A8A4E"),
    "rakos":          dict(color="#96A54C"),
    "kvet_cervena":   dict(color="#E24A4A"),
    "kvet_zluta":     dict(color="#F2C230"),
    "kvet_ruzova":    dict(color="#E27ACF"),
    "kvet_bila":      dict(color="#F0F0F0"),
    "kvet_fialova":   dict(color="#7A6FE0"),
    "plody":          dict(color="#B9243C"),
    "lava":           dict(color="#FF5A0A", emission_color="#FF7A1A", emission_strength=8.0),
    "lava_kura":      dict(color="#3A1E14", emission_strength=0.4),
    "skala_jeskyne":  dict(color="#4A4340"),
    "rakos_palice":   dict(color="#7A5030"),      # kap. 7.3 — hnědá palice rákosu
    "sena":           dict(color="#C9A94E"),      # kap. 6.4 — kupky sena
    "houba_hneda":    dict(color="#7A5A3A"),      # kap. 8.4
    "houba_cervena":  dict(color="#C8302A"),      # kap. 8.4
    "obsidian":       dict(color="#0A0A0C", roughness=0.15),          # kap. 10.2 E4
    "svetlo_zaval":   dict(color="#FFF3D0", emission_color="#FFF3D0", emission_strength=1.5),
    "zaslepovaci_plocha": dict(color="#FFF3D0", emission_color="#FFF3D0", emission_strength=2.5),
    "rez":            dict(color="#7A4A28", metallic=0.6, roughness=0.6),   # kap. 6.4 rezavý drát
    "sklo":           dict(color="#8C8F94", metallic=0.9, roughness=0.1),   # kap. 5.1 okenní sklo
    "interier_tma":   dict(color="#0D0D0D", roughness=0.95),   # tmavá deska za okny domu
    "drevo_suchy":    dict(color="#6B5F4A"),   # kap. 8.2 suché/holé stromy
    "lava_portal":    dict(color="#FF5A0A", emission_color="#FF7A1A", emission_strength=3.0),
    "lava_odlesk":    dict(color="#FF5A0A", emission_color="#FF7A1A", emission_strength=0.8),
}

KVET_KEYS = ("kvet_cervena", "kvet_zluta", "kvet_ruzova", "kvet_bila", "kvet_fialova")


def hex_to_linear(hex_str):
    hex_str = hex_str.lstrip("#")
    r, g, b = (int(hex_str[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

    def to_linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return tuple(to_linear(c) for c in (r, g, b))


def get_material(key):
    """Materiál z `MATERIALS`, recyklovaný podle jména (kap. 1.3 bod 8)."""
    name = "KRAJ_%s" % key
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing

    spec = MATERIALS[key]
    color = hex_to_linear(spec["color"])
    alpha = spec.get("alpha", 1.0)

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], alpha)
    bsdf.inputs["Roughness"].default_value = spec.get("roughness", 0.85)
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    for spec_name in ("Specular IOR Level", "Specular"):   # 4.x přejmenovalo vstup
        if spec_name in bsdf.inputs:
            bsdf.inputs[spec_name].default_value = 0.2
            break

    transmission = spec.get("transmission", 0.0)
    if transmission > 0.0:
        for tname in ("Transmission Weight", "Transmission"):
            if tname in bsdf.inputs:
                bsdf.inputs[tname].default_value = transmission

    if "emission_color" in spec:
        ecolor = hex_to_linear(spec["emission_color"])
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (ecolor[0], ecolor[1], ecolor[2], 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = spec.get("emission_strength", 1.0)

    if alpha < 1.0 or transmission > 0.0:
        material.blend_method = "BLEND"

    material.diffuse_color = (color[0], color[1], color[2], alpha)   # viewport solid mode
    return material


# ---------------------------------------------------------------------------
# Rozptyl bodů (kap. 12) — Poisson-like rejection sampling se spatial hashem,
# aby to bylo použitelné i pro tisíce bodů (luční tráva) v rozumném čase.
# ---------------------------------------------------------------------------

def scatter(bounds, density_per_m2, min_dist, rng_, exclude_fn=None, max_factor=25):
    x0, y0, x1, y1 = bounds
    w, h = max(0.0, x1 - x0), max(0.0, y1 - y0)
    target = int(w * h * density_per_m2)
    if target <= 0 or min_dist <= 0:
        return []

    cell = min_dist
    grid = {}

    def key(x, y):
        return (int((x - x0) // cell), int((y - y0) // cell))

    def far_enough(x, y):
        gx, gy = key(x, y)
        for ix in range(gx - 1, gx + 2):
            for iy in range(gy - 1, gy + 2):
                for (px, py) in grid.get((ix, iy), ()):
                    if (px - x) ** 2 + (py - y) ** 2 < min_dist * min_dist:
                        return False
        return True

    points = []
    tries = 0
    max_tries = target * max_factor
    while len(points) < target and tries < max_tries:
        tries += 1
        x = rng_.uniform(x0, x1)
        y = rng_.uniform(y0, y1)
        if exclude_fn is not None and exclude_fn(x, y):
            continue
        if not far_enough(x, y):
            continue
        points.append((x, y))
        grid.setdefault(key(x, y), []).append((x, y))
    return points


def cluster_scatter(bounds, count, cluster_size_range, cluster_count, spread, rng_, exclude_fn=None):
    """Ostrůvkovité rozložení (kap. 6.2 — luční květiny): `cluster_count` náhodných
    center, kolem každého `cluster_size_range` bodů v poloměru `spread`."""
    x0, y0, x1, y1 = bounds
    points = []
    centers = [(rng_.uniform(x0, x1), rng_.uniform(y0, y1)) for _ in range(cluster_count)]
    tries = 0
    max_tries = count * 40
    while len(points) < count and tries < max_tries:
        tries += 1
        cx, cy = centers[rng_.randrange(len(centers))]
        x = cx + rng_.uniform(-spread, spread)
        y = cy + rng_.uniform(-spread, spread)
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            continue
        if exclude_fn is not None and exclude_fn(x, y):
            continue
        points.append((x, y))
    return points


# ---------------------------------------------------------------------------
# Geometrie
# ---------------------------------------------------------------------------

def new_mesh_object(name, verts, faces, coll=None, material=None):
    """Tenký wrapper nad `bpy.data.meshes.new()` + `from_pydata()`."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    for poly in mesh.polygons:
        poly.use_smooth = False   # explicitně flat (kap. 1 — žádné smooth normály)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    nc.place(obj, coll)
    if material is not None:
        nc.set_material(obj, material)
    return obj


class Batch(object):
    """Sběrač vrcholů/ploch pro spoustu malých prvků (dlažba, jehličí, kameny
    obruby...) do JEDNOHO mesh objektu — žádné `bpy.ops` v cyklu (kap. 1.3 bod 3)."""

    def __init__(self):
        self.verts = []
        self.faces = []

    def add(self, verts, faces):
        offset = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(i + offset for i in f) for f in faces)

    def add_object_mesh(self, mesh, matrix):
        """Přidá (a smaže) existující mesh data transformovaná maticí — pro
        skládání z primitiv postavených přes `nc.box/cyl/...`."""
        offset = len(self.verts)
        self.verts.extend(tuple(matrix @ v.co) for v in mesh.vertices)
        self.faces.extend(tuple(i + offset for i in p.vertices) for p in mesh.polygons)

    def build(self, name, coll=None, material=None):
        if not self.faces:
            return None
        return new_mesh_object(name, self.verts, self.faces, coll=coll, material=material)


def merge_into_batch(batch, obj):
    """Přesune geometrii dočasného objektu (postaveného přes `nc.box/cyl/...`)
    do dávky a objekt i jeho mesh smaže — používá se, když prototyp jednoho
    prvku vznikl pohodlně přes primitiva, ale finální výsledek má být jedna
    dávková mesh, ne stovky samostatných objektů."""
    obj.data.update()
    batch.add_object_mesh(obj.data, obj.matrix_basis.copy())
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def link_dup(name, proto_obj, loc, rot_z=0.0, scale=1.0, coll=None):
    """Linked duplicate — sdílená mesh data, vlastní transform (kap. 1.3 bod 4)."""
    obj = bpy.data.objects.new(name, proto_obj.data)
    obj.location = Vector(loc)
    if isinstance(scale, (int, float)):
        obj.scale = (scale, scale, scale)
    else:
        obj.scale = Vector(scale)
    obj.rotation_euler = (0.0, 0.0, radians(rot_z))
    nc.place(obj, coll)
    return obj


def set_material_override(obj, material):
    """Materiál jen pro TENTO objekt, ne pro sdílená mesh data. `nc.set_material`
    píše do `obj.data.materials`, a `link_dup` instance sdílejí `.data` —
    volání na jedné instanci by tak přebarvilo úplně všechny (např. jeden
    "suchý" strom by odbarvil celý les). Přepne slot na OBJECT-link."""
    if not obj.data.materials:
        obj.data.materials.append(material)
        return obj
    slot = obj.material_slots[0]
    slot.link = "OBJECT"
    slot.material = material
    return obj


def jitter_verts(obj, amount, rng_):
    for v in obj.data.vertices:
        v.co.x += rng_.uniform(-amount, amount)
        v.co.y += rng_.uniform(-amount, amount)
        v.co.z += rng_.uniform(-amount, amount)
    obj.data.update()


def ico(name, r, subdiv=1, loc=(0, 0, 0), scale=(1, 1, 1), rot_z=0.0,
        coll=None, material=None):
    """Ico-koule — `ncr_common` má jen UV `sphere()`, krajina potřebuje často
    hranatější ico tvar (koruny, keře, balvany)."""
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=subdiv, location=(0, 0, 0))
    obj = bpy.context.object
    obj.data.transform(Matrix.Diagonal(Vector((scale[0], scale[1], scale[2], 1.0))))
    obj.rotation_euler = (0.0, 0.0, radians(rot_z))
    obj.location = Vector(loc)
    obj.name = name
    obj.data.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = False
    nc.place(obj, coll)
    if material is not None:
        nc.set_material(obj, material)
    return obj


def box_verts(cx, cy, cz, sx, sy, sz, rot_z=0.0, rot_x=0.0):
    """Vrátí (verts, faces) kvádru se středem (cx,cy,cz) — pro dávkovou
    geometrii (plaňky, prkna, jehličí...), bez `bpy.ops`."""
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    local = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
             (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    crz, srz = math.cos(radians(rot_z)), math.sin(radians(rot_z))
    crx, srx = math.cos(radians(rot_x)), math.sin(radians(rot_x))
    out = []
    for (x, y, z) in local:
        if rot_x:
            y, z = y * crx - z * srx, y * srx + z * crx
        if rot_z:
            x, y = x * crz - y * srz, x * srz + y * crz
        out.append((cx + x, cy + y, cz + z))
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return out, faces


def blade_verts(cx, cy, cz, height, width, bend=0.02, rot_z=0.0):
    """Úzký zužující se pás o 3 trojúhelnících (kap. 5.3/6.2) — tráva, stébla
    rákosu, stonky květin. Mírně se ohýbá ve směru `bend` (lokální +Y)."""
    a = radians(rot_z)
    ca, sa = math.cos(a), math.sin(a)

    def rot(lx, ly):
        return (cx + lx * ca - ly * sa, cy + lx * sa + ly * ca)

    b_l, b_r = rot(-width * 0.5, 0.0), rot(width * 0.5, 0.0)
    mid_h = height * 0.55
    m_l, m_r = rot(-width * 0.25, bend * 0.5), rot(width * 0.25, bend * 0.5)
    tip = rot(0.0, bend)
    verts = [(b_l[0], b_l[1], cz), (b_r[0], b_r[1], cz),
             (m_l[0], m_l[1], cz + mid_h), (m_r[0], m_r[1], cz + mid_h),
             (tip[0], tip[1], cz + height)]
    faces = [(0, 1, 3), (0, 3, 2), (2, 3, 4)]
    return verts, faces


def disc_verts(cx, cy, cz, radius, sides, rot_z=0.0):
    """Plochý n-úhelník (víčko pařezu, okvětní disk, list leknínu...)."""
    a0 = radians(rot_z)
    verts = [(cx, cy, cz)]
    for i in range(sides):
        a = a0 + 2.0 * math.pi * i / sides
        verts.append((cx + radius * math.cos(a), cy + radius * math.sin(a), cz))
    faces = [(0, 1 + i, 1 + (i + 1) % sides) for i in range(sides)]
    return verts, faces


def build_clump_prototypes(name_prefix, count, blade_range, height_range, width_range,
                            material, rng_, bend_range=(0.01, 0.05)):
    """N prototypů travního/rákosového trsu — pár blade_verts() svázaných
    kolem počátku (kap. 1.3 bod 4: 3-5 prototypů, varianty se dělají rotací
    a scale při scatteru, ne novou geometrií)."""
    protos = []
    for i in range(count):
        batch = Batch()
        for _ in range(rng_.randint(*blade_range)):
            bx, by = rng_.uniform(-0.05, 0.05), rng_.uniform(-0.05, 0.05)
            v, f = blade_verts(bx, by, 0.0, rng_.uniform(*height_range),
                               rng_.uniform(*width_range), bend=rng_.uniform(*bend_range),
                               rot_z=rng_.uniform(0.0, 360.0))
            batch.add(v, f)
        proto = batch.build("%s_proto_%d" % (name_prefix, i), material=material)
        if proto is not None:
            protos.append(proto)
    return protos


def scatter_instances(name_prefix, points, prototypes, coll, rng_, rot_random=True,
                       scale_range=(0.85, 1.15), z_fn=None, start_index=0):
    """Rozsází linked duplicates prototypů na dané body (kap. 1.3 bod 4)."""
    objs = []
    if not prototypes:
        return objs
    for i, (x, y) in enumerate(points):
        proto = prototypes[rng_.randrange(len(prototypes))]
        z = z_fn(x, y) if z_fn is not None else 0.0
        rot_z = rng_.uniform(0.0, 360.0) if rot_random else 0.0
        s = rng_.uniform(*scale_range) if scale_range else 1.0
        obj = link_dup("%s_%04d" % (name_prefix, start_index + i), proto, (x, y, z),
                       rot_z=rot_z, scale=s, coll=coll)
        objs.append(obj)
    return objs


def build_rock_prototypes(name_prefix, count, radius_range, material, rng_,
                          jitter_frac=0.18, subdiv=0):
    """N nepravidelných kamenů (ico-koule + jitter vrcholů, nerovnoměrný scale)
    jako prototypy pro `scatter_instances`/`link_dup` — používá se pro veškeré
    volné kameny v krajině (obruby, koryto, suťové pole, zával...).

    `subdiv=0` (výchozí, 20 trojúhelníků/kámen) je pro davové rozptýlení
    (desítky až stovky kusů); `subdiv=1` (80 tri) jen pro pár velkých
    samostatných balvanů, kde se to na rozpočtu neprojeví."""
    protos = []
    for i in range(count):
        r = rng_.uniform(*radius_range)
        obj = ico("%s_proto_%d" % (name_prefix, i), r, subdiv=subdiv,
                  scale=(rng_.uniform(0.7, 1.3), rng_.uniform(0.7, 1.3), rng_.uniform(0.5, 0.9)),
                  material=material)
        jitter_verts(obj, r * jitter_frac, rng_)
        protos.append(obj)
    return protos


def remove_prototypes(prototypes):
    for p in prototypes:
        if p is not None:
            bpy.data.objects.remove(p, do_unlink=True)


def triangle_count(objects):
    total = 0
    for o in objects:
        if o is not None and o.type == "MESH":
            total += sum(max(0, len(poly.vertices) - 2) for poly in o.data.polygons)
    return total


def force_flat(obj):
    """`nc.limb()` s poloměrem (studniční hadice, lano, vzpěry, ...) si samo
    přepíše i explicitní `smooth_angle=0` na 30° (`smooth_angle or 30` v
    ncr_common), a Blender 4.1+ přidá k tomu navíc modifier "Smooth by
    Angle". Kap. 2 chce flat shading bez výjimky, takže se to tu dorovnává
    plošně, místo aby se to hlídalo na každém volacím místě zvlášť."""
    if obj is None or obj.type != "MESH":
        return obj
    for poly in obj.data.polygons:
        poly.use_smooth = False
    mod = obj.modifiers.get("Smooth by Angle")
    if mod is not None:
        obj.modifiers.remove(mod)
    return obj


def force_flat_all(objects):
    for o in objects:
        force_flat(o)
    return objects
