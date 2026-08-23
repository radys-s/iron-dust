class_name GameData
extends RefCounted

## Static game data ported from the HTML prototype's const tables, with the tech
## tree taken from GAME_DESIGN.md (17 nodes) rather than the prototype's shorter
## 10-node draft.

# --- Resources ---------------------------------------------------------------

const RESOURCES: Array[String] = ["gold", "food", "iron", "wood", "coal", "salt"]

const RESOURCE_LABELS := {
	"gold": "Zlato",
	"food": "Jídlo",
	"iron": "Železo",
	"wood": "Dřevo",
	"coal": "Uhlí",
	"salt": "Sůl",
}

# --- Terrain (gameplay meaning, distinct from the visual mesh) ----------------

enum Terrain {
	FOG,
	PRAIRIE,
	OWNED,
	RAILWAY,
	TOWN,
	DESERT,
	RIVER,
	MOUNTAIN,
	MINE,
	ENEMY,
}

const TERRAIN_NAMES := {
	Terrain.FOG: "Neznámé území",
	Terrain.PRAIRIE: "Prérie",
	Terrain.OWNED: "Vlastněné území",
	Terrain.RAILWAY: "Železnice",
	Terrain.TOWN: "Dustfall",
	Terrain.DESERT: "Poušť",
	Terrain.RIVER: "Řeka Colorado",
	Terrain.MOUNTAIN: "Pohoří",
	Terrain.MINE: "Důl",
	Terrain.ENEMY: "Harlan-Voss území",
}

const TERRAIN_DESCRIPTIONS := {
	Terrain.FOG: "Zahalené tajemstvím. Vyšlete průzkumníka k odhalení.",
	Terrain.PRAIRIE: "Úrodná půda vhodná pro osídlení a zemědělství.",
	Terrain.OWNED: "Vaše území. Zde můžete stavět a rozvíjet infrastrukturu.",
	Terrain.RAILWAY: "Klíčová tepna regionu. Umožňuje rychlý transport a obchod.",
	Terrain.TOWN: "Srdce vašeho impéria. Zde se kříží cesty a osudy.",
	Terrain.DESERT: "Vyprahlá země skrývající ložiska soli a vzácné oázy.",
	Terrain.RIVER: "Zdroj vody a obživy. Možnost rybolovu a rýžování zlata.",
	Terrain.MOUNTAIN: "Těžko prostupný terén bohatý na rudu a strategické body.",
	Terrain.MINE: "Průmyslový uzel pro těžbu uhlí a železa.",
	Terrain.ENEMY: "Kontrolováno korporací Harlan-Voss. Vstup na vlastní nebezpečí.",
}

## Per-turn yield of a single tile. Terrain not listed here produces nothing.
const TERRAIN_YIELDS := {
	Terrain.PRAIRIE: {"food": 3},
	Terrain.OWNED: {"food": 2, "wood": 1},
	Terrain.MINE: {"iron": 8, "coal": 5},
	Terrain.RIVER: {"food": 2},
	Terrain.TOWN: {"gold": 15},
	Terrain.RAILWAY: {"gold": 5},
}

# --- Tech tree (GAME_DESIGN.md) ----------------------------------------------

