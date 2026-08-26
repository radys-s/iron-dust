extends Node

## Authoritative game state (autoload). Holds resources, reputation, the tech
## tree, the map with its ownership layer, settlements, buildings, the market and
## the contract book; runs the per-turn economy. UI listens to signals rather
## than polling.
##
## Economy rules are ported from the HTML prototype (reference/prototype/app.js,
## calculateEconomyState + runTurnEconomy). Everything added in Phase 3 —
## claiming, settlements, combat, trade — layers on top without changing those
## numbers: an unclaimed, settlement-free game still balances exactly as before.

signal resources_changed(resources: Dictionary)
signal turn_advanced(turn: int, season: String, year: int)
signal notified(text: String, type: String)
signal story_added(entry: Dictionary)
signal tech_researched(tech_id: String)
signal reputation_changed(reputation: Dictionary)
signal map_changed()
signal combat_resolved(report: Dictionary)
signal contracts_changed()
signal market_changed()
signal game_loaded()
signal game_over(reason: String)

const STARTING_RESOURCES := {
	"gold": 2340, "food": 480, "iron": 210, "wood": 95, "coal": 140, "salt": 62,
}
const STARTING_REPUTATION := {
	"settlers": 68, "merchants": 54, "soldiers": 72, "tribes": 45,
}
const STARTING_POPULATION := 1240
const STARTING_COACH_IN := 3

var player_name := "Hráč"
var year := 1872
var season := GameData.SEASONS[0]
var turn_count := 0
var population := STARTING_POPULATION

var resources: Dictionary = STARTING_RESOURCES.duplicate()
var reputation: Dictionary = STARTING_REPUTATION.duplicate()

var researched_techs: Array[String] = []
var tech_points := 0
var tech_total_earned := 0

## Placed buildings: [{name, production, cell}]
var buildings: Array[Dictionary] = []

## Map: Vector2i cell -> GameData.Terrain, as the player currently sees it.
var tiles: Dictionary = {}

## What FOG is hiding. Revealed one cell at a time by the explore action.
var hidden_tiles: Dictionary = {}

## Explicitly claimed cells (Vector2i -> true). TOWN and OWNED terrain count as
## yours without an entry here — see is_owned().
var owned: Dictionary = {}

## Vector2i -> settlement level (1..4).
var settlements: Dictionary = {}

## One-shot actions already spent, keyed "q,r|action_id".
var used_actions: Dictionary = {}

## Market price multipliers per tradeable good, random-walked every turn.
var market: Dictionary = {}

var contracts: Array[Dictionary] = []
var next_contract_id := 1

## Turns until the coach arrives, and how long it stays once it has.
var coach_in := 3
var coach_stay := 0

var map_seed := 0
var story_log: Array[Dictionary] = []

## Cached result of calculate_economy(), refreshed after every change.
var economy: Dictionary = {}

## Last battle report, kept so the UI can re-open the detail panel.
var last_combat: Dictionary = {}

## Battles fought since the turn began; reset by advance_turn().
var attacks_this_turn := 0

## Harlan-Voss' own ledger — same 6-key shape as the player's `resources` for
## consistency, though only "gold" moves in Phase 4.
var ai_resources: Dictionary = GameData.empty_resources()

## Vector2i -> settlement level (1..4). Parallel to but never overlapping the
## player's own `settlements`. AI territory itself is not tracked separately —
## a cell belongs to Harlan-Voss iff its terrain is Terrain.ENEMY, see
## is_ai_territory() — so there is no "ai_owned" dictionary to keep in sync.
var ai_settlements: Dictionary = {}

## Set once Dustfall falls, or once Harlan-Voss holds no territory at all.
## Either flips this pair: advance_turn()/perform_action() become no-ops.
var is_defeated := false
var is_victorious := false
var game_over_reason := ""

## Rules this particular game runs under — see Ruleset. Always fully populated
## by start_new_game(), never consulted with a fallback, so a forgotten key
## fails loudly instead of silently reverting to a default.
var mode := Ruleset.ADVANCED
var ruleset: Dictionary = Ruleset.for_mode(Ruleset.ADVANCED)

