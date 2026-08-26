extends SceneTree

## Overuje predavaci retezec menu -> herni scena, ktery se jinak da otestovat
## jen rucnim proklikanim: rezim zvoleny v menu se musi opravdu promitnout do
## pravidel partie a prezit ulozeni a nacteni.
##
## godot --headless --path . --script res://scripts/dev/menu_flow_test.gd

const EXPECTED_CHECKS := 17
const SEED := 18720412
const SLOT := 3

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")

	print("\n[1] Rezimy maji opravdu jina pravidla")
	var beginner := Ruleset.for_mode(Ruleset.BEGINNER)
	var advanced := Ruleset.for_mode(Ruleset.ADVANCED)
	_check("v Beginner nemuze H-V vzit Dustfall", bool(beginner["ai_can_capture_town"]), false)
	_check("v Advanced muze H-V vzit Dustfall", bool(advanced["ai_can_capture_town"]), true)
	_check("naradi je potreba jen v Advanced", bool(beginner["build_requires_tools"]), false)
	_check("Beginner ma velkorysejsi limit tahu",
		int(beginner["turn_limit"]) > int(advanced["turn_limit"]), true)
	_check("Beginner ma drazsi utoky H-V",
		int(beginner["ai_attack_cost_gold"]) > int(advanced["ai_attack_cost_gold"]), true)
	_check("neznamy rezim spadne na Advanced (ne na lehci)",
		bool(Ruleset.for_mode("nesmysl")["ai_can_capture_town"]), true)

	print("\n[2] Volba z menu se promitne do partie")
	gs.start_new_game(SEED, Ruleset.BEGINNER)
	_check("rezim je ulozeny", gs.mode, Ruleset.BEGINNER)
	_check("pravidla odpovidaji rezimu", bool(gs.ruleset["ai_can_capture_town"]), false)

	gs.start_new_game(SEED, Ruleset.ADVANCED)
	_check("prepnuti rezimu prepise pravidla", bool(gs.ruleset["ai_can_capture_town"]), true)

	# Testy z Fazi 2-5 volaji start_new_game(SEED) bez rezimu — nesmi jim to
	# rezim prepsat, jinak by se rozbila cela stavajici sada.
	gs.start_new_game(SEED)
	_check("volani bez rezimu nechá predchozi", gs.mode, Ruleset.ADVANCED)

	print("\n[3] Rezim prezije ulozeni a nacteni")
	gs.start_new_game(SEED, Ruleset.BEGINNER)
	_check("ulozeni probehlo", gs.save_to_slot(SLOT), true)
	gs.start_new_game(SEED, Ruleset.ADVANCED)
	_check("nacteni probehlo", gs.load_from_slot(SLOT), true)
	_check("nacteny rezim sedi", gs.mode, Ruleset.BEGINNER)
	# Pravidla se neukladaji, odvozuji se z rezimu — doladeni balancu tak plati
	# i pro rozehrane hry.
	_check("pravidla se po nacteni odvodila znovu",
		bool(gs.ruleset["ai_can_capture_town"]), false)
	SaveGame.delete_slot(SLOT)

	print("
[4] Slib z menu plati i v chovani, ne jen v tabulce")
	# Obrazovka vyberu obtiznosti rika doslova "Harlan-Voss vás nemůže zničit".
	# Tohle overuje, ze to plati i kdyz se korporace k Dustfallu probojuje —
	# jednou uz se stalo, ze pravidlo existovalo, ale nikdo ho necetl.
	gs.start_new_game(SEED, Ruleset.BEGINNER)
	gs.tiles[Vector2i(0, 1)] = GameData.Terrain.ENEMY
	gs.ai_resources["gold"] = 1000000
	gs._ai_attack_player_cell(MapBuilder.TOWN_CELL, Vector2i(0, 1))
	_check("v Zacatecnikovi Dustfall nepadne", gs.is_defeated, false)
	_check("a zustava hracuv", gs.get_tile(MapBuilder.TOWN_CELL), GameData.Terrain.TOWN)

	# V Pokrocilem musi tataz cesta porad fungovat, jinak by slo o regresi Faze 4.
	gs.start_new_game(SEED, Ruleset.ADVANCED)
	gs.tiles[Vector2i(0, 1)] = GameData.Terrain.ENEMY
	gs.ai_resources["gold"] = 1000000
	gs._ai_attack_player_cell(MapBuilder.TOWN_CELL, Vector2i(0, 1))
	_check("v Pokrocilem Dustfall padnout muze", gs.is_defeated, true)

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


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-52s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-52s = %s (cekano %s)" % [label, actual, expected])