const TECH_NODES := [
	# Průmysl
	{"id": "forge", "branch": "industry", "tier": 1, "name": "Kovárna", "cost": 1,
		"desc": "+2 tech body navíc každé 3 tahy.", "requires": []},
	{"id": "steel", "branch": "industry", "tier": 2, "name": "Ocelárna", "cost": 2,
		"desc": "+10 % zlata z železnice a města.", "requires": ["forge"]},
	{"id": "weapons", "branch": "industry", "tier": 2, "name": "Zbrojírna", "cost": 2,
		"desc": "+1 síla v boji.", "requires": ["forge"]},
	{"id": "steam", "branch": "industry", "tier": 3, "name": "Parní stroj", "cost": 3,
		"desc": "+50 % produkce budov.", "requires": ["steel"]},
	# Doprava
	{"id": "coach", "branch": "transport", "tier": 1, "name": "Dostavník", "cost": 1,
		"desc": "Dostavník přijíždí častěji.", "requires": []},
	{"id": "express", "branch": "transport", "tier": 2, "name": "Expresní linka", "cost": 2,
		"desc": "+10 % zlata z železnice a města.", "requires": ["coach"]},
	{"id": "telegraph", "branch": "transport", "tier": 2, "name": "Telegraf", "cost": 2,
		"desc": "Průzkum levnější, odhalí sousedy.", "requires": ["coach"]},
	{"id": "railway", "branch": "transport", "tier": 3, "name": "Železniční uzel", "cost": 3,
		"desc": "KOMBINOVANÝ: Ocelárna + Expresní. +20 zlata/tah.", "requires": ["steel", "express"]},
	# Politika
	{"id": "council", "branch": "politics", "tier": 1, "name": "Městská rada", "cost": 1,
		"desc": "+10 reputace osadníků.", "requires": []},
	{"id": "federal", "branch": "politics", "tier": 2, "name": "Fed. kontakty", "cost": 2,
		"desc": "+8 reputace kupců, blokuje expanzi H-V.", "requires": ["council"]},
	{"id": "print", "branch": "politics", "tier": 2, "name": "Tiskárna", "cost": 2,
		"desc": "+morálka vojáků.", "requires": ["council"]},
	{"id": "court", "branch": "politics", "tier": 3, "name": "Soudní vliv", "cost": 3,
		"desc": "30 % šance na kapitulaci nepřítele.", "requires": ["federal"]},
	# Válka
	{"id": "militia", "branch": "war", "tier": 1, "name": "Milice", "cost": 1,
		"desc": "+2 síla v boji.", "requires": []},
	{"id": "escort", "branch": "war", "tier": 2, "name": "Eskorta", "cost": 2,
		"desc": "+1 síla, karavany nelze přepadnout.", "requires": ["militia"]},
	{"id": "artillery", "branch": "war", "tier": 2, "name": "Dělostřelectvo", "cost": 2,
		"desc": "+3 síla, obléhání fortů.", "requires": ["militia"]},
	{"id": "sabotage", "branch": "war", "tier": 3, "name": "Sabotáž", "cost": 3,
		"desc": "Zničí budovu nepřítele.", "requires": ["escort"]},
	# Kombinovaný
	{"id": "general", "branch": "combined", "tier": 4, "name": "Generál", "cost": 4,
		"desc": "KOMBINOVANÝ: Soud + Sabotáž. +2 síla ke všemu.", "requires": ["court", "sabotage"]},
]

const TECH_BRANCHES: Array[String] = ["industry", "transport", "politics", "war", "combined"]

## Combat strength granted by researched nodes. Consumed by the Phase 3 combat
## system; declared here so the tech data stays in one place.
const TECH_COMBAT_POWER := {
	"weapons": 1,
	"militia": 2,
	"escort": 1,
	"artillery": 3,
	"general": 2,
}

# --- Buildings ---------------------------------------------------------------

const BUILDABLES := [
	{"name": "Poštovní stanice", "costs": {"gold": 150, "wood": 20},
		"production": {"gold": 8}, "effect": "+dostavník frekvence, +8 zlata/tah"},
	{"name": "Farma", "costs": {"gold": 80, "wood": 30},
		"production": {"food": 12}, "effect": "+12 jídla/tah"},
	{"name": "Kovárna", "costs": {"gold": 200, "iron": 15, "coal": 10},
		"production": {"iron": 15}, "effect": "+15 železa/tah, odemyká zbraně"},
	{"name": "Sklad", "costs": {"gold": 120, "wood": 40, "iron": 5},
		"production": {}, "effect": "+80 kapacity surovin"},
	{"name": "Strážní věž", "costs": {"gold": 150, "wood": 25, "iron": 10},
		"production": {}, "effect": "+obrana, -riziko přepadení"},
	{"name": "Lékárna", "costs": {"gold": 180, "iron": 8, "salt": 15},
		"production": {}, "effect": "+spokojenost osadníků"},
	{"name": "Solárna", "costs": {"gold": 100, "wood": 10},
		"production": {"salt": 10}, "effect": "+10 soli/tah"},
	{"name": "Mlýn", "costs": {"gold": 90, "wood": 35},
		"production": {"food": 8, "gold": 5}, "effect": "+8 jídla, +5 zlata/tah"},
]

