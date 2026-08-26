extends SceneTree

## Hammers the win condition and the settlement-cleanup fix its design exposed
## in _do_attack(): a settlement Harlan-Voss founded on a cell the player later
## captures must not go on contributing income/defense from land that is no
## longer theirs — the same reasoning _capture_player_cell() already applies
## to the player's own settlements when Harlan-Voss takes a cell.
##
## godot --headless --path . --script res://scripts/dev/victory_test.gd

const EXPECTED_CHECKS := 16
const SEED := 18720412
## Same cell _battle() in scenario_demo.gd already relies on: hand-authored
## Harlan-Voss ground whose neighbor (0,2) sits inside the starting owned
## ring (OWNED_RADIUS), so it is always a legal attack target with no setup.
const TARGET := Vector2i(0, 3)

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")

	_test_last_cell_wins(gs)
	_test_not_last_cell(gs)
	_test_guards_after_victory(gs)
	_test_settlement_cleared_on_capture(gs)

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


## Same "ohromna prevaha" pattern enemy_ai_test.gd uses for its defender side —
## here it guarantees the attacker's roll captures regardless of the d6.
func _stack_odds(gs) -> void:
	gs.reputation["soldiers"] = 100000
	for id in ["militia", "escort", "artillery", "weapons"]:
		if not gs.has_tech(id):
			gs.researched_techs.append(id)


func _clear_all_but(gs, keep: Vector2i) -> void:
	for cell in gs.tiles.keys():
		if gs.tiles[cell] == GameData.Terrain.ENEMY and cell != keep:
			gs.tiles[cell] = GameData.Terrain.OWNED
			gs.owned[cell] = true


# --- Last cell -----------------------------------------------------------

func _test_last_cell_wins(gs) -> void:
	print("\n[1] Posledni dlazdice H-V padne -> vitezstvi")
	gs.start_new_game(SEED)
	_clear_all_but(gs, TARGET)
	_stack_odds(gs)

	# Lambda zachytava lokalni int hodnotou, ne odkazem — pole obchazi ten
	# problem, protoze je referencni typ.
	var fired := [0]
	gs.game_over.connect(func(_reason: String) -> void: fired[0] += 1)

	_check("pred utokem hra nebyla vyhrana", gs.is_victorious, false)
	_check("H-V drzi presne jednu dlazdici", gs._enemy_tile_count(), 1)

	var result: Dictionary = gs.perform_action("attack", TARGET)
	_check("utok probehl", bool(result["ok"]), true)
	_check("posledni dlazdice padla -> vitezstvi", gs.is_victorious, true)
	_check("H-V uz nedrzi nic", gs._enemy_tile_count(), 0)
	_check("dlazdice je nyni hracova", gs.get_tile(TARGET), GameData.Terrain.OWNED)
	_check("duvod vitezstvi je vyplneny", gs.game_over_reason.is_empty(), false)
	_check("signal game_over se vyslal prave jednou", fired[0], 1)


# --- Not the last cell -----------------------------------------------------

func _test_not_last_cell(gs) -> void:
	print("\n[2] Zabrani jedne dlazdice mezi mnoha nestaci")
	gs.start_new_game(SEED)
	_stack_odds(gs)

	var before: int = gs._enemy_tile_count()
	var result: Dictionary = gs.perform_action("attack", TARGET)
	_check("utok probehl", bool(result["ok"]), true)
	_check("H-V porad drzi zbytek uzemi", gs._enemy_tile_count(), before - 1)
	_check("hra jeste neni vyhrana", gs.is_victorious, false)


# --- Guards -----------------------------------------------------------------

func _test_guards_after_victory(gs) -> void:
	print("\n[3] Po vitezstvi je hra uzavrena stejne jako po prohre")
	gs.start_new_game(SEED)
	_clear_all_but(gs, TARGET)
	_stack_odds(gs)
	gs.perform_action("attack", TARGET)
	_check("scenar skutecne vyhral", gs.is_victorious, true)

	var turn_before: int = gs.turn_count
	gs.advance_turn()
	_check("po vitezstvi je advance_turn no-op", gs.turn_count, turn_before)

	var result: Dictionary = gs.perform_action("explore", Vector2i(1, 1))
	_check("po vitezstvi perform_action odmitne", bool(result["ok"]), false)


# --- Settlement cleanup bug fix ---------------------------------------------

func _test_settlement_cleared_on_capture(gs) -> void:
	print("\n[4] Zabrana dlazdice s AI sidlem sidlo smaze")
	gs.start_new_game(SEED)
	gs.ai_settlements[TARGET] = 2
	_stack_odds(gs)

	var result: Dictionary = gs.perform_action("attack", TARGET)
	_check("utok probehl", bool(result["ok"]), true)
	_check("AI sidlo na zabrane dlazdici zmizelo", gs.ai_settlements.has(TARGET), false)


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-52s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-52s = %s (cekano %s)" % [label, actual, expected])
