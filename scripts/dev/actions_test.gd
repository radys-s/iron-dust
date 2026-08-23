extends SceneTree

## Exercises every tile action end to end against the real Dustfall map:
## adjacency gating, costs, exploration, claiming, settlements, building supply,
## the two one-shot actions, and how a battle result lands on the map.
##
## godot --headless --path . --script res://scripts/dev/actions_test.gd

const EXPECTED_CHECKS := 80
const SEED := 18720412

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")

	_test_availability(gs)
	_test_claim(gs)
	_test_explore(gs)
	_test_settlements(gs)
	_test_building(gs)
	_test_combat_application(gs)
	_test_one_shots(gs)

	print("")
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


# --- Availability ------------------------------------------------------------

func _test_availability(gs) -> void:
	print("\n[1] Nabidka akci a sousedstvi")
	gs.start_new_game(SEED)

	_check("Dustfall je mesto", gs.get_tile(Vector2i(0, 0)), GameData.Terrain.TOWN)
	_check("mesto je vlastnene", gs.is_owned(Vector2i(0, 0)), true)
	_check("prerie 3 hexy od mesta neni vlastnena", gs.is_owned(Vector2i(3, -1)), false)

	_check("obchod jde jen v Dustfallu", _ids(gs, Vector2i(0, 0)).has("trade"), true)
	_check("mimo mesto se neobchoduje", _ids(gs, Vector2i(3, -1)).has("trade"), false)

	# Prerie u vlastneneho uzemi jde zabrat, vzdalena ne.
	_check("blizka prerie jde zabrat", _enabled(gs, "claim", Vector2i(3, -1)), true)
	_check("vzdalena prerie zatim ne", _enabled(gs, "claim", Vector2i(5, -2)), false)
	_check("duvod je sousedstvi",
		_reason(gs, "claim", Vector2i(5, -2)).begins_with("Musí sousedit"), true)

	# Mlha na zacatku nesousedi s nicim vlastnenym.
	_check("mlha zatim nejde prozkoumat", _enabled(gs, "explore", Vector2i(5, -1)), false)
	_check("stavba mimo vlastnictvi nejde", _enabled(gs, "build", Vector2i(3, -1)), false)


# --- Claim -------------------------------------------------------------------

func _test_claim(gs) -> void:
	print("\n[2] Zabor uzemi")
	gs.start_new_game(SEED)

	var cell := Vector2i(3, -1)
	var cost: Dictionary = TileAction.cost(gs, "claim", cell)
	var expected_gold := GameData.CLAIM_COST_BASE \
		+ HexGrid.distance(cell, MapBuilder.TOWN_CELL) * GameData.CLAIM_COST_PER_STEP
	_check("cena zaboru roste se vzdalenosti", int(cost["gold"]), expected_gold)

	var gold_before: int = gs.resources["gold"]
	var wood_before: int = gs.resources["wood"]
	var tribes_before: int = gs.reputation["tribes"]

	_check("zabor probehl", bool(gs.perform_action("claim", cell)["ok"]), true)
	_check("zlato odecteno", gs.resources["gold"], gold_before - expected_gold)
	_check("drevo odecteno", gs.resources["wood"], wood_before - GameData.CLAIM_COST_WOOD)
	_check("dlazdice je vlastnena", gs.is_owned(cell), true)
	_check("prerie se stala vlastnenym uzemim", gs.get_tile(cell), GameData.Terrain.OWNED)
	_check("kmeny zabor nelibi", gs.reputation["tribes"] < tribes_before, true)

	_check("podruhe uz zabrat nelze", _enabled(gs, "claim", cell), false)

	# Zabor tvrdeho terenu nemeni teren, jen pridava mytne. K dolu se musi
	# postupovat po sousedicich dlazdicich.
	gs.perform_action("claim", Vector2i(4, -1))
	gs.perform_action("claim", Vector2i(4, -2))
	var mine_cell := Vector2i(4, -3)
	_check("dul je pred zaborem dul", gs.get_tile(mine_cell), GameData.Terrain.MINE)
	_check("zabor dolu probehl", bool(gs.perform_action("claim", mine_cell)["ok"]), true)
	_check("dul zustal dolem", gs.get_tile(mine_cell), GameData.Terrain.MINE)
	_check("dul plati mytne", int(gs.economy["claim_income"]["gold"]), GameData.CLAIM_BONUS["gold"])


# --- Explore -----------------------------------------------------------------

