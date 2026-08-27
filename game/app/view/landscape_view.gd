class_name LandscapeView
extends Node3D

## Čistě dekorativní krajina kolem levelu (docs/import-assets.md §7.2 —
## "kulisa levelu"). Nesahá na simulaci ani na formát levelu; jen se
## postaví na scénu a nic víc — použito jak editorovým nástrojem umístění
## (world_placement_view.gd, který si nad ní navíc staví vlastní kolizi pro
## editorový raycast), tak přímo při hraní (level_controller.gd), kde
## žádná kolize s krajinou není potřeba.

const LANDSCAPE_SCENE := "res://assets/world_map/krajina.glb"

## Zkušební textury povrchů (docs/zadani_textury_dalle.md) — jméno materiálu
## z Blenderu (`KRAJ_<klíč>` z blender/krajina/common.py, MATERIALS) na
## texturu. Terén i shluky trávy nemají UV (docs/zadani_krajina_lowpoly_bpy.md
## kap. 1: "UV negenerovat"), takže se textura mapuje triplanárně podle
## světové pozice, ne přes UV souřadnice.
const SURFACE_TEXTURES := {
	"KRAJ_trava_zahrada": "res://assets/world_map/textures/trava_zahrada.jpg",
	"KRAJ_trava_louka": "res://assets/world_map/textures/trava_louka.jpg",
	"KRAJ_trava_ridka": "res://assets/world_map/textures/trava_ridka.jpg",
	"KRAJ_hlina_cesta": "res://assets/world_map/textures/hlina_cesta.jpg",
	"KRAJ_hlina_holy": "res://assets/world_map/textures/hlina_holy.jpg",
	"KRAJ_kamen_dlazba": "res://assets/world_map/textures/kamen_dlazba.jpg",
	"KRAJ_kamen_skala": "res://assets/world_map/textures/kamen_skala.jpg",
	"KRAJ_kamen_balvan": "res://assets/world_map/textures/kamen_balvan.jpg",
	"KRAJ_mech": "res://assets/world_map/textures/mech.jpg",
	"KRAJ_drevo_plot": "res://assets/world_map/textures/drevo_plot.jpg",
	"KRAJ_drevo_tmave": "res://assets/world_map/textures/drevo_tmave.jpg",
	"KRAJ_drevo_kmen": "res://assets/world_map/textures/drevo_kmen.jpg",
	"KRAJ_drevo_suchy": "res://assets/world_map/textures/drevo_suchy.jpg",
	"KRAJ_beton": "res://assets/world_map/textures/beton.jpg",
	"KRAJ_strecha": "res://assets/world_map/textures/strecha.jpg",
	"KRAJ_jehlici_zeme": "res://assets/world_map/textures/jehlici_zeme.jpg",
	"KRAJ_jehlici_zelen": "res://assets/world_map/textures/jehlici_zelen.jpg",
	"KRAJ_listi_tmave": "res://assets/world_map/textures/listi_tmave.jpg",
	"KRAJ_listi_svetle": "res://assets/world_map/textures/listi_svetle.jpg",
	"KRAJ_voda_rybnik": "res://assets/world_map/textures/voda_rybnik.jpg",
	"KRAJ_voda_potok": "res://assets/world_map/textures/voda_potok.jpg",
	"KRAJ_lava_kura": "res://assets/world_map/textures/lava_kura.jpg",
	"KRAJ_skala_jeskyne": "res://assets/world_map/textures/skala_jeskyne.jpg",
	"KRAJ_obsidian": "res://assets/world_map/textures/obsidian.jpg",
}
const TEXTURE_TILE_SIZE := 2.0   ## metrů světa na jedno opakování textury

## Černé desky za okny domu proti z-fightingu zdi/rámu/skla (blender/krajina/
## 03_dum_plot.py, WINDOW_DARK_*) — krajina.glb je poslední dobou beze změny
## (nešlo reexportovat/reimportovat), takže je oprava zrcadlená přímo tady.
## Souřadnice přepočtené z Blenderu (X, Z, -Y — standardní glTF/Godot osy,
## ověřeno na translaci A_dum_okno_0/1 v krajina.glb, T.y=1.700982): wx
## zůstává, Godot Y = Blender Z (z0 + WINDOW_SILL + WINDOW_SIZE.y/2),
## Godot Z = -(HOUSE_Y[1] + WINDOW_DARK_FRONT - WINDOW_DARK_DEPTH/2) = -0.02.
const WINDOW_DARK_X := [-2.8, 2.8]
const WINDOW_DARK_Y := 1.700982
const WINDOW_DARK_Z := -0.02
## O trochu větší než sklo (0.90 × 1.10 v Blenderu) — plně ho tím zakryje,
## takže odpadá i lesklá/"svítící" plocha skla (KRAJ_sklo, metallic 0.9) a
## její vlastní blikání proti rámu, ne jen zeď pod tím.
const WINDOW_DARK_SIZE := Vector3(0.94, 1.14, 0.02)   ## (šířka, výška, tloušťka)

