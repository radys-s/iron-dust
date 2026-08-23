extends SceneTree

## Hammers the battle resolver. Combat.resolve() is pure, so the whole outcome
## table can be checked exhaustively instead of hoping a play-through hits every
## branch.
##
## godot --headless --path . --script res://scripts/dev/combat_test.gd

const EXPECTED_CHECKS := 19
const SAMPLES := 4000

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")
	gs.start_new_game(18720412)

	_test_power(gs)
	_test_outcome_table()
	_test_distribution()
	_test_capitulation()

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


# --- Power -------------------------------------------------------------------

func _test_power(gs) -> void:
	print("\n[1] Vypocet sily")
	var cell := Vector2i(0, 4)

	gs.reputation["soldiers"] = 72
	gs.researched_techs.clear()
	gs.settlements = {}
	# 72 / 8 = 9, zadny tech, zadne sidlo.
	_check("zaklad z reputace vojaku", Combat.player_power(gs, cell), 9)

	gs.researched_techs.append("militia")
	gs.researched_techs.append("artillery")
	# +2 milice, +3 delostrelectvo.
	_check("sila s milici a delostrelectvem", Combat.player_power(gs, cell), 14)

	# Fort (uroven 3) v dosahu pridava svou obranu.
	gs.settlements = {Vector2i(0, 3): 3}
	_check("podpora fortu v dosahu", Combat.settlement_support(gs, cell), 3)
	_check("sila vcetne podpory", Combat.player_power(gs, cell), 17)

	# Mimo dosah uz nepomuze.
	gs.settlements = {Vector2i(0, 0): 3}
	_check("sidlo mimo dosah nepodporuje", Combat.settlement_support(gs, cell), 0)

	gs.settlements = {}
	gs.researched_techs.clear()
	gs.turn_count = 0
	var near_power := Combat.enemy_power(gs, Vector2i(0, 3))
	var far_power := Combat.enemy_power(gs, Vector2i(0, 6))
	_check("H-V je silnejsi dal od mesta", far_power > near_power, true)

	gs.turn_count = 60
	_check("H-V posiluje s postupem hry",
		Combat.enemy_power(gs, Vector2i(0, 3)) > near_power, true)
	gs.turn_count = 0


# --- Outcome table -----------------------------------------------------------

func _test_outcome_table() -> void:
	print("\n[2] Tabulka vysledku podle marze")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var mismatches := 0
	var reported_capture_errors := 0

	for i in SAMPLES:
		var mine := rng.randi_range(0, 24)
		var theirs := rng.randi_range(0, 24)
		var report := Combat.resolve(mine, theirs, rng, false)

		if int(report["result"]) != _expected_result(int(report["margin"])):
			mismatches += 1

		# Vysledek a jeho dopad musi sedet: zabrat lze jen pri vitezstvi.
		var captures := bool(report["captures"])
		var winning := int(report["margin"]) >= 1
		if captures != winning:
			reported_capture_errors += 1

	_check("vysledek vzdy odpovida marzi", mismatches, 0)
	_check("zabrat lze jen pri kladne marzi", reported_capture_errors, 0)

	# Kostka musi byt v rozsahu 1..6 pro obe strany.
	rng.seed = 77
	var out_of_range := 0
	for i in SAMPLES:
		var report := Combat.resolve(5, 5, rng, false)
		if int(report["player_die"]) < 1 or int(report["player_die"]) > GameData.COMBAT_DIE:
			out_of_range += 1
		if int(report["enemy_die"]) < 1 or int(report["enemy_die"]) > GameData.COMBAT_DIE:
			out_of_range += 1
	_check("k6 je vzdy 1..6", out_of_range, 0)


func _expected_result(margin: int) -> int:
	if margin >= Combat.CRUSHING_MARGIN:
		return GameData.CombatResult.CRUSHING
	if margin >= 1:
		return GameData.CombatResult.VICTORY
	if margin == 0:
		return GameData.CombatResult.STALEMATE
	if margin <= Combat.ROUT_MARGIN:
		return GameData.CombatResult.ROUT
	return GameData.CombatResult.DEFEAT


# --- Distribution ------------------------------------------------------------

func _test_distribution() -> void:
	print("\n[3] Rozdeleni vysledku")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1872

	var seen := {}
	for i in SAMPLES:
		var mine := rng.randi_range(0, 20)
		var theirs := rng.randi_range(0, 20)
		var report := Combat.resolve(mine, theirs, rng, false)
		var key := int(report["result"])
		seen[key] = int(seen.get(key, 0)) + 1

	for result in GameData.CombatResult.values():
		if result == GameData.CombatResult.CAPITULATION:
			continue
		var name: String = GameData.COMBAT_RESULT_NAMES[result]
		print("  %-20s %d" % [name, int(seen.get(result, 0))])
		_check("vyskytuje se %s" % name.to_lower(), int(seen.get(result, 0)) > 0, true)

	# Silnejsi strana ma vyhravat vyrazne casteji nez prohravat.
	rng.seed = 5150
	var wins := 0
	var losses := 0
	for i in SAMPLES:
		var report := Combat.resolve(18, 8, rng, false)
		if bool(report["captures"]):
			wins += 1
		elif int(report["margin"]) < 0:
			losses += 1
	print("  prevaha 18 vs 8: vyhry %d, prohry %d" % [wins, losses])
	_check("drtiva prevaha temer vzdy vitezi", wins > losses * 20, true)

	# Vyrovnane sily maji dat remizu radove v jednotkach procent.
	rng.seed = 909
	var draws := 0
	for i in SAMPLES:
		if int(Combat.resolve(10, 10, rng, false)["margin"]) == 0:
			draws += 1
	var draw_rate := float(draws) / float(SAMPLES)
	print("  remizy pri vyrovnanych silach: %.1f %%" % (draw_rate * 100.0))
	_check("remiza je mezi 10 a 22 %", draw_rate > 0.10 and draw_rate < 0.22, true)


# --- Court -------------------------------------------------------------------

func _test_capitulation() -> void:
	print("\n[4] Soudni vliv")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337

	var capitulations := 0
	for i in SAMPLES:
		var report := Combat.resolve(2, 20, rng, true)
		if bool(report["capitulated"]):
			capitulations += 1
			if not bool(report["captures"]):
				_fail("kapitulace nezabrala uzemi")
				return

	var rate := float(capitulations) / float(SAMPLES)
	print("  kapitulaci: %.1f %% (ocekavano ~%.0f %%)" % [
		rate * 100.0, GameData.COURT_CAPITULATION_CHANCE * 100.0
	])
	_check("kapitulace kolem 30 %", absf(rate - GameData.COURT_CAPITULATION_CHANCE) < 0.04, true)

	# Bez Soudniho vlivu nekapituluje nikdo, ani proti presile.
	rng.seed = 31337
	var without := 0
	for i in SAMPLES:
		if bool(Combat.resolve(2, 20, rng, false)["capitulated"]):
			without += 1
	_check("bez soudu zadna kapitulace", without, 0)


# --- Harness -----------------------------------------------------------------

func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-44s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-44s = %s (cekano %s)" % [label, actual, expected])


func _fail(label: String) -> void:
	_ran += 1
	_failures += 1
	print("  FAIL %s" % label)
