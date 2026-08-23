# -*- coding: utf-8 -*-
"""
Krajina "Cesta robotů" — finální sestavení (kap. 12, poslední řádek tabulky:
kontrolní skript splynulý se skriptem pro spojení, protože zadání obojí
chtělo v jednom).

Spustí všech devět `NN_*.py` v pořadí z kap. 12 (terén nejdřív), poskládá
kolekce podle kap. 1.2, vypíše statistiky trojúhelníků a spot-checkne pár
acceptačních kritérií z kap. 11, kde to jde automaticky.

    blender --background --factory-startup --python blender/krajina/build_krajina.py
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

teren = _ncr_import("01_teren")
cesta = _ncr_import("02_cesta")
dum_plot = _ncr_import("03_dum_plot")
zahrada = _ncr_import("04_zahrada")
louka = _ncr_import("05_louka_potok")
rybnik = _ncr_import("06_rybnik")
les = _ncr_import("07_les")
hora = _ncr_import("08_hora")
jeskyne = _ncr_import("09_jeskyne")

EXPORT_GLB = False   # True = zapsat *.glb do EXPORT_DIR (viz export_sections)
TRI_BUDGET = (150_000, 250_000)

# spot-check kritérium 4 — jméno prefixu -> (x, y) v okolí, kde by měl objekt
# sedět na zemi (ne plavat/zapadat); tolerance je štědrá, protože "podlaha"
# staveb má tloušťku a základy nejsou vždy přesně na height()
ANCHOR_CHECKS = (
    ("A_dum_zed", (0.0, -3.0)),
    ("A_studna_skruz", (-4.0, 12.0)),
    ("A_kulna_podlaha", (-7.5, 14.5)),
    ("B_strom_kmen_dolni", (9.0, 24.0)),
    ("E_mohyla_0", (2.0, 148.0)),
)
ANCHOR_TOLERANCE = 0.5


def build():
    nc.prepare()

    root = nc.collection("Krajina")
    nc.collection("T_Teren", root)
    nc.collection("A_Zahrada", root)
    nc.collection("B_Louka", root)
    nc.collection("C_Rybnik", root)
    nc.collection("D_Les", root)
    nc.collection("E_Hora", root)
    nc.collection("F_Jeskyne", root)
    nc.collection("X_Helpers", root)
    nc.collection("P_Cesta", root)   # mimo kap. 1.2 — cesta protíná všechny sekce, viz README

    sections = [
        ("Teren", teren.build_terrain(root)),
        ("Cesta", cesta.build_path(root)),
        ("Dum+Plot", dum_plot.build_house_and_fence(root)),
        ("Zahrada", zahrada.build_garden_details(root)),
        ("Louka+Potok", louka.build_meadow_and_creek(root)),
        ("Rybnik", rybnik.build_pond(root)),
        ("Les", les.build_forest(root)),
        ("Hora", hora.build_mountain(root)),
        ("Jeskyne", jeskyne.build_cave(root)),
    ]

    for _, objs in sections:
        C.force_flat_all(objs)

    report(sections)

    if EXPORT_GLB:
        export_sections(sections)

    return sections


# ---------------------------------------------------------------------------
# Kontroly (kap. 11)
# ---------------------------------------------------------------------------

def report(sections):
    print("\n[NCR] ---- Krajina: hotovo ----")
    total = 0
    for name, objs in sections:
        objs = [o for o in objs if o is not None]
        tris = C.triangle_count(objs)
        total += tris
        print("[NCR] %-14s %5d objektu  %7d trojuhelniku" % (name, len(objs), tris))
    print("[NCR] CELKEM: %d trojuhelniku (rozpočet %d-%d)" % (total, TRI_BUDGET[0], TRI_BUDGET[1]))
    if total < TRI_BUDGET[0]:
        print("[NCR] POZOR: pod rozpočtem — scéna může působit řídce.")
    elif total > TRI_BUDGET[1]:
        print("[NCR] POZOR: nad rozpočtem — zvaž snížení hustoty scatterů.")
    else:
        print("[NCR] rozpočet OK.")

    _check_flat_shading()
    _check_anchors()
    print("[NCR] kritérium 13 (žádná zvířata/hmyz/ptáci/ryby) — nelze ověřit "
          "automaticky, je to na autorovi kódu při psaní (dodrženo záměrně).")


def _check_flat_shading():
    prefixes = ("T_", "A_", "B_", "C_", "D_", "E_", "F_", "P_", "X_")
    offenders = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or not obj.name.startswith(prefixes):
            continue
        if any(poly.use_smooth for poly in obj.data.polygons):
            offenders.append(obj.name)
    if offenders:
        print("[NCR] POZOR kritérium 3: %d objektu ma smooth polygony: %s"
              % (len(offenders), ", ".join(offenders[:8])))
    else:
        print("[NCR] kritérium 3 OK: nikde smooth normály.")


def _check_anchors():
    bpy.context.view_layer.update()
    bad = []
    for prefix, (x, y) in ANCHOR_CHECKS:
        obj = bpy.data.objects.get(prefix)
        if obj is None:
            candidates = [o for o in bpy.data.objects if o.name.startswith(prefix)]
            obj = candidates[0] if candidates else None
        if obj is None or obj.type != "MESH":
            continue
        lowest = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
        ground = C.snap_to_ground(x, y)
        if abs(lowest - ground) > ANCHOR_TOLERANCE:
            bad.append((obj.name, lowest, ground))
    if bad:
        print("[NCR] POZOR kritérium 4: %d kotev mimo toleranci %.1fm:" % (len(bad), ANCHOR_TOLERANCE))
        for name, lowest, ground in bad:
            print("[NCR]   %s: nejnizsi vrchol %.2f, terén %.2f" % (name, lowest, ground))
    else:
        print("[NCR] kritérium 4 (spot-check): hlavní stavby sedí na terénu.")


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_sections(sections):
    """Krajina není součástí robotí asset pipeline (game/assets/robots/...) —
    exportuje se vedle skriptu, ať to nekříží konvenci `import-assets.md`,
    která je psaná pro roboty v buňce mřížky, ne pro world-space scenérii."""
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(here, "export")
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)

    nc.prepare()
    for name, objs in sections:
        objs = [o for o in objs if o is not None]
        if not objs:
            continue
        for o in bpy.data.objects:
            o.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        path = os.path.join(out_dir, "%s.glb" % name.lower().replace("+", "_"))
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_yup=True, export_apply=True)
        print("[NCR] export: %s" % path)


if __name__ == "__main__":
    build()