## Handover from the main menu, which runs in its own scene and cannot call
## start_new_game() itself — the map has to be built by the play scene, after
## its world node exists. game_scene.gd reads and clears these on _ready().
var pending_mode := ""
var pending_tutorial := false
## 0 = start fresh; otherwise load this slot instead of generating a new map.
var pending_load_slot := 0
## True while the tutorial chapter is running (content lands in Etapa 4).
var tutorial_active := false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	market = Trade.initial_market()
	refresh_economy()


## Deterministic runs for tests and reproducible maps.
func set_seed(value: int) -> void:
	map_seed = value
	_rng.seed = value


## Wipes everything back to turn zero and installs a fresh Dustfall basin.
## Used by the play scene on start-up and by "nová hra" in the save panel.
func start_new_game(seed_value: int, game_mode: String = "") -> void:
	set_seed(seed_value)

	# Prazdny mod = ponechat stavajici. Diky tomu vsechny testy z Fazi 2-5,
	# ktere volaji start_new_game(SEED), bezi dal na vychozich pravidlech.
	if game_mode != "":
		mode = game_mode if Ruleset.is_valid(game_mode) else Ruleset.ADVANCED
	ruleset = Ruleset.for_mode(mode)

	year = 1872
	season = GameData.SEASONS[0]
	turn_count = 0
	population = STARTING_POPULATION
	resources = STARTING_RESOURCES.duplicate()
	reputation = STARTING_REPUTATION.duplicate()

	# Typed arrays reject a plain `[]` literal, so clear them in place.
	researched_techs.clear()
	buildings.clear()
	contracts.clear()
	story_log.clear()

	tech_points = 0
	tech_total_earned = 0
	owned = {}
	settlements = {MapBuilder.TOWN_CELL: MapBuilder.TOWN_SETTLEMENT_LEVEL}
	used_actions = {}
	market = Trade.initial_market()
	next_contract_id = 1
	coach_in = STARTING_COACH_IN
	coach_stay = 0
	last_combat = {}
	attacks_this_turn = 0

	ai_resources = GameData.empty_resources()
	ai_resources["gold"] = GameData.AI_STARTING_GOLD
	ai_settlements = {}
	is_defeated = false
	is_victorious = false
	game_over_reason = ""

	var map := MapBuilder.generate()
	load_tiles(map["tiles"], map["hidden"])

	add_story("Přijezd do Dustfallu. Otevřena dopravní stanice.")
	resources_changed.emit(resources)
	reputation_changed.emit(reputation)
	contracts_changed.emit()
	market_changed.emit()
	game_loaded.emit()


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


## Total combat strength from researched tech.
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


func load_tiles(new_tiles: Dictionary, new_hidden: Dictionary = {}) -> void:
	tiles = new_tiles.duplicate()
	hidden_tiles = new_hidden.duplicate()
	refresh_economy()
	map_changed.emit()


# --- Ownership ---------------------------------------------------------------

## True for the town, for inherited OWNED terrain, and for anything claimed.
func is_owned(cell: Vector2i) -> bool:
	if owned.has(cell):
		return true
	return GameData.INHERENTLY_OWNED.has(get_tile(cell))


func is_adjacent_to_owned(cell: Vector2i) -> bool:
	for neighbor in HexGrid.get_neighbors(cell.x, cell.y):
		if tiles.has(neighbor) and is_owned(neighbor):
			return true
	return false


## A cell belongs to Harlan-Voss iff its terrain is ENEMY — true both for the
## quadrant the map starts with and for anything since claimed or captured,
## since both paths flip the cell's terrain to ENEMY. No separate ledger needed.
func is_ai_territory(cell: Vector2i) -> bool:
	return get_tile(cell) == GameData.Terrain.ENEMY


func owned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in tiles:
		if is_owned(cell):
			out.append(cell)
	return out


func building_at(cell: Vector2i) -> Dictionary:
	for building in buildings:
		if building.get("cell", Vector2i.MAX) == cell:
			return building
	return {}


func settlement_at(cell: Vector2i) -> int:
	return int(settlements.get(cell, 0))


## Steps to the closest settlement, or a large number when there is none.
func nearest_settlement_distance(cell: Vector2i) -> int:
	var best := 9999
	for settlement_cell in settlements:
		best = mini(best, HexGrid.distance(settlement_cell, cell))
	return best


## A hex may host a building only inside some settlement's supply radius.
func in_supply(cell: Vector2i) -> bool:
	for settlement_cell in settlements:
		var reach := int(GameData.settlement_data(settlements[settlement_cell]).get("supply", 0))
		if HexGrid.distance(settlement_cell, cell) <= reach:
			return true
	return false


