class_name SaveGame
extends RefCounted

## Save/load into three JSON slots under user://.
##
## JSON has no Vector2i and no integers (every number comes back as a float), so
## hex keys travel as "q,r" strings and everything numeric is re-cast on the way
## in. Nothing here trusts the file: a malformed slot fails loudly instead of
## half-restoring a game.

const SLOT_COUNT := 3
const SAVE_VERSION := 1


static func slot_path(slot: int) -> String:
	return "user://irondust_slot_%d.json" % slot


static func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Header shown on the save/load buttons without loading the whole game.
static func slot_info(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {"exists": false}
	var data := _read(slot)
	if data.is_empty():
		return {"exists": false}
	return {
		"exists": true,
		"player": String(data.get("player_name", "?")),
		"season": String(data.get("season", "?")),
		"year": int(data.get("year", 0)),
		"turn": int(data.get("turn_count", 0)),
		"gold": int(data.get("resources", {}).get("gold", 0)),
	}


# --- Public API --------------------------------------------------------------

static func save(gs, slot: int) -> bool:
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Nelze zapsat slot %d: %s" % [slot, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(capture(gs), "\t"))
	file.close()
	return true


static func load_slot(gs, slot: int) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	return restore(gs, data)


static func delete_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK


# --- Serialisation -----------------------------------------------------------

static func capture(gs) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": gs.player_name,
		"year": gs.year,
		"season": gs.season,
		"turn_count": gs.turn_count,
		"population": gs.population,
		"resources": gs.resources.duplicate(),
		"reputation": gs.reputation.duplicate(),
		"researched_techs": gs.researched_techs.duplicate(),
		"tech_points": gs.tech_points,
		"tech_total_earned": gs.tech_total_earned,
		"buildings": _buildings_out(gs.buildings),
		"tiles": _cells_out(gs.tiles),
		"hidden_tiles": _cells_out(gs.hidden_tiles),
		"owned": _cells_out(gs.owned),
		"settlements": _cells_out(gs.settlements),
		"used_actions": gs.used_actions.duplicate(),
		"market": gs.market.duplicate(),
		"contracts": gs.contracts.duplicate(true),
		"next_contract_id": gs.next_contract_id,
		"coach_in": gs.coach_in,
		"coach_stay": gs.coach_stay,
		"attacks_this_turn": gs.attacks_this_turn,
		"map_seed": gs.map_seed,
		"story_log": gs.story_log.duplicate(true),
	}


static func restore(gs, data: Dictionary) -> bool:
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_error("Nepodporovaná verze uložené hry: %s" % data.get("version", "?"))
		return false

	gs.player_name = String(data.get("player_name", "Hráč"))
	gs.year = int(data.get("year", 1872))
	gs.season = String(data.get("season", GameData.SEASONS[0]))
	gs.turn_count = int(data.get("turn_count", 0))
	gs.population = int(data.get("population", 0))

	gs.resources = _ints(data.get("resources", {}))
	gs.reputation = _ints(data.get("reputation", {}))

	var techs: Array[String] = []
	for id in data.get("researched_techs", []):
		techs.append(String(id))
	gs.researched_techs = techs

	gs.tech_points = int(data.get("tech_points", 0))
	gs.tech_total_earned = int(data.get("tech_total_earned", 0))
	gs.buildings = _buildings_in(data.get("buildings", []))

	gs.tiles = _cells_in(data.get("tiles", {}), true)
	gs.hidden_tiles = _cells_in(data.get("hidden_tiles", {}), true)
	gs.owned = _cells_in(data.get("owned", {}), false)
	gs.settlements = _cells_in(data.get("settlements", {}), true)

	gs.used_actions = data.get("used_actions", {}).duplicate()

	var market := {}
	for key in data.get("market", {}):
		market[String(key)] = float(data["market"][key])
	gs.market = market

	var contracts: Array[Dictionary] = []
	for entry in data.get("contracts", []):
		contracts.append(_contract_in(entry))
	gs.contracts = contracts

	gs.next_contract_id = int(data.get("next_contract_id", 1))
	gs.coach_in = int(data.get("coach_in", 3))
	gs.coach_stay = int(data.get("coach_stay", 0))
	gs.attacks_this_turn = int(data.get("attacks_this_turn", 0))
	gs.map_seed = int(data.get("map_seed", 0))

	var entries: Array[Dictionary] = []
	for entry in data.get("story_log", []):
		entries.append({
			"year": int(entry.get("year", 0)),
			"season": String(entry.get("season", "")),
			"turn": int(entry.get("turn", 0)),
			"text": String(entry.get("text", "")),
		})
	gs.story_log = entries

	gs.set_seed(gs.map_seed)
	gs.refresh_economy()
	return true


# --- Helpers -----------------------------------------------------------------

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func key_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.MAX
	return Vector2i(int(parts[0]), int(parts[1]))


static func _cells_out(source: Dictionary) -> Dictionary:
	var out := {}
	for cell in source:
		out[cell_key(cell)] = source[cell]
	return out


## `numeric` distinguishes terrain/level maps from the plain cell sets, whose
## values are just `true`.
static func _cells_in(source: Dictionary, numeric: bool) -> Dictionary:
	var out := {}
	for key in source:
		var cell := key_cell(String(key))
		if cell == Vector2i.MAX:
			continue
		out[cell] = int(source[key]) if numeric else true
	return out


static func _buildings_out(buildings: Array) -> Array:
	var out := []
	for building in buildings:
		out.append({
			"name": String(building.get("name", "")),
			"production": building.get("production", {}).duplicate(),
			"cell": cell_key(building.get("cell", Vector2i.ZERO)),
		})
	return out


static func _buildings_in(source: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in source:
		out.append({
			"name": String(entry.get("name", "")),
			"production": _ints(entry.get("production", {})),
			"cell": key_cell(String(entry.get("cell", "0,0"))),
		})
	return out


static func _contract_in(entry: Dictionary) -> Dictionary:
	return {
		"id": int(entry.get("id", 0)),
		"faction": String(entry.get("faction", "")),
		"faction_name": String(entry.get("faction_name", "")),
		"track": String(entry.get("track", "")),
		"resource": String(entry.get("resource", "")),
		"amount": int(entry.get("amount", 0)),
		"turns_left": int(entry.get("turns_left", 0)),
		"issued_turn": int(entry.get("issued_turn", 0)),
		"reward_gold": int(entry.get("reward_gold", 0)),
		"reward_reputation": int(entry.get("reward_reputation", 0)),
	}


## JSON hands every number back as a float; resource counts must stay ints.
static func _ints(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source:
		out[String(key)] = int(source[key])
	return out


static func _read(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Slot %d není platný JSON." % slot)
		return {}
	return parsed
