extends SceneTree

## Hammers EnemyAI and the loss condition it feeds.
##
## Three things matter most here: EnemyAI never mutates GameState (it only
## plans, GameState._run_ai_turn() executes), its turn never exceeds its own
## action/attack budget, and the game can only actually end through a resolved
## assault on Dustfall (the proactive attack, which runs Combat.resolve() and
## therefore respects AI_TOWN_DEFENSE_BONUS) — never as a side effect of a
## rout fought somewhere else on the map (the reactive counterattack).
##
## godot --headless --path . --script res://scripts/dev/enemy_ai_test.gd

const EXPECTED_CHECKS := 36
const SEED := 18720412

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")

	_test_power_formula(gs)
	_test_expansion(gs)
	_test_attack(gs)
	_test_action_budget(gs)
	_test_defeat(gs)
	_test_multi_turn(gs)

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


# --- Power ---------------------------------------------------------------

func _test_power_formula(gs) -> void:
	print("\n[1] enemy_power(): regrese a nove cleny")
	gs.start_new_game(SEED)
	var cell := Vector2i(0, 4)
	gs.turn_count = 0
	gs.ai_settlements = {}
	gs.ai_resources = GameData.empty_resources()

	var baseline := Combat.enemy_power(gs, cell)
	_check("baseline odpovida puvodnimu vzorci", baseline,
		GameData.ENEMY_BASE_POWER + HexGrid.distance(cell, MapBuilder.TOWN_CELL) * GameData.ENEMY_POWER_PER_DISTANCE)

	gs.ai_settlements = {Vector2i(0, 3): 3}
	_check("AI sidlo v dosahu pridava obranu", Combat.enemy_power(gs, cell),
		baseline + int(GameData.settlement_data(3)["defense"]))

	gs.ai_settlements = {MapBuilder.TOWN_CELL: 3}
	_check("AI sidlo mimo dosah nepridava nic", Combat.enemy_power(gs, cell), baseline)

	gs.ai_settlements = {}
	gs.ai_resources["gold"] = GameData.AI_POWER_PER_GOLD * 3
	_check("pokladna pridava silu", Combat.enemy_power(gs, cell), baseline + 3)

	gs.ai_resources = GameData.empty_resources()
	_check("prazdna pokladna nic neprida", Combat.enemy_power(gs, cell), baseline)

	gs.reputation["soldiers"] = 0
	gs.researched_techs.clear()
	gs.settlements = {}
	_check("Dustfall ma kapitalovy bonus navic",
		Combat.player_power(gs, MapBuilder.TOWN_CELL), GameData.AI_TOWN_DEFENSE_BONUS)
	_check("jina dlazdice kapitalovy bonus nema", Combat.player_power(gs, cell), 0)


# --- Expansion -------------------------------------------------------------

func _test_expansion(gs) -> void:
	print("\n[2] Expanze")
	gs.start_new_game(SEED)
	gs.ai_resources["gold"] = 10000
	# I na cerstve mape uz existuje hranicni bunka na hranici vyhody (viz sekce
	# [3]) — ohromna obrana hrace tu zarucuje, ze rozpocet padne na expanzi,
	# ne na utok, coz je presne to, co se tu izoluje k otestovani.
	gs.reputation["soldiers"] = 100000

	var plan := EnemyAI.run_turn(gs)
	_check("EnemyAI nemutuje ai_resources", int(gs.ai_resources["gold"]), 10000)

	var expansions := _actions_of_kind(plan, EnemyAI.KIND_EXPAND)
	_check("cerstva hra: presne jedna expanze (rozpocet 1, zadny cil k utoku)",
		expansions.size(), 1)

	var cell: Vector2i = expansions[0]["cell"]
	_check("planovana dlazdice jeste neni obsazena (run_turn je cisty)",
		gs.get_tile(cell) != GameData.Terrain.ENEMY, true)
	_check("expandovana dlazdice neni mlha", gs.get_tile(cell) != GameData.Terrain.FOG, true)
	_check("expandovana dlazdice neni hracova", gs.is_owned(cell), false)
	_check("expandovana dlazdice je zaberatelna", GameData.CLAIMABLE.has(gs.get_tile(cell)), true)

	gs.researched_techs.append("federal")
	var blocked := EnemyAI.run_turn(gs)
	_check("federalni kontakty expanzi zastavi",
		_actions_of_kind(blocked, EnemyAI.KIND_EXPAND).size(), 0)


# --- Attack ------------------------------------------------------------------

func _test_attack(gs) -> void:
	print("\n[3] Utok: cil a minimalni vyhoda")
	gs.start_new_game(SEED)
	gs.reputation["soldiers"] = 0
	gs.researched_techs.clear()
	gs.settlements = {}
	gs.ai_resources["gold"] = 10000

	var plan := EnemyAI.run_turn(gs)
	var attacks := _actions_of_kind(plan, EnemyAI.KIND_ATTACK)
	_check("se slabou obranou AI zautoci (max 1x)", attacks.size(), 1)

	var target: Vector2i = attacks[0]["cell"]
	_check("cil utoku je hracovo uzemi", gs.is_owned(target), true)
	_check("launch bunka je uzemi H-V", gs.get_tile(attacks[0]["launch_cell"]), GameData.Terrain.ENEMY)

	# Ohromna prevaha hrace vsude na mape -> AI se do zadneho souboje nepusti.
	gs.reputation["soldiers"] = 100000
	var declined := EnemyAI.run_turn(gs)
	_check("s ohromnou prevahou hrace AI nezautoci",
		_actions_of_kind(declined, EnemyAI.KIND_ATTACK).size(), 0)


# --- Action budget -----------------------------------------------------------