const STORAGE_BUILDING := "Sklad"
const STORAGE_PER_BUILDING := 80

# --- Ownership ---------------------------------------------------------------

## Terrain that is yours the moment the map loads, without an explicit claim.
const INHERENTLY_OWNED: Array[Terrain] = [Terrain.TOWN, Terrain.OWNED]

## Terrain a claim can be placed on. ENEMY needs a battle, FOG needs scouting.
const CLAIMABLE: Array[Terrain] = [
	Terrain.PRAIRIE, Terrain.DESERT, Terrain.RIVER, Terrain.MOUNTAIN, Terrain.MINE, Terrain.RAILWAY,
]

## Extra per-turn yield of a claimed tile whose terrain is not inherently yours —
## property tax and toll income. TOWN/OWNED already carry their own yields.
const CLAIM_BONUS := {"gold": 3}

## Tuned against scripts/dev/playthrough_test.gd: at 80 + 25/hex and +2 a turn a
## claim three hexes out took ~78 turns to pay for itself, which made expansion
## a pure loss. It is still meant to be bought for the territory, not the toll.
const CLAIM_COST_BASE := 60
const CLAIM_COST_PER_STEP := 20
const CLAIM_COST_WOOD := 15

# --- Tile actions ------------------------------------------------------------

## Coarse terrain filter per action; the fine-grained rules (ownership, supply,
## adjacency) live in TileAction._available so they can read live state.
const ACTIONS := [
	{
		"id": "explore",
		"name": "Vyslat průzkumníka",
		"hint": "Odhalí, co se skrývá pod mlhou.",
		"terrains": [Terrain.FOG],
		"needs_adjacency": true,
	},
	{
		"id": "claim",
		"name": "Zabrat území",
		"hint": "Připojí dlaždici k Dustfallu. Cena roste se vzdáleností.",
		"terrains": CLAIMABLE,
		"needs_adjacency": true,
	},
	{
		"id": "build",
		"name": "Postavit budovu",
		"hint": "Otevře nabídku staveb pro tuto dlaždici.",
		"terrains": [],
		"needs_adjacency": false,
	},
	{
		"id": "found",
		"name": "Založit osadu",
		"hint": "Nové sídlo rozšíří dosah zásobování.",
		"terrains": [],
		"needs_adjacency": false,
	},
	{
		"id": "upgrade",
		"name": "Vylepšit sídlo",
		"hint": "Vyšší úroveň = větší dosah, produkce i obrana.",
		"terrains": [],
		"needs_adjacency": false,
	},
	{
		"id": "attack",
		"name": "Zaútočit",
		"hint": "Střet s Harlan-Voss. Výsledek rozhodne síla a kostka.",
		"terrains": [Terrain.ENEMY],
		"needs_adjacency": true,
	},
	{
		"id": "trade",
		"name": "Obchodovat",
		"hint": "Obchodní stanice Dustfallu: kupci, trh a kontrakty.",
		"terrains": [Terrain.TOWN],
		"needs_adjacency": false,
	},
	{
		"id": "prospect",
		"name": "Prohledat ložisko",
		"hint": "Jednorázový výnos. Vzácně odhalí nový důl.",
		"terrains": [Terrain.MOUNTAIN, Terrain.DESERT],
		"needs_adjacency": false,
	},
	{
		"id": "repair",
		"name": "Opravit koleje",
		"hint": "Údržba trati potěší kupce.",
		"terrains": [Terrain.RAILWAY],
		"needs_adjacency": false,
	},
]

const EXPLORE_COST := 60
const EXPLORE_COST_TELEGRAPH := 40

