extends SceneTree

## Dev check for the ported economy. Builds a known map, then asserts the numbers
## the prototype's calculateEconomyState() would produce, so a regression in the
## port shows up as a failed line rather than a plausible-looking wrong total.
##
## godot --headless --path . --script res://scripts/dev/economy_test.gd

const EXPECTED_CHECKS := 43

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")
	gs.set_seed(1872)

	_test_tile_yields(gs)
	_test_transit_multiplier(gs)
	_test_steam_and_storage(gs)
	_test_consumption(gs)
	_test_clamping(gs)
	_test_tech_gating(gs)
	_test_turn(gs)

	print("")
	# A runtime error aborts a test function mid-way, which would otherwise look
	# like a clean pass. Treat a short run as failure.
	if _ran < EXPECTED_CHECKS:
		print("SELHALO: probehlo jen %d z %d kontrol (nekde spadl runtime error)" % [_ran, EXPECTED_CHECKS])
		quit(1)
		return
	if _failures > 0:
		print("SELHALO: %d z %d kontrol" % [_failures, _ran])
		quit(1)
		return
	print("VSE OK (%d kontrol)" % _ran)
	quit(0)


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-46s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-46s = %s (cekano %s)" % [label, actual, expected])


func _no_techs() -> Array[String]:
	var out: Array[String] = []
	return out


func _no_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## GameState.researched_techs is Array[String]; an untyped literal will not assign.
func _techs(a := "", b := "", c := "") -> Array[String]:
	var out: Array[String] = []
	for id in [a, b, c]:
		if id != "":
			out.append(id)
	return out


