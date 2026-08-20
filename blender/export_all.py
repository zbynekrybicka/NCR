# -*- coding: utf-8 -*-
"""
Reexport všech sedmi robotů do `game/assets/robots/*.glb`.

    blender --background --factory-startup --python blender/export_all.py

Nebo jen některé:

    blender --background --factory-startup --python blender/export_all.py -- han da

Každý robot se staví v čerstvém souboru: `build_*.py` si přes
`importlib.reload` tahá vlastní díly a spouštět dva roboty v jednom
běhu Blenderu by znamenalo míchat jejich moduly i objekty ve scéně.
Skript proto pro každého robota spustí Blender znovu — pomalejší,
zato bez překvapení.

Konvence exportu popisuje `docs/import-assets.md` §2.2–2.5; otočku kořene
(glTF má předek na +Z, Godot na −Z) řeší `ncr_common.godot_forward()`
uvnitř `export_glb()`.
"""

import os
import subprocess
import sys

ROBOTS = ("han", "dul", "set", "net", "da", "yeo", "il")

HERE = os.path.dirname(os.path.abspath(__file__))

# --- větev, která běží uvnitř Blenderu pro jednoho robota -------------------

CHILD_FLAG = "--ncr-export-one"


def export_one(robot):
    """Sestaví jednoho robota a zapíše jeho .glb."""
    import importlib
    sys.path.insert(0, os.path.join(HERE, "common"))
    sys.path.insert(0, os.path.join(HERE, robot))
    build = importlib.import_module("build_%s" % robot)
    build.EXPORT_GLB = True
    build.build()


# --- větev, která běží jako první a rozdává práci ---------------------------

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    if argv[:1] == [CHILD_FLAG]:
        export_one(argv[1])
        return

    wanted = [r for r in argv if not r.startswith("-")] or list(ROBOTS)
    unknown = [r for r in wanted if r not in ROBOTS]
    if unknown:
        raise SystemExit("neznámý robot: %s (znám %s)"
                         % (", ".join(unknown), ", ".join(ROBOTS)))

    failed = []
    for robot in wanted:
        print("\n[NCR] ===== export %s =====" % robot)
        result = subprocess.call([sys.argv[0], "--background", "--factory-startup",
                                  "--python", os.path.abspath(__file__),
                                  "--", CHILD_FLAG, robot])
        if result != 0:
            failed.append(robot)

    print("\n[NCR] hotovo: %d z %d" % (len(wanted) - len(failed), len(wanted)))
    if failed:
        raise SystemExit("[NCR] SELHALO: %s" % ", ".join(failed))


if __name__ == "__main__":
    main()
