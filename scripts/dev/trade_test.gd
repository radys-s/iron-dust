extends SceneTree

## Prices, the coach-gated market and the contract book.
##
## Contract lifecycle is driven through _tick_contracts() directly rather than
## advance_turn(), so a random event cannot quietly move the reputation the
## assertions are checking.
##
## godot --headless --path . --script res://scripts/dev/trade_test.gd

const EXPECTED_CHECKS := 47
const SEED := 18720412

var _failures := 0
var _ran := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")

	_test_vendor(gs)
	_test_market(gs)
	_test_transactions(gs)
	_test_contracts(gs)

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


# --- Vendor ------------------------------------------------------------------

func _test_vendor(gs) -> void:
	print("\n[1] Ceny kupce")
	gs.start_new_game(SEED)
	gs.reputation["merchants"] = 50

	for resource in GameData.TRADE_GOODS:
		var buy := Trade.vendor_price(gs, resource, true)
		var sell := Trade.vendor_price(gs, resource, false)
		print("  %-6s nakup %2d  prodej %2d" % [resource, buy, sell])
		_check("kupec ma marzi na %s" % resource, buy > sell, true)

	var base_buy := Trade.vendor_price(gs, "iron", true)
	var base_sell := Trade.vendor_price(gs, "iron", false)

	gs.reputation["merchants"] = 90
	_check("s dobrou povesti nakup levneji",
		Trade.vendor_price(gs, "iron", true) < base_buy, true)
	_check("a prodej draz",
		Trade.vendor_price(gs, "iron", false) > base_sell, true)

	gs.reputation["merchants"] = 10
	_check("pri bojkotu nakup draz",
		Trade.vendor_price(gs, "iron", true) > base_buy, true)
	_check("a prodej levneji",
		Trade.vendor_price(gs, "iron", false) < base_sell, true)

	gs.reputation["merchants"] = 50


# --- Market ------------------------------------------------------------------

func _test_market(gs) -> void:
	print("\n[2] Trh a dostavnik")
	gs.start_new_game(SEED)

	gs.coach_stay = 0
	_check("bez dostavniku je trh zavreny", gs.market_open(), false)
	_check("nakup na zavrenem trhu selze",
		bool(gs.buy("food", 10, true)["ok"]), false)
	_check("prodej na zavrenem trhu selze",
		bool(gs.sell("food", 10, true)["ok"]), false)

	gs.coach_stay = GameData.COACH_STAY_TURNS
	_check("s dostavnikem je trh otevreny", gs.market_open(), true)

	# Bez driftu je trh presne uprostred kupcova rozpeti.
	gs.market = Trade.initial_market()
	gs.reputation["merchants"] = 50
	var mid := Trade.market_base("iron")
	_check("stredni cena zeleza je prumer rozpeti", mid,
		(float(GameData.VENDOR_PRICES["iron"]["buy"])
			+ float(GameData.VENDOR_PRICES["iron"]["sell"])) * 0.5)
	_check("trh nema marzi",
		Trade.market_price(gs, "iron", true), Trade.market_price(gs, "iron", false))
	_check("na trhu se prodava lepe nez kupci",
		Trade.market_price(gs, "iron", false) > Trade.vendor_price(gs, "iron", false), true)

	# Drift musi zustat v pasmu i po stovkach tahu.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var drifting := Trade.initial_market()
	var out_of_band := 0
	var lowest := 99.0
	var highest := 0.0
	for i in 800:
		drifting = Trade.drift_market(drifting, rng)
		for key in GameData.TRADE_GOODS:
			var value := float(drifting[key])
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
			if value < GameData.MARKET_DRIFT_MIN or value > GameData.MARKET_DRIFT_MAX:
				out_of_band += 1
	print("  drift po 800 tazich: %.2f az %.2f" % [lowest, highest])
	_check("drift nikdy neopusti pasmo", out_of_band, 0)
	_check("cena se opravdu hybe", highest - lowest > 0.3, true)


# --- Transactions ------------------------------------------------------------

