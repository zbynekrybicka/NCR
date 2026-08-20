# -*- coding: utf-8 -*-
"""
Sdílená animační knihovna — klipy, které se dají vyexportovat do glTF.

Doplněk `ncr_common.py`: ta staví tvar, tahle ho rozhýbe. Platí pro ni
stejné pravidlo — všechna čísla patří do `*_spec.py`, tady jsou jen
nástroje.

Model je stavebnice objektů (žádná armatura), takže klip je sada rotací
a posunů jednotlivých dílů. Origin každého pohyblivého dílu už sedí ve
svém čepu (`ncr_common.limb`, `set_origin`), takže se nic nepřepočítává.

===========================================================================
Jak se z několika klipů stane několik animací v jednom .glb
===========================================================================
Blender má na objektu jen jednu aktivní akci, klipů je ale víc. Každý se
proto po dokončení odloží do vlastní **NLA stopy** pojmenované jménem
klipu. Exportér glTF v režimu `export_animation_mode='NLA_TRACKS'` udělá
z každé stopy jednu animaci a stopy stejného jména na různých objektech
slije do jedné — přesně to potřebujeme, protože jeden klip hýbe osmi
rotory nebo dvanácti články nohou.

V Godotu je pak `AnimationPlayer` uvidí pod jmény stop: `walk`,
`turn_left`, `rotors`, …

===========================================================================
Pasti, na které se tu naráží
===========================================================================
- **Kvaternion má dvojí zápis.** Rozklad matice vrátí `q` nebo `-q` podle
  úhlu a Blender i glTF interpolují po složkách — dva sousední klíče
  s opačným znaménkem se přetočí "dlouhou cestou" dokola. `set_world()`
  proto znaménko srovnává podle předchozí hodnoty.
- **Rotace o víc než 180° mezi dvěma klíči nejde zapsat.** glTF zná jen
  kvaterniony a jde nejkratší cestou. Otáčka vrtule potřebuje klíč aspoň
  po 60°, ne dva klíče na celé kolo.
- **`matrix_world` rodiče je uprostřed snímku zastaralá.** Když se v témž
  snímku hýbe rodič i dítě, depsgraph o novém stavu rodiče ještě neví.
  `set_world()` proto bere `parent_world` jako parametr a nečte si ho sám,
  pokud se rodič hýbe.
- **Klíč se vkládá z aktuální hodnoty vlastnosti**, takže pořadí je vždy
  "nastav transformaci → vlož klíč". Mezi tím nesmí přijít nic, co by
  vyvolalo přepočet animace (`frame_set`, `view_layer.update()`).
"""

import bpy

from math import pi, sin
from mathutils import Matrix, Quaternion, Vector

# 30 fps stačí: klipy se v Godotu stejně roztahují přes `speed_scale`
# (import-assets.md §6.3), takže hustota klíčů je věc plynulosti, ne tempa.
FPS = 30


def scene_fps(fps=FPS):
    """Nastaví snímkovou frekvenci scény — do glTF se propíše jako časy."""
    scene = bpy.context.scene
    scene.render.fps = int(fps)
    scene.render.fps_base = 1.0
    return scene.render.fps


def seconds(frames, fps=FPS):
    return frames / float(fps)


# ---------------------------------------------------------------------------
# Úklid
# ---------------------------------------------------------------------------

def clear(objects):
    """Zahodí animaci daných objektů, ať je skript spustitelný opakovaně."""
    for obj in objects:
        if obj is not None and obj.animation_data is not None:
            obj.animation_data_clear()
    purge_orphan_actions()


def purge_orphan_actions():
    for action in list(bpy.data.actions):
        if action.users == 0:
            bpy.data.actions.remove(action)


def mute_tracks(objects, mute=True):
    """Umlčí (nebo zase pustí) hotové NLA stopy.

    Když se na jeden model dělá víc klipů za sebou, hotové stopy by při
    každém `frame_set` znovu pózovaly objekty a přepisovaly rozdělaný klip.
    Autoring si je proto drží umlčené a na konci je zase pustí — exportér
    umlčenou stopu přeskočí, takže se to nesmí zapomenout.
    """
    for obj in objects:
        if obj is None or obj.animation_data is None:
            continue
        for track in obj.animation_data.nla_tracks:
            track.mute = mute


# ---------------------------------------------------------------------------
# Pózování
# ---------------------------------------------------------------------------

