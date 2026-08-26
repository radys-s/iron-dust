class_name EnemyAI
extends RefCounted

## Rule-based turn planner for Harlan-Voss.
##
## Mirrors Combat/TileAction/Trade: this class only ever reads `gs`, it never
## mutates it. run_turn() returns a plan (income + an ordered list of actions);
## GameState._run_ai_turn() is the only thing that actually applies it, the same
## relationship perform_action() has to TileAction's verdicts.
##
## Planning uses local copies of the bits of state a turn can change (territory,
## settlement levels, treasury) so later steps in the same turn see the effect
## of earlier ones without ever touching the real GameState.

const KIND_ATTACK := "attack"
const KIND_EXPAND := "expand"
const KIND_FOUND := "found"
const KIND_UPGRADE := "upgrade"


## Decides everything Harlan-Voss does this turn. Deterministic given `gs` and
## its RNG state (the plan itself makes no random choices — only combat rolls,
## applied later by GameState, are random).
static func run_turn(gs) -> Dictionary:
	var income := turn_income(gs)
	var treasury := int(gs.ai_resources.get("gold", 0)) + income

	var ai_territory := _collect_ai_territory(gs)
	var ai_settlements: Dictionary = gs.ai_settlements.duplicate()

	var actions: Array[Dictionary] = []
	var budget := action_budget(gs)
	var attacks_left := GameData.AI_ATTACKS_PER_TURN

	if attacks_left > 0 and budget > 0 and treasury >= GameData.AI_ATTACK_COST_GOLD:
		var target := _pick_attack_target(gs, ai_territory)
		if target != Vector2i.MAX:
			var launch := _territory_neighbor(target, ai_territory)
			actions.append({"kind": KIND_ATTACK, "cell": target, "launch_cell": launch})
			treasury -= GameData.AI_ATTACK_COST_GOLD
			budget -= 1
			attacks_left -= 1

	while budget > 0 and treasury >= GameData.AI_EXPAND_COST_GOLD:
		var target := _pick_expansion_target(gs, ai_territory)
		if target == Vector2i.MAX:
			break
		actions.append({"kind": KIND_EXPAND, "cell": target})
		ai_territory[target] = true
		treasury -= GameData.AI_EXPAND_COST_GOLD
		budget -= 1

	while budget > 0:
		var step := _pick_settlement_action(gs, ai_territory, ai_settlements)
		if String(step.get("kind", "none")) == "none":
			break
		var step_cost := int(step["cost"])
		if treasury < step_cost:
			break
		actions.append(step)
		treasury -= step_cost
		var cell: Vector2i = step["cell"]
		if String(step["kind"]) == KIND_FOUND:
			ai_settlements[cell] = 1
		else:
			ai_settlements[cell] = int(ai_settlements.get(cell, 1)) + 1
		budget -= 1

	return {"income": income, "actions": actions}


## Passive per-turn gold: a base income plus each settlement's own gold output
## (from the shared SETTLEMENT_LEVELS table) — the more Harlan-Voss has built,
## the faster it builds further.
static func turn_income(gs) -> int:
	var income := GameData.AI_BASE_INCOME_GOLD
	for cell in gs.ai_settlements:
		var level := int(gs.ai_settlements[cell])
		var data := GameData.settlement_data(level)
		income += int(data.get("production", {}).get("gold", 0))
	return income


## Total actions (attack + expand + settlement growth, combined) Harlan-Voss
## may take this turn. Scales with how much empire it has already built, not
## with an unbounded formula — the single biggest brake on runaway difficulty.
static func action_budget(gs) -> int:
	return clampi(1 + gs.ai_settlements.size() / 2, 1, GameData.AI_ACTIONS_MAX)


# --- Attack --------------------------------------------------------------------

