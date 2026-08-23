extends Node3D

## Main play scene: owns the 3D world (terrain, props, lighting, selection ring)
## and wires tile clicks to GameState / the HUD.

const MAP_SEED := 18720412

@onready var _rig: IsoCameraRig = $CameraRig
@onready var _hud: CanvasLayer = $GameHUD

var _terrain_root: Node3D
var _prop_root: Node3D
var _highlight: MeshInstance3D
var _selected: Vector2i = Vector2i.MAX
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = MAP_SEED
	GameState.set_seed(MAP_SEED)

	_build_environment()
	_build_roots()
	_build_highlight()

	GameState.load_tiles(MapBuilder.generate_terrain(_rng))
	MapBuilder.render(GameState.tiles, _terrain_root, _prop_root, _rng)

	GameState.map_changed.connect(_on_map_changed)
	GameState.add_story("Přijezd do Dustfallu. Otevřena dopravní stanice.")


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
	if not GameState.tiles.has(cell):
		_selected = Vector2i.MAX
		_highlight.visible = false
		_hud.hide_tile()
		return

	_selected = cell
	var center := HexGrid.axial_to_world(cell.x, cell.y)
	_highlight.position = center + Vector3(0.0, TileCatalog.TILE_TOP_Y + 0.02, 0.0)
	_highlight.visible = true
	_hud.show_tile(cell, GameState.get_tile(cell))


func _on_map_changed() -> void:
	MapBuilder.render(GameState.tiles, _terrain_root, _prop_root, _rng)


func _build_roots() -> void:
	_terrain_root = Node3D.new()
	_terrain_root.name = "Terrain"
	add_child(_terrain_root)

	_prop_root = Node3D.new()
	_prop_root.name = "Props"
	add_child(_prop_root)


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
	# Tall tiles (mountains reach ~1.08) would otherwise swallow a ring sitting at
	# ground level, leaving a selected peak with no visible marker.
	mat.no_depth_test = true
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
	# Kenney's palette is lush; pull it toward a sun-bleached 1872 Nevada.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.62
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.04

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