def set_world(obj, matrix, parent_world=None):
    """Posadí objekt tak, aby jeho světová matice byla `matrix`.

    `parent_world` se předává, když se rodič hýbe v témže snímku — jeho
    `matrix_world` je v tu chvíli zastaralá a depsgraph ji přepočítá až po
    vložení klíčů, tedy pozdě.

    Znaménko kvaternionu se srovnává podle předchozí hodnoty: rozklad
    matice vrací `q` i `-q` a při interpolaci po složkách by se díl mezi
    takovými klíči přetočil dokola (u vrtule je to vidět okamžitě).
    """
    if obj.parent is None:
        local = matrix.copy()
    else:
        pw = obj.parent.matrix_world if parent_world is None else parent_world
        local = (pw @ obj.matrix_parent_inverse).inverted() @ matrix

    loc, quat, scale = local.decompose()
    obj.location = loc
    obj.scale = scale
    if obj.rotation_mode == 'QUATERNION':
        if quat.dot(obj.rotation_quaternion) < 0.0:
            quat.negate()
        obj.rotation_quaternion = quat
    else:
        obj.rotation_euler = quat.to_euler(obj.rotation_mode)
    return matrix


def swing(rest, pivot, direction_rest, direction_new):
    """Světová matice dílu otočeného ve svém čepu z jednoho směru do druhého.

    Vrací `rest` otočenou kolem `pivot` tak, aby `direction_rest` mířil tam,
    kam `direction_new`. Nezáleží na tom, jestli se rotace už zapekly do
    meshe (`APPLY_ROTATIONS`), protože se počítá přírůstek ke klidové
    poloze, ne absolutní natočení dílu.
    """
    a = Vector(direction_rest).normalized()
    b = Vector(direction_new).normalized()
    rot = a.rotation_difference(b).to_matrix().to_4x4()
    pivot = Vector(pivot)
    return Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ rest


def spin(rest, pivot, angle, axis=(0.0, 0.0, 1.0)):
    """Světová matice dílu otočeného o `angle` (radiány) kolem osy v čepu."""
    rot = Quaternion(Vector(axis).normalized(), angle).to_matrix().to_4x4()
    pivot = Vector(pivot)
    return Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ rest


# ---------------------------------------------------------------------------
# Kinematika
# ---------------------------------------------------------------------------

def ik_two_link(hip, foot, femur_len, tibia_len, knee_rest, slack=1e-4):
    """Koleno dvoučlánkové nohy: kam se ohne, aby chodidlo dosáhlo na `foot`.

    Rovina ohybu je daná klidovou polohou kolena — noha se tedy ohýbá pořád
    "nahoru jako u pavouka" a nepřeklopí se, ať chodidlo míří kamkoli. Když
    je cíl mimo dosah, noha se natáhne na doraz (narovná se, neskočí).
    """
    hip, foot, knee_rest = Vector(hip), Vector(foot), Vector(knee_rest)
    span = foot - hip
    length = span.length
    if length < 1e-9:
        span, length = Vector((0.0, 0.0, -1.0)), 1e-9

    low = abs(femur_len - tibia_len) + slack
    high = femur_len + tibia_len - slack
    length = min(max(length, low), high)
    axis = span.normalized()

    # kolmý směr, ve kterém koleno odstává — bere se z klidové polohy, aby
    # se ohyb nikdy nepřeklopil na druhou stranu
    offset = knee_rest - hip
    perp = offset - axis * offset.dot(axis)
    if perp.length < 1e-6:
        perp = Vector((0.0, 0.0, 1.0)) - axis * axis.z
        if perp.length < 1e-6:
            perp = Vector((1.0, 0.0, 0.0)) - axis * axis.x
    perp.normalize()

    along = (femur_len ** 2 - tibia_len ** 2 + length ** 2) / (2.0 * length)
    out = max(0.0, femur_len ** 2 - along ** 2) ** 0.5
    return hip + axis * along + perp * out


# ---------------------------------------------------------------------------
# Průběhy
# ---------------------------------------------------------------------------

def smoothstep(t):
    """0→1 s nulovou rychlostí na obou koncích — noha nevyrazí ani nedosedne
    trhnutím."""
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def arc(t):
    """0→1→0 obloukem; výška kroku, houpnutí těla."""
    return sin(pi * min(max(t, 0.0), 1.0))


