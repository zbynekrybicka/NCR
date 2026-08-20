# -*- coding: utf-8 -*-
"""
ANIMACE — chůze a otáčení na místě, spec §4 ("6x článkované nohy").

Klipy: `walk` (krok o jednu buňku vpřed), `turn_left`, `turn_right`
(otočka o 90° na místě), `turn_around` (čelem vzad).

===========================================================================
Vůdčí myšlenka: chodidlo se drží země, ne těla
===========================================================================
Uzel s modelem posouvá a otáčí `EventAnimator` v Godotu — klip smí hýbat
jenom tím, co je uvnitř modelu (`docs/import-assets.md` §6.4). Když tedy
robot ujede buňku vpřed, nohy, které zrovna stojí, musí v klipu couvnout
přesně o tu buňku dozadu, jinak chodidla po zemi kloužou.

Klip proto nepočítá "o kolik se natočí kloub", ale "kde v prostoru je
chodidlo", a kloubní úhly z toho dopočítá inverzní kinematika
(`ncr_anim.ik_two_link`). Díky tomu je došlap přesný na tisícinu buňky
a stačí změnit jediné číslo (`WALK_CYCLES`), aby se přešlo z dlouhých
kroků na cupitání, aniž se sáhne na křivky.

**Střídavý tripod** (přední levá + střední pravá + zadní levá, pak
opačná trojice) je nejjednodušší chod, u kterého robot v každém okamžiku
stojí na třech nohách. Tři nohy stojí, tři kročí.

===========================================================================
Kde klip začíná a končí
===========================================================================
Klip má celý počet cyklů, takže první a poslední snímek jsou stejná póza
a kroky se dají řetězit za sebe bez trhnutí (hráč drží klávesu). Není to
ale úplně symetrický postoj modelu: v okamžiku výměny tripodu je jedna
trojice nohou o půl kroku vpředu a druhá vzadu. Tohle je pro šestinožce
přirozená "stojící" póza a od ní se bude odvíjet i budoucí klip `idle`.

===========================================================================
Vlevo a vpravo
===========================================================================
Otočky jsou pojmenované z pohledu robota: `turn_left` otáčí příď doleva.
Model míří přídí k -Y a v Blenderu je pak jeho vlastní levá strana na
+X — otočení doleva je tedy KLADNÁ rotace kolem +Z. Pozor na to, že
`ncr_common.p(fwd, right, up)` mapuje svůj parametr `right` taky na +X,
takže to, čemu říká výkres "doprava", je ve skutečnosti robotova levá
ruka. Roboti jsou soumerní, takže na tvaru to nikde nesešlo, ale u otáčení
by záměna byla vidět okamžitě.

Objekty: NET_Body, NET_LegFemur_*, NET_LegTibia_*
"""

import bpy
import os
import sys
import types
import importlib

from math import floor, radians


def _ncr_import(module_name):
    """Načte modul ze složky robota nebo ze sousední `blender/common`.
    Funguje v Text Editoru i přes `blender --python`."""
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
            "Nenasel jsem %s.py - otevri pres Text > Open skripty ze slozky "
            "robota i z blender/common, at k sobe navzajem vidi." % module_name)
    module = types.ModuleType(module_name)
    exec(text.as_string(), module.__dict__)
    sys.modules[module_name] = module
    return module


nc = _ncr_import("ncr_common")
na = _ncr_import("ncr_anim")
S = _ncr_import("net_spec")

Matrix, Vector = nc.Matrix, nc.Vector

CLIPS = ("walk", "turn_left", "turn_right", "turn_around")


# ---------------------------------------------------------------------------
# Klidový stav nohou
# ---------------------------------------------------------------------------

