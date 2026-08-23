extends SceneTree

## Checks the generated Dustfall map against the economy: counts each terrain,
## prints the resulting production, and asserts the map is actually playable
## (it produces the resources the design says it should).
##
## godot --headless --path . --script res://scripts/dev/map_economy_test.gd

var _failures := 0
var _ran := 0
const EXPECTED_CHECKS := 10


func _initialize() -> void:
	var gs := root.get_node("GameState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 18720412

	var tiles := MapBuilder.generate_terrain(rng)
	gs.load_tiles(tiles)

	print("\n[1] Slozeni mapy (%d dlazdic)" % tiles.size())
	var counts := {}
	for cell in tiles:
		var t: int = tiles[cell]
		counts[t] = int(counts.get(t, 0)) + 1
	for terrain in GameData.Terrain.values():
		var n := int(counts.get(terrain, 0))
		if n > 0:
			print("  %-22s %d" % [GameData.TERRAIN_NAMES[terrain], n])

	_check("mapa ma 91 dlazdic (polomer 5)", tiles.size(), 91)
	_check("prave jedno mesto", int(counts.get(GameData.Terrain.TOWN, 0)), 1)
	_check("existuje zeleznice", int(counts.get(GameData.Terrain.RAILWAY, 0)) > 0, true)
	_check("existuje dul", int(counts.get(GameData.Terrain.MINE, 0)) > 0, true)
	_check("existuje uzemi H-V", int(counts.get(GameData.Terrain.ENEMY, 0)) > 0, true)

	print("\n[2] Ekonomika teto mapy")
	var eco = gs.calculate_economy()
	for key in GameData.RESOURCES:
		print("  %-8s hruby %4d  spotreba %4d  cisty %+5d" % [
			key, eco["gross"][key], eco["consumption"][key], eco["net"][key]
		])

	_check("mapa produkuje zlato", eco["gross"]["gold"] > 0, true)
	_check("mapa produkuje jidlo", eco["gross"]["food"] > 0, true)
	_check("mapa produkuje zelezo z dolu", eco["gross"]["iron"] > 0, true)
	_check("mapa produkuje uhli z dolu", eco["gross"]["coal"] > 0, true)
	_check("mapa produkuje drevo z owned", eco["gross"]["wood"] > 0, true)

	print("\n[3] Prvni tri tahy")
	gs.set_seed(99)
	gs.coach_in = 99
	for i in 3:
		var gold_before: int = gs.resources["gold"]
		var food_before: int = gs.resources["food"]
		gs.advance_turn()
		print("  tah %d: %s %d | zlato %d -> %d | jidlo %d -> %d | tech %d" % [
			gs.turn_count, gs.season, gs.year,
			gold_before, gs.resources["gold"],
			food_before, gs.resources["food"],
			gs.tech_points,
		])

	print("")
	if _ran < EXPECTED_CHECKS:
		print("SELHALO: probehlo jen %d z %d kontrol" % [_ran, EXPECTED_CHECKS])
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
		print("  ok   %-40s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-40s = %s (cekano %s)" % [label, actual, expected])
