extends Node

## Authoritative game state (autoload). Holds resources, reputation, the tech
## tree, buildings and the map; runs the per-turn economy. UI listens to signals
## rather than polling.
##
## Economy rules are ported from the HTML prototype (reference/prototype/app.js,
## calculateEconomyState + runTurnEconomy).

signal resources_changed(resources: Dictionary)
signal turn_advanced(turn: int, season: String, year: int)
signal notified(text: String, type: String)
signal story_added(entry: Dictionary)
signal tech_researched(tech_id: String)
signal reputation_changed(reputation: Dictionary)
signal map_changed()

var player_name := "Hráč"
var year := 1872
var season := GameData.SEASONS[0]
var turn_count := 0
var population := 1240

var resources := {"gold": 2340, "food": 480, "iron": 210, "wood": 95, "coal": 140, "salt": 62}
var reputation := {"settlers": 68, "merchants": 54, "soldiers": 72, "tribes": 45}

var researched_techs: Array[String] = []
var tech_points := 0
var tech_total_earned := 0

## Placed buildings: [{name, production, cell}]
var buildings: Array[Dictionary] = []

## Map: Vector2i cell -> GameData.Terrain
var tiles: Dictionary = {}

var coach_in := 3
var story_log: Array[Dictionary] = []

## Cached result of calculate_economy(), refreshed after every change.
var economy: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	refresh_economy()


## Deterministic runs for tests and reproducible maps.
func set_seed(value: int) -> void:
	_rng.seed = value


# --- Tech --------------------------------------------------------------------

func has_tech(id: String) -> bool:
	return id in researched_techs


func can_research(id: String) -> bool:
	if has_tech(id):
		return false
	var node := GameData.find_tech(id)
	if node.is_empty():
		return false
	if tech_points < int(node["cost"]):
		return false
	for required in node["requires"]:
		if not has_tech(required):
			return false
	return true


func research(id: String) -> bool:
	if not can_research(id):
		return false
	var node := GameData.find_tech(id)
	tech_points -= int(node["cost"])
	researched_techs.append(id)

	# One-off effects that land the moment the node is unlocked.
	match id:
		"council":
			adjust_reputation("settlers", 10)
		"federal":
			adjust_reputation("merchants", 8)

	refresh_economy()
	tech_researched.emit(id)
	notify("Výzkum dokončen: %s" % node["name"], "success")
	add_story("Výzkum dokončen: %s." % node["name"])
	return true


## Total combat strength from researched tech (used by the Phase 3 combat system).
func tech_combat_power() -> int:
	var total := 0
	for id in researched_techs:
		total += int(GameData.TECH_COMBAT_POWER.get(id, 0))
	return total


# --- Map ---------------------------------------------------------------------

func set_tile(cell: Vector2i, terrain: GameData.Terrain) -> void:
	tiles[cell] = terrain
	refresh_economy()
	map_changed.emit()


func get_tile(cell: Vector2i) -> GameData.Terrain:
	return tiles.get(cell, GameData.Terrain.FOG)


func load_tiles(new_tiles: Dictionary) -> void:
	tiles = new_tiles.duplicate()
	refresh_economy()
	map_changed.emit()


# --- Economy -----------------------------------------------------------------