def wave(t, periods=1.0, phase=0.0):
    """Sinusovka, která na celém klipu vyjde na celé periody, takže začátek
    a konec sedí na sebe a klip se dá zacyklit."""
    return sin(2.0 * pi * (periods * t + phase))


# ---------------------------------------------------------------------------
# Klip
# ---------------------------------------------------------------------------

class Clip(object):
    """Jeden klip = jedna NLA stopa téhož jména na všech dotčených objektech.

    Použití:

        clip = Clip("walk")
        for frame in range(0, length + 1):
            clip.frame(frame)                 # nejdřív přepnout snímek
            clip.key(obj, frame, matrix)      # pak teprve pózovat a klíčovat
        clip.finish()
    """

    def __init__(self, name, interpolation='LINEAR', start=0, loop=False):
        self.name = name
        self.interpolation = interpolation
        self.start = int(start)
        self.loop = loop
        self.objects = []          # v pořadí prvního klíče
        self.last = self.start

    # -- klíčování ----------------------------------------------------------

    def frame(self, frame):
        """Přepne scénu na daný snímek. Musí se volat PŘED nastavením
        transformací: `frame_set` přepočítá animaci a přepsal by je.

        Klipy začínají na snímku 0, ne 1 — jinak by v .glb začínaly až
        na 0.033 s a smyčka by měla na začátku hluchou mezeru."""
        bpy.context.scene.frame_set(self.start + int(round(frame)))

    def key(self, obj, frame, matrix=None, parent_world=None):
        """Vloží klíč polohy i natočení. `matrix` je světová matice dílu."""
        self._action(obj)
        if matrix is not None:
            set_world(obj, matrix, parent_world)
        at = self.start + int(round(frame))
        obj.keyframe_insert("location", frame=at)
        if obj.rotation_mode == 'QUATERNION':
            obj.keyframe_insert("rotation_quaternion", frame=at)
        else:
            obj.keyframe_insert("rotation_euler", frame=at)
        self.last = max(self.last, at)
        return obj

    def _action(self, obj):
        if obj.animation_data is None:
            obj.animation_data_create()
        action = obj.animation_data.action
        if action is None or not action.name.startswith(self.name + "|"):
            action = bpy.data.actions.new("%s|%s" % (self.name, obj.name))
            obj.animation_data.action = action
            _assign_slot(obj, action)
            self.objects.append(obj)
        return action

    # -- odložení do NLA ----------------------------------------------------

    def finish(self):
        """Odloží akce do NLA stop, ať jsou objekty volné pro další klip."""
        for obj in self.objects:
            data = obj.animation_data
            action = data.action
            for curve in action.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation = self.interpolation
            track = data.nla_tracks.new()
            track.name = self.name
            strip = track.strips.new(self.name, self.start, action)
            strip.name = self.name
            data.action = None
        return self

    @property
    def length(self):
        """Délka klipu ve snímcích."""
        return self.last - self.start

    def describe(self):
        return "%-12s %3d snímků  %.2f s  %2d objektů%s" % (
            self.name, self.length, seconds(self.length), len(self.objects),
            "  smyčka" if self.loop else "")


def _assign_slot(obj, action):
    """Blender 4.4+ chce k akci ještě slot; ve 4.2 tenhle pojem neexistuje."""
    slots = getattr(action, "slots", None)
    if slots is None:
        return
    try:
        slot = slots.new(id_type='OBJECT', name=obj.name)
        obj.animation_data.action_slot = slot
    except (AttributeError, RuntimeError, TypeError):
        pass


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def gltf_animation_options():
    """Nastavení exportu, při kterém se z NLA stop stanou animace v .glb.

    Vrací jen ty klíče, kterým dané vydání exportéru rozumí — jména se mezi
    verzemi Blenderu měnila a neznámý parametr shodí celý export.
    """
    wanted = dict(export_animations=True,
                  export_animation_mode='NLA_TRACKS',
                  export_frame_range=False,
                  export_force_sampling=True,
                  export_optimize_animation_size=False,
                  export_anim_slide_to_zero=False,
                  export_negative_frame='CROP')
    rna = getattr(bpy.ops.export_scene.gltf, "get_rna_type", None)
    if rna is None:
        return wanted
    properties = rna().properties.keys()
    return {key: value for key, value in wanted.items() if key in properties}