func _test_transactions(gs) -> void:
	print("\n[3] Nakup a prodej")
	gs.start_new_game(SEED)
	gs.reputation["merchants"] = 50
	gs.resources["gold"] = 1000
	gs.resources["iron"] = 100

	var price: int = gs.trade_price("iron", true, false)
	var result: Dictionary = gs.buy("iron", 10, false)
	_check("nakup probehl", bool(result["ok"]), true)
	_check("zelezo pribylo", gs.resources["iron"], 110)
	_check("zlato ubylo o cenu", gs.resources["gold"], 1000 - price * 10)

	var sell_price: int = gs.trade_price("iron", false, false)
	var gold_before: int = gs.resources["gold"]
	_check("prodej probehl", bool(gs.sell("iron", 10, false)["ok"]), true)
	_check("zelezo ubylo", gs.resources["iron"], 100)
	_check("zlato pribylo", gs.resources["gold"], gold_before + sell_price * 10)

	_check("nulove mnozstvi neprojde", bool(gs.buy("iron", 0, false)["ok"]), false)
	_check("zlatem se neobchoduje", bool(gs.buy("gold", 5, false)["ok"]), false)

	gs.resources["gold"] = 5
	_check("bez zlata se nenakupuje", bool(gs.buy("iron", 10, false)["ok"]), false)

	gs.resources["gold"] = 100000
	gs.resources["salt"] = gs.storage_capacity() - 5
	_check("nad kapacitu skladu se nenakupuje",
		bool(gs.buy("salt", 50, false)["ok"]), false)
	_check("do zbytku kapacity ano", bool(gs.buy("salt", 5, false)["ok"]), true)

	gs.resources["wood"] = 3
	_check("neprodava se co nemame", bool(gs.sell("wood", 10, false)["ok"]), false)


# --- Contracts ---------------------------------------------------------------

func _test_contracts(gs) -> void:
	print("\n[4] Kontrakty")
	gs.start_new_game(SEED)
	gs.contracts.clear()

	for step in [1, 2, 3, 4]:
		gs.turn_count = step * GameData.CONTRACT_INTERVAL
		gs._tick_contracts()
	_check("nabidky se nehromadi nad limit", gs.contracts.size(),
		GameData.CONTRACT_MAX_ACTIVE)

	var contract: Dictionary = gs.contracts[0]
	print("  %s" % Trade.describe_contract(contract))
	_check("kontrakt chce obchodovatelnou surovinu",
		GameData.TRADE_GOODS.has(String(contract["resource"])), true)
	_check("kontrakt ma odmenu", int(contract["reward_gold"]) > 0, true)
	_check("kontrakt ma frakci",
		GameData.find_faction(String(contract["faction"])).is_empty(), false)
	_check("odmena odpovida vzorci", int(contract["reward_gold"]),
		Trade.contract_reward(String(contract["resource"]), int(contract["amount"])))

	# Splneni: bez zbozi to nejde, se zbozim ano.
	var resource := String(contract["resource"])
	var amount := int(contract["amount"])
	gs.resources[resource] = amount - 1
	_check("bez zasob kontrakt splnit nelze",
		gs.can_fulfill_contract(int(contract["id"])), false)
	_check("a pokus skonci odmitnutim",
		bool(gs.fulfill_contract(int(contract["id"]))["ok"]), false)

	gs.resources[resource] = amount + 20
	gs.resources["gold"] = 1000
	var track := String(contract["track"])
	gs.reputation[track] = 50
	var before_count: int = gs.contracts.size()

	_check("se zasobami splnit lze", gs.can_fulfill_contract(int(contract["id"])), true)
	_check("splneni probehlo", bool(gs.fulfill_contract(int(contract["id"]))["ok"]), true)
	_check("zbozi bylo dodano", gs.resources[resource], 20)
	_check("odmena vyplacena", gs.resources["gold"], 1000 + int(contract["reward_gold"]))
	_check("reputace stoupla", gs.reputation[track],
		50 + int(contract["reward_reputation"]))
	_check("kontrakt zmizel ze seznamu", gs.contracts.size(), before_count - 1)
	_check("a uz se nenajde", gs.find_contract(int(contract["id"])).is_empty(), true)

	# Vyprseni sebere reputaci.
	gs.contracts.clear()
	gs.turn_count = GameData.CONTRACT_INTERVAL
	gs._tick_contracts()
	_check("mame cerstvy kontrakt", gs.contracts.size(), 1)

	var expiring: Dictionary = gs.contracts[0]
	var expiring_track := String(expiring["track"])
	gs.reputation[expiring_track] = 50
	gs.contracts[0]["turns_left"] = 1
	# Tah, ktery neni nasobkem intervalu, aby nepribyl novy kontrakt.
	gs.turn_count = GameData.CONTRACT_INTERVAL + 1
	gs._tick_contracts()

	_check("vyprseny kontrakt zmizel", gs.contracts.size(), 0)
	_check("a stal reputaci", gs.reputation[expiring_track],
		50 + GameData.CONTRACT_EXPIRY_REPUTATION)


# --- Harness -----------------------------------------------------------------

func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-46s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-46s = %s (cekano %s)" % [label, actual, expected])
