class_name TileCatalog
extends RefCounted

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

const SETTLEMENT_PATH := "res://assets/kenney/hexagon-kit/building-cabin.glb"

# Surface height of a flat Kenney hex tile, for placing props on top.
const TILE_TOP_Y := 0.2

static var _cache: Dictionary = {}


static func terrain_scene(type: TileType) -> PackedScene:
	return _load_cached(TERRAIN_PATHS[type])


static func prop_scene(name: String) -> PackedScene:
	return _load_cached(PROP_PATHS[name])


static func settlement_scene() -> PackedScene:
	return _load_cached(SETTLEMENT_PATH)


static func _load_cached(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
