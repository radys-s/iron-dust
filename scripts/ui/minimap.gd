class_name Minimap
extends Control

## Mezifáze 2: minimapa ve stylu Settlers/AoE2 — rámeček viditelné oblasti
## kamery, klik/tažení pro rychlý přesun pohledu, zvětšené splývající tečky
## území, rám přes sdílený UITheme styl. Beze skutečného flood-fill polygonu
## (mimo rozsah), jen vizuálně hustší dojem plochy.

const MINIMAP_SIZE := Vector2(170, 170)

var _gs = null
var _camera_rig: IsoCameraRig = null
var _last_rig_position := Vector3.INF
var _last_rig_zoom := -1.0


func _init() -> void:
	custom_minimum_size = MINIMAP_SIZE
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true


func setup(gs) -> void:
	_gs = gs
	if not _gs.map_changed.is_connected(queue_redraw):
		_gs.map_changed.connect(queue_redraw)
	if not _gs.turn_advanced.is_connected(queue_redraw):
		_gs.turn_advanced.connect(queue_redraw)
	queue_redraw()


## Kamera potřebná na rámeček viditelné oblasti a na klik/tažení-k-přesunu
## (IsoCameraRig.center_on()/screen_to_ground()).
func set_camera_rig(rig: IsoCameraRig) -> void:
	_camera_rig = rig
	queue_redraw()


func _process(_delta: float) -> void:
	if _camera_rig == null:
		return
	if _camera_rig.position != _last_rig_position or _camera_rig.zoom_size != _last_rig_zoom:
		_last_rig_position = _camera_rig.position
		_last_rig_zoom = _camera_rig.zoom_size
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _camera_rig == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_recenter_on(event.position)
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_recenter_on(event.position)
		accept_event()


func _recenter_on(local_pos: Vector2) -> void:
	var scale_factor := _scale_factor()
	if scale_factor <= 0.0:
		return
	var offset := local_pos - size * 0.5
	_camera_rig.center_on(Vector2(offset.x / scale_factor, offset.y / scale_factor))


func _scale_factor() -> float:
	var max_extent := float(MapBuilder.MAP_RADIUS) * HexGrid.HEX_RADIUS * HexGrid.SQRT3
	if max_extent <= 0.0:
		return 0.0
	return (size.x * 0.44) / max_extent


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	UITheme.panel_style(UITheme.LEATHER, UITheme.BRASS, 0.75).draw(get_canvas_item(), rect)
	if _gs == null or not ("tiles" in _gs):
		return

	var center := size * 0.5
	var scale_factor := _scale_factor()
	for cell in _gs.tiles:
		var terrain: GameData.Terrain = _gs.tiles[cell]
		var world_pos := HexGrid.axial_to_world(cell.x, cell.y)
		var pt := center + Vector2(world_pos.x * scale_factor, world_pos.z * scale_factor)
		var color: Color
		var radius := 1.8
		if terrain == GameData.Terrain.FOG:
			color = Color(0.13, 0.11, 0.10, 0.95); radius = 1.4
		elif terrain == GameData.Terrain.OCEAN:
			color = Color(0.18, 0.28, 0.38); radius = 1.4
		elif _gs.is_ai_territory(cell):
			color = UITheme.ENEMY; radius = 2.8
		elif _gs.is_owned(cell):
			color = UITheme.BRASS_BRIGHT; radius = 2.6
		elif cell == MapBuilder.TOWN_CELL:
			color = UITheme.BRASS_BRIGHT; radius = 2.8
		else:
			color = MapBuilder.TERRAIN_TINT.get(terrain, Color(0.5, 0.45, 0.4))
		draw_circle(pt, radius, color)

	var town_pos := HexGrid.axial_to_world(MapBuilder.TOWN_CELL.x, MapBuilder.TOWN_CELL.y)
	var town_pt := center + Vector2(town_pos.x * scale_factor, town_pos.z * scale_factor)
	draw_circle(town_pt, 3.2, UITheme.BRASS_BRIGHT)
	draw_circle(town_pt, 1.6, UITheme.INK)

	_draw_camera_frame(center, scale_factor)


## Obrys viditelné oblasti kamery — 4 rohy viewportu promítnuté na zemní
## rovinu (IsoCameraRig.screen_to_ground(), stejná projekce jako kliky na
## mapě) a přepočtené stejným vzorcem jako tečky výše.
func _draw_camera_frame(center: Vector2, scale_factor: float) -> void:
	if _camera_rig == null or scale_factor <= 0.0:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen_size := viewport.get_visible_rect().size
	var corners_screen := [
		Vector2.ZERO, Vector2(screen_size.x, 0.0),
		screen_size, Vector2(0.0, screen_size.y),
	]
	var points := PackedVector2Array()
	for corner in corners_screen:
		var ground := _camera_rig.screen_to_ground(corner)
		if ground == Vector3.INF:
			return
		points.append(center + Vector2(ground.x * scale_factor, ground.z * scale_factor))
	points.append(points[0])
	draw_polyline(points, UITheme.BRASS_BRIGHT, 1.4, true)