func _test_action_budget(gs) -> void:
	print("\n[4] Rozpocet akci za tah")
	gs.start_new_game(SEED)
	gs.ai_resources["gold"] = 1000000

	_check("0 zakladen -> rozpocet 1", EnemyAI.action_budget(gs), 1)

	gs.ai_settlements = {Vector2i(0, 3): 1, Vector2i(1, 3): 1}
	_check("2 zakladny -> rozpocet 2", EnemyAI.action_budget(gs), 2)

	gs.ai_settlements = {
		Vector2i(0, 3): 1, Vector2i(1, 3): 1, Vector2i(2, 3): 1, Vector2i(3, 3): 1, Vector2i(4, 3): 1,
	}
	_check("5 zakladen -> rozpocet na strop 3", EnemyAI.action_budget(gs), 3)

	var plan := EnemyAI.run_turn(gs)
	_check("naplanovanych akci nikdy nad rozpocet",
		plan["actions"].size() <= EnemyAI.action_budget(gs), true)


# --- Loss condition ------------------------------------------------------------

func _test_defeat(gs) -> void:
	print("\n[5] Prohra jen skutecnym utokem na Dustfall")
	gs.start_new_game(SEED)
	gs.tiles[Vector2i(0, 1)] = GameData.Terrain.ENEMY
	gs.ai_resources["gold"] = 1000000

	# Lambda zachytava lokalni int hodnotou, ne odkazem — pole obchazi ten
	# problem, protoze je referencni typ.
	var fired := [0]
	gs.game_over.connect(func(_reason: String) -> void: fired[0] += 1)

	_check("pred utokem hra nekoncila", gs.is_defeated, false)
	gs._ai_attack_player_cell(MapBuilder.TOWN_CELL, Vector2i(0, 1))
	_check("proaktivni utok dobyl Dustfall", gs.is_defeated, true)
	_check("Dustfall je nyni uzemim H-V", gs.get_tile(MapBuilder.TOWN_CELL), GameData.Terrain.ENEMY)
	_check("duvod prohry je vyplneny", gs.game_over_reason.is_empty(), false)
	_check("signal game_over se vyslal prave jednou", fired[0], 1)

	var turn_before: int = gs.turn_count
	var gold_before := int(gs.resources["gold"])
	gs.advance_turn()
	_check("po prohre je advance_turn no-op", gs.turn_count, turn_before)

	var result: Dictionary = gs.perform_action("explore", Vector2i(1, 1))
	_check("po prohre perform_action odmitne", bool(result["ok"]), false)
	_check("a nemeni zdroje", int(gs.resources["gold"]), gold_before)

	print("\n[6] Reaktivni protiutok Dustfall nikdy neveme")
	gs.start_new_game(SEED)
	# Umely scenar: kazdy soused (0,1) krome Dustfallu je zbaven vlastnictvi,
	# takze Dustfall je jedinym zpusobilym cilem — presne test te vyjimky.
	for neighbor in HexGrid.get_neighbors(0, 1):
		if neighbor == MapBuilder.TOWN_CELL:
			continue
		gs.tiles[neighbor] = GameData.Terrain.PRAIRIE
		gs.owned.erase(neighbor)
	gs.tiles[Vector2i(0, 1)] = GameData.Terrain.ENEMY

	var lost: Vector2i = gs._enemy_counterattack(Vector2i(0, 1))
	_check("reaktivni cesta Dustfall nikdy neveme", lost, Vector2i.MAX)
	_check("Dustfall zustal hracuv", gs.get_tile(MapBuilder.TOWN_CELL), GameData.Terrain.TOWN)
	_check("hra nekonci vedlejsim efektem boje jinde", gs.is_defeated, false)

	print("\n[7] Nedustfallovske obsazeni prohru nespusti")
	gs.start_new_game(SEED)
	gs.reputation["soldiers"] = 0
	gs.researched_techs.clear()
	gs.settlements = {}
	gs.ai_resources["gold"] = 1000000
	gs._ai_attack_player_cell(Vector2i(0, 2), Vector2i(0, 3))
	_check("beznou dlazdici AI vezme bez prohry", gs.is_defeated, false)


# --- Multi-turn --------------------------------------------------------------

func _test_multi_turn(gs) -> void:
	print("\n[8] Kratka simulace (40 tahu, hrac + AI)")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	gs.start_new_game(SEED)

	var violations := 0
	for turn in 40:
		var options := _legal_actions(gs)
		if not options.is_empty():
			var pick: Dictionary = options[rng.randi_range(0, options.size() - 1)]
			gs.perform_action(String(pick["id"]), pick["cell"])
		gs.advance_turn()

		for key in GameData.RESOURCES:
			if int(gs.ai_resources.get(key, 0)) < 0:
				violations += 1
		for cell in gs.ai_settlements:
			if gs.settlements.has(cell) or gs.is_owned(cell):
				violations += 1

		if gs.is_defeated:
			break

	_check("zadne poruseni v kratke simulaci", violations, 0)
	_check("hra zustala ve validnim stavu",
		gs.get_tile(MapBuilder.TOWN_CELL) != GameData.Terrain.FOG, true)


# --- Helpers -------------------------------------------------------------------

func _actions_of_kind(plan: Dictionary, kind: String) -> Array:
	var out := []
	for action in plan["actions"]:
		if String(action["kind"]) == kind:
			out.append(action)
	return out


func _legal_actions(gs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cell in gs.tiles:
		for action in gs.actions_for(cell):
			if not bool(action["enabled"]) or bool(action["overlay"]):
				continue
			out.append({"id": action["id"], "cell": cell})
	return out


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-52s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-52s = %s (cekano %s)" % [label, actual, expected])
