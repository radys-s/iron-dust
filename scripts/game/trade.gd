class_name Trade
extends RefCounted

## Prices and contracts.
##
## Two ways to move goods, as GAME_DESIGN.md describes them:
##  * the vendor — fixed prices with a margin, open every turn;
##  * the market — one price for both directions (no margin), but it drifts from
##    turn to turn and only trades while the stage coach is in Dustfall.
##
## Everything here is static and side-effect free apart from the RNG it is
## handed, so the price model can be checked without running a game.

const MIN_PRICE := 1


# --- Prices ------------------------------------------------------------------

## Every tradeable good starts at its plain vendor valuation.
static func initial_market() -> Dictionary:
	var out := {}
	for key in GameData.TRADE_GOODS:
		out[key] = 1.0
	return out


## Random walk of the multiplier, clamped to the band from GameData.
static func drift_market(market: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for key in GameData.TRADE_GOODS:
		var current := float(market.get(key, 1.0))
		var step := rng.randf_range(-GameData.MARKET_DRIFT_STEP, GameData.MARKET_DRIFT_STEP)
		out[key] = clampf(current + step, GameData.MARKET_DRIFT_MIN, GameData.MARKET_DRIFT_MAX)
	return out


## Merchant standing bends every price: friendly kupci sell cheaper and pay more,
## a boycott does the opposite.
static func reputation_modifier(gs, buying: bool) -> float:
	var standing := int(gs.reputation.get("merchants", 50))
	if standing >= GameData.REPUTATION_HIGH:
		return 1.0 - GameData.REPUTATION_PRICE_BONUS if buying \
			else 1.0 + GameData.REPUTATION_PRICE_BONUS
	if standing < GameData.REPUTATION_LOW:
		return 1.0 + GameData.REPUTATION_PRICE_PENALTY if buying \
			else 1.0 - GameData.REPUTATION_PRICE_PENALTY
	return 1.0


static func vendor_price(gs, resource: String, buying: bool) -> int:
	var table: Dictionary = GameData.VENDOR_PRICES.get(resource, {})
	if table.is_empty():
		return 0
	var base := float(table["buy" if buying else "sell"])
	return maxi(MIN_PRICE, roundi(base * reputation_modifier(gs, buying)))


## Midpoint of the vendor spread — the market's honest valuation before drift.
static func market_base(resource: String) -> float:
	var table: Dictionary = GameData.VENDOR_PRICES.get(resource, {})
	if table.is_empty():
		return 0.0
	return (float(table["buy"]) + float(table["sell"])) * 0.5


static func market_price(gs, resource: String, buying: bool) -> int:
	var base := market_base(resource)
	if base <= 0.0:
		return 0
	var drift := float(gs.market.get(resource, 1.0))
	return maxi(MIN_PRICE, roundi(base * drift * reputation_modifier(gs, buying)))


## The market only trades while the coach is parked in town.
static func market_open(gs) -> bool:
	return int(gs.coach_stay) > 0


# --- Contracts ---------------------------------------------------------------

static func make_contract(id: int, rng: RandomNumberGenerator, turn: int) -> Dictionary:
	var faction: Dictionary = GameData.CONTRACT_FACTIONS[
		rng.randi_range(0, GameData.CONTRACT_FACTIONS.size() - 1)
	]
	var resource: String = GameData.TRADE_GOODS[
		rng.randi_range(0, GameData.TRADE_GOODS.size() - 1)
	]
	var span: Array = GameData.CONTRACT_AMOUNTS[resource]
	var amount := rng.randi_range(int(span[0]), int(span[1]))
	var duration := rng.randi_range(
		GameData.CONTRACT_DURATION_MIN, GameData.CONTRACT_DURATION_MAX
	)

	return {
		"id": id,
		"faction": faction["id"],
		"faction_name": faction["name"],
		"track": faction["track"],
		"resource": resource,
		"amount": amount,
		"turns_left": duration,
		"issued_turn": turn,
		"reward_gold": contract_reward(resource, amount),
		"reward_reputation": GameData.CONTRACT_REWARD_REPUTATION,
	}


static func contract_reward(resource: String, amount: int) -> int:
	var table: Dictionary = GameData.VENDOR_PRICES.get(resource, {})
	if table.is_empty():
		return 0
	return roundi(float(amount) * float(table["sell"]) * GameData.CONTRACT_REWARD_MULTIPLIER)


static func describe_contract(contract: Dictionary) -> String:
	return "%s žádá %d × %s do %d tahů — odměna %d zlata a +%d reputace." % [
		contract["faction_name"],
		int(contract["amount"]),
		GameData.RESOURCE_LABELS[contract["resource"]],
		int(contract["turns_left"]),
		int(contract["reward_gold"]),
		int(contract["reward_reputation"]),
	]