const PROSPECT_COST := 70
## Jednorázový výnos průzkumu ložiska podle terénu.
const PROSPECT_YIELDS := {
	Terrain.MOUNTAIN: {"iron": 24, "coal": 12},
	Terrain.DESERT: {"salt": 20, "gold": 15},
}
## Šance, že se z prohledaného pohoří stane trvalý důl.
const PROSPECT_MINE_CHANCE := 0.18

const REPAIR_COST := 55
const REPAIR_REPUTATION := 4

# --- Settlements -------------------------------------------------------------

## Level 1..4. `supply` is the hex radius in which buildings may be placed,
## `defense` feeds combat support, `population` is the one-off influx on
## founding or upgrading.
const SETTLEMENT_LEVELS := {
	1: {"name": "Osada", "supply": 1, "defense": 0, "population": 40,
		"production": {"food": 2}},
	2: {"name": "Kolonie", "supply": 2, "defense": 1, "population": 90,
		"production": {"food": 4, "gold": 4}},
	3: {"name": "Fort", "supply": 3, "defense": 3, "population": 140,
		"production": {"food": 4, "gold": 6, "iron": 2}},
	4: {"name": "Město", "supply": 4, "defense": 5, "population": 220,
		"production": {"food": 6, "gold": 14, "iron": 3}},
}

const SETTLEMENT_MAX_LEVEL := 4
const SETTLEMENT_FOUND_COST := {"gold": 250, "wood": 50}
## GAME_DESIGN.md: upgrade za gold, cena = level × 200.
const SETTLEMENT_UPGRADE_PER_LEVEL := 200
## Nové sídlo musí být aspoň takhle daleko od každého jiného.
const SETTLEMENT_MIN_SPACING := 2

## Údržba sídla za tah = úroveň × tohle.
const SETTLEMENT_UPKEEP_PER_LEVEL := 5

## Sídlo poskytuje bojovou podporu na dlaždice do této vzdálenosti.
const SETTLEMENT_SUPPORT_RANGE := 2

# --- Combat ------------------------------------------------------------------

const ATTACK_COST := 40
## Kolik útoků svede vojsko za jeden tah. Bez limitu šlo projet celou frontu
## v jediném tahu — boj má být rozhodnutí, ne série kliknutí.
const ATTACKS_PER_TURN := 1
const COMBAT_DIE := 6
## Reputace vojáků dělená tímhle číslem dává základní sílu.
const COMBAT_REPUTATION_DIVISOR := 8
const ENEMY_BASE_POWER := 8
## Za každý hex vzdálenosti od Dustfallu je H-V zakopanější.
const ENEMY_POWER_PER_DISTANCE := 1
## Korporace posiluje s postupem hry.
const ENEMY_POWER_PER_TURNS := 6
## Soudní vliv: šance, že posádka kapituluje bez boje.
const COURT_CAPITULATION_CHANCE := 0.3

enum CombatResult { CAPITULATION, CRUSHING, VICTORY, STALEMATE, DEFEAT, ROUT }

const COMBAT_RESULT_NAMES := {
	CombatResult.CAPITULATION: "Kapitulace",
	CombatResult.CRUSHING: "Drtivé vítězství",
	CombatResult.VICTORY: "Vítězství",
	CombatResult.STALEMATE: "Remíza",
	CombatResult.DEFEAT: "Porážka",
	CombatResult.ROUT: "Těžká porážka",
}

