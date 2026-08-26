extends SceneTree

## Save/load round-trip.
##
## JSON loses both Vector2i keys and the difference between int and float, so the
## interesting failures are silent type drift rather than missing data: a map key
## coming back as the string "3,-1", or gold turning into 2340.0. This checks the
## whole snapshot for equality *and* pokes at the types individually.
##
## godot --headless --path . --script res://scripts/dev/save_test.gd

const EXPECTED_CHECKS := 51
const SEED := 18720412
const SLOT := 3

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")

	_build_interesting_state(gs)
	var snapshot := SaveGame.capture(gs)

	print("\n[1] Ulozeni")
	_check("ulozeni probehlo", gs.save_to_slot(SLOT), true)
	_check("slot existuje", SaveGame.has_slot(SLOT), true)

	var info := SaveGame.slot_info(SLOT)
	_check("hlavicka slotu se cte", bool(info["exists"]), true)
	_check("hlavicka zna tah", int(info["turn"]), int(gs.turn_count))
	_check("hlavicka zna rok", int(info["year"]), int(gs.year))
	_check("hlavicka zna zlato", int(info["gold"]), int(gs.resources["gold"]))

	print("\n[2] Prepsani stavu a nacteni")
	gs.start_new_game(999)
	_check("nova hra stav opravdu zmenila", gs.turn_count, 0)
	_check("a smazala vyzkum", gs.researched_techs.size(), 0)

	_check("nacteni probehlo", gs.load_from_slot(SLOT), true)

	print("\n[3] Shoda po nacteni")
	var restored := SaveGame.capture(gs)
	for key in snapshot:
		_check("shoduje se %s" % key, JSON.stringify(restored.get(key)),
			JSON.stringify(snapshot[key]))

	print("\n[4] Typy prezily JSON")
	_check("klice mapy jsou Vector2i",
		typeof(gs.tiles.keys()[0]), TYPE_VECTOR2I)
	_check("zlato je cele cislo", typeof(gs.resources["gold"]), TYPE_INT)
	_check("uroven sidla je cele cislo",
		typeof(gs.settlements.values()[0]), TYPE_INT)
	_check("vyzkum je typovane pole retezcu", gs.researched_techs.is_typed(), true)
	_check("budova si drzi Vector2i", typeof(gs.buildings[0]["cell"]), TYPE_VECTOR2I)
	_check("ekonomika se po nacteni prepocitala",
		gs.economy.has("gross"), true)

	print("\n[5] Odolnost")
	_check("neexistujici slot se nenacte", gs.load_from_slot(SaveGame.SLOT_COUNT + 5), false)
	_check("nepodporovana verze se odmitne",
		SaveGame.restore(gs, {"version": 999}), false)
	_check("smazani slotu probehlo", SaveGame.delete_slot(SLOT), true)
	_check("slot je pryc", SaveGame.has_slot(SLOT), false)
	_check("smazat podruhe uz nelze", SaveGame.delete_slot(SLOT), false)

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


## A game with something in every layer the save format has to carry.
func _build_interesting_state(gs) -> void:
	gs.start_new_game(SEED)
	gs.player_name = "Tomáš"
	gs.resources["gold"] = 9000
	gs.resources["wood"] = 400

	# Zadrátované souřadnice tady dřív tiše přestaly platit, jakmile Etapa 1c
	# zvětšila VISIBLE_RADIUS a zorganičtila vlastněné území — hledáme proto
	# cílové buňky dynamicky, stejný vzor jako actions_test.gd.
	var claim_a := _find_claimable_prairie(gs)
	gs.perform_action("claim", claim_a)
	var claim_b := _find_claimable_prairie(gs)
	gs.perform_action("claim", claim_b)

	var fog_cell := _find_adjacent_fog(gs)
	gs.perform_action("explore", fog_cell)

	gs.perform_action("found", claim_b)

	var rail_cell := _find_claimable_railway(gs)
	gs.perform_action("claim", rail_cell)
	gs.perform_action("repair", rail_cell)

	var build_a := _find_buildable_owned(gs, [])
	gs.build("Farma", build_a)
	var build_b := _find_buildable_owned(gs, [build_a])
	gs.build("Sklad", build_b)

	gs.tech_points = 6
	gs.research("forge")
	gs.research("coach")

	gs.contracts.clear()
	gs.turn_count = GameData.CONTRACT_INTERVAL
	gs._tick_contracts()

	gs.coach_stay = 1
	gs.advance_turn()
	gs.advance_turn()

	print("Vychozi stav: tah %d, %d dlazdic, %d zabranych, %d sidel, %d budov, %d kontraktu" % [
		gs.turn_count, gs.tiles.size(), gs.owned.size(),
		gs.settlements.size(), gs.buildings.size(), gs.contracts.size(),
	])


func _find_claimable_prairie(gs) -> Vector2i:
	for cell in gs.tiles:
		if gs.get_tile(cell) == GameData.Terrain.PRAIRIE and not gs.is_owned(cell) and gs.is_adjacent_to_owned(cell):
			return cell
	return Vector2i.MAX


func _find_adjacent_fog(gs) -> Vector2i:
	for cell in gs.tiles:
		if gs.tiles[cell] == GameData.Terrain.FOG and gs.is_adjacent_to_owned(cell):
			return cell
	return Vector2i.MAX


func _find_claimable_railway(gs) -> Vector2i:
	for cell in gs.tiles:
		if gs.get_tile(cell) == GameData.Terrain.RAILWAY and not gs.is_owned(cell) and gs.is_adjacent_to_owned(cell):
			return cell
	return Vector2i.MAX


func _find_buildable_owned(gs, exclude: Array) -> Vector2i:
	for cell in gs.tiles:
		if exclude.has(cell):
			continue
		if gs.get_tile(cell) != GameData.Terrain.OWNED:
			continue
		if gs.settlement_at(cell) > 0:
			continue
		if not gs.building_at(cell).is_empty():
			continue
		if not gs.in_supply(cell):
			continue
		return cell
	return Vector2i.MAX


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		var shown := str(actual)
		if shown.length() > 48:
			shown = shown.substr(0, 45) + "..."
		print("  ok   %-42s = %s" % [label, shown])
	else:
		_failures += 1
		print("  FAIL %-42s = %s (cekano %s)" % [label, actual, expected])