class Leg(object):
    """Jedna noha i s tím, co o ní potřebuje kinematika.

    Všechny body jsou ve světových souřadnicích klidové polohy — tedy
    přesně to, co spočítal `net_spec`, jen přeložené přes `nc.p()`.
    """

    def __init__(self, index, side):
        tag = "%s%d" % ("L" if side < 0 else "P", index)
        self.femur = bpy.data.objects.get("NET_LegFemur_" + tag)
        self.tibia = bpy.data.objects.get("NET_LegTibia_" + tag)
        self.phase = S.TRIPOD_PHASE[(index, side)]

        self.hip = nc.p(*S.hip_point(index, side))
        self.knee = nc.p(*S.knee_point(index, side))
        self.foot = nc.p(*S.foot_point(index, side))

        self.femur_len = (self.knee - self.hip).length
        self.tibia_len = (self.foot - self.knee).length

    def capture(self):
        """Zapamatuje si klidové matice. Volá se jednou, před prvním klipem
        a až po `view_layer.update()` — jinak jsou po zavěšení do hierarchie
        zastaralé."""
        self.femur_rest = self.femur.matrix_world.copy()
        self.tibia_rest = self.tibia.matrix_world.copy()
        # kde chodidlo sedí v lokálním prostoru holeně — tím se dá zpětně
        # ověřit, že kinematika opravdu trefila cíl
        self.foot_in_tibia = self.tibia_rest.inverted() @ self.foot

    @property
    def objects(self):
        return [self.femur, self.tibia]


def _legs():
    legs = [Leg(index, side) for index in range(3) for side in (-1, 1)]
    return [leg for leg in legs if leg.femur is not None and leg.tibia is not None]


# ---------------------------------------------------------------------------
# Chod
# ---------------------------------------------------------------------------

def _walk_motion(t):
    """Kam se za dobu klipu dostane celý robot: o buňku vpřed."""
    return Matrix.Translation(nc.FORWARD * (nc.CELL * t))


def _turn_motion(angle):
    """Otočka na místě o `angle` stupňů; kladný úhel = doleva."""
    def motion(t):
        return Matrix.Rotation(radians(angle) * t, 4, 'Z')
    return motion


def _foot_target(leg, t, motion, cycles, lift):
    """Kde má být chodidlo v čase `t` (0..1), v prostoru modelu.

    Noha půl cyklu stojí a půl kročí. Stojící noha je přišlápnutá k zemi:
    její bod v prostoru je pevný a do prostoru modelu se přepočítá přes
    inverzi pohybu robota. Došlap je vždycky umístěný tak, aby uprostřed
    stojící fáze bylo chodidlo přesně v klidové poloze — noha se tak
    stejným dílem natahuje dopředu i dozadu.
    """
    cycle = t * cycles - leg.phase
    step = floor(cycle)
    u = cycle - step
    to_model = motion(t).inverted()

    def plant(offset):
        """Bod v prostoru, kde noha stojí v cyklu `step + offset`."""
        return motion((step + offset + leg.phase) / float(cycles)) @ leg.foot

    if u >= 0.5:                                   # stojí
        return to_model @ plant(0.75)

    s = na.smoothstep(u / 0.5)                     # kročí
    point = to_model @ plant(-0.25).lerp(plant(0.75), s)
    return point + Vector((0.0, 0.0, lift * na.arc(s)))


# ---------------------------------------------------------------------------
# Sestavení klipu
# ---------------------------------------------------------------------------

