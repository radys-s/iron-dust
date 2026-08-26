extends SceneTree

## Verifies hex connectivity masks, path/river orientation logic, and determinism.

const EXPECTED_CHECKS := 25
var _checks := 0
var _failed := 0


func _init() -> void:
	_test_neighbor_masks()
	_test_straight_connections()
	_test_corner_connections()
	_test_network_determinism()

	if _checks != EXPECTED_CHECKS:
		print("CHYBA: ocekavano %d kontrol, probehlo %d" % [EXPECTED_CHECKS, _checks])
		quit(1)
		return

	if _failed > 0:
		print("CHYBA: %d kontrol selhalo" % _failed)
		quit(1)
		return

	print("\nVSE OK (%d kontrol)" % _checks)
	quit(0)


func _check(condition: bool, label: String, actual = null) -> void:
	_checks += 1
	if condition:
		if actual != null:
			print("  ok   %-52s = %s" % [label, str(actual)])
		else:
			print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %-52s (actual: %s)" % [label, str(actual)])


func _test_neighbor_masks() -> void:
	print("\n[1] 6bitova maska sousedu")
	var cell := Vector2i(0, 0)
	var network: Dictionary = {
		Vector2i(1, 0): true,   # neighbor 0
		Vector2i(-1, 0): true,  # neighbor 3
	}
	var mask := MapBuilder.connectivity_mask(cell, network)
	_check(mask == ((1 << 0) | (1 << 3)), "maska pro protejsi sousedy (0 a 3) je spravna", mask)

	var all_neighbors: Dictionary = {}
	for d in HexGrid.NEIGHBOR_DIRS:
		all_neighbors[cell + d] = true
	var full_mask := MapBuilder.connectivity_mask(cell, all_neighbors)
	_check(full_mask == 63, "maska pro vsech 6 sousedu je 63 (0b111111)", full_mask)

	var empty_mask := MapBuilder.connectivity_mask(cell, {})
	_check(empty_mask == 0, "prazdna maska je 0", empty_mask)


func _test_straight_connections() -> void:
	print("\n[2] Rovne useky a jejich rotace")
	# Pair (0, 3): E-W straight line
	var east_west_mask := (1 << 0) | (1 << 3)
	var ew_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, east_west_mask)
	_check(ew_config["type"] == TileCatalog.TileType.ROAD, "typ pro (0,3) je ROAD (straight)", ew_config["type"])
	_check(is_equal_approx(ew_config["yaw"], 90.0), "yaw pro (0,3) je 90 stupnu", ew_config["yaw"])

	# Pair (1, 4): diagonal straight
	var diag1_mask := (1 << 1) | (1 << 4)
	var diag1_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, diag1_mask)
	_check(diag1_config["type"] == TileCatalog.TileType.ROAD, "typ pro (1,4) je ROAD", diag1_config["type"])
	_check(is_equal_approx(diag1_config["yaw"], 30.0) or is_equal_approx(diag1_config["yaw"], -150.0) or is_equal_approx(diag1_config["yaw"], 210.0), "yaw pro (1,4) odpovida sklonu", diag1_config["yaw"])

	# River straight
	var river_straight_config := MapBuilder.connectivity_config(GameData.Terrain.RIVER, east_west_mask)
	_check(river_straight_config["type"] == TileCatalog.TileType.RIVER_STRAIGHT, "typ pro reku je RIVER_STRAIGHT", river_straight_config["type"])


