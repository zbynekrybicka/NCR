# -*- coding: utf-8 -*-
"""
Elektrická skříň a řídicí jednotka — rozměry.

Jediné místo, kde se ladí proporce (stejný princip jako `<robot>_spec.py`).
Design dokument (§2.2.1 "Elektrická zařízení v mřížce") žádá, aby zařízení
zabíralo **celou buňku** a chovalo se jako zeď — pouzdro proto vyplňuje
`right`/`up` stejně jako blok WALL (`world_view.gd` staví WALL na
`CELL_SIZE`), jen hloubka (`fwd`) nechává místo na dvířka/panel.

Rozměry v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd    dopředu — kladně směrem k čelu (dvířkům/panelu)
    right  doprava
    up     výška nad podlahou buňky (0 = podlaha, 1 = strop)

Čelo (dvířka/panel) nesmí přesáhnout `fwd = 0.5` — to je hranice buňky, za
kterou by model zasahoval do sousední (průchozí) buňky, kde musí stát Il.
"""

# ---------------------------------------------------------------------------
# Pouzdro — sdílené oběma zařízeními (§13.1: jedna kostka, chová se jako zeď)
# ---------------------------------------------------------------------------

CASE_RIGHT = 0.500            # plná šířka buňky, stejně jako WALL
CASE_UP = (0.0, 1.0)          # podlaha až strop, stejně jako WALL
CASE_BACK = -0.500
CASE_EDGE_BEVEL = 0.006

# ---------------------------------------------------------------------------
# Elektrická skříň (POWER_CABINET)
# ---------------------------------------------------------------------------

CAB_CASE_FRONT = 0.430
CAB_DOOR_THICK = 0.050
CAB_DOOR_FRONT = CAB_CASE_FRONT + CAB_DOOR_THICK   # 0.480 — pod hranicí 0.5

CAB_DOOR_RIGHT = 0.400
CAB_DOOR_UP = (0.10, 0.88)

CAB_HINGE_RIGHT = -CAB_DOOR_RIGHT - 0.015   # levá hrana dvířek
CAB_HINGE_R = 0.020
CAB_HINGE_LEN = 0.070
CAB_HINGE_UPS = (0.22, 0.49, 0.76)

CAB_LATCH_RIGHT = CAB_DOOR_RIGHT - 0.02
CAB_LATCH_UP = 0.49
# Rozměry ve stejném pořadí, v jakém je čte `nc.box(size=(right, fwd, up))`.
# Umístění je `p(CAB_DOOR_FRONT + CAB_LATCH_SIZE[1] * 0.5, ...)` (part_01_cabinet.py),
# takže přední stěna kliky sedí na `CAB_DOOR_FRONT + CAB_LATCH_SIZE[1]` — fwd
# rozměr (druhá hodnota) proto musí zůstat malý, ať nepřesáhne hranici buňky
# (0.480 + 0.012 = 0.492, bezpečná rezerva 0.008).
CAB_LATCH_SIZE = (0.055, 0.012, 0.045)

CAB_LAMP_RIGHT = 0.0
CAB_LAMP_UP = 0.945
CAB_LAMP_R = 0.045
CAB_LAMP_DEPTH = 0.030

CAB_BOLT_RIGHT = 0.15          # poloviční šířka symbolu
CAB_BOLT_UP = (0.32, 0.70)
CAB_BOLT_THICK = 0.014

CAB_VENT_RIGHT = 0.30
CAB_VENT_UPS = (0.15, 0.19, 0.23)
CAB_VENT_THICK = 0.010
CAB_VENT_DEPTH = 0.006

# --- poškození (§ zadání "pokud je skříň rozbitá, lítají z ní jiskry") -----
# Statická geometrie poškození (trhlina + útržky) je součást modelu a Godot
# ji jen zobrazí/skryje (`DeviceView.update_cabinet`, uzel "Damage"). Skutečné
# jiskry jsou dynamické GPUParticles3D v Godotu (stejný princip jako částice
# cíle ve `world_view.gd`), zakotvené na uzlu "SparkAnchor".
CAB_CRACK_RIGHT = (-0.22, 0.24)
CAB_CRACK_UP = 0.52
CAB_CRACK_JAG = (0.0, 0.05, -0.03, 0.06, -0.02, 0.04, 0.0)
CAB_CRACK_THICK = 0.010

CAB_SHARD_COUNT = 3
CAB_SHARD_SIZE = (0.05, 0.012, 0.035)   # (right, fwd, up) — viz nc.box(size=...)

CAB_SPARK_ANCHOR = (CAB_DOOR_FRONT + 0.03, 0.02, CAB_CRACK_UP)   # (fwd, right, up)

# ---------------------------------------------------------------------------
# Řídicí jednotka (CONTROL_UNIT) — tlačítko i přepínač jsou týž fyzický
# panel (design dok. §2.2.1: liší se jen `control_mode`), páka reprezentuje
# obojí a Godot ji natáčí do dvou poloh podle stavu napojeného mechanismu
# (`DeviceView.update_control_unit`, viz import-assets.md §4.3).
# ---------------------------------------------------------------------------

CTRL_CASE_FRONT = 0.430
CTRL_PANEL_THICK = 0.030
CTRL_PANEL_FRONT = CTRL_CASE_FRONT + CTRL_PANEL_THICK   # 0.460

CTRL_PANEL_RIGHT = 0.360
CTRL_PANEL_UP = (0.16, 0.84)

CTRL_SCREW_R = 0.014
CTRL_SCREW_INSET = 0.045   # od rohu panelu

CTRL_HOUSING_RIGHT = 0.110
CTRL_HOUSING_UP = (0.38, 0.64)
CTRL_HOUSING_FRONT = CTRL_PANEL_FRONT + 0.010   # 0.470 — jen malý límec kolem páky

## Páka je záměrně krátká: pivot sedí na `CTRL_HOUSING_FRONT` (0.470, tj.
## 0.03 před hranicí buňky) a při naklopení o `LEVER_POSE_DEG` opíše oblouk
## `CTRL_LEVER_LEN * sin(28°) ≈ 0.035` + poloměr hlavice — hlavice páky proto
## v krajní poloze o pár centimetrů přesáhne `fwd = 0.5`. Na rozdíl od
## pouzdra/dvířek (které musí zůstat uvnitř buňky, jinak by vizuálně
## zasahovaly do sousední průchozí buňky) je tohle žádoucí a neškodí: páka
## nemá kolizi (vykreslování je čistě kosmetické, kolize řeší mřížka —
## import-assets.md §1), a pár centimetrů výstupku čitelně čte jako "tady je
## ovladač", ne jako chyba modelu.
CTRL_LEVER_R = 0.018
CTRL_LEVER_LEN = 0.075
CTRL_LEVER_BASE_R = 0.026
CTRL_LEVER_BASE_LEN = 0.016

## Poloha páky ve stupních (§ zadání "přepínač udělej ve dvou polohách, aby
## bylo možné vizuálně rozlišovat") — Godot rotuje uzel "Lever" o tuhle
## hodnotu kolem lokální X (viz DeviceView.LEVER_POSE_DEG, musí sedět).
LEVER_POSE_DEG = (-28.0, 28.0)   # (poloha 0, poloha 1)
