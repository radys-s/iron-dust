class_name Combat
extends RefCounted

## Battle resolution against Harlan-Voss.
##
## GAME_DESIGN.md: both sides roll `síla + d6`, the margin picks one of five
## outcomes, and Soudní vliv (court) can end the fight before a shot is fired.
##
## `resolve()` is deliberately pure — it takes numbers and an RNG, never touches
## GameState — so the outcome table can be hammered deterministically in tests.
## GameState.attack() is the thin layer that applies the result.

const CRUSHING_MARGIN := 6
const ROUT_MARGIN := -6


## Base strength the player brings to a fight for `cell`. Dustfall itself
## carries a flat capital-defense bonus on top of everything else — the
## difference between an outlying claim and the seat of the whole operation.
static func player_power(gs, cell: Vector2i) -> int:
	var from_reputation := int(gs.reputation.get("soldiers", 0)) / GameData.COMBAT_REPUTATION_DIVISOR
	var from_tech: int = gs.tech_combat_power()
	var from_capital := GameData.AI_TOWN_DEFENSE_BONUS if cell == MapBuilder.TOWN_CELL else 0
	return from_reputation + from_tech + settlement_support(gs, cell) + from_capital


## Best defensive bonus of a player settlement close enough to send men.
static func settlement_support(gs, cell: Vector2i) -> int:
	var best := 0
	for settlement_cell in gs.settlements:
		if HexGrid.distance(settlement_cell, cell) > GameData.SETTLEMENT_SUPPORT_RANGE:
			continue
		var level := int(gs.settlements[settlement_cell])
		best = maxi(best, int(GameData.settlement_data(level).get("defense", 0)))
	return best


## Harlan-Voss digs in further from town, grows stronger as the game runs on,
## and — since Phase 4 — draws extra muscle from its own settlements and treasury.
static func enemy_power(gs, cell: Vector2i) -> int:
	var distance := HexGrid.distance(cell, MapBuilder.TOWN_CELL)
	var escalation := int(gs.turn_count) / GameData.ENEMY_POWER_PER_TURNS
	var from_settlements := ai_settlement_support(gs, cell)
	var from_treasury := int(gs.ai_resources.get("gold", 0)) / GameData.AI_POWER_PER_GOLD
	return GameData.ENEMY_BASE_POWER \
		+ distance * GameData.ENEMY_POWER_PER_DISTANCE \
		+ escalation \
		+ from_settlements \
		+ from_treasury


## Best defensive bonus of an AI settlement close enough to send men. Mirrors
## settlement_support() but reads gs.ai_settlements instead of gs.settlements.
static func ai_settlement_support(gs, cell: Vector2i) -> int:
	var best := 0
	for settlement_cell in gs.ai_settlements:
		if HexGrid.distance(settlement_cell, cell) > GameData.AI_SUPPORT_RANGE:
			continue
		var level := int(gs.ai_settlements[settlement_cell])
		best = maxi(best, int(GameData.settlement_data(level).get("defense", 0)))
	return best


## Rolls the battle. Returns everything the UI needs to explain what happened.
static func resolve(player_strength: int, enemy_strength: int,
		rng: RandomNumberGenerator, has_court: bool = false) -> Dictionary:
	if has_court and rng.randf() < GameData.COURT_CAPITULATION_CHANCE:
		return _outcome(GameData.CombatResult.CAPITULATION,
			player_strength, enemy_strength, 0, 0, true)

	var player_die := rng.randi_range(1, GameData.COMBAT_DIE)
	var enemy_die := rng.randi_range(1, GameData.COMBAT_DIE)
	var margin := (player_strength + player_die) - (enemy_strength + enemy_die)

	var result: GameData.CombatResult
	if margin >= CRUSHING_MARGIN:
		result = GameData.CombatResult.CRUSHING
	elif margin >= 1:
		result = GameData.CombatResult.VICTORY
	elif margin == 0:
		result = GameData.CombatResult.STALEMATE
	elif margin <= ROUT_MARGIN:
		result = GameData.CombatResult.ROUT
	else:
		result = GameData.CombatResult.DEFEAT

	return _outcome(result, player_strength, enemy_strength, player_die, enemy_die, false)


static func _outcome(result: GameData.CombatResult, player_strength: int,
		enemy_strength: int, player_die: int, enemy_die: int,
		capitulated: bool) -> Dictionary:
	var effects: Dictionary = GameData.COMBAT_EFFECTS[result]
	return {
		"result": result,
		"name": GameData.COMBAT_RESULT_NAMES[result],
		"text": effects["text"],
		"capitulated": capitulated,
		"player_strength": player_strength,
		"enemy_strength": enemy_strength,
		"player_die": player_die,
		"enemy_die": enemy_die,
		"player_roll": player_strength + player_die,
		"enemy_roll": enemy_strength + enemy_die,
		"margin": (player_strength + player_die) - (enemy_strength + enemy_die),
		"captures": bool(effects["captures"]),
		"loses_tile": bool(effects["loses_tile"]),
		"resources": effects["resources"],
		"reputation": effects["reputation"],
	}


## Human-readable odds preview for the tile panel, so an attack is a decision
## rather than a coin flip in the dark.
static func forecast(player_strength: int, enemy_strength: int) -> String:
	var gap := player_strength - enemy_strength
	if gap >= 5:
		return "Naše převaha je drtivá."
	if gap >= 2:
		return "Máme navrch."
	if gap >= -1:
		return "Vyrovnané síly — rozhodne kostka."
	if gap >= -4:
		return "Jsme ve ztrátě, útok je riskantní."
	return "Sebevražedný útok."