func has_used_action(cell: Vector2i, id: String) -> bool:
	return used_actions.has(_action_key(cell, id))


func _mark_action_used(cell: Vector2i, id: String) -> void:
	used_actions[_action_key(cell, id)] = true


func _action_key(cell: Vector2i, id: String) -> String:
	return "%d,%d|%s" % [cell.x, cell.y, id]


# --- Economy -----------------------------------------------------------------

## Mirrors calculateEconomyState() from the prototype, extended with the claim
## bonus and settlement output added in Phase 3.
func calculate_economy() -> Dictionary:
	var tile_production := GameData.empty_resources()
	var building_production := GameData.empty_resources()
	var settlement_production := GameData.empty_resources()
	var claim_income := GameData.empty_resources()
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

	# Claimed land that is not already TOWN/OWNED pays a toll; TOWN and OWNED
	# carry their own yields and must not be counted twice.
	for cell in owned:
		if GameData.INHERENTLY_OWNED.has(get_tile(cell)):
			continue
		for key in GameData.CLAIM_BONUS:
			claim_income[key] += int(GameData.CLAIM_BONUS[key])

	for cell in settlements:
		var data := GameData.settlement_data(int(settlements[cell]))
		for key in data.get("production", {}):
			settlement_production[key] += int(data["production"][key])

	for building in buildings:
		for key in building.get("production", {}):
			building_production[key] += int(building["production"][key])

	if has_tech("steam"):
		for key in GameData.RESOURCES:
			building_production[key] = roundi(float(building_production[key]) * 1.5)

	var gross := GameData.empty_resources()
	for key in GameData.RESOURCES:
		gross[key] = tile_production[key] + claim_income[key] \
			+ settlement_production[key] + building_production[key]

	var storage_capacity := GameData.BASE_STORAGE_CAPACITY
	for building in buildings:
		if building.get("name", "") == GameData.STORAGE_BUILDING:
			storage_capacity += GameData.STORAGE_PER_BUILDING

	var consumption := GameData.empty_resources()
	consumption["food"] = int(floor(float(population) / GameData.POPULATION_PER_FOOD))
	consumption["gold"] = buildings.size() * GameData.BUILD_UPKEEP_GOLD
	for cell in settlements:
		consumption["gold"] += int(settlements[cell]) * GameData.SETTLEMENT_UPKEEP_PER_LEVEL
	if int(reputation.get("soldiers", 0)) > GameData.SOLDIER_UPKEEP_REPUTATION:
		consumption["gold"] += GameData.SOLDIER_UPKEEP_GOLD

	var net := GameData.empty_resources()
	for key in GameData.RESOURCES:
		net[key] = gross[key] - consumption[key]

	return {
		"counts": counts,
		"tile_production": tile_production,
		"claim_income": claim_income,
		"settlement_production": settlement_production,
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


# --- Tile actions ------------------------------------------------------------

func actions_for(cell: Vector2i) -> Array[Dictionary]:
	return TileAction.available(self, cell)


## Single entry point for everything the tile panel can trigger. Overlay actions
## ("build", "trade") are refused here — the HUD opens a panel for those.
func perform_action(id: String, cell: Vector2i) -> Dictionary:
	if is_defeated or is_victorious:
		return {"ok": false, "reason": "Hra skončila."}
	if TileAction.is_overlay(id):
		return {"ok": false, "reason": "Tuhle akci otevírá panel, ne přímé volání."}

	var verdict := TileAction.can_perform(self, id, cell)
	if not bool(verdict["ok"]):
		notify(String(verdict["reason"]), "warning")
		return verdict

	spend(TileAction.cost(self, id, cell))
	if id in TileAction.ONE_SHOT_ACTIONS:
		_mark_action_used(cell, id)

	var result: Dictionary
	match id:
		"explore":
			result = _do_explore(cell)
		"claim":
			result = _do_claim(cell)
		"found":
			result = _do_found(cell)
		"upgrade":
			result = _do_upgrade(cell)
		"attack":
			result = _do_attack(cell)
		"prospect":
			result = _do_prospect(cell)
		"repair":
			result = _do_repair(cell)
		_:
			result = {"ok": false, "reason": "Akce %s není implementována." % id}

	refresh_economy()
	map_changed.emit()
	return result


func _do_explore(cell: Vector2i) -> Dictionary:
	var revealed := _reveal(cell)
	var extra: Array[Vector2i] = []

	# Telegraf: zpráva o okolí dorazí spolu s průzkumníkem.
	if has_tech("telegraph"):
		for neighbor in HexGrid.get_neighbors(cell.x, cell.y):
			if tiles.has(neighbor) and tiles[neighbor] == GameData.Terrain.FOG:
				if _reveal(neighbor) != GameData.Terrain.FOG:
					extra.append(neighbor)

	var name: String = GameData.TERRAIN_NAMES[revealed]
	if extra.is_empty():
		notify("Průzkum odhalil: %s" % name, "success")
	else:
		notify("Průzkum odhalil: %s (+%d dalších dlaždic telegrafem)" % [name, extra.size()], "success")
	add_story("Průzkumník se vrátil ze sektoru %d:%d — %s." % [cell.x, cell.y, name])
	return {"ok": true, "reason": "", "terrain": revealed, "extra": extra}


## Lifts the fog on one cell; falls back to prairie if the map never stored a
## hidden terrain for it.
func _reveal(cell: Vector2i) -> GameData.Terrain:
	var revealed: GameData.Terrain = hidden_tiles.get(cell, GameData.Terrain.PRAIRIE)
	if revealed == GameData.Terrain.FOG:
		revealed = GameData.Terrain.PRAIRIE
	tiles[cell] = revealed
	hidden_tiles.erase(cell)
	return revealed


func _do_claim(cell: Vector2i) -> Dictionary:
	var terrain := get_tile(cell)
	owned[cell] = true

	# Prairie becomes fenced-off homestead land; harsher terrain keeps its
	# character and simply starts paying a toll.
	if terrain == GameData.Terrain.PRAIRIE:
		tiles[cell] = GameData.Terrain.OWNED

	adjust_reputation("settlers", 2)
	adjust_reputation("tribes", -2)
	notify("Území %d:%d je vaše." % [cell.x, cell.y], "success")
	add_story("Zábor území %d:%d (%s)." % [cell.x, cell.y, GameData.TERRAIN_NAMES[terrain]])
	return {"ok": true, "reason": "", "terrain": get_tile(cell)}


func _do_found(cell: Vector2i) -> Dictionary:
	settlements[cell] = 1
	var influx := int(GameData.settlement_data(1)["population"])
	population += influx
	adjust_reputation("settlers", 5)
	notify("Založena osada (+%d obyvatel)." % influx, "success")
	add_story("Na %d:%d vyrostla nová osada." % [cell.x, cell.y])
	return {"ok": true, "reason": "", "level": 1}


func _do_upgrade(cell: Vector2i) -> Dictionary:
	var level := settlement_at(cell) + 1
	settlements[cell] = level
	var data := GameData.settlement_data(level)
	var influx := int(data["population"])
	population += influx
	adjust_reputation("settlers", 4)
	notify("Sídlo povýšeno na %s (+%d obyvatel)." % [data["name"], influx], "success")
	add_story("Sídlo na %d:%d bylo povýšeno na %s." % [cell.x, cell.y, data["name"]])
	return {"ok": true, "reason": "", "level": level}


func _do_prospect(cell: Vector2i) -> Dictionary:
	var terrain := get_tile(cell)
	var yields: Dictionary = GameData.PROSPECT_YIELDS.get(terrain, {})
	apply_resource_bundle(yields)

	var struck := false
	if terrain == GameData.Terrain.MOUNTAIN and _rng.randf() < GameData.PROSPECT_MINE_CHANCE:
		tiles[cell] = GameData.Terrain.MINE
		struck = true

	if struck:
		notify("Ložisko odkryto! Z pohoří je důl.", "success")
		add_story("Prospektoři narazili na žílu — na %d:%d vzniká důl." % [cell.x, cell.y])
	else:
		notify("Ložisko vytěženo: %s" % GameData.format_costs(yields), "info")
		add_story("Ložisko na %d:%d bylo prohledáno." % [cell.x, cell.y])
	return {"ok": true, "reason": "", "yields": yields, "mine": struck}


func _do_repair(cell: Vector2i) -> Dictionary:
	adjust_reputation("merchants", GameData.REPAIR_REPUTATION)
	notify("Trať opravena, kupci to ocenili (+%d)." % GameData.REPAIR_REPUTATION, "success")
	add_story("Úsek trati na %d:%d byl opraven." % [cell.x, cell.y])
	return {"ok": true, "reason": ""}


# --- Combat ------------------------------------------------------------------

func combat_preview(cell: Vector2i) -> Dictionary:
	var mine := Combat.player_power(self, cell)
	var theirs := Combat.enemy_power(self, cell)
	return {
		"player": mine,
		"enemy": theirs,
		"forecast": Combat.forecast(mine, theirs),
	}


func _do_attack(cell: Vector2i) -> Dictionary:
	attacks_this_turn += 1
	var report := Combat.resolve(
		Combat.player_power(self, cell),
		Combat.enemy_power(self, cell),
		_rng,
		has_tech("court")
	)
	report["cell"] = cell

	apply_resource_bundle(report["resources"])
	for track in report["reputation"]:
		adjust_reputation(track, int(report["reputation"][track]))

	if bool(report["captures"]):
		tiles[cell] = GameData.Terrain.OWNED
		owned[cell] = true
		# Symmetric to _capture_player_cell() erasing the player's settlement:
		# a settlement Harlan-Voss founded here does not survive the tile
		# changing hands, or it would go on contributing AI income/defense
		# support from land that is no longer theirs.
		ai_settlements.erase(cell)

	elif bool(report["loses_tile"]):
		var lost := _enemy_counterattack(cell)
		report["lost_cell"] = lost

	last_combat = report
	notify(report["text"], "success" if bool(report["captures"]) else "warning")
	add_story("%s u %d:%d (%d proti %d)." % [
		report["name"], cell.x, cell.y, report["player_roll"], report["enemy_roll"]
	])
	combat_resolved.emit(report)
	if bool(report["captures"]):
		_check_victory()
	return {"ok": true, "reason": "", "report": report}


## After a rout Harlan-Voss takes the closest thing you own, structures and
## all — an opportunistic grab with no roll of its own, since it is already the
## consequence of one you just lost. Dustfall is excluded on purpose: a
## garrisoned capital is not something that changes hands as a side effect of
## a fight fought somewhere else on the map. It can still fall, but only to a
## resolved assault that has to beat its own defense — see
## _ai_attack_player_cell(), the only path that runs through Combat.resolve()
## and therefore the only one AI_TOWN_DEFENSE_BONUS actually governs.
func _enemy_counterattack(from_cell: Vector2i) -> Vector2i:
	for neighbor in HexGrid.get_neighbors(from_cell.x, from_cell.y):
		if not tiles.has(neighbor) or not is_owned(neighbor):
			continue
		if neighbor == MapBuilder.TOWN_CELL:
			continue
		return _capture_player_cell(neighbor)
	return Vector2i.MAX


# --- AI faction (Harlan-Voss) --------------------------------------------------

## Called once per advance_turn(). EnemyAI decides (a pure read of `self`); this
## applies whatever it decided, exactly like perform_action() applies TileAction's
## verdicts. Stops early if a step ends the game, so nothing fires post-defeat.
func _run_ai_turn() -> void:
	var plan := EnemyAI.run_turn(self)
	ai_resources["gold"] = int(ai_resources.get("gold", 0)) + int(plan["income"])

	var attacked := 0
	var expanded := 0
	var grew := 0

	for action in plan["actions"]:
		if is_defeated:
			break
		match String(action["kind"]):
			"attack":
				ai_resources["gold"] -= GameData.AI_ATTACK_COST_GOLD
				_ai_attack_player_cell(action["cell"], action["launch_cell"])
				attacked += 1
			"expand":
				ai_resources["gold"] -= GameData.AI_EXPAND_COST_GOLD
				_ai_capture_wild(action["cell"])
				expanded += 1
			"found":
				ai_resources["gold"] -= int(action["cost"])
				_ai_found_settlement(action["cell"])
				grew += 1
			"upgrade":
				ai_resources["gold"] -= int(action["cost"])
				_ai_upgrade_settlement(action["cell"])
				grew += 1

	if attacked > 0 or expanded > 0 or grew > 0:
		add_story("Harlan-Voss tento tah: %d útok, %d expanze, %d posílení základen." % [
			attacked, expanded, grew
		])


## Harlan-Voss attacks a player-owned cell from one of its own (launch_cell).
## Combat.resolve() always keeps the player in the defender slot, so the banner
## and COMBAT_EFFECTS table read the same as a player-initiated attack; only
## `loses_tile` (the AI's raid succeeding) has any effect here — a successful
## defense does not "capture" a tile the player already owns.
func _ai_attack_player_cell(target_cell: Vector2i, launch_cell: Vector2i) -> void:
	var report := Combat.resolve(
		Combat.player_power(self, target_cell),
		Combat.enemy_power(self, launch_cell),
		_rng,
		false
	)
	report["cell"] = target_cell

	apply_resource_bundle(report["resources"])
	for track in report["reputation"]:
		adjust_reputation(track, int(report["reputation"][track]))

	if bool(report["loses_tile"]):
		_capture_player_cell(target_cell)
	else:
		notify("Harlan-Voss zaútočil na %d:%d, ale ubránili jsme se (%d proti %d)." % [
			target_cell.x, target_cell.y, report["player_roll"], report["enemy_roll"]
		], "success")
		add_story("Harlan-Voss zaútočil na %d:%d — ubránili jsme se." % [target_cell.x, target_cell.y])

	last_combat = report
	combat_resolved.emit(report)


## Shared by both the reactive counterattack and the proactive AI attack — the
## single place a player cell actually changes hands. Capturing TOWN ends the
## game instead of being skipped, unlike before Phase 4.
func _capture_player_cell(cell: Vector2i) -> Vector2i:
	# Pojistka k témuž pravidlu v EnemyAI._pick_attack_target(): v Začátečníkovi
	# Dustfall padnout nesmí, protože to menu výslovně slibuje. Hlídá se to na
	# obou místech schválně — plánovač AI je jen jedna ze dvou cest, kterými se
	# dlaždice může přehodit, a slib daný hráči nemá viset na jedné z nich.
	if cell == MapBuilder.TOWN_CELL and not bool(ruleset["ai_can_capture_town"]):
		return Vector2i.MAX

	tiles[cell] = GameData.Terrain.ENEMY
	owned.erase(cell)
	settlements.erase(cell)
	for i in range(buildings.size() - 1, -1, -1):
		if buildings[i].get("cell", Vector2i.MAX) == cell:
			buildings.remove_at(i)
	notify("Harlan-Voss obsadil %d:%d!" % [cell.x, cell.y], "warning")
	add_story("Korporace obsadila území %d:%d." % [cell.x, cell.y])
	if cell == MapBuilder.TOWN_CELL:
		_trigger_defeat()
	return cell


func _trigger_defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	game_over_reason = "Harlan-Voss dobyl Dustfall. Vaše impérium v Nevadě padlo."
	notify(game_over_reason, "warning")
	add_story(game_over_reason)
	game_over.emit(game_over_reason)


## The only thing that can shrink Harlan-Voss's territory to nothing is the
## player winning an attack (EnemyAI only ever expands into wilderness or
## the player's own land, never gives ground back) — so this is the only
## call site that needs to check it.
func _check_victory() -> void:
	if is_defeated or is_victorious:
		return
	if _enemy_tile_count() > 0:
		return
	is_victorious = true
	game_over_reason = "Harlan-Voss byl vyhnán z Nevady. Dustfall je vaše."
	notify(game_over_reason, "success")
	add_story(game_over_reason)
	game_over.emit(game_over_reason)


func _enemy_tile_count() -> int:
	var count := 0
	for cell in tiles:
		if tiles[cell] == GameData.Terrain.ENEMY:
			count += 1
	return count


func _ai_capture_wild(cell: Vector2i) -> void:
	var terrain := get_tile(cell)
	tiles[cell] = GameData.Terrain.ENEMY
	notify("Harlan-Voss rozšířil území na %d:%d." % [cell.x, cell.y], "warning")
	add_story("Korporace zabrala divočinu na %d:%d (%s)." % [cell.x, cell.y, GameData.TERRAIN_NAMES[terrain]])


func _ai_found_settlement(cell: Vector2i) -> void:
	ai_settlements[cell] = 1
	notify("Harlan-Voss založil základnu na %d:%d." % [cell.x, cell.y], "warning")
	add_story("Korporace založila základnu na %d:%d." % [cell.x, cell.y])


func _ai_upgrade_settlement(cell: Vector2i) -> void:
	var level := int(ai_settlements.get(cell, 1)) + 1
	ai_settlements[cell] = level
	var data := GameData.settlement_data(level)
	notify("Harlan-Voss posílil základnu na %d:%d (%s)." % [cell.x, cell.y, data["name"]], "warning")
	add_story("Základna Harlan-Voss na %d:%d byla posílena na úroveň %s." % [cell.x, cell.y, data["name"]])


# --- Buildings ---------------------------------------------------------------

func can_build_at(cell: Vector2i) -> Dictionary:
	return TileAction.can_perform(self, "build", cell)


func build(name: String, cell: Vector2i) -> bool:
	var entry := GameData.find_buildable(name)
	if entry.is_empty():
		return false

	var placement := can_build_at(cell)
	if not bool(placement["ok"]):
		notify(String(placement["reason"]), "warning")
		return false

	if not can_afford(entry["costs"]):
		notify("Chybí: %s" % GameData.format_costs(missing_costs(entry["costs"])), "warning")
		return false

	spend(entry["costs"])
	buildings.append({
		"name": name,
		"production": entry["production"].duplicate(),
		"cell": cell,
	})
	refresh_economy()
	map_changed.emit()
	notify("Postaveno: %s" % name, "success")
	add_story("V Dustfallu vyrostla stavba: %s (%d:%d)." % [name, cell.x, cell.y])
	return true


# --- Trade -------------------------------------------------------------------

func trade_price(resource: String, buying: bool, at_market: bool) -> int:
	return Trade.market_price(self, resource, buying) if at_market \
		else Trade.vendor_price(self, resource, buying)


func market_open() -> bool:
	return Trade.market_open(self)


## Buys `amount` units of `resource`, paying gold. Returns {ok, reason, gold}.
func buy(resource: String, amount: int, at_market: bool = false) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "Neplatné množství."}
	if at_market and not market_open():
		return {"ok": false, "reason": "Trh je otevřený jen když je ve městě dostavník."}
	if not GameData.TRADE_GOODS.has(resource):
		return {"ok": false, "reason": "Tímhle se neobchoduje."}

	var price := trade_price(resource, true, at_market)
	var total := price * amount
	if int(resources.get("gold", 0)) < total:
		return {"ok": false, "reason": "Chybí %d zlata." % (total - int(resources.get("gold", 0)))}

	var room := storage_capacity() - int(resources.get(resource, 0))
	if room < amount:
		return {"ok": false, "reason": "Ve skladu není místo (volno %d)." % maxi(room, 0)}

	apply_resource("gold", -total)
	apply_resource(resource, amount)
	notify("Nakoupeno %d × %s za %d zlata." % [
		amount, GameData.RESOURCE_LABELS[resource], total
	], "info")
	return {"ok": true, "reason": "", "gold": -total}


