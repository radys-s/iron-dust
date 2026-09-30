extends SceneTree

## Verifies hex connectivity masks, path/river orientation logic, and determinism.

const EXPECTED_CHECKS := 50
var _checks := 0
var _failed := 0


func _init() -> void:
	_test_neighbor_masks()
	_test_straight_connections()
	_test_corner_connections()
	_test_network_determinism()
	_test_mezifaze2_camera_and_border()
	_test_mezifaze3_yaw_fix_and_fences()

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
	_check(is_equal_approx(ew_config["yaw"], 0.0), "yaw pro (0,3) je 0 (nativni osa rovneho dilu, geometrie .glb)", ew_config["yaw"])

	# Pair (1, 4): diagonal straight
	var diag1_mask := (1 << 1) | (1 << 4)
	var diag1_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, diag1_mask)
	_check(diag1_config["type"] == TileCatalog.TileType.ROAD, "typ pro (1,4) je ROAD", diag1_config["type"])
	_check(is_equal_approx(diag1_config["yaw"], 60.0), "yaw pro (1,4) je 60 stupnu", diag1_config["yaw"])

	# River straight
	var river_straight_config := MapBuilder.connectivity_config(GameData.Terrain.RIVER, east_west_mask)
	_check(river_straight_config["type"] == TileCatalog.TileType.RIVER_STRAIGHT, "typ pro reku je RIVER_STRAIGHT", river_straight_config["type"])


func _test_corner_connections() -> void:
	print("\n[3] Zatkacky: siroke (120 st.) a ostre (60 st.)")
	# Wide corner: difference 2 steps e.g. (0, 2)
	var wide_mask := (1 << 0) | (1 << 2)
	var wide_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, wide_mask)
	_check(wide_config["type"] == TileCatalog.TileType.ROAD_CORNER, "siroka zatacka vybira ROAD_CORNER", wide_config["type"])
	_check(is_equal_approx(wide_config["yaw"], -60.0), "yaw pro sirokou zatacku (0,2) je -60 stupnu", wide_config["yaw"])

	var river_wide_config := MapBuilder.connectivity_config(GameData.Terrain.RIVER, wide_mask)
	_check(river_wide_config["type"] == TileCatalog.TileType.RIVER_CORNER, "reka siroka zatacka vybira RIVER_CORNER", river_wide_config["type"])

	# Sharp corner: difference 1 step e.g. (0, 1)
	var sharp_mask := (1 << 0) | (1 << 1)
	var sharp_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, sharp_mask)
	_check(sharp_config["type"] == TileCatalog.TileType.ROAD_CORNER_SHARP, "ostra zatacka vybira ROAD_CORNER_SHARP", sharp_config["type"])
	_check(is_equal_approx(sharp_config["yaw"], -120.0), "yaw pro ostrou zatacku (0,1) je -120 stupnu", sharp_config["yaw"])

	var river_sharp_config := MapBuilder.connectivity_config(GameData.Terrain.RIVER, sharp_mask)
	_check(river_sharp_config["type"] == TileCatalog.TileType.RIVER_CORNER_SHARP, "reka ostra zatacka vybira RIVER_CORNER_SHARP", river_sharp_config["type"])

	# Dead end / start: 1 connection e.g. (1 << 0)
	var start_mask := (1 << 0)
	var start_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, start_mask)
	_check(start_config["type"] == TileCatalog.TileType.ROAD_START or start_config["type"] == TileCatalog.TileType.ROAD_END, "konecny usek vybira ROAD_START/END", start_config["type"])
	_check(is_equal_approx(start_config["yaw"], -180.0), "yaw pro konecny usek (dir 0) je -180 stupnu", start_config["yaw"])

	# 3+ connections: crossing bez protejsiho paru (0,2,4) -> fallback na nejnizsi bit
	var cross_mask := (1 << 0) | (1 << 2) | (1 << 4)
	var cross_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, cross_mask)
	_check(cross_config["type"] == TileCatalog.TileType.ROAD_CROSSING, "krizovatka vybira ROAD_CROSSING", cross_config["type"])
	_check(is_equal_approx(cross_config["yaw"], 0.0), "krizovatka bez paru pouzije nejnizsi bit (0 stupnu)", cross_config["yaw"])

	# 3+ connections: crossing S protejsim parem (0,2,5 — 2 a 5 jsou protejsi) -> srovna se s primym usekem
	var paired_mask := (1 << 0) | (1 << 2) | (1 << 5)
	var paired_config := MapBuilder.connectivity_config(GameData.Terrain.RAILWAY, paired_mask)
	_check(is_equal_approx(paired_config["yaw"], 120.0), "krizovatka s protejsim parem srovna osu (120 stupnu)", paired_config["yaw"])


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

	# Meandrove rozsireni nesmi zkreslit masku sousedu jadra reky
	var widen_clean := true
	var widen_is_river := true
	for w in MapBuilder._cached_river_widen:
		if MapBuilder._cached_river_dict.has(w):
			widen_clean = false
		var t := MapBuilder.base_terrain(w)
		if t != GameData.Terrain.RIVER and t != GameData.Terrain.RAILWAY and t != GameData.Terrain.TOWN and t != GameData.Terrain.OCEAN and t != GameData.Terrain.MINE:
			widen_is_river = false
	_check(not MapBuilder._cached_river_widen.is_empty(), "reka ma nejake meandrove rozsireni", MapBuilder._cached_river_widen.size())
	_check(widen_clean, "rozsireni neni v jadru reky (nepocita se do masky)", true)
	_check(widen_is_river, "rozsireni je gameplayove RIVER (pokud jej nepřebije jiný terén)", true)

	# Ukonceni: random walk se musi zastavit v ramci sveho krokoveho stropu,
	# ne zacyklit se donekonecna.
	_check(railway_cells.size() <= (MapBuilder.RAILWAY_REACH * 2 + 1),
		"zeleznice se zastavi v ramci kroku (nezacykli se)", true)
	_check(river_cells.size() <= (MapBuilder.RIVER_REACH + 1),
		"reka se zastavi v ramci kroku (nezacykli se)", true)


