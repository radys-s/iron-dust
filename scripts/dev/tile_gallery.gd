extends Node3D

## Dev scene: lays out every mesh in TileCatalog side by side so the mapping in
## MapBuilder.TERRAIN_MESH can be judged by looking rather than by guessing.
## Handy again whenever the placeholder art gets re-skinned.
##
## Screenshot it with:
##   --script res://scripts/dev/screenshot.gd -- res://scenes/dev/tile_gallery.tscn out.png 60

const SPACING := 1.20
const ROW_SPACING := 1.35
const PER_ROW := 6

## Extra meshes that are not wired into the game yet but are candidates for it.
const CANDIDATES := {
	"?wall": "res://assets/kenney/hexagon-kit/building-wall.glb",
	"?walls": "res://assets/kenney/hexagon-kit/building-walls.glb",
	"?lumber": "res://assets/kenney/hexagon-kit/dirt-lumber.glb",
}


var _index := 0


func _ready() -> void:
	_build_environment()

	for type in TileCatalog.TileType.values():
		_place(TileCatalog.terrain_scene(type).instantiate(),
			TileCatalog.TileType.keys()[type])

	for level in range(1, GameData.SETTLEMENT_MAX_LEVEL + 1):
		_place(TileCatalog.settlement_scene(level).instantiate(),
			"%d %s" % [level, GameData.settlement_name(level)])

	for name in TileCatalog.BUILDING_PATHS:
		_place(TileCatalog.building_scene(name).instantiate(), name)

	for name in CANDIDATES:
		_place((load(CANDIDATES[name]) as PackedScene).instantiate(), name)

	# The camera can only be framed once the final tile count is known.
	_build_camera()


func _place(node: Node3D, caption: String) -> void:
	var origin := _slot(_index)
	_index += 1

	node.position = origin
	add_child(node)

	var label := Label3D.new()
	label.text = caption
	label.font_size = 64
	label.pixel_size = 0.0022
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = origin + Vector3(0.0, 1.25, 0.0)
	label.modulate = Color(1.0, 0.92, 0.72)
	label.outline_size = 16
	label.outline_modulate = Color(0.05, 0.04, 0.03)
	add_child(label)


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
	arm.rotation_degrees = Vector3(-35.264, 0.0, 0.0)
	pivot.add_child(arm)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# The grid is turned 45° to the camera, so its screen-vertical extent is the
	# rotated diagonal foreshortened by the isometric pitch.
	camera.size = (width + depth) / sqrt(2.0) * 0.6 + 2.2
	camera.position = Vector3(0.0, 0.0, 30.0)
	camera.current = true
	arm.add_child(camera)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -140.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.93, 0.79)
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.10, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.50, 0.42)
	env.ambient_light_energy = 0.5

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
