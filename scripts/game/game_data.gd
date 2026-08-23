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
