extends Node3D

## Dev scene: lays out every railway/river connectivity mask (straight both
## diagonals, wide corner both branches, sharp corner both branches, dead end,
## crossing with/without an opposite pair) so the yaw picked by
## MapBuilder.connectivity_config() can be checked against real mesh geometry
## by looking, not guessing. Each active mask direction gets a bright red
## marker at the true hex-edge midpoint — a correctly-rotated piece should
## visually reach toward every marker.
##
## Screenshot it with:
##   --script res://scripts/dev/screenshot.gd -- res://scenes/dev/connectivity_gallery.tscn out.png 60

const SPACING := 1.7
const ROW_SPACING := 1.9
const PER_ROW := 5

const CASES := [
	{"name": "straight EW", "mask": (1 << 0) | (1 << 3)},
	{"name": "straight diag", "mask": (1 << 1) | (1 << 4)},
	{"name": "wide corner (0,2)", "mask": (1 << 0) | (1 << 2)},
	{"name": "wide corner (0,4)", "mask": (1 << 0) | (1 << 4)},
	{"name": "sharp corner (0,1)", "mask": (1 << 0) | (1 << 1)},
	{"name": "sharp corner (0,5)", "mask": (1 << 0) | (1 << 5)},
	{"name": "dead end (0)", "mask": (1 << 0)},
	{"name": "crossing no pair", "mask": (1 << 0) | (1 << 2) | (1 << 4)},
	{"name": "crossing w/ pair", "mask": (1 << 0) | (1 << 2) | (1 << 5)},
]

var _index := 0


func _ready() -> void:
	_build_environment()

	for terrain in [GameData.Terrain.RAILWAY, GameData.Terrain.RIVER]:
		var terrain_name := "RAIL" if terrain == GameData.Terrain.RAILWAY else "RIVER"
		for case in CASES:
			_place(terrain, terrain_name, case["name"], case["mask"])

	_build_camera()


func _place(terrain: GameData.Terrain, terrain_name: String, case_name: String, mask: int) -> void:
	var origin := _slot(_index)
	_index += 1

	var cfg := MapBuilder.connectivity_config(terrain, mask)
	var tile: Node3D = TileCatalog.terrain_scene(cfg["type"]).instantiate()
	tile.position = origin
	tile.rotation.y = deg_to_rad(cfg["yaw"])
	add_child(tile)

	for i in range(6):
		if (mask & (1 << i)) == 0:
			continue
		var angle: float = MapBuilder._EDGE_ANGLES_DEG[i]
		var corner_a: Vector3 = MapBuilder._hex_corner(origin, angle - 30.0)
		var corner_b: Vector3 = MapBuilder._hex_corner(origin, angle + 30.0)
		var mid := (corner_a + corner_b) * 0.5
		_place_marker(mid)

	var label := Label3D.new()
	label.text = "%s\n%s" % [terrain_name, case_name]
	label.font_size = 48
	label.pixel_size = 0.0022
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = origin + Vector3(0.0, 1.0, 0.0)
	label.modulate = Color(1.0, 0.92, 0.72)
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.04, 0.03)
	add_child(label)


func _place_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1)
	mat.emission_energy_multiplier = 1.5
	marker.material_override = mat
	marker.position = pos + Vector3(0.0, 0.3, 0.0)
	add_child(marker)


func _slot(index: int) -> Vector3:
	return Vector3(
		(float(index % PER_ROW) - float(PER_ROW - 1) * 0.5) * SPACING,
		0.0,
		float(index / PER_ROW) * ROW_SPACING
	)


func _build_camera() -> void:
	var rows := int(ceil(float(_index) / float(PER_ROW)))
	var width := float(PER_ROW) * SPACING
	var depth := float(rows) * ROW_SPACING

	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, float(rows - 1) * ROW_SPACING * 0.5)
	pivot.rotation_degrees = Vector3(0.0, -45.0, 0.0)
	add_child(pivot)

	var arm := Node3D.new()
	arm.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	pivot.add_child(arm)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (width + depth) / sqrt(2.0) * 0.6 + 2.0
	camera.position = Vector3(0.0, 0.0, 30.0)
	camera.current = true
	arm.add_child(camera)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -140.0, 0.0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.85)
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.ambient_light_energy = 0.55

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
