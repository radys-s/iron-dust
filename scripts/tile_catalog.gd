class_name TileCatalog
extends RefCounted

## Every mesh the map can show, and where it sits vertically.
##
## Kenney's `building-*` models are complete hex tiles with their own base, not
## props — so a settlement or a building *replaces* the terrain mesh on its cell
## instead of stacking on top of it. `unit-*` and the nature kit are loose props
## that do stack.

enum TileType {
	GRASS,
	GRASS_HILL,
	GRASS_FOREST,
	SAND,
	SAND_DESERT,
	SAND_ROCKS,
	STONE,
	STONE_HILL,
	STONE_MOUNTAIN,
	STONE_ROCKS,
	WATER,
	DIRT,
	MINE_SITE,
	ENEMY_CAMP,
	ENEMY_WALL,
}

const TERRAIN_PATHS := {
	TileType.GRASS: "res://assets/kenney/hexagon-kit/grass.glb",
	TileType.GRASS_HILL: "res://assets/kenney/hexagon-kit/grass-hill.glb",
	TileType.GRASS_FOREST: "res://assets/kenney/hexagon-kit/grass-forest.glb",
	TileType.SAND: "res://assets/kenney/hexagon-kit/sand.glb",
	TileType.SAND_DESERT: "res://assets/kenney/hexagon-kit/sand-desert.glb",
	TileType.SAND_ROCKS: "res://assets/kenney/hexagon-kit/sand-rocks.glb",
	TileType.STONE: "res://assets/kenney/hexagon-kit/stone.glb",
	TileType.STONE_HILL: "res://assets/kenney/hexagon-kit/stone-hill.glb",
	TileType.STONE_MOUNTAIN: "res://assets/kenney/hexagon-kit/stone-mountain.glb",
	TileType.STONE_ROCKS: "res://assets/kenney/hexagon-kit/stone-rocks.glb",
	TileType.WATER: "res://assets/kenney/hexagon-kit/water.glb",
	TileType.DIRT: "res://assets/kenney/hexagon-kit/dirt.glb",
	TileType.MINE_SITE: "res://assets/kenney/hexagon-kit/building-mine.glb",
	# Harlan-Voss fortifies whatever it takes — walls read as "occupied" at a
	# glance, and capturing a hex visibly clears them away.
	TileType.ENEMY_CAMP: "res://assets/kenney/hexagon-kit/building-walls.glb",
	TileType.ENEMY_WALL: "res://assets/kenney/hexagon-kit/building-wall.glb",
}

const PROP_PATHS := {
	"cactus_short": "res://assets/kenney/nature-kit/cactus_short.glb",
	"cactus_tall": "res://assets/kenney/nature-kit/cactus_tall.glb",
	"rock_smallA": "res://assets/kenney/nature-kit/rock_smallA.glb",
	"rock_smallB": "res://assets/kenney/nature-kit/rock_smallB.glb",
	"rock_smallC": "res://assets/kenney/nature-kit/rock_smallC.glb",
	"rock_smallD": "res://assets/kenney/nature-kit/rock_smallD.glb",
	"rock_largeA": "res://assets/kenney/nature-kit/rock_largeA.glb",
	"rock_largeB": "res://assets/kenney/nature-kit/rock_largeB.glb",
	"rock_largeC": "res://assets/kenney/nature-kit/rock_largeC.glb",
	"stump_old": "res://assets/kenney/nature-kit/stump_old.glb",
	"bush_small": "res://assets/kenney/nature-kit/plant_bushSmall.glb",
}

## Settlement level (1..4) -> mesh. Placeholder medieval shapes; a western
## re-skin only has to swap these paths.
const SETTLEMENT_PATHS := {
	1: "res://assets/kenney/hexagon-kit/building-cabin.glb",
	2: "res://assets/kenney/hexagon-kit/building-village.glb",
	3: "res://assets/kenney/hexagon-kit/building-tower.glb",
	4: "res://assets/kenney/hexagon-kit/building-castle.glb",
}

## Buildable name (GameData.BUILDABLES) -> mesh.
const BUILDING_PATHS := {
	"Poštovní stanice": "res://assets/kenney/hexagon-kit/building-market.glb",
	"Farma": "res://assets/kenney/hexagon-kit/building-farm.glb",
	"Kovárna": "res://assets/kenney/hexagon-kit/building-smelter.glb",
	"Sklad": "res://assets/kenney/hexagon-kit/building-house.glb",
	"Strážní věž": "res://assets/kenney/hexagon-kit/building-archery.glb",
	"Lékárna": "res://assets/kenney/hexagon-kit/building-sheep.glb",
	"Solárna": "res://assets/kenney/hexagon-kit/building-mill.glb",
	"Mlýn": "res://assets/kenney/hexagon-kit/building-watermill.glb",
}

## Surface height of a flat Kenney hex tile, for placing props on top.
const TILE_TOP_Y := 0.2

## Height of the hex *rim* (not the decoration on it), where ownership and
## selection rings belong. Measured from the GLB bounds; 0.2 is the kit default.
const RIM_HEIGHT_DEFAULT := 0.2
const RIM_HEIGHTS := {
	TileType.DIRT: 0.1,
	TileType.WATER: 0.1,
}

static var _cache: Dictionary = {}


static func terrain_scene(type: TileType) -> PackedScene:
	return _load_cached(TERRAIN_PATHS[type])


static func prop_scene(name: String) -> PackedScene:
	return _load_cached(PROP_PATHS[name])


static func settlement_scene(level: int) -> PackedScene:
	var clamped := clampi(level, 1, SETTLEMENT_PATHS.size())
	return _load_cached(SETTLEMENT_PATHS[clamped])


## Null when a buildable has no dedicated mesh yet — the caller falls back to
## leaving the terrain tile alone rather than crashing.
static func building_scene(name: String) -> PackedScene:
	if not BUILDING_PATHS.has(name):
		return null
	return _load_cached(BUILDING_PATHS[name])


static func rim_height(type: TileType) -> float:
	return float(RIM_HEIGHTS.get(type, RIM_HEIGHT_DEFAULT))


static func _load_cached(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