func _test_explore(gs) -> void:
	print("\n[3] Pruzkum mlhy")
	gs.start_new_game(SEED)

	# Postup na vychod, dokud nedosahneme mlhy.
	gs.perform_action("claim", Vector2i(3, -1))
	gs.perform_action("claim", Vector2i(4, -1))

	var fog_cell := Vector2i(5, -1)
	_check("cil je pod mlhou", gs.get_tile(fog_cell), GameData.Terrain.FOG)
	_check("ted uz pruzkum jde", _enabled(gs, "explore", fog_cell), true)

	var hidden: GameData.Terrain = gs.hidden_tiles[fog_cell]
	var gold_before: int = gs.resources["gold"]
	var result: Dictionary = gs.perform_action("explore", fog_cell)

	_check("pruzkum probehl", bool(result["ok"]), true)
	_check("odhaleny teren sedi se skrytym", gs.get_tile(fog_cell), hidden)
	_check("zaplaceno za pruzkum", gs.resources["gold"], gold_before - GameData.EXPLORE_COST)
	_check("zaznam mlhy zmizel", gs.hidden_tiles.has(fog_cell), false)

	# Telegraf odhali i sousedni mlhu naráz.
	gs.researched_techs.append("telegraph")
	gs.resources["gold"] = 5000
	gs.perform_action("claim", Vector2i(5, -1))

	var next_fog := Vector2i(6, -1)
	var fogged_before := _fog_count(gs)
	var telegraph_result: Dictionary = gs.perform_action("explore", next_fog)
	_check("telegraf odhalil i okoli",
		int((telegraph_result["extra"] as Array).size()) > 0, true)
	_check("mlhy ubylo o vic nez jednu dlazdici",
		fogged_before - _fog_count(gs) > 1, true)
	_check("telegraf zlevnil pruzkum",
		int(TileAction.cost(gs, "explore", Vector2i(7, -1))["gold"]),
		GameData.EXPLORE_COST_TELEGRAPH)


# --- Settlements -------------------------------------------------------------

func _test_settlements(gs) -> void:
	print("\n[4] Sidla")
	gs.start_new_game(SEED)
	gs.resources["gold"] = 5000
	gs.resources["wood"] = 500

	_check("Dustfall zacina jako sidlo",
		gs.settlement_at(MapBuilder.TOWN_CELL), MapBuilder.TOWN_SETTLEMENT_LEVEL)
	_check("v meste se sidlo zakladat nedá", _enabled(gs, "found", MapBuilder.TOWN_CELL), false)
	_check("hned vedle Dustfallu je to moc blizko",
		_reason(gs, "found", Vector2i(0, 1)).begins_with("Příliš blízko"), true)

	var cell := Vector2i(3, -1)
	gs.perform_action("claim", cell)
	var population_before: int = gs.population

	_check("zalozeni osady probehlo", bool(gs.perform_action("found", cell)["ok"]), true)
	_check("sidlo ma uroven 1", gs.settlement_at(cell), 1)
	_check("prisli obyvatele", gs.population,
		population_before + int(GameData.settlement_data(1)["population"]))
	_check("na sidle uz se stavet nedá", _enabled(gs, "build", cell), false)

	var upgrade_cost: Dictionary = TileAction.cost(gs, "upgrade", cell)
	_check("cena povyseni je uroven x 200", int(upgrade_cost["gold"]),
		1 * GameData.SETTLEMENT_UPGRADE_PER_LEVEL)

	var gold_before: int = gs.resources["gold"]
	gs.perform_action("upgrade", cell)
	_check("sidlo je kolonie", gs.settlement_at(cell), 2)
	_check("zaplaceno za povyseni", gs.resources["gold"],
		gold_before - int(upgrade_cost["gold"]))
	_check("dosah zasobovani se zvetsil", gs.in_supply(Vector2i(4, -1)), true)

	# Az na maximum a dal ne.
	gs.resources["gold"] = 5000
	gs.perform_action("upgrade", cell)
	gs.resources["gold"] = 5000
	gs.perform_action("upgrade", cell)
	_check("nejvyssi uroven je %d" % GameData.SETTLEMENT_MAX_LEVEL,
		gs.settlement_at(cell), GameData.SETTLEMENT_MAX_LEVEL)
	_check("dal uz povysit nelze", _enabled(gs, "upgrade", cell), false)


# --- Building ----------------------------------------------------------------

func _test_building(gs) -> void:
	print("\n[5] Stavby a dosah zasobovani")
	gs.start_new_game(SEED)
	gs.resources["gold"] = 5000
	gs.resources["wood"] = 500

	var near := Vector2i(1, 1)
	_check("dlazdice u mesta je vlastnena", gs.is_owned(near), true)
	_check("a je v dosahu zasobovani", gs.in_supply(near), true)
	_check("postaveno", gs.build("Farma", near), true)
	_check("budova je na miste", String(gs.building_at(near)["name"]), "Farma")
	_check("produkce farmy se projevila",
		int(gs.economy["building_production"]["food"]), 12)
	_check("na obsazenou dlazdici uz ne", gs.build("Mlýn", near), false)

	# Zabrane uzemi mimo dosah sidel stavet neumozni.
	var far := Vector2i(3, -1)
	gs.perform_action("claim", far)
	_check("vzdalena dlazdice je vlastnena", gs.is_owned(far), true)
	_check("ale mimo dosah zasobovani", gs.in_supply(far), false)
	_check("stavba mimo dosah selze", gs.build("Farma", far), false)
	_check("duvodem je zasobovani",
		_reason(gs, "build", far).begins_with("Mimo dosah"), true)

	# Osada na sousedni dlazdici dosah doplni.
	gs.perform_action("claim", Vector2i(4, -1))
	gs.perform_action("found", Vector2i(4, -1))
	_check("osada vedle otevrela stavbu", gs.build("Sklad", far), true)
	_check("sklad zvedl kapacitu", gs.storage_capacity(),
		GameData.BASE_STORAGE_CAPACITY + GameData.STORAGE_PER_BUILDING)