## Mirrors calculateEconomyState() from the prototype.
func calculate_economy() -> Dictionary:
	var tile_production := GameData.empty_resources()
	var building_production := GameData.empty_resources()
	var counts := {}

	var transit_multiplier := 1.0
	if has_tech("express"):
		transit_multiplier += 0.1
	if has_tech("steel"):
		transit_multiplier += 0.1

	for cell in tiles:
		var terrain: GameData.Terrain = tiles[cell]
		if not GameData.TERRAIN_YIELDS.has(terrain):
			continue
		counts[terrain] = int(counts.get(terrain, 0)) + 1
		for key in GameData.TERRAIN_YIELDS[terrain]:
			var amount: int = GameData.TERRAIN_YIELDS[terrain][key]
			if key == "gold" and terrain in [GameData.Terrain.RAILWAY, GameData.Terrain.TOWN]:
				amount = roundi(float(amount) * transit_multiplier)
			tile_production[key] += amount

	# Railway tech node is a flat per-turn gold bonus, not a tile yield.
	if has_tech("railway"):
		tile_production["gold"] += 20

	for building in buildings:
		for key in building.get("production", {}):
			building_production[key] += int(building["production"][key])

	if has_tech("steam"):
		for key in GameData.RESOURCES:
			building_production[key] = roundi(float(building_production[key]) * 1.5)

	var gross := GameData.empty_resources()
	for key in GameData.RESOURCES:
		gross[key] = tile_production[key] + building_production[key]

	var storage_capacity := GameData.BASE_STORAGE_CAPACITY
	for building in buildings:
		if building.get("name", "") == GameData.STORAGE_BUILDING:
			storage_capacity += GameData.STORAGE_PER_BUILDING

	var consumption := GameData.empty_resources()
	consumption["food"] = int(floor(float(population) / GameData.POPULATION_PER_FOOD))
	consumption["gold"] = buildings.size() * GameData.BUILD_UPKEEP_GOLD
	if int(reputation.get("soldiers", 0)) > GameData.SOLDIER_UPKEEP_REPUTATION:
		consumption["gold"] += GameData.SOLDIER_UPKEEP_GOLD

	var net := GameData.empty_resources()
	for key in GameData.RESOURCES:
		net[key] = gross[key] - consumption[key]

	return {
		"counts": counts,
		"tile_production": tile_production,
		"building_production": building_production,
		"gross": gross,
		"consumption": consumption,
		"net": net,
		"storage_capacity": storage_capacity,
	}


func refresh_economy() -> void:
	economy = calculate_economy()


func storage_capacity() -> int:
	if economy.is_empty():
		return GameData.BASE_STORAGE_CAPACITY
	return int(economy["storage_capacity"])


## Applies a delta and returns how much actually landed after clamping.
## Gold has no ceiling; everything else is capped by storage.
func apply_resource(key: String, delta: int) -> int:
	if delta == 0:
		return 0
	var current := int(resources.get(key, 0))
	var next := current + delta
	if key == "gold":
		next = maxi(0, next)
	else:
		next = clampi(next, 0, storage_capacity())
	var applied := next - current
	if applied == 0:
		return 0
	resources[key] = next
	resources_changed.emit(resources)
	return applied


func apply_resource_bundle(bundle: Dictionary, factor: int = 1) -> Dictionary:
	var applied := GameData.empty_resources()
	for key in GameData.RESOURCES:
		applied[key] = apply_resource(key, int(bundle.get(key, 0)) * factor)
	return applied


func can_afford(costs: Dictionary) -> bool:
	for key in costs:
		if int(resources.get(key, 0)) < int(costs[key]):
			return false
	return true


func missing_costs(costs: Dictionary) -> Dictionary:
	var missing := {}
	for key in costs:
		var short := int(costs[key]) - int(resources.get(key, 0))
		if short > 0:
			missing[key] = short
	return missing


func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for key in costs:
		apply_resource(key, -int(costs[key]))
	return true


# --- Buildings ---------------------------------------------------------------

func build(name: String, cell: Vector2i) -> bool:
	var entry := GameData.find_buildable(name)
	if entry.is_empty():
		return false
	if not can_afford(entry["costs"]):
		var missing := missing_costs(entry["costs"])
		var parts: Array[String] = []
		for key in missing:
			parts.append("%d %s" % [missing[key], GameData.RESOURCE_LABELS[key]])
		notify("Chybí: %s" % ", ".join(parts), "warning")
		return false

	spend(entry["costs"])
	buildings.append({
		"name": name,
		"production": entry["production"].duplicate(),
		"cell": cell,
	})
	refresh_economy()
	notify("Postaveno: %s" % name, "success")
	add_story("V Dustfallu vyrostla stavba: %s." % name)
	return true


# --- Reputation --------------------------------------------------------------

