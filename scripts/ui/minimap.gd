class_name Minimap
extends Control

## Minimap widget showing the island, fog of war, territories, and key locations.
## Placed in the bottom right corner of the HUD, redraws whenever the map changes.

const MINIMAP_SIZE := Vector2(170, 170)

var _gs = null


func _init() -> void:
	custom_minimum_size = MINIMAP_SIZE
	mouse_filter = MOUSE_FILTER_PASS


func setup(gs) -> void:
	_gs = gs
	if not _gs.map_changed.is_connected(queue_redraw):
		_gs.map_changed.connect(queue_redraw)
	if not _gs.turn_advanced.is_connected(queue_redraw):
		_gs.turn_advanced.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	# Background and frame
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UITheme.LEATHER, true)
	draw_rect(rect, UITheme.BRASS_DEEP, false, 1.0)

	if _gs == null or not ("tiles" in _gs):
		return

	var center := size * 0.5
	var max_extent := float(MapBuilder.MAP_RADIUS) * HexGrid.HEX_RADIUS * HexGrid.SQRT3
	var scale_factor: float = (size.x * 0.44) / max_extent

	for cell in _gs.tiles:
		var terrain: GameData.Terrain = _gs.tiles[cell]
		var world_pos := HexGrid.axial_to_world(cell.x, cell.y)
		var pt := center + Vector2(world_pos.x * scale_factor, world_pos.z * scale_factor)

		var color: Color
		var radius := 1.8

		if terrain == GameData.Terrain.FOG:
			# Fog is uniformly dark on the minimap (no spoilers)
			color = Color(0.13, 0.11, 0.10, 0.95)
			radius = 1.4
		elif terrain == GameData.Terrain.OCEAN:
			color = Color(0.18, 0.28, 0.38)
			radius = 1.4
		elif _gs.is_ai_territory(cell):
			color = UITheme.ENEMY
			radius = 2.2
		elif _gs.is_owned(cell):
			color = UITheme.BRASS_BRIGHT
			radius = 2.0
		elif cell == MapBuilder.TOWN_CELL:
			color = UITheme.BRASS_BRIGHT
			radius = 2.8
		else:
			color = MapBuilder.TERRAIN_TINT.get(terrain, Color(0.5, 0.45, 0.4))

		draw_circle(pt, radius, color)

	# Town marker highlight
	var town_pos := HexGrid.axial_to_world(MapBuilder.TOWN_CELL.x, MapBuilder.TOWN_CELL.y)
	var town_pt := center + Vector2(town_pos.x * scale_factor, town_pos.z * scale_factor)
	draw_circle(town_pt, 3.2, UITheme.BRASS_BRIGHT)
	draw_circle(town_pt, 1.6, UITheme.INK)