## Mezifaze 2: _clamp_position()/PAN_BOUND_RADIUS jako cista funkce (meze
## kamery) a _add_contested_edge() jako presny, ne zdvojeny pocet segmentu
## (oprava problikavani sporne hranice hrac-vs-Voss).
func _test_mezifaze2_camera_and_border() -> void:
	print("\n[5] Meze kamery a dedup sporne hranice (Mezifaze 2)")

	var rig := IsoCameraRig.new()
	var inside := Vector3(1.0, 5.0, 1.0)
	var clamped_inside: Vector3 = rig._clamp_position(inside)
	_check(clamped_inside == inside, "pozice uvnitr polomeru zustava nedotcena", clamped_inside)

	var far := Vector3(100.0, 5.0, 0.0)
	var clamped_far: Vector3 = rig._clamp_position(far)
	var clamped_len := Vector2(clamped_far.x, clamped_far.z).length()
	_check(is_equal_approx(clamped_len, IsoCameraRig.PAN_BOUND_RADIUS),
		"pozice mimo polomer se orizne presne na PAN_BOUND_RADIUS", clamped_len)
	_check(is_equal_approx(clamped_far.y, far.y), "orez nemeni vysku Y", clamped_far.y)
	rig.free()

	var overlay := Node3D.new()
	MapBuilder._add_contested_edge(overlay, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 0.1,
		MapBuilder._border_mesh(), MapBuilder._owned_material(), MapBuilder._enemy_material(),
		MapBuilder._owned_glow_material_get(), MapBuilder._enemy_glow_material_get())
	_check(overlay.get_child_count() == MapBuilder.CONTESTED_DASH_COUNT * 2,
		"sporna hrana vyrobi presne CONTESTED_DASH_COUNT*2 segmentu, ne dvojnasobek",
		overlay.get_child_count())
	overlay.free()


