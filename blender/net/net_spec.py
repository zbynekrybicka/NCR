# -*- coding: utf-8 -*-
"""
Net — přírodní robot (zelená). Rozměry a attachment pointy.

Jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud berou
všechna čísla a samy žádnou konstantu nedefinují.

Zdroj: `docs/robots-blender-spec.md` §0 a §4.

Rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu                      up  výška nad podlahou buňky
    right doprava                      1.0 = velikost jedné buňky mřížky

===========================================================================
ZADÁNÍ AUTORA — PLATÍ NADE VŠÍM OSTATNÍM
===========================================================================
**Net nemá obličej, oči ani kusadla.** Žádné párové kulaté prvky na přídi,
žádná tykadla, žádné čelisti, nic, co by šlo přečíst jako tvář. Přední
segment je hladký, symetrický a beze všeho.

Spec §4 sice zmiňuje "hlavu" (u umístění jádra), ale myslí tím jen místo
na těle — hlava jako taková se nemodeluje.

Orientaci robota proto nesou tři jiné věci, ne obličej:
  1. zúžená příď oproti široké zádi,
  2. sklon nohou (přední pár dopředu, zadní dozadu),
  3. nápis v hangulu na jádru, který podle spec §0.1 kouká dopředu.
===========================================================================

Vůdčí myšlenky tvaru (spec §4):

1. **"nízké těžiště, chitinózní krunýř"** — Net je nejnižší ze všech.
   Tělo je jeden hladký loft, ne skládačka kvádrů, a člení ho vystouplé
   segmentové pásky.
2. **"jediný bez koleček, šplhá po svislých stěnách"** — šest článkovaných
   nohou s přísavkami na koncích; nohy sahají dál než tělo, aby se robot
   opíral o široký polygon.
3. **"nejmenší profil ze všech"** u jádra — koule je pro všech 7 stejně
   velká (0.3u), takže "nejmenší profil" se dá splnit jen zapuštěním:
   u Neta je jádro zanořené až po spodek těla a kouká z něj nejmíň.
"""

ROBOT = "net"

# ---------------------------------------------------------------------------
# Tělo (spec §4: "nízké těžiště, chitinózní krunýř")
# ---------------------------------------------------------------------------

BODY_AXIS_UP = 0.168      # výška podélné osy těla; jediná konstanta, kterou
                          # se celý robot posadí výš nebo níž i s nohama
BODY_SEGMENTS = 28        # dělení elipsových řezů po obvodu

# Profil těla: (fwd, poloměr doprava, poloměr nahoru, převýšení osy).
# Od přídě k zádi. Příď je JEN zúžená — žádné prvky, viz zadání nahoře.
_BODY_PROFILE = (
    ( 0.360, 0.072, 0.040, -0.003),
    ( 0.300, 0.135, 0.062, -0.003),
    ( 0.220, 0.185, 0.070,  0.000),
    ( 0.080, 0.200, 0.070,  0.000),
    (-0.060, 0.200, 0.068,  0.000),
    (-0.200, 0.180, 0.062,  0.001),
    (-0.300, 0.118, 0.042,  0.003),
)

BODY_SECTIONS = tuple((fwd, r_right, r_up, BODY_AXIS_UP + off)
                      for fwd, r_right, r_up, off in _BODY_PROFILE)

BODY_BOW = BODY_SECTIONS[0][0]
BODY_STERN = BODY_SECTIONS[-1][0]

# Vystouplé segmentové pásky — chitin se člení, ne že je hladký jako mýdlo
SEAM_FWD = (0.245, 0.105)
SEAM_LEN = 0.020
SEAM_GROW = 0.007

# ---------------------------------------------------------------------------
# Jádro (spec §0.1 + §4: "na hřbetě, mezi krunýřem a hlavou — nejmenší
# profil ze všech")
# ---------------------------------------------------------------------------

CORE_FWD = 0.200
CORE_UP = BODY_AXIS_UP + 0.080   # spodek koule = spodek těla, hlouběji to nejde
CORE_RIVETS = 14
CORE_NAME_PITCH = 30.0    # nápis níž než u ostatních — jádro málo vyčnívá

FAIRING_R = (0.152, 0.140)
FAIRING_UP = (BODY_AXIS_UP + 0.045, BODY_AXIS_UP + 0.087)

# ---------------------------------------------------------------------------
# Nohy (spec §4: "6x článkované, přísavky nebo hroty na koncích")
# ---------------------------------------------------------------------------
#
# Přísavky, ne hroty — na svislou stěnu sedí líp a nevypadají výhrůžně.

LEG_HIPS = (0.215, 0.000, -0.215)    # fwd kyčlí (pro každou stranu tři)
HIP_RIGHT = 0.182
HIP_UP = BODY_AXIS_UP - 0.017

# Chodidla: (fwd, right). Přední pár dopředu, zadní dozadu — tohle nese
# orientaci robota místo obličeje.
LEG_FEET = ((0.352, 0.348), (0.020, 0.418), (-0.330, 0.348))

KNEE_UP = BODY_AXIS_UP + 0.097   # koleno nad hřbetem, jako u pavouka
KNEE_T = 0.55             # poloha kolena na půdorysné spojnici kyčle a chodidla

FEMUR_SIZE = (0.038, 0.032)   # (šířka, tloušťka) hranolu
TIBIA_R = (0.024, 0.016)      # (u kolena, u chodidla)
JOINT_R = 0.024               # kloubové koule