## Sells `amount` units of `resource` for gold.
func sell(resource: String, amount: int, at_market: bool = false) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "Neplatné množství."}
	if at_market and not market_open():
		return {"ok": false, "reason": "Trh je otevřený jen když je ve městě dostavník."}
	if not GameData.TRADE_GOODS.has(resource):
		return {"ok": false, "reason": "Tímhle se neobchoduje."}
	if int(resources.get(resource, 0)) < amount:
		return {"ok": false, "reason": "Tolik %s nemáte." % GameData.RESOURCE_LABELS[resource]}

	var price := trade_price(resource, false, at_market)
	var total := price * amount
	apply_resource(resource, -amount)
	apply_resource("gold", total)
	notify("Prodáno %d × %s za %d zlata." % [
		amount, GameData.RESOURCE_LABELS[resource], total
	], "info")
	return {"ok": true, "reason": "", "gold": total}


# --- Contracts ---------------------------------------------------------------

func find_contract(id: int) -> Dictionary:
	for contract in contracts:
		if int(contract["id"]) == id:
			return contract
	return {}


func can_fulfill_contract(id: int) -> bool:
	var contract := find_contract(id)
	if contract.is_empty():
		return false
	return int(resources.get(contract["resource"], 0)) >= int(contract["amount"])


func fulfill_contract(id: int) -> Dictionary:
	var contract := find_contract(id)
	if contract.is_empty():
		return {"ok": false, "reason": "Takový kontrakt neexistuje."}
	if not can_fulfill_contract(id):
		return {"ok": false, "reason": "Nemáte dost surovin na splnění."}

	apply_resource(contract["resource"], -int(contract["amount"]))
	apply_resource("gold", int(contract["reward_gold"]))
	adjust_reputation(String(contract["track"]), int(contract["reward_reputation"]))

	contracts.erase(contract)
	contracts_changed.emit()
	notify("Kontrakt splněn: %s (+%d zlata)" % [
		contract["faction_name"], int(contract["reward_gold"])
	], "success")
	add_story("Kontrakt pro %s byl splněn." % contract["faction_name"])
	return {"ok": true, "reason": "", "contract": contract}


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
	if is_defeated or is_victorious:
		return

	var season_index := GameData.SEASONS.find(season) + 1
	if season_index >= GameData.SEASONS.size():
		season_index = 0
		year += 1
		add_story("Začal nový rok %d." % year)
	season = GameData.SEASONS[season_index]
	turn_count += 1
	attacks_this_turn = 0

	_run_turn_economy()
	_award_tech_points()
	_tick_coach()
	_tick_market()
	_tick_contracts()
	_trigger_random_event()
	_run_ai_turn()

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