func _buildings(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in entries:
		out.append(entry)
	return out


func _fresh_map(gs) -> void:
	# 3 prairie (food 3), 2 owned (food 2 + wood 1), 1 mine (iron 8, coal 5),
	# 1 river (food 2), 1 town (gold 15), 2 railway (gold 5).
	gs.load_tiles({
		Vector2i(0, 0): GameData.Terrain.TOWN,
		Vector2i(1, 0): GameData.Terrain.PRAIRIE,
		Vector2i(2, 0): GameData.Terrain.PRAIRIE,
		Vector2i(3, 0): GameData.Terrain.PRAIRIE,
		Vector2i(0, 1): GameData.Terrain.OWNED,
		Vector2i(1, 1): GameData.Terrain.OWNED,
		Vector2i(2, 1): GameData.Terrain.MINE,
		Vector2i(3, 1): GameData.Terrain.RIVER,
		Vector2i(0, 2): GameData.Terrain.RAILWAY,
		Vector2i(1, 2): GameData.Terrain.RAILWAY,
		Vector2i(2, 2): GameData.Terrain.MOUNTAIN,
		Vector2i(3, 2): GameData.Terrain.FOG,
	})


func _test_tile_yields(gs) -> void:
	print("\n[1] Vynosy dlazdic")
	gs.researched_techs = _no_techs()
	gs.buildings = _no_buildings()
	_fresh_map(gs)
	var eco = gs.calculate_economy()
	# food: 3*3 prairie + 2*2 owned + 2 river = 9 + 4 + 2 = 15
	_check("food z dlazdic", eco["gross"]["food"], 15)
	_check("wood z dlazdic (2x owned)", eco["gross"]["wood"], 2)
	_check("iron z dolu", eco["gross"]["iron"], 8)
	_check("coal z dolu", eco["gross"]["coal"], 5)
	# gold: town 15 + 2 railway * 5 = 25, bez tech multiplikatoru
	_check("gold bez tech", eco["gross"]["gold"], 25)
	_check("mountain/fog neprodukuji", eco["gross"]["salt"], 0)


func _test_transit_multiplier(gs) -> void:
	print("\n[2] Transit multiplikator (steel + express)")
	_fresh_map(gs)

	gs.researched_techs = _techs("steel")
	var eco = gs.calculate_economy()
	# 1.1x: town round(15*1.1)=17, railway round(5*1.1)=6 kazda => 17 + 12 = 29
	_check("gold se steel (1.1x)", eco["gross"]["gold"], 29)

	gs.researched_techs = _techs("steel", "express")
	eco = gs.calculate_economy()
	# 1.2x: town round(15*1.2)=18, railway round(5*1.2)=6 kazda => 18 + 12 = 30
	_check("gold se steel+express (1.2x)", eco["gross"]["gold"], 30)

	gs.researched_techs = _techs("steel", "express", "railway")
	eco = gs.calculate_economy()
	_check("gold + railway uzel (+20)", eco["gross"]["gold"], 50)

	gs.researched_techs = _no_techs()


func _test_steam_and_storage(gs) -> void:
	print("\n[3] Parni stroj a kapacita skladu")
	_fresh_map(gs)
	gs.researched_techs = _no_techs()
	gs.buildings = _buildings([
		{"name": "Farma", "production": {"food": 12}, "cell": Vector2i.ZERO},
		{"name": "Sklad", "production": {}, "cell": Vector2i.ZERO},
	])
	var eco = gs.calculate_economy()
	_check("food = dlazdice 15 + farma 12", eco["gross"]["food"], 27)
	_check("kapacita 600 + 1 sklad", eco["storage_capacity"], 680)

	gs.researched_techs = _techs("steam")
	eco = gs.calculate_economy()
	# steam nasobi jen produkci budov: 15 + round(12*1.5) = 15 + 18 = 33
	_check("food se steam (jen budovy x1.5)", eco["gross"]["food"], 33)

	gs.buildings.append({"name": "Sklad", "production": {}, "cell": Vector2i.ZERO})
	eco = gs.calculate_economy()
	_check("kapacita 600 + 2 sklady", eco["storage_capacity"], 760)

	gs.researched_techs = _no_techs()
	gs.buildings = _no_buildings()


func _test_consumption(gs) -> void:
	print("\n[4] Spotreba")
	_fresh_map(gs)
	gs.buildings = _buildings([
		{"name": "Farma", "production": {"food": 12}, "cell": Vector2i.ZERO},
		{"name": "Mlyn", "production": {"food": 8}, "cell": Vector2i.ZERO},
	])
	gs.population = 1240
	gs.reputation["soldiers"] = 72
	var eco = gs.calculate_economy()
	_check("food spotreba floor(1240/50)", eco["consumption"]["food"], 24)
	# 2 budovy * 5 + 20 (soldiers > 60)
	_check("gold spotreba 2 budovy + zoldnere", eco["consumption"]["gold"], 30)

	gs.reputation["soldiers"] = 55
	eco = gs.calculate_economy()
	_check("gold spotreba bez zoldneru", eco["consumption"]["gold"], 10)

	_check("net food = gross - spotreba", eco["net"]["food"], eco["gross"]["food"] - 24)

	gs.reputation["soldiers"] = 72
	gs.buildings = _no_buildings()


func _test_clamping(gs) -> void:
	print("\n[5] Limity surovin")
	_fresh_map(gs)
	gs.buildings = _no_buildings()
	gs.refresh_economy()

	gs.resources["gold"] = 50
	var applied = gs.apply_resource("gold", -200)
	_check("gold neklesne pod nulu (aplikovano)", applied, -50)
	_check("gold po prekroceni", gs.resources["gold"], 0)

	gs.resources["food"] = 500
	applied = gs.apply_resource("food", 500)
	_check("food strop = kapacita 600", gs.resources["food"], 600)
	_check("food aplikovano jen do stropu", applied, 100)

	gs.resources["gold"] = 99999
	applied = gs.apply_resource("gold", 5000)
	_check("gold nema strop", gs.resources["gold"], 104999)

	gs.resources = {"gold": 2340, "food": 480, "iron": 210, "wood": 95, "coal": 140, "salt": 62}


func _test_tech_gating(gs) -> void:
	print("\n[6] Tech strom - podminky")
	gs.researched_techs = _no_techs()
	gs.tech_points = 0
	_check("bez bodu nelze nic", gs.can_research("forge"), false)

	gs.tech_points = 1
	_check("forge za 1 bod lze", gs.can_research("forge"), true)
	_check("steel bez forge nelze", gs.can_research("steel"), false)

	gs.research("forge")
	_check("forge zapsan", gs.has_tech("forge"), true)
	_check("body odecteny", gs.tech_points, 0)

	gs.tech_points = 2
	_check("steel s forge a 2 body lze", gs.can_research("steel"), true)
	_check("uz vyzkoumany nelze znovu", gs.can_research("forge"), false)

	gs.tech_points = 10
	_check("railway bez steel+express nelze", gs.can_research("railway"), false)
	gs.research("steel")
	gs.research("coach")
	gs.research("express")
	_check("railway po steel+express lze", gs.can_research("railway"), true)

	gs.tech_points = 99
	gs.researched_techs = _techs("militia", "escort", "weapons")
	_check("bojova sila 2+1+1", gs.tech_combat_power(), 4)

	gs.researched_techs = _no_techs()
	gs.tech_points = 0


func _test_turn(gs) -> void:
	print("\n[7] Prubeh tahu")
	_fresh_map(gs)
	gs.buildings = _no_buildings()
	gs.researched_techs = _no_techs()
	gs.tech_points = 0
	gs.turn_count = 0
	gs.year = 1872
	gs.season = GameData.SEASONS[0]
	gs.population = 1240
	gs.coach_in = 99  # drzi dostavnik mimo, aby netrhal cisla
	gs.resources = {"gold": 1000, "food": 500, "iron": 0, "wood": 0, "coal": 0, "salt": 0}

	gs.advance_turn()
	_check("turn_count po 1 tahu", gs.turn_count, 1)
	_check("sezona po 1 tahu", gs.season, "Léto")
	_check("rok se nemeni", gs.year, 1872)
	_check("tech body pred 3. tahem", gs.tech_points, 0)

	gs.advance_turn()
	gs.advance_turn()
	_check("tech body ve 3. tahu (+2)", gs.tech_points, 2)
	_check("sezona po 3 tazich", gs.season, "Zima")

	gs.advance_turn()
	_check("rok po 4 tazich", gs.year, 1873)
	_check("sezona po 4 tazich", gs.season, "Jaro")

	gs.researched_techs = _techs("forge")
	gs.tech_points = 0
	gs.turn_count = 0
	gs.advance_turn()
	gs.advance_turn()
	gs.advance_turn()
	_check("tech body s forge (+4)", gs.tech_points, 4)

	print("\n[8] Dostavnik")
	gs.coach_in = 1
	var gold_before: int = gs.resources["gold"]
	var pop_before: int = gs.population
	gs.researched_techs = _no_techs()
	gs.advance_turn()
	_check("dostavnik pridal populaci", gs.population >= pop_before + GameData.COACH_POPULATION, true)
	_check("dostavnik prenastavil odpocet", gs.coach_in >= 2 and gs.coach_in <= 4, true)
	print("       (gold pred %d, po %d - zahrnuje i produkci a event)" % [gold_before, gs.resources["gold"]])