## Rám i sklo domovních oken (jeden spojený mesh z Blenderu, "A_dum_okno_*")
## leží přesně v rovině fasády stejně jako zeď pod nimi -> blikání. Celý uzel
## se posune o kousek dopředu (Godot -Z, směrem od domu), aby se roviny
## rozešly; deska výš (WINDOW_DARK_*) pak zajistí, že zůstane před rámem, ne
## naopak.
const WINDOW_FRAME_NAMES := ["A_dum_okno_0", "A_dum_okno_1", "A_dum_dvere"]
const WINDOW_FRAME_FORWARD := 0.02

signal landscape_ready(found: bool)

var instance: Node3D

func _ready() -> void:
	if not ResourceLoader.exists(LANDSCAPE_SCENE):
		push_warning("Krajina nenalezena: %s" % LANDSCAPE_SCENE)
		landscape_ready.emit(false)
		return
	var packed: PackedScene = load(LANDSCAPE_SCENE)
	instance = packed.instantiate()
	_apply_surface_textures(instance)
	add_child(instance)
	_move_window_frames_forward(instance)
	_add_window_dark_panels(instance)
	landscape_ready.emit(true)

## Nahradí materiály podle jména jejich texturovanou variantou
## (SURFACE_TEXTURES). Chybějící textura nebo neznámý materiál => beze
## změny, stejný fallback princip jako u ModelLibrary/RobotView
## (docs/import-assets.md) — chybějící asset nic nerozbije.
func _apply_surface_textures(root: Node3D) -> void:
	if SURFACE_TEXTURES.is_empty():
		return
	var cache: Dictionary = {}   # resource_name materiálu -> texturovaná kopie
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface)
			if material == null:
				continue
			var texture_path: String = SURFACE_TEXTURES.get(material.resource_name, "")
			if texture_path == "" or not ResourceLoader.exists(texture_path):
				continue
			if not cache.has(material.resource_name):
				cache[material.resource_name] = _textured_variant(material, texture_path)
			mesh_instance.set_surface_override_material(surface, cache[material.resource_name])

## Duplikuje materiál (zachová barvu/roughness z Blenderu jako podklad pod
## texturou) a přidá albedo texturu s triplanárním promítáním ve světových
## souřadnicích — funguje i bez UV a sedí i na terén táhnoucí se přes
## desítky metrů beze švů.
func _textured_variant(source: Material, texture_path: String) -> Material:
	var base := source.duplicate() as BaseMaterial3D
	if base == null:
		return source
	base.albedo_texture = load(texture_path)
	base.uv1_triplanar = true
	base.uv1_world_triplanar = true
	base.uv1_scale = Vector3.ONE / TEXTURE_TILE_SIZE
	return base

## Viz WINDOW_FRAME_* výše — posune celý uzel rámu+skla dopředu od fasády.
func _move_window_frames_forward(root: Node3D) -> void:
	for frame_name in WINDOW_FRAME_NAMES:
		var node := root.find_child(frame_name, true, false)
		if node is Node3D:
			node.position.z -= WINDOW_FRAME_FORWARD

## Viz WINDOW_DARK_* výše — dvě desky přidané do stromu ručně, mimo geometrii
## z .glb, aby se neshodovaly žádnou plochou se zdí/rámem/sklem okna.
func _add_window_dark_panels(root: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.051, 0.051, 0.051)   # #0D0D0D, KRAJ_interier_tma
	material.roughness = 0.95
	for i in WINDOW_DARK_X.size():
		var box := BoxMesh.new()
		box.size = WINDOW_DARK_SIZE
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "A_dum_okno_tma_%d" % i
		mesh_instance.mesh = box
		mesh_instance.material_override = material
		mesh_instance.position = Vector3(WINDOW_DARK_X[i], WINDOW_DARK_Y, WINDOW_DARK_Z)
		root.add_child(mesh_instance)
