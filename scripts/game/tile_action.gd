class_name TileAction
extends RefCounted

## Rules for what the player may do with a selected hex.
##
## This module answers *whether* an action is legal and *what it costs*; the
## actual state change lives in GameState, which calls back here before touching
## anything. Keeping the rules in one place means the tile panel can grey out a
## button for exactly the reason the executor would have refused it.

## Actions that open a panel instead of changing the world on the spot.
const OVERLAY_ACTIONS: Array[String] = ["build", "trade"]

## Actions that may be taken only once per hex.
const ONE_SHOT_ACTIONS: Array[String] = ["prospect", "repair"]


# --- Query -------------------------------------------------------------------

## Every action offered for `cell`, each already annotated with cost, whether it
## is currently affordable/legal, and the reason if not.
static func available(gs, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in GameData.ACTIONS:
		var id: String = entry["id"]
		if not _matches_terrain(gs, id, cell):
			continue
		var verdict := can_perform(gs, id, cell)
		out.append({
			"id": id,
			"name": _display_name(gs, id, cell),
			"hint": entry["hint"],
			"cost": cost(gs, id, cell),
			"enabled": bool(verdict["ok"]),
			"reason": String(verdict["reason"]),
			"overlay": id in OVERLAY_ACTIONS,
		})
	return out


static func is_overlay(id: String) -> bool:
	return id in OVERLAY_ACTIONS


static func cost(gs, id: String, cell: Vector2i) -> Dictionary:
	match id:
		"explore":
			var gold := GameData.EXPLORE_COST_TELEGRAPH if gs.has_tech("telegraph") \
				else GameData.EXPLORE_COST
			return {"gold": gold}
		"claim":
			var steps := HexGrid.distance(cell, MapBuilder.TOWN_CELL)
			return {
				"gold": GameData.CLAIM_COST_BASE + steps * GameData.CLAIM_COST_PER_STEP,
				"wood": GameData.CLAIM_COST_WOOD,
			}
		"found":
			return GameData.SETTLEMENT_FOUND_COST.duplicate()
		"upgrade":
			var current_level: int = gs.settlement_at(cell)
			return GameData.settlement_upgrade_cost(current_level)
		"attack":
			return {"gold": GameData.ATTACK_COST}
		"prospect":
			return {"gold": GameData.PROSPECT_COST}
		"repair":
			return {"gold": GameData.REPAIR_COST}
	return {}


## The single authority on legality. Returns {ok: bool, reason: String}.
static func can_perform(gs, id: String, cell: Vector2i) -> Dictionary:
	var entry := GameData.find_action(id)
	if entry.is_empty():
		return _no("Neznámá akce.")
	if not gs.tiles.has(cell):
		return _no("Mimo mapu.")

	var terrain: GameData.Terrain = gs.get_tile(cell)

	if bool(entry.get("needs_adjacency", false)) and not gs.is_adjacent_to_owned(cell):
		return _no("Musí sousedit s vaším územím.")

	if id in ONE_SHOT_ACTIONS and gs.has_used_action(cell, id):
		return _no("Tady už to bylo provedeno.")

	match id:
		"explore":
			if terrain != GameData.Terrain.FOG:
				return _no("Není co odhalovat.")
		"claim":
			if gs.is_owned(cell):
				return _no("Území už vlastníte.")
			if not GameData.CLAIMABLE.has(terrain):
				return _no("Tenhle terén zabrat nelze.")
		"build":
			var supply := _supply_check(gs, cell)
			if not bool(supply["ok"]):
				return supply
		"found":
			if not gs.is_owned(cell):
				return _no("Nejdřív území zaberte.")
			if terrain == GameData.Terrain.TOWN:
				return _no("Dustfall už sídlem je.")
			if gs.settlement_at(cell) > 0:
				return _no("Sídlo tu už stojí.")
			if not gs.building_at(cell).is_empty():
				return _no("Dlaždici zabírá budova.")
			if gs.nearest_settlement_distance(cell) < GameData.SETTLEMENT_MIN_SPACING:
				return _no("Příliš blízko jinému sídlu.")
		"upgrade":
			var level: int = gs.settlement_at(cell)
			if level <= 0:
				return _no("Tady žádné sídlo není.")
			if level >= GameData.SETTLEMENT_MAX_LEVEL:
				return _no("Nejvyšší úroveň už je dosažena.")
		"attack":
			if terrain != GameData.Terrain.ENEMY:
				return _no("Není koho napadnout.")
			if int(gs.attacks_this_turn) >= GameData.ATTACKS_PER_TURN:
				return _no("Vojsko už tento tah bojovalo.")
		"trade":
			if terrain != GameData.Terrain.TOWN:
				return _no("Obchoduje se jen v Dustfallu.")
		"prospect":
			if not gs.is_owned(cell):
				return _no("Nejdřív území zaberte.")
		"repair":
			if not gs.is_owned(cell):
				return _no("Nejdřív území zaberte.")

	var costs := cost(gs, id, cell)
	if not costs.is_empty() and not gs.can_afford(costs):
		return _no("Chybí: %s" % GameData.format_costs(gs.missing_costs(costs)))

	return {"ok": true, "reason": ""}


# --- Internals ---------------------------------------------------------------

## Coarse pass: should this action even show up on this hex?
static func _matches_terrain(gs, id: String, cell: Vector2i) -> bool:
	var entry := GameData.find_action(id)
	var terrains: Array = entry.get("terrains", [])
	if not terrains.is_empty():
		return gs.get_tile(cell) in terrains

	# Actions with no terrain filter are gated by ownership instead.
	match id:
		"build":
			return gs.is_owned(cell) and gs.settlement_at(cell) == 0 \
				and gs.building_at(cell).is_empty()
		"found":
			return gs.is_owned(cell) and gs.get_tile(cell) != GameData.Terrain.TOWN \
				and gs.settlement_at(cell) == 0
		"upgrade":
			return gs.settlement_at(cell) > 0
	return false


static func _display_name(gs, id: String, cell: Vector2i) -> String:
	if id == "upgrade":
		var level: int = gs.settlement_at(cell)
		if level > 0 and level < GameData.SETTLEMENT_MAX_LEVEL:
			return "Povýšit na %s" % GameData.settlement_name(level + 1)
	return String(GameData.find_action(id)["name"])


static func _supply_check(gs, cell: Vector2i) -> Dictionary:
	if not gs.is_owned(cell):
		return _no("Nejdřív území zaberte.")
	if gs.settlement_at(cell) > 0:
		return _no("Dlaždici zabírá sídlo.")
	if not gs.building_at(cell).is_empty():
		return _no("Budova tu už stojí.")
	if not gs.in_supply(cell):
		return _no("Mimo dosah zásobování sídel.")
	return {"ok": true, "reason": ""}


static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
