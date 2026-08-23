extends SceneTree

## Plays a whole game unattended: every turn it takes a few legal actions chosen
## at random, then checks the invariants that must hold no matter what happened.
##
## Unit tests prove each system in isolation; this one is here to catch the
## damage they do to each other — a rout deleting a settlement that a building
## still depends on, storage overflowing after a contract payout, and so on.
## It also prints a balance trace, which is the quickest way to see whether the
## economy runs away or stalls.
##
## godot --headless --path . --script res://scripts/dev/playthrough_test.gd

const EXPECTED_CHECKS := 9
const TURNS := 60
const ACTIONS_PER_TURN := 3
const SEED := 18720412

var _failures := 0
var _ran := 0
var _violations: Dictionary = {}
var _performed: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var gs := root.get_node("GameState")
	_rng.seed = SEED
	gs.start_new_game(SEED)

	print("\n[1] Prubeh %d tahu" % TURNS)
	print("  tah | zlato  jidlo  zelezo | pop   | zabrano sidla budovy | mlha | kontrakty")

	for turn in TURNS:
		_take_actions(gs)
		gs.advance_turn()
		_check_invariants(gs)
		if (turn + 1) % 10 == 0:
			_print_row(gs)

	print("\n[2] Co se za hru stalo")
	for id in _performed:
		print("  %-10s %dx" % [id, int(_performed[id])])
	print("  bitev celkem: %d" % int(_performed.get("attack", 0)))

	print("\n[3] Invarianty")
	_check("suroviny nikdy nesly do minusu", int(_violations.get("negative", 0)), 0)
	_check("nic nepreteklo kapacitu skladu", int(_violations.get("overflow", 0)), 0)
	_check("reputace zustala v 0..100", int(_violations.get("reputation", 0)), 0)
	_check("kazde sidlo stoji na vlastnenem uzemi",
		int(_violations.get("settlement_owned", 0)), 0)
	_check("kazda budova stoji na vlastnenem uzemi",
		int(_violations.get("building_owned", 0)), 0)
	_check("zadna budova nesdili dlazdici se sidlem",
		int(_violations.get("building_on_settlement", 0)), 0)
	_check("odhalena dlazdice uz neni ve skryte vrstve",
		int(_violations.get("hidden_leak", 0)), 0)
	_check("populace neklesla pod nulu", int(_violations.get("population", 0)), 0)

	# Hra se musi opravdu rozjet, ne jen prezit bez chyby.
	_check("hrac za %d tahu neco zabral" % TURNS, gs.owned.size() > 0, true)

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


# --- Playing -----------------------------------------------------------------

## Picks legal actions at random, preferring the ones that grow the game so the
## run does not stall on a board where nothing is affordable.
func _take_actions(gs) -> void:
	for i in ACTIONS_PER_TURN:
		var options := _legal_actions(gs)
		if options.is_empty():
			return
		var pick: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
		var id := String(pick["id"])
		gs.perform_action(id, pick["cell"])
		_performed[id] = int(_performed.get(id, 0)) + 1

	# Buildings do not go through perform_action, so drive them separately.
	if _rng.randf() < 0.35:
		_try_build(gs)


func _legal_actions(gs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cell in gs.tiles:
		for action in gs.actions_for(cell):
			if not bool(action["enabled"]) or bool(action["overlay"]):
				continue
			out.append({"id": action["id"], "cell": cell})
	return out


func _try_build(gs) -> void:
	var entry: Dictionary = GameData.BUILDABLES[
		_rng.randi_range(0, GameData.BUILDABLES.size() - 1)
	]
	for cell in gs.tiles:
		if not bool(gs.can_build_at(cell)["ok"]):
			continue
		if gs.build(String(entry["name"]), cell):
			_performed["build"] = int(_performed.get("build", 0)) + 1
		return


# --- Invariants --------------------------------------------------------------

func _check_invariants(gs) -> void:
	for key in GameData.RESOURCES:
		var value := int(gs.resources.get(key, 0))
		if value < 0:
			_violate("negative")
		if key != "gold" and value > gs.storage_capacity():
			_violate("overflow")

	for track in GameData.REPUTATION_TRACKS:
		var standing := int(gs.reputation.get(track, 0))
		if standing < 0 or standing > 100:
			_violate("reputation")

	if int(gs.population) < 0:
		_violate("population")

	for cell in gs.settlements:
		if not gs.is_owned(cell):
			_violate("settlement_owned")

	for building in gs.buildings:
		var cell: Vector2i = building["cell"]
		if not gs.is_owned(cell):
			_violate("building_owned")
		if gs.settlement_at(cell) > 0:
			_violate("building_on_settlement")

	for cell in gs.hidden_tiles:
		if gs.tiles.get(cell, GameData.Terrain.FOG) != GameData.Terrain.FOG:
			_violate("hidden_leak")


func _violate(key: String) -> void:
	_violations[key] = int(_violations.get(key, 0)) + 1


# --- Output ------------------------------------------------------------------

func _print_row(gs) -> void:
	var fogged := 0
	for cell in gs.tiles:
		if gs.tiles[cell] == GameData.Terrain.FOG:
			fogged += 1

	print("  %4d | %6d %6d %6d | %5d | %7d %5d %6d | %4d | %d" % [
		gs.turn_count,
		int(gs.resources["gold"]), int(gs.resources["food"]), int(gs.resources["iron"]),
		int(gs.population),
		gs.owned.size(), gs.settlements.size(), gs.buildings.size(),
		fogged, gs.contracts.size(),
	])


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-48s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-48s = %s (cekano %s)" % [label, actual, expected])
