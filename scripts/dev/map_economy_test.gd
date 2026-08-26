extends SceneTree

## Checks the generated Dustfall region against the economy: counts each terrain,
## verifies the fog layer, prints the resulting production, and asserts the map is
## actually playable (it produces the resources the design says it should).
##
## godot --headless --path . --script res://scripts/dev/map_economy_test.gd

const EXPECTED_CHECKS := 25

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")
	gs.start_new_game(18720412)

	var full := MapBuilder.full_terrain()
	var expected_cells := 3 * MapBuilder.MAP_RADIUS * (MapBuilder.MAP_RADIUS + 1) + 1

	print("\n[1] Slozeni cele oblasti (%d dlazdic)" % full.size())
	var counts := _count(full)
	for terrain in GameData.Terrain.values():
		var n := int(counts.get(terrain, 0))
		if n > 0:
			print("  %-22s %d" % [GameData.TERRAIN_NAMES[terrain], n])

	_check("pocet dlazdic pro polomer %d" % MapBuilder.MAP_RADIUS, full.size(), expected_cells)
	_check("prave jedno mesto", int(counts.get(GameData.Terrain.TOWN, 0)), 1)
	_check("existuje oceán na okraji ostrova", int(counts.get(GameData.Terrain.OCEAN, 0)) > 0, true)
	_check("existuje zeleznice", int(counts.get(GameData.Terrain.RAILWAY, 0)) > 0, true)
	_check("existuje reka", int(counts.get(GameData.Terrain.RIVER, 0)) > 0, true)
	_check("existuji hory", int(counts.get(GameData.Terrain.MOUNTAIN, 0)) > 0, true)
	_check("existuje poust", int(counts.get(GameData.Terrain.DESERT, 0)) > 0, true)
	_check("vsechny doly rozmisteny", int(counts.get(GameData.Terrain.MINE, 0)),
		MapBuilder.MINE_CELLS.size())
	_check("existuje uzemi H-V", int(counts.get(GameData.Terrain.ENEMY, 0)) > 0, true)
	_check("v cele oblasti neni mlha", int(counts.get(GameData.Terrain.FOG, 0)), 0)
	_check("generovani mapy je deterministicke", MapBuilder.full_terrain().size() == full.size(), true)

	# Etapa 1c audit: 4 kontroly, co zadani chtelo a puvodne nedostaly misto.
	var ocean_near_edge := true
	for cell in full:
		if full[cell] == GameData.Terrain.OCEAN and HexGrid.distance(cell, MapBuilder.TOWN_CELL) < 13:
			ocean_near_edge = false
			break
	_check("ocean je jen blizko okraje ostrova, nezasahuje hluboko dovnitr", ocean_near_edge, true)

	var owned_count := int(counts.get(GameData.Terrain.OWNED, 0))
	var core_disk_area := 3 * MapBuilder.OWNED_RADIUS_CORE * (MapBuilder.OWNED_RADIUS_CORE + 1) + 1
	_check("vlastnene uzemi je vetsi nez ciste jadro (neni to pravidelny disk)",
		owned_count > core_disk_area, true)

	var full_again := MapBuilder.full_terrain()
	var content_same := full_again.size() == full.size()
	if content_same:
		for cell in full:
			if not full_again.has(cell) or full_again[cell] != full[cell]:
				content_same = false
				break
	_check("generovani mapy je deterministicke i obsahem, ne jen poctem", content_same, true)

	_check("zeleznice je klikata cesta, ne rovna cara",
		_has_direction_change(MapBuilder.railway_cells()), true)
	_check("reka je klikata cesta, ne rovna cara",
		_has_direction_change(MapBuilder.river_cells()), true)

	print("\n[2] Mlha na zacatku hry")
	var visible_counts := _count(gs.tiles)
	var fogged := int(visible_counts.get(GameData.Terrain.FOG, 0))
	print("  viditelnych %d, zamlzenych %d, skrytych zaznamu %d" % [
		gs.tiles.size() - fogged, fogged, gs.hidden_tiles.size()
	])
	_check("kazda mlha ma skryty teren", gs.hidden_tiles.size(), fogged)
	_check("neco je zamlzeneho", fogged > 0, true)
	_check("mesto neni pod mlhou", gs.get_tile(MapBuilder.TOWN_CELL), GameData.Terrain.TOWN)

	var hidden_fog := 0
	for cell in gs.hidden_tiles:
		if gs.hidden_tiles[cell] == GameData.Terrain.FOG:
			hidden_fog += 1
	_check("pod mlhou neni dalsi mlha", hidden_fog, 0)

	print("\n[3] Ekonomika startovni mapy")
	var eco = gs.calculate_economy()
	for key in GameData.RESOURCES:
		print("  %-8s hruby %4d  spotreba %4d  cisty %+5d" % [
			key, eco["gross"][key], eco["consumption"][key], eco["net"][key]
		])

	_check("mapa produkuje zlato", eco["gross"]["gold"] > 0, true)
	_check("mapa produkuje jidlo", eco["gross"]["food"] > 0, true)
	_check("mapa produkuje drevo z owned", eco["gross"]["wood"] > 0, true)
	_check("Dustfall je sidlo urovne %d" % MapBuilder.TOWN_SETTLEMENT_LEVEL,
		gs.settlement_at(MapBuilder.TOWN_CELL), MapBuilder.TOWN_SETTLEMENT_LEVEL)
	_check("okoli mesta je v dosahu zasobovani", gs.in_supply(Vector2i(2, 0)), true)

	print("\n[4] Prvni tri tahy")
	gs.set_seed(99)
	gs.coach_in = 99
	for i in 3:
		var gold_before: int = gs.resources["gold"]
		var food_before: int = gs.resources["food"]
		gs.advance_turn()
		print("  tah %d: %s %d | zlato %d -> %d | jidlo %d -> %d | tech %d" % [
			gs.turn_count, gs.season, gs.year,
			gold_before, gs.resources["gold"],
			food_before, gs.resources["food"],
			gs.tech_points,
		])

	print("")
	if _ran < EXPECTED_CHECKS:
		print("SELHALO: probehlo jen %d z %d kontrol" % [_ran, EXPECTED_CHECKS])
		quit(1)
		return
	if _failures > 0:
		print("SELHALO: %d z %d kontrol" % [_failures, _ran])
		quit(1)
		return
	print("VSE OK (%d kontrol)" % _ran)
	quit(0)


func _has_direction_change(cells: Array) -> bool:
	var last_dir := Vector2i.ZERO
	for i in range(1, cells.size()):
		var d: Vector2i = cells[i] - cells[i - 1]
		if last_dir != Vector2i.ZERO and d != last_dir:
			return true
		last_dir = d
	return false


func _count(tiles: Dictionary) -> Dictionary:
	var counts := {}
	for cell in tiles:
		var t: int = tiles[cell]
		counts[t] = int(counts.get(t, 0)) + 1
	return counts


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-42s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-42s = %s (cekano %s)" % [label, actual, expected])
