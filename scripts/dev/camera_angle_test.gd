extends Node3D

## Dev scene: compares 35.264 deg ("true" isometric) against 30 deg (dimetric,
## the more common look) on real terrain geometry. Space toggles between them.

const ANGLES := [
	{"pitch": -35.264, "label": "35.264 (true isometric)"},
	{"pitch": -30.0, "label": "30.0 (dimetric)"},
]
const YAW_DEG := -45.0
const CAMERA_DISTANCE := 40.0
const ORTHO_SIZE := 4.5

var _index := 0
var _rig: Node3D
var _camera: Camera3D
var _label: Label


func _ready() -> void:
	_build_environment()
	_build_camera()
	_build_terrain_sample()
	_build_hud()
	_apply_angle()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_index = (_index + 1) % ANGLES.size()
			_apply_angle()


func _apply_angle() -> void:
	var entry: Dictionary = ANGLES[_index]
	_rig.rotation_degrees = Vector3(entry["pitch"], YAW_DEG, 0.0)
	_label.text = "Uhel kamery: %s\n[mezernik] = prepnout" % entry["label"]
	print("[camera_angle_test] pitch = %s" % entry["label"])


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	add_child(_rig)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ORTHO_SIZE
	_camera.near = 0.05
	_camera.far = 200.0
	_camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	_rig.add_child(_camera)
	_camera.current = true


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -140.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.09, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.48, 0.42)
	env.ambient_light_energy = 0.55

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


## A short strip of contrasting terrain so the angle difference is readable on
## real geometry (flat tiles plus something tall) rather than on primitives.
func _build_terrain_sample() -> void:
	var layout := [
		{"q": -1, "r": 0, "type": TileCatalog.TileType.SAND_DESERT},
		{"q": 0, "r": 0, "type": TileCatalog.TileType.GRASS},
		{"q": 1, "r": 0, "type": TileCatalog.TileType.STONE_MOUNTAIN},
		{"q": -1, "r": 1, "type": TileCatalog.TileType.SAND},
		{"q": 0, "r": 1, "type": TileCatalog.TileType.GRASS_HILL},
		{"q": 0, "r": -1, "type": TileCatalog.TileType.WATER},
		{"q": 1, "r": -1, "type": TileCatalog.TileType.SAND_ROCKS},
	]
	var root := Node3D.new()
	root.name = "TerrainSample"
	add_child(root)

	for cell in layout:
		var tile := TileCatalog.terrain_scene(cell["type"]).instantiate()
		tile.position = HexGrid.axial_to_world(cell["q"], cell["r"])
		root.add_child(tile)

	var cactus := TileCatalog.prop_scene("cactus_tall").instantiate()
	cactus.position = HexGrid.axial_to_world(-1, 0) + Vector3(0.0, TileCatalog.TILE_TOP_Y, 0.0)
	root.add_child(cactus)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.42))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_label)