## The weakest-defended player cell adjacent to AI territory, skipped if even
## that one would be a bad bet (offense - defense < AI_MIN_ATTACK_ADVANTAGE).
## Dustfall is a perfectly legal target here — nothing protects it anymore.
static func _pick_attack_target(gs, ai_territory: Dictionary) -> Vector2i:
	var best := Vector2i.MAX
	var best_defense := 999999

	# Zacatecnicky rezim slibuje v menu doslova "Harlan-Voss vás nemůže zničit".
	# Korporace proto na Dustfall vubec neuvazuje jako o cili — bere okolni
	# uzemi, ale hlavni mesto nechava byt.
	var town_off_limits: bool = not bool(gs.ruleset["ai_can_capture_town"])

	for cell in gs.tiles:
		if not gs.is_owned(cell):
			continue
		if town_off_limits and cell == MapBuilder.TOWN_CELL:
			continue
		var launch := _territory_neighbor(cell, ai_territory)
		if launch == Vector2i.MAX:
			continue

		var defense := Combat.player_power(gs, cell)
		var offense := Combat.enemy_power(gs, launch)
		if offense - defense < int(gs.ruleset["ai_min_attack_advantage"]):
			continue

		if defense < best_defense:
			best_defense = defense
			best = cell

	return best


static func _territory_neighbor(cell: Vector2i, ai_territory: Dictionary) -> Vector2i:
	for neighbor in HexGrid.get_neighbors(cell.x, cell.y):
		if ai_territory.has(neighbor):
			return neighbor
	return Vector2i.MAX


# --- Expansion -------------------------------------------------------------

## A claimable, already-explored, unowned cell next to AI territory. Restricted
## to explored ground so the AI never reveals fog on the player's behalf.
## Fed. kontakty (GameData tech "federal") shuts this down entirely — the
## concrete payoff of that tech's long-promised "blokuje expanzi H-V".
static func _pick_expansion_target(gs, ai_territory: Dictionary) -> Vector2i:
	if gs.has_tech("federal"):
		return Vector2i.MAX

	for cell in ai_territory.keys():
		for neighbor in HexGrid.get_neighbors(cell.x, cell.y):
			if not gs.tiles.has(neighbor):
				continue
			if ai_territory.has(neighbor):
				continue
			var terrain: GameData.Terrain = gs.get_tile(neighbor)
			if terrain == GameData.Terrain.FOG:
				continue
			if gs.is_owned(neighbor):
				continue
			if not GameData.CLAIMABLE.has(terrain):
				continue
			return neighbor

	return Vector2i.MAX


# --- Settlement growth -----------------------------------------------------

## Prefers upgrading the lowest-level existing settlement over founding a new
## one, so Harlan-Voss consolidates instead of sprawling into level-1 outposts.
static func _pick_settlement_action(gs, ai_territory: Dictionary, ai_settlements: Dictionary) -> Dictionary:
	var upgrade_cell := Vector2i.MAX
	var upgrade_level := 999

	for cell in ai_settlements:
		var level := int(ai_settlements[cell])
		if level >= GameData.SETTLEMENT_MAX_LEVEL:
			continue
		if level < upgrade_level:
			upgrade_level = level
			upgrade_cell = cell

	if upgrade_cell != Vector2i.MAX:
		return {
			"kind": KIND_UPGRADE, "cell": upgrade_cell,
			"cost": upgrade_level * GameData.AI_SETTLEMENT_UPGRADE_PER_LEVEL_GOLD,
		}

	for cell in ai_territory.keys():
		if gs.settlement_at(cell) > 0 or not gs.building_at(cell).is_empty():
			continue
		var too_close := false
		for settlement_cell in ai_settlements:
			if HexGrid.distance(settlement_cell, cell) < GameData.AI_SETTLEMENT_MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue
		return {"kind": KIND_FOUND, "cell": cell, "cost": GameData.AI_SETTLEMENT_FOUND_COST_GOLD}

	return {"kind": "none"}


# --- Internals ---------------------------------------------------------------

static func _collect_ai_territory(gs) -> Dictionary:
	var out := {}
	for cell in gs.tiles:
		if gs.tiles[cell] == GameData.Terrain.ENEMY:
			out[cell] = true
	return out