func adjust_reputation(track: String, delta: int) -> void:
	if not reputation.has(track):
		return
	var before := int(reputation[track])
	reputation[track] = clampi(before + delta, 0, 100)
	if reputation[track] == before:
		return
	reputation_changed.emit(reputation)

	if before >= GameData.REPUTATION_LOW and reputation[track] < GameData.REPUTATION_LOW:
		notify(GameData.REPUTATION_PENALTIES[track], "warning")
		add_story(GameData.REPUTATION_PENALTIES[track])
	elif before < GameData.REPUTATION_HIGH and reputation[track] >= GameData.REPUTATION_HIGH:
		notify("%s vám fandí." % GameData.REPUTATION_LABELS[track], "success")


# --- Turn --------------------------------------------------------------------

func advance_turn() -> void:
	var season_index := GameData.SEASONS.find(season) + 1
	if season_index >= GameData.SEASONS.size():
		season_index = 0
		year += 1
		add_story("Začal nový rok %d." % year)
	season = GameData.SEASONS[season_index]
	turn_count += 1

	_run_turn_economy()
	_award_tech_points()
	_tick_coach()
	_trigger_random_event()

	refresh_economy()
	notify("Tah dokončen. Nyní je %s %d." % [season, year], "info")
	turn_advanced.emit(turn_count, season, year)


func _run_turn_economy() -> void:
	var eco := calculate_economy()
	apply_resource_bundle(eco["gross"])
	apply_resource("gold", -int(eco["consumption"]["gold"]))

	var food_consumption := int(eco["consumption"]["food"])
	var projected_food := int(resources.get("food", 0)) - food_consumption
	apply_resource("food", -food_consumption)

	if projected_food < 0:
		population = maxi(0, population - GameData.STARVATION_POPULATION_LOSS)
		notify("Nedostatek jídla! Populace klesá o %d." % GameData.STARVATION_POPULATION_LOSS, "warning")

	notify("Produkce: +%d zlata, +%d jídla, +%d železa" % [
		eco["gross"]["gold"], eco["gross"]["food"], eco["gross"]["iron"]
	], "production")


func _award_tech_points() -> void:
	if turn_count % GameData.TECH_POINTS_INTERVAL != 0:
		return
	var points := GameData.TECH_POINTS_BASE
	if has_tech("forge"):
		points += GameData.TECH_POINTS_FORGE_BONUS
	tech_points += points
	tech_total_earned += points
	notify("Technologické body: +%d" % points, "info")
	add_story("Získány technologické body: +%d." % points)


func _tick_coach() -> void:
	coach_in -= 1
	if coach_in > 0:
		return
	apply_resource("gold", GameData.COACH_GOLD)
	population += GameData.COACH_POPULATION
	notify("Dostavník dorazil! +%d zlata, +%d populace" % [
		GameData.COACH_GOLD, GameData.COACH_POPULATION
	], "success")
	add_story("Dostavník dorazil do Dustfallu s novými osadníky a hotovostí.")
	var minimum := 1 if has_tech("coach") else 2
	coach_in = _rng.randi_range(0, 2) + minimum


func _trigger_random_event() -> void:
	var event: Dictionary = GameData.RANDOM_EVENTS[_rng.randi_range(0, GameData.RANDOM_EVENTS.size() - 1)]
	for key in event["resources"]:
		apply_resource(key, int(event["resources"][key]))
	for track in event["reputation"]:
		adjust_reputation(track, int(event["reputation"][track]))
	if int(event["population"]) != 0:
		population = maxi(0, population + int(event["population"]))
	notify(event["text"], event["type"])
	add_story(event["text"])


# --- Log ---------------------------------------------------------------------

func notify(text: String, type: String = "info") -> void:
	notified.emit(text, type)


func add_story(text: String) -> void:
	var entry := {"year": year, "season": season, "turn": turn_count, "text": text}
	story_log.push_front(entry)
	if story_log.size() > 100:
		story_log.resize(100)
	story_added.emit(entry)
