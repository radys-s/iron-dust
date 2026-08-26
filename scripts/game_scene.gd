extends Node3D

## Main play scene: owns the 3D world (terrain, props, structures, lighting,
## selection ring) and wires tile clicks to GameState and the HUD.

const MAP_SEED := 18720412

@onready var _rig: IsoCameraRig = $CameraRig
@onready var _hud: CanvasLayer = $GameHUD

var _world: Node3D
var _highlight: MeshInstance3D
var _placement_root: Node3D
var _selected: Vector2i = Vector2i.MAX

## Building waiting to be placed, or "" when not in placement mode.
var _pending_building := ""


func _ready() -> void:
	_build_environment()

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	_placement_root = Node3D.new()
	_placement_root.name = "PlacementHints"
	add_child(_placement_root)

	_build_highlight()

	_begin_session()
	MapBuilder.render(GameState, _world)

	GameState.map_changed.connect(_on_map_changed)
	GameState.game_loaded.connect(_on_game_loaded)
	_hud.build_requested.connect(_begin_placement)


## Rozhodne, s cim se do sceny vstupuje: novou partii v rezimu zvolenem
## v menu, nebo nactenym slotem. Menu bezi ve vlastni scene a nemuze partii
## zalozit samo — mapa se musi postavit az tady, kdyz uz existuje `_world`.
##
## Predavaci pole se hned nuluji, aby dalsi navrat do teto sceny (nova hra
## z overlaye konce hry) nezopakoval nactení stareho slotu.
func _begin_session() -> void:
	var slot := GameState.pending_load_slot
	var mode := GameState.pending_mode
	var tutorial := GameState.pending_tutorial

	GameState.pending_load_slot = 0
	GameState.pending_mode = ""
	GameState.pending_tutorial = false

	if slot > 0 and GameState.load_from_slot(slot):
		return

	GameState.start_new_game(MAP_SEED, mode)
	GameState.tutorial_active = tutorial


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE and _pending_building != "":
		_cancel_placement()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click_at(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and _pending_building != "":
			_cancel_placement()
			# Pravé tlačítko je od Etapy 1b výhradně zrušení/kontext (kameru
			# posouvá jen prostřední) — i tak si tenhle klik označíme jako
			# zpracovaný, ať v budoucnu nikdo jiný neposlouchá stejné tlačítko.
			get_viewport().set_input_as_handled()


func _click_at(screen_pos: Vector2) -> void:
	var ground := _rig.screen_to_ground(screen_pos)
	if ground == Vector3.INF:
		return
	var cell := HexGrid.world_to_axial(ground / MapBuilder.WORLD_SCALE)

	if _pending_building != "":
		_try_place(cell)
		return
	_select(cell)


func _select(cell: Vector2i) -> void:
	if not GameState.tiles.has(cell):
		_selected = Vector2i.MAX
		_highlight.visible = false
		_hud.hide_tile()
		return

	_selected = cell
	_move_highlight(cell)
	_hud.show_tile(cell)


func _move_highlight(cell: Vector2i) -> void:
	var center := HexGrid.axial_to_world(cell.x, cell.y) * MapBuilder.WORLD_SCALE
	_highlight.position = center + Vector3(0.0, (TileCatalog.TILE_TOP_Y + 0.02) * MapBuilder.WORLD_SCALE, 0.0)
	_highlight.visible = true


# --- Placement mode ----------------------------------------------------------

func _begin_placement(building_name: String) -> void:
	_pending_building = building_name
	_show_placement_hints()
	GameState.notify("Vyberte dlaždici pro stavbu: %s (Esc zruší)" % building_name, "info")


func _cancel_placement() -> void:
	if _pending_building == "":
		return
	_pending_building = ""
	_clear_placement_hints()
	GameState.notify("Stavba zrušena.", "info")


func _try_place(cell: Vector2i) -> void:
	var building_name := _pending_building
	if not GameState.tiles.has(cell):
		return

	var placement: Dictionary = GameState.can_build_at(cell)
	if not bool(placement["ok"]):
		GameState.notify(String(placement["reason"]), "warning")
		return

	# Leave placement mode first: a successful build re-renders the world, and a
	# stale hint layer would survive that redraw.
	_pending_building = ""
	_clear_placement_hints()

	if GameState.build(building_name, cell):
		_select(cell)


## Marks every hex the pending building could legally go on.
func _show_placement_hints() -> void:
	_clear_placement_hints()

	var mesh := CylinderMesh.new()
	mesh.top_radius = HexGrid.HEX_RADIUS * 0.82 * MapBuilder.WORLD_SCALE
	mesh.bottom_radius = HexGrid.HEX_RADIUS * 0.82 * MapBuilder.WORLD_SCALE
	mesh.height = 0.02 * MapBuilder.WORLD_SCALE
	mesh.radial_segments = 6

	var mat := StandardMaterial3D.new()
	# Cyan, not green: buildable land *is* green pasture, and a green overlay on
	# it was invisible.
	mat.albedo_color = Color(0.35, 0.85, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.30, 0.75, 0.95)
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

	for cell in GameState.tiles:
		if not bool(GameState.can_build_at(cell)["ok"]):
			continue
		var hint := MeshInstance3D.new()
		hint.mesh = mesh
		var terrain: GameData.Terrain = GameState.tiles[cell]
		var height := (TileCatalog.rim_height(MapBuilder.TERRAIN_MESH[terrain]) + 0.03) * MapBuilder.WORLD_SCALE
		hint.position = HexGrid.axial_to_world(cell.x, cell.y) * MapBuilder.WORLD_SCALE + Vector3(0.0, height, 0.0)
		# A 6-segment cylinder points along +X; Kenney's hexes are pointy-top.
		hint.rotation.y = deg_to_rad(30.0)
		_placement_root.add_child(hint)


func _clear_placement_hints() -> void:
	for child in _placement_root.get_children():
		_placement_root.remove_child(child)
		child.queue_free()


# --- State signals -----------------------------------------------------------

func _on_map_changed() -> void:
	MapBuilder.render(GameState, _world)
	if _pending_building != "":
		_show_placement_hints()


func _on_game_loaded() -> void:
	_cancel_placement()
	_selected = Vector2i.MAX
	_highlight.visible = false
	_hud.hide_tile()
	MapBuilder.render(GameState, _world)


# --- World construction ------------------------------------------------------

func _build_highlight() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = HexGrid.HEX_RADIUS * 0.86 * MapBuilder.WORLD_SCALE
	ring.outer_radius = HexGrid.HEX_RADIUS * 0.94 * MapBuilder.WORLD_SCALE
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
	# Nízké odpolední slunce ze západu — dlouhé stíny čitelně modelují terén
	# a je to hodina, kterou má western v hlavě.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -135.0, 0.0)
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.87, 0.68)
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.105, 0.082, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Odražené světlo z prachu je teplé, ne neutrální — modré stíny by celý
	# efekt vysušené krajiny zrušily.
	env.ambient_light_color = Color(0.62, 0.50, 0.38)
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.38, 0.26)
	env.fog_density = 0.006
	# Kenney maluje bujnou zeleň; tohle ji stáhne do vyprahlé Nevady roku 1872.
	# Saturace níž než dřív (0.62) — na screenshotu byla krajina pořád smaragdová.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.42
	env.adjustment_contrast = 1.14
	env.adjustment_brightness = 1.02

	# Jemné záření na mosazi v UI i na obrysech území; bez něj působí obraz plochý.
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