# --- Combat on the map -------------------------------------------------------

func _test_combat_application(gs) -> void:
	print("\n[6] Dopad boje na mapu")
	var target := Vector2i(0, 3)

	# Jistá výhra: rozdíl sil 11 přebije i nejhorší hod kostkou.
	gs.start_new_game(SEED)
	_check("cil patri Harlan-Voss", gs.get_tile(target), GameData.Terrain.ENEMY)

	gs.reputation["soldiers"] = 100
	for id in ["militia", "escort", "artillery", "weapons"]:
		gs.researched_techs.append(id)
	gs.settlements[Vector2i(0, 2)] = 3

	var preview: Dictionary = gs.combat_preview(target)
	_check("prevaha je aspon 11",
		int(preview["player"]) - int(preview["enemy"]) >= 11, true)

	gs.perform_action("attack", target)
	_check("uzemi je po vitezstvi nase", gs.get_tile(target), GameData.Terrain.OWNED)
	_check("a je zapsane jako zabrane", gs.owned.has(target), true)
	_check("vysledek je drtive vitezstvi",
		int(gs.last_combat["result"]), GameData.CombatResult.CRUSHING)

	# Jeden stret za tah: dalsi sousedni cil uz tenhle tah nejde.
	var next_target := Vector2i(1, 3)
	_check("dalsi cil je take H-V", gs.get_tile(next_target), GameData.Terrain.ENEMY)
	_check("druhy utok v tomtez tahu nejde", _enabled(gs, "attack", next_target), false)
	_check("duvodem je vycerpany tah",
		_reason(gs, "attack", next_target).begins_with("Vojsko už"), true)
	gs.advance_turn()
	_check("po konci tahu vojsko zase muze",
		_enabled(gs, "attack", next_target), true)

	# Jistá porážka: bez vojáků a bez podpory je marže vždy pod −6.
	gs.start_new_game(SEED)
	gs.reputation["soldiers"] = 0
	var lost_candidate := Vector2i(0, 2)
	_check("sousedni dlazdice je pred bojem nase", gs.is_owned(lost_candidate), true)

	gs.perform_action("attack", target)
	_check("vysledek je tezka porazka",
		int(gs.last_combat["result"]), GameData.CombatResult.ROUT)
	_check("cil zustal nepriteli", gs.get_tile(target), GameData.Terrain.ENEMY)
	_check("protiutok obsadil sousedni dlazdici",
		gs.get_tile(lost_candidate), GameData.Terrain.ENEMY)
	_check("a uz neni nase", gs.is_owned(lost_candidate), false)


# --- One-shot actions --------------------------------------------------------

func _test_one_shots(gs) -> void:
	print("\n[7] Jednorazove akce")
	gs.start_new_game(SEED)
	gs.resources["gold"] = 5000

	# Prospekce v horach.
	gs.perform_action("claim", Vector2i(0, -3))
	var mountain := Vector2i(0, -4)
	_check("cil je pohori", gs.get_tile(mountain), GameData.Terrain.MOUNTAIN)
	gs.perform_action("claim", mountain)

	var iron_before: int = gs.resources["iron"]
	_check("prospekce probehla", bool(gs.perform_action("prospect", mountain)["ok"]), true)
	_check("zelezo pribylo", gs.resources["iron"] > iron_before, true)
	_check("podruhe uz ne", _enabled(gs, "prospect", mountain), false)
	_check("duvodem je jednorazovost",
		_reason(gs, "prospect", mountain).begins_with("Tady už"), true)

	# Oprava trati.
	var rail := Vector2i(1, 0)
	_check("cil je zeleznice", gs.get_tile(rail), GameData.Terrain.RAILWAY)
	_check("nezabranou trat opravit nelze", _enabled(gs, "repair", rail), false)
	gs.perform_action("claim", rail)

	var merchants_before: int = gs.reputation["merchants"]
	_check("oprava probehla", bool(gs.perform_action("repair", rail)["ok"]), true)
	_check("kupci to ocenili", gs.reputation["merchants"],
		merchants_before + GameData.REPAIR_REPUTATION)
	_check("opravit dvakrat nelze", _enabled(gs, "repair", rail), false)


# --- Harness -----------------------------------------------------------------

func _ids(gs, cell: Vector2i) -> Array:
	var out: Array = []
	for action in gs.actions_for(cell):
		out.append(String(action["id"]))
	return out


func _enabled(gs, id: String, cell: Vector2i) -> bool:
	return bool(TileAction.can_perform(gs, id, cell)["ok"])


func _reason(gs, id: String, cell: Vector2i) -> String:
	return String(TileAction.can_perform(gs, id, cell)["reason"])


func _fog_count(gs) -> int:
	var total := 0
	for cell in gs.tiles:
		if gs.tiles[cell] == GameData.Terrain.FOG:
			total += 1
	return total


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-46s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-46s = %s (cekano %s)" % [label, actual, expected])