## The coach travels, stays a couple of turns (the market is open then), leaves.
func _tick_coach() -> void:
	if coach_stay > 0:
		coach_stay -= 1
		if coach_stay == 0:
			notify("Dostavník opustil Dustfall. Trh se zavírá.", "info")
			market_changed.emit()
		return

	coach_in -= 1
	if coach_in > 0:
		return

	apply_resource("gold", GameData.COACH_GOLD)
	population += GameData.COACH_POPULATION
	coach_stay = GameData.COACH_STAY_TURNS
	notify("Dostavník dorazil! +%d zlata, +%d populace. Trh je otevřen." % [
		GameData.COACH_GOLD, GameData.COACH_POPULATION
	], "success")
	add_story("Dostavník dorazil do Dustfallu s novými osadníky a hotovostí.")
	var minimum := 1 if has_tech("coach") else 2
	coach_in = _rng.randi_range(0, 2) + minimum
	market_changed.emit()


func _tick_market() -> void:
	market = Trade.drift_market(market, _rng)
	market_changed.emit()


func _tick_contracts() -> void:
	var changed := false

	for i in range(contracts.size() - 1, -1, -1):
		contracts[i]["turns_left"] = int(contracts[i]["turns_left"]) - 1
		if int(contracts[i]["turns_left"]) > 0:
			continue
		var expired: Dictionary = contracts[i]
		adjust_reputation(String(expired["track"]), GameData.CONTRACT_EXPIRY_REPUTATION)
		notify("Kontrakt vypršel: %s" % expired["faction_name"], "warning")
		add_story("Kontrakt pro %s vypršel nesplněný." % expired["faction_name"])
		contracts.remove_at(i)
		changed = true

	if turn_count % GameData.CONTRACT_INTERVAL == 0 \
			and contracts.size() < GameData.CONTRACT_MAX_ACTIVE:
		var contract := Trade.make_contract(next_contract_id, _rng, turn_count)
		next_contract_id += 1
		contracts.append(contract)
		notify("Nová nabídka: %s" % Trade.describe_contract(contract), "info")
		add_story("Přišla nabídka kontraktu od %s." % contract["faction_name"])
		changed = true

	if changed:
		contracts_changed.emit()


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


# --- Save / load -------------------------------------------------------------

func save_to_slot(slot: int) -> bool:
	if not SaveGame.save(self, slot):
		notify("Uložení do slotu %d selhalo." % slot, "warning")
		return false
	notify("Uloženo do slotu %d." % slot, "success")
	return true


func load_from_slot(slot: int) -> bool:
	if not SaveGame.load_slot(self, slot):
		notify("Slot %d se nepodařilo načíst." % slot, "warning")
		return false
	resources_changed.emit(resources)
	reputation_changed.emit(reputation)
	contracts_changed.emit()
	market_changed.emit()
	map_changed.emit()
	game_loaded.emit()
	notify("Načteno ze slotu %d — %s %d." % [slot, season, year], "success")
	return true


# --- Log ---------------------------------------------------------------------

func notify(text: String, type: String = "info") -> void:
	notified.emit(text, type)


func add_story(text: String) -> void:
	var entry := {"year": year, "season": season, "turn": turn_count, "text": text}
	story_log.push_front(entry)
	if story_log.size() > 100:
		story_log.resize(100)
	story_added.emit(entry)