## Dopad každého výsledku. `captures` = dlaždice přechází k hráči,
## `loses_tile` = H-V naopak zabere jednu sousední vlastněnou dlaždici.
const COMBAT_EFFECTS := {
	CombatResult.CAPITULATION: {
		"captures": true, "loses_tile": false,
		"resources": {"gold": 40},
		"reputation": {"merchants": 5, "soldiers": 2},
		"text": "Posádka Harlan-Voss složila zbraně bez jediného výstřelu.",
	},
	CombatResult.CRUSHING: {
		"captures": true, "loses_tile": false,
		"resources": {"gold": 150},
		"reputation": {"soldiers": 8, "settlers": 3},
		"text": "Drtivé vítězství! Pozice padla během jediného útoku.",
	},
	CombatResult.VICTORY: {
		"captures": true, "loses_tile": false,
		"resources": {"gold": 60, "food": -20},
		"reputation": {"soldiers": 4},
		"text": "Vítězství. Území je vaše, ale zásoby ubyly.",
	},
	CombatResult.STALEMATE: {
		"captures": false, "loses_tile": false,
		"resources": {"gold": -30, "food": -15},
		"reputation": {"soldiers": -2},
		"text": "Střet skončil bez rozhodnutí. Obě strany se stáhly.",
	},
	CombatResult.DEFEAT: {
		"captures": false, "loses_tile": false,
		"resources": {"gold": -90, "food": -30},
		"reputation": {"soldiers": -6},
		"text": "Porážka. Harlan-Voss udržel pozici.",
	},
	CombatResult.ROUT: {
		"captures": false, "loses_tile": true,
		"resources": {"gold": -200, "food": -60},
		"reputation": {"soldiers": -12, "settlers": -5},
		"text": "Těžká porážka! Korporace přešla do protiútoku.",
	},
}

# --- Trade -------------------------------------------------------------------

## Pevné ceny obchodní stanice. `buy` = kolik zaplatíte za jednotku,
## `sell` = kolik dostanete. Rozdíl je marže kupce.
const VENDOR_PRICES := {
	"food": {"buy": 4, "sell": 2},
	"wood": {"buy": 6, "sell": 3},
	"coal": {"buy": 9, "sell": 5},
	"iron": {"buy": 12, "sell": 7},
	"salt": {"buy": 14, "sell": 8},
}

const TRADE_GOODS: Array[String] = ["food", "wood", "coal", "iron", "salt"]

## Trh nemá marži — kupujete i prodáváte za stejnou cenu, ale ta kolísá
## a je dostupná jen když je ve městě dostavník.
const MARKET_DRIFT_MIN := 0.6
const MARKET_DRIFT_MAX := 1.6
const MARKET_DRIFT_STEP := 0.18

const REPUTATION_PRICE_BONUS := 0.1
const REPUTATION_PRICE_PENALTY := 0.15

const COACH_STAY_TURNS := 2

# --- Contracts ---------------------------------------------------------------

const CONTRACT_INTERVAL := 5
const CONTRACT_MAX_ACTIVE := 3
const CONTRACT_DURATION_MIN := 4
const CONTRACT_DURATION_MAX := 8

const CONTRACT_FACTIONS := [
	{"id": "union_pacific", "name": "Union Pacific", "track": "merchants"},
	{"id": "army", "name": "Federální armáda", "track": "soldiers"},
	{"id": "tonahve", "name": "Kmen Tonáhve", "track": "tribes"},
	{"id": "settlers_guild", "name": "Osadnický spolek", "track": "settlers"},
]

## Požadované množství podle suroviny (min, max).
const CONTRACT_AMOUNTS := {
	"food": [60, 140],
	"wood": [30, 80],
	"coal": [25, 60],
	"iron": [30, 70],
	"salt": [20, 50],
}

## Odměna = množství × výkupní cena kupce × tenhle násobek. Kontrakt se tak
## vyplatí víc než prostý výprodej, ale zboží musíte držet a stihnout termín.
const CONTRACT_REWARD_MULTIPLIER := 2.0
const CONTRACT_REWARD_REPUTATION := 6
const CONTRACT_EXPIRY_REPUTATION := -8

# --- Economy tuning ----------------------------------------------------------

const BASE_STORAGE_CAPACITY := 600
const BUILD_UPKEEP_GOLD := 5
const SOLDIER_UPKEEP_GOLD := 20
const SOLDIER_UPKEEP_REPUTATION := 60
const POPULATION_PER_FOOD := 50
const STARVATION_POPULATION_LOSS := 10