def _clip(name, body, body_rest, legs, motion, frames, cycles, lift, bob=0.0):
    clip = na.Clip(name, interpolation='LINEAR')
    miss = 0.0            # jak daleko od cíle skončilo chodidlo
    lowest = 1e9          # nejnižší bod chodidla (podlaha je -0.5)
    slip = 0.0            # o kolik se pohnula stojící noha po zemi

    planted = {}
    for frame in range(frames + 1):
        t = frame / float(frames)
        clip.frame(frame)

        rise = Matrix.Translation((0.0, 0.0, bob * na.wave(t, periods=2.0 * cycles)))
        body_world = rise @ body_rest
        clip.key(body, frame, body_world)

        for leg in legs:
            target = _foot_target(leg, t, motion, cycles, lift)
            # kinematika se počítá v klidovém rámci těla, houpnutí se přidá
            # až na výslednou matici — jinak by se pohupování promítlo i do
            # kloubních úhlů a chodidla by se zvedala s tělem
            local_target = rise.inverted() @ target
            knee = na.ik_two_link(leg.hip, local_target, leg.femur_len,
                                  leg.tibia_len, leg.knee)

            femur_world = rise @ na.swing(leg.femur_rest, leg.hip,
                                          leg.knee - leg.hip, knee - leg.hip)
            tibia_world = (rise
                           @ Matrix.Translation(knee - leg.knee)
                           @ na.swing(leg.tibia_rest, leg.knee,
                                      leg.foot - leg.knee, local_target - knee))

            clip.key(leg.femur, frame, femur_world, parent_world=body_world)
            clip.key(leg.tibia, frame, tibia_world, parent_world=femur_world)

            # kontrola: kde chodidlo po pózování opravdu skončilo
            actual = tibia_world @ leg.foot_in_tibia
            miss = max(miss, (actual - target).length)
            lowest = min(lowest, actual.z)

            # stojící noha se nesmí po zemi ani hnout: převede se zpátky do
            # prostoru země a porovná s prvním snímkem téže stojící fáze
            cycle = t * cycles - leg.phase
            stance = floor(cycle) if cycle - floor(cycle) >= 0.5 else None
            if stance is None:
                planted.pop(leg.femur.name, None)
            else:
                ground = motion(t) @ actual
                first = planted.get(leg.femur.name)
                if first is None or first[0] != stance:
                    planted[leg.femur.name] = (stance, ground)
                else:
                    slip = max(slip, (ground - first[1]).length)

    clip.finish()
    return clip, dict(miss=miss, lowest=lowest, slip=slip)


def build():
    na.scene_fps()

    body = bpy.data.objects.get("NET_Body")
    legs = _legs()
    if body is None or len(legs) != 6:
        raise RuntimeError("chybí NET_Body nebo některá noha — spusť build_net.py")

    animated = [body]
    for leg in legs:
        animated += leg.objects

    # klidová póza se snímá jednou, před prvním klipem: jakmile na objektech
    # visí hotová stopa, každý `frame_set` je přepózuje
    na.clear(animated)
    bpy.context.view_layer.update()
    body_rest = body.matrix_world.copy()
    for leg in legs:
        leg.capture()

    plan = (
        ("walk", _walk_motion, S.WALK_FRAMES, S.WALK_CYCLES, S.WALK_LIFT, S.WALK_BOB),
        ("turn_left", _turn_motion(90.0), S.TURN_FRAMES, S.TURN_CYCLES,
         S.TURN_LIFT, S.WALK_BOB),
        ("turn_right", _turn_motion(-90.0), S.TURN_FRAMES, S.TURN_CYCLES,
         S.TURN_LIFT, S.WALK_BOB),
        ("turn_around", _turn_motion(180.0), S.TURN_AROUND_FRAMES,
         S.TURN_AROUND_CYCLES, S.TURN_LIFT, S.WALK_BOB),
    )

    results = []
    for name, motion, frames, cycles, lift, bob in plan:
        clip, check = _clip(name, body, body_rest, legs, motion, frames,
                            cycles, lift, bob)
        na.mute_tracks(animated, True)
        results.append((clip, check))
        print("[NCR] animace — %s" % clip.describe())
        print("[NCR]     chodidlo mimo cíl %.4fu, prokluz stojící nohy %.4fu, "
              "nejníž %.3f (podlaha %.3f)"
              % (check["miss"], check["slip"], check["lowest"], nc.FLOOR))
        if check["miss"] > 1e-3:
            print("[NCR]     POZOR: noha nedosáhne — zvyš WALK_CYCLES nebo "
                  "zkrať krok")
        if check["lowest"] < nc.FLOOR - 1e-3:
            print("[NCR]     POZOR: chodidlo prošlapuje podlahu")

    # stopy se musí zase pustit, jinak je exportér do .glb nezapíše
    na.mute_tracks(animated, False)
    bpy.context.scene.frame_set(0)
    return results


if __name__ == "__main__":
    build()