PAD_R = 0.040             # přísavka
PAD_H = 0.018

# ---------------------------------------------------------------------------
# Chůze a otáčení (klipy `walk`, `turn_left`, `turn_right`, `turn_around`)
# ---------------------------------------------------------------------------
#
# Střídavý tripod: tři nohy vždycky stojí, tři kročí. Nohy stojící fáze
# jsou v klipu přišlápnuté k zemi, takže se posouvají PROTI směru pohybu
# robota — uzel s modelem se totiž v Godotu posouvá do nové buňky sám
# (import-assets.md §6.4) a klip smí hýbat jenom tím, co je uvnitř.
#
# Kolik cyklů proběhne za jeden krok, určuje, jak daleko musí chodidlo
# dosáhnout: za jednu stojící fázi ujede tělo CELL / (2 * WALK_CYCLES),
# a přesně o tolik musí chodidlo couvnout vůči tělu. Při dvou cyklech to
# je 0.25u, což Netova noha zvládne bez natažení na doraz. Míň cyklů =
# delší krok, než na jaký noha dosáhne; víc cyklů = drobné cupitání.

WALK_CYCLES = 2           # cyklů tripodu na jeden krok o buňku
WALK_FRAMES = 24          # přirozená délka klipu (30 fps -> 0.8 s)
WALK_LIFT = 0.052         # o kolik se chodidlo při kročení zvedne
WALK_BOB = 0.010          # svislé pohupování těla; 2x za cyklus, jak se
                          # tripody střídají

TURN_FRAMES = 20          # otočka o 90° (30 fps -> 0.67 s)
TURN_CYCLES = 2
TURN_LIFT = 0.044
TURN_AROUND_FRAMES = 30   # čelem vzad, o 180°
TURN_AROUND_CYCLES = 3

# Tripod A kročí v první polovině cyklu, tripod B v druhé. Klíčem je
# (index nohy, strana), hodnotou fázový posun v cyklech.
TRIPOD_PHASE = {(0, -1): 0.0, (1, 1): 0.0, (2, -1): 0.0,
                (0, 1): 0.5, (1, -1): 0.5, (2, 1): 0.5}

# ---------------------------------------------------------------------------
# Krunýř (spec §4: "sklopný/otevírací krunýř jako úložný prostor —
# vizuálně odlišit 'nese 0-2' vs 'nese 3-4' předměty")
# ---------------------------------------------------------------------------

CARAPACE_BASE = BODY_AXIS_UP + 0.040   # rovina, kde krunýř dosedá na tělo
CARAPACE_SECTIONS = (
    ( 0.020, 0.118, 0.052, CARAPACE_BASE),
    (-0.040, 0.180, 0.094, CARAPACE_BASE),
    (-0.110, 0.215, 0.115, CARAPACE_BASE),
    (-0.190, 0.205, 0.108, CARAPACE_BASE),
    (-0.268, 0.158, 0.080, CARAPACE_BASE),
    (-0.322, 0.082, 0.038, CARAPACE_BASE),
)
CARAPACE_SEGMENTS = 28
CARAPACE_RIBS = (-0.075, -0.185)   # příčná žebra krunýře
CARAPACE_RIB_LEN = 0.018
CARAPACE_RIB_GROW = 0.006

CARAPACE_HINGE = (0.020, CARAPACE_BASE + 0.013)    # (fwd, up) čep vpředu — krunýř se zvedá vzadu
CARAPACE_OPEN = 0.0                # stupně; při 3-4 předmětech se otevře

# ---------------------------------------------------------------------------
# Náklad (spec §4: úložný prostor na zádech)
# ---------------------------------------------------------------------------

CARGO_COUNT = 0           # 0..4 — kolik předmětů Net veze
CARGO_OPEN_FROM = 3       # od tolika předmětů se krunýř nedovře
CARGO_OPEN_ANGLE = 32.0   # o kolik se pak zvedne. Znaménko je KLADNÉ,
                          # protože čep je vpředu — záporný úhel by krunýř
                          # sklopil dolů do těla (u Hanovy korby je čep vzadu,
                          # tam platí opačné znaménko)

CARGO_SIZE = (0.086, 0.086, 0.078)
CARGO_AT = ((-0.088, 0.074), (-0.088, -0.074),    # (fwd, right)
            (-0.208, 0.074), (-0.208, -0.074))
CARGO_UP = CARAPACE_BASE + 0.013   # spodek předmětů = dno schránky

FLOOR_FWD = (-0.290, 0.000)   # dno schránky, aby se předměty o něco opíraly
FLOOR_RIGHT = 0.165
FLOOR_UP = (CARAPACE_BASE - 0.003, CARAPACE_BASE + 0.013)


def knee_point(index, side):
    """(fwd, right, up) kolena dané nohy. Index 0=přední, 1=střední, 2=zadní."""
    hip_fwd = LEG_HIPS[index]
    foot_fwd, foot_right = LEG_FEET[index]
    t = KNEE_T
    return (hip_fwd + (foot_fwd - hip_fwd) * t,
            side * (HIP_RIGHT + (foot_right - HIP_RIGHT) * t),
            KNEE_UP)


def hip_point(index, side):
    return (LEG_HIPS[index], side * HIP_RIGHT, HIP_UP)


def foot_point(index, side):
    foot_fwd, foot_right = LEG_FEET[index]
    return (foot_fwd, side * foot_right, PAD_H * 0.5)