const TECH_POINTS_INTERVAL := 3
const TECH_POINTS_BASE := 2
const TECH_POINTS_FORGE_BONUS := 2

const COACH_GOLD := 100
const COACH_POPULATION := 5

const SEASONS: Array[String] = ["Jaro", "Léto", "Podzim", "Zima"]

# --- Reputation --------------------------------------------------------------

const REPUTATION_TRACKS: Array[String] = ["settlers", "merchants", "soldiers", "tribes"]

const REPUTATION_LABELS := {
	"settlers": "Osadníci",
	"merchants": "Kupci",
	"soldiers": "Vojáci",
	"tribes": "Kmeny",
}

const REPUTATION_LOW := 30
const REPUTATION_HIGH := 80

## Fired when a track drops below REPUTATION_LOW.
const REPUTATION_PENALTIES := {
	"settlers": "Osadníci stávkují — produkce jídla vázne.",
	"merchants": "Kupci bojkotují Dustfall — obchod je dražší.",
	"soldiers": "Vojáci dezertují — obrana slábne.",
	"tribes": "Kmeny na válečné stezce — hrozí nájezdy.",
}

# --- Random events -----------------------------------------------------------

const RANDOM_EVENTS := [
	{"text": "Dostavník ze severu přivezl zásoby.", "type": "success",
		"resources": {"food": 50}, "reputation": {}, "population": 0},
	{"text": "Agent Harlan-Voss viděn v okolí Dustfallu.", "type": "warning",
		"resources": {}, "reputation": {"merchants": -5}, "population": 0},
	{"text": "Nová rodina se usadila. Populace roste.", "type": "info",
		"resources": {}, "reputation": {}, "population": 10},
	{"text": "Sucho zasáhlo pláně. Úroda slabá.", "type": "warning",
		"resources": {"food": -30}, "reputation": {}, "population": 0},
	{"text": "Zlatý prach nalezen v řece Colorado.", "type": "success",
		"resources": {"gold": 120}, "reputation": {}, "population": 0},
	{"text": "Správce skladu hlásí nesrovnalosti.", "type": "warning",
		"resources": {"gold": -80}, "reputation": {}, "population": 0},
	{"text": "Kupci z východu nabízejí kontrakt.", "type": "info",
		"resources": {}, "reputation": {"merchants": 8}, "population": 0},
	{"text": "Kmen Tonáhve poslal posly. Opatrnost.", "type": "warning",
		"resources": {}, "reputation": {"tribes": -5}, "population": 0},
]

# --- Helpers -----------------------------------------------------------------

static func empty_resources() -> Dictionary:
	var out := {}
	for key in RESOURCES:
		out[key] = 0
	return out


static func find_tech(id: String) -> Dictionary:
	for node in TECH_NODES:
		if node["id"] == id:
			return node
	return {}


static func find_buildable(name: String) -> Dictionary:
	for entry in BUILDABLES:
		if entry["name"] == name:
			return entry
	return {}


static func find_action(id: String) -> Dictionary:
	for entry in ACTIONS:
		if entry["id"] == id:
			return entry
	return {}


static func find_faction(id: String) -> Dictionary:
	for entry in CONTRACT_FACTIONS:
		if entry["id"] == id:
			return entry
	return {}


static func settlement_data(level: int) -> Dictionary:
	return SETTLEMENT_LEVELS.get(clampi(level, 1, SETTLEMENT_MAX_LEVEL), {})


static func settlement_name(level: int) -> String:
	var data := settlement_data(level)
	return String(data.get("name", "Sídlo"))


## Cena povýšení sídla z `level` na `level + 1`.
static func settlement_upgrade_cost(level: int) -> Dictionary:
	return {"gold": level * SETTLEMENT_UPGRADE_PER_LEVEL}


static func format_costs(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for key in RESOURCES:
		if costs.has(key) and int(costs[key]) != 0:
			parts.append("%d %s" % [int(costs[key]), RESOURCE_LABELS[key]])
	return ", ".join(parts) if not parts.is_empty() else "zdarma"