## Mezifaze 3: sign fix rotace (_world_yaw/_crossing_yaw), skladba plotu podle
## masky (_pasture_fence_pieces), rim_height pro Vossovo uzemi (plovouci
## stiny) a bucketovany sum mesh variant (mapa "na sebe nenavazuje").
func _test_mezifaze3_yaw_fix_and_fences() -> void:
	print("\n[6] Sign fix rotace, skladba plotu, rim_height a bucketovany sum (Mezifaze 3)")

	_check(MapBuilder._world_yaw(90.0) == -90.0, "_world_yaw neguje uhel", MapBuilder._world_yaw(90.0))
	# Plot: sloupek na kazdem UNIKATNIM vrcholu hranice, i na prechodech mezi sousedy
	var single := MapBuilder._pasture_boundary({Vector2i(0, 0): true})
	_check(single["edges"].size() == 6 and single["posts"].size() == 6, "osamela bunka = 6 hran + 6 sloupku", single["posts"].size())
	var pair := MapBuilder._pasture_boundary({Vector2i(0, 0): true, Vector2i(1, 0): true})
	_check(pair["edges"].size() == 10 and pair["posts"].size() == 10, "dve sousedici bunky = 10 hran, 10 sloupku (sdilene vrcholy se nezdvoji)", pair["posts"].size())
	var flower_cells := {Vector2i(0, 0): true}
	for d in HexGrid.NEIGHBOR_DIRS:
		flower_cells[Vector2i(0, 0) + d] = true
	var flower := MapBuilder._pasture_boundary(flower_cells)
	_check(flower["edges"].size() == 18 and flower["posts"].size() == 18, "sedmicka hexu = 18 hran, 18 sloupku (vnitrek bez plotu)", flower["posts"].size())
	_check(TileCatalog.surface_height(TileCatalog.TileType.STONE_MOUNTAIN, Vector2.ZERO) > 0.9, "vrchol hory je vysoko (props se nezahrabou)", TileCatalog.surface_height(TileCatalog.TileType.STONE_MOUNTAIN, Vector2.ZERO))
	_check(is_equal_approx(TileCatalog.surface_height(TileCatalog.TileType.GRASS, Vector2.ZERO), 0.2), "plochy typ vraci rim_height", true)
	var fence_bounds :=TileCatalog.prop_bounds("fence_simple")
	_check(fence_bounds.size.x > 0.9, "fence_simple ma nativni delku ~1.0 (po roztazeni sedi na hranu)", fence_bounds.size.x)

	_check(is_equal_approx(TileCatalog.rim_height(TileCatalog.TileType.ENEMY_CAMP), 0.1), "rim_height(ENEMY_CAMP) je 0.1", TileCatalog.rim_height(TileCatalog.TileType.ENEMY_CAMP))
	_check(is_equal_approx(TileCatalog.rim_height(TileCatalog.TileType.ENEMY_WALL), 0.1), "rim_height(ENEMY_WALL) je 0.1", TileCatalog.rim_height(TileCatalog.TileType.ENEMY_WALL))

	_check(MapBuilder.PROP_DENSITY[GameData.Terrain.OWNED] == 3, "PROP_DENSITY[OWNED] zvednuto na 3", MapBuilder.PROP_DENSITY[GameData.Terrain.OWNED])
	_check(MapBuilder.PROP_DENSITY[GameData.Terrain.MOUNTAIN] == 3, "PROP_DENSITY[MOUNTAIN] zvednuto na 3", MapBuilder.PROP_DENSITY[GameData.Terrain.MOUNTAIN])

	_check(MapBuilder._variant_bucket(Vector2i(0, 0)) == MapBuilder._variant_bucket(Vector2i(-1, -1)), "blizke bunky sdili plosku", true)
	_check(MapBuilder._variant_bucket(Vector2i(0, 0)) != MapBuilder._variant_bucket(Vector2i(20, 20)), "vzdalene bunky jsou v jine plosce", true)