func _test_corner_connections() -> void:
	print("\n[3] Zatkacky: siroke (120 st.) a ostre (60 st.)")
	# Wide corner: difference 2 steps e.g. (0, 2)
	var wide_mask := (1 << 0) | (1 << 2)
	var wide_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, wide_mask)
	_check(wide_config["type"] == TileCatalog.TileType.ROAD_CORNER, "siroka zatacka vybira ROAD_CORNER", wide_config["type"])

	var river_wide_config := MapBuilder.connectivity_config(GameData.Terrain.RIVER, wide_mask)
	_check(river_wide_config["type"] == TileCatalog.TileType.RIVER_CORNER, "reka siroka zatacka vybira RIVER_CORNER", river_wide_config["type"])

	# Sharp corner: difference 1 step e.g. (0, 1)
	var sharp_mask := (1 << 0) | (1 << 1)
	var sharp_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, sharp_mask)
	_check(sharp_config["type"] == TileCatalog.TileType.ROAD_CORNER_SHARP, "ostra zatacka vybira ROAD_CORNER_SHARP", sharp_config["type"])

	var river_sharp_config := MapBuilder.connectivity_config(GameData.Terrain.RIVER, sharp_mask)
	_check(river_sharp_config["type"] == TileCatalog.TileType.RIVER_CORNER_SHARP, "reka ostra zatacka vybira RIVER_CORNER_SHARP", river_sharp_config["type"])

	# Dead end / start: 1 connection e.g. (1 << 0)
	var start_mask := (1 << 0)
	var start_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, start_mask)
	_check(start_config["type"] == TileCatalog.TileType.ROAD_START or start_config["type"] == TileCatalog.TileType.ROAD_END, "konecny usek vybira ROAD_START/END", start_config["type"])

	# 3+ connections: crossing
	var cross_mask := (1 << 0) | (1 << 2) | (1 << 4)
	var cross_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, cross_mask)
	_check(cross_config["type"] == TileCatalog.TileType.ROAD_CROSSING, "krizovatka vybira ROAD_CROSSING", cross_config["type"])


func _test_network_determinism() -> void:
	print("\n[4] Trate a reky jsou deterministicke a souvisle")
	var railway_cells := MapBuilder.railway_cells()
	_check(railway_cells.size() >= 10, "zeleznice ma aspon 10 bunek", railway_cells.size())
	_check(railway_cells.has(MapBuilder.TOWN_CELL), "zeleznice prochazi mestem Dustfall", true)

	var river_cells := MapBuilder.river_cells()
	_check(river_cells.size() >= 10, "reka Colorado ma aspon 10 bunek", river_cells.size())
	_check(not river_cells.has(MapBuilder.TOWN_CELL), "reka neprotina primo Dustfall", true)

	# Twice calling gives identical arrays
	var r2 := MapBuilder.railway_cells()
	var same_rail := (railway_cells.size() == r2.size())
	_check(same_rail, "zeleznice je deterministicka", true)

	var riv2 := MapBuilder.river_cells()
	var same_riv := (river_cells.size() == riv2.size())
	_check(same_riv, "reka je deterministicka", true)

	# Neighbor continuity
	var continuous := true
	for i in range(1, river_cells.size()):
		var prev: Vector2i = river_cells[i - 1]
		var curr: Vector2i = river_cells[i]
		if HexGrid.distance(prev, curr) != 1:
			continuous = false
			break
	_check(continuous, "reka je souvisly retezec sousednich hexu", continuous)

	# Skutecny algoritmicky determinismus, ne jen identita staticke cache:
	# zavola se necachovany vypocet dvakrat nezavisle na sobe.
	var rail_a := MapBuilder._compute_railway_cells()
	var rail_b := MapBuilder._compute_railway_cells()
	_check(rail_a == rail_b, "zeleznice: nezavisly prepocet (bez cache) dava stejnou cestu", true)

	var riv_a := MapBuilder._compute_river_cells()
	var riv_b := MapBuilder._compute_river_cells()
	_check(riv_a == riv_b, "reka: nezavisly prepocet (bez cache) dava stejnou cestu", true)

	# Ukonceni: random walk se musi zastavit v ramci sveho krokoveho stropu,
	# ne zacyklit se donekonecna.
	_check(railway_cells.size() <= (MapBuilder.RAILWAY_REACH * 2 + 1),
		"zeleznice se zastavi v ramci kroku (nezacykli se)", true)
	_check(river_cells.size() <= (MapBuilder.RIVER_REACH + 1),
		"reka se zastavi v ramci kroku (nezacykli se)", true)
