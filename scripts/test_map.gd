extends Node3D

## Phase 1 test map: a static hand-shaped hex region around Dustfall, built from
## Kenney tiles. No game logic yet - this exists to verify the grid math, the
## isometric camera and the asset pipeline against a real running scene.

const MAP_RADIUS := 5
const SETTLEMENT_CELL := Vector2i(0, 0)

@onready var _rig: IsoCameraRig = $CameraRig

var _tiles: Dictionary = {}
var _highlight: MeshInstance3D
var _label: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 18720412
	_build_environment()
	_build_map()
	_build_highlight()
	_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_select_at(event.position)


func _select_at(screen_pos: Vector2) -> void:
	var ground := _rig.screen_to_ground(screen_pos)
	if ground == Vector3.INF:
		return

	var cell := HexGrid.world_to_axial(ground)
	if not _tiles.has(cell):
		_highlight.visible = false
		_label.text = "Mimo mapu"
		return

	# Round-trip check: the cell's own center must map back to the same cell.
	var center := HexGrid.axial_to_world(cell.x, cell.y)
	var round_trip := HexGrid.world_to_axial(center)
	var terrain_name: String = TileCatalog.TileType.keys()[_tiles[cell]]

	_highlight.position = center + Vector3(0.0, TileCatalog.TILE_TOP_Y + 0.02, 0.0)
	_highlight.visible = true
	_label.text = "Dlazdice q=%d r=%d | %s | vzdalenost od Dustfall: %d" % [
		cell.x, cell.y, terrain_name, HexGrid.distance(cell, SETTLEMENT_CELL)
	]

	print("[test_map] klik -> world(%.3f, %.3f) -> axial(%d, %d) | round-trip %s | %s" % [
		ground.x, ground.z, cell.x, cell.y,
		"OK" if round_trip == cell else "CHYBA %s" % round_trip,
		terrain_name,
	])


func _build_map() -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)

	var prop_root := Node3D.new()
	prop_root.name = "Props"
	add_child(prop_root)

	for cell in HexGrid.spiral_area(MAP_RADIUS):
		var type := _terrain_for(cell)
		_tiles[cell] = type

		var tile := TileCatalog.terrain_scene(type).instantiate()
		tile.position = HexGrid.axial_to_world(cell.x, cell.y)
		terrain_root.add_child(tile)

		_scatter_props(cell, type, prop_root)

	var cabin := TileCatalog.settlement_scene().instantiate()
	cabin.position = HexGrid.axial_to_world(SETTLEMENT_CELL.x, SETTLEMENT_CELL.y)
	cabin.name = "DustfallPlaceholder"
	add_child(cabin)


## Hand-authored terrain bands: dry basin in the south-west, mountains along the
## northern rim, a creek cutting through, grass around the town.
func _terrain_for(cell: Vector2i) -> TileCatalog.TileType:
	var dist := HexGrid.distance(cell, Vector2i.ZERO)

	if dist == 0:
		return TileCatalog.TileType.DIRT

	# Creek: a short diagonal run of water east of town.
	if cell in [Vector2i(2, -3), Vector2i(2, -2), Vector2i(1, -1), Vector2i(2, -1)]:
		return TileCatalog.TileType.WATER

	# Northern mountain rim.
	if cell.y <= -3:
		return TileCatalog.TileType.STONE_MOUNTAIN if dist >= 4 else TileCatalog.TileType.STONE_HILL

	if cell.y == -2 and dist >= 4:
		return TileCatalog.TileType.STONE_ROCKS

	# South-western desert basin.
	if cell.x <= -1 and cell.y >= 1:
		if dist >= 4:
			return TileCatalog.TileType.SAND_DESERT
		return TileCatalog.TileType.SAND_ROCKS if _rng.randf() < 0.25 else TileCatalog.TileType.SAND

	# Southern scrubland fading into sand.
	if cell.y >= 3:
		return TileCatalog.TileType.SAND

	if dist >= 4 and _rng.randf() < 0.3:
		return TileCatalog.TileType.GRASS_FOREST

	if dist >= 3 and _rng.randf() < 0.2:
		return TileCatalog.TileType.GRASS_HILL

	return TileCatalog.TileType.GRASS


func _scatter_props(cell: Vector2i, type: TileCatalog.TileType, parent: Node3D) -> void:
	if cell == SETTLEMENT_CELL:
		return

	var choices: Array[String] = []
	match type:
		TileCatalog.TileType.SAND, TileCatalog.TileType.SAND_DESERT:
			choices = ["cactus_tall", "cactus_short", "rock_smallA", "stump_old"]
		TileCatalog.TileType.GRASS:
			choices = ["bush_small", "rock_smallB", "rock_smallC"]
		TileCatalog.TileType.STONE, TileCatalog.TileType.STONE_HILL:
			choices = ["rock_largeA", "rock_largeB", "rock_smallD"]
		TileCatalog.TileType.DIRT:
			choices = ["rock_smallA", "rock_smallD"]
		_:
			return

	if _rng.randf() > 0.45:
		return

	var prop := TileCatalog.prop_scene(choices[_rng.randi_range(0, choices.size() - 1)]).instantiate()
	var base := HexGrid.axial_to_world(cell.x, cell.y)
	var jitter := Vector3(_rng.randf_range(-0.22, 0.22), 0.0, _rng.randf_range(-0.22, 0.22))
	prop.position = base + jitter + Vector3(0.0, TileCatalog.TILE_TOP_Y, 0.0)
	prop.rotation.y = _rng.randf_range(0.0, TAU)
	parent.add_child(prop)


func _build_highlight() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = HexGrid.HEX_RADIUS * 0.86
	ring.outer_radius = HexGrid.HEX_RADIUS * 0.94
	ring.rings = 6

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.25)
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material = mat

	_highlight = MeshInstance3D.new()
	_highlight.mesh = ring
	_highlight.visible = false
	add_child(_highlight)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -140.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.93, 0.79)
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.10, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.50, 0.42)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.34, 0.24)
	env.fog_density = 0.004
	# Kenney's palette is lush and saturated; pull it toward a sun-bleached
	# 1872 Nevada look without editing the shared source textures.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.62
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.04

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.87, 0.74, 0.44))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.text = "Klikni na dlazdici"
	layer.add_child(_label)

	var help := Label.new()
	help.position = Vector2(24, 50)
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.72, 0.63, 0.48))
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	help.add_theme_constant_override("shadow_offset_y", 2)
	help.text = "WASD / sipky = posun  |  prave tlacitko = tazeni  |  kolecko = zoom"
	layer.add_child(help)
