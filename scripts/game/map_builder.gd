class_name MapBuilder
extends RefCounted

## Builds the Dustfall region: decides which gameplay terrain sits on each hex,
## then renders it with the visual tiles from TileCatalog.
##
## Gameplay terrain (GameData.Terrain) and visual mesh (TileCatalog.TileType) are
## deliberately separate — yields come from the former, looks from the latter, so
## a re-skin never changes the economy.

const MAP_RADIUS := 5
const TOWN_CELL := Vector2i(0, 0)

## Gameplay terrain -> visual tile. Several gameplay types can share a mesh.
const TERRAIN_MESH := {
	GameData.Terrain.FOG: TileCatalog.TileType.STONE,
	GameData.Terrain.PRAIRIE: TileCatalog.TileType.GRASS,
	GameData.Terrain.OWNED: TileCatalog.TileType.GRASS_HILL,
	GameData.Terrain.RAILWAY: TileCatalog.TileType.DIRT,
	GameData.Terrain.TOWN: TileCatalog.TileType.DIRT,
	GameData.Terrain.DESERT: TileCatalog.TileType.SAND_DESERT,
	GameData.Terrain.RIVER: TileCatalog.TileType.WATER,
	GameData.Terrain.MOUNTAIN: TileCatalog.TileType.STONE_MOUNTAIN,
	GameData.Terrain.MINE: TileCatalog.TileType.STONE_ROCKS,
	GameData.Terrain.ENEMY: TileCatalog.TileType.SAND_ROCKS,
}

## Scattered decoration per gameplay terrain.
const TERRAIN_PROPS := {
	GameData.Terrain.PRAIRIE: ["bush_small", "rock_smallB", "rock_smallC"],
	GameData.Terrain.OWNED: ["bush_small", "rock_smallC"],
	GameData.Terrain.DESERT: ["cactus_tall", "cactus_short", "rock_smallA", "stump_old"],
	GameData.Terrain.MOUNTAIN: ["rock_largeA", "rock_largeB"],
	GameData.Terrain.MINE: ["rock_largeC", "rock_smallD"],
	GameData.Terrain.ENEMY: ["rock_smallA", "stump_old"],
}


## Hand-authored layout of the Dustfall basin.
static func generate_terrain(rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}

	for cell in HexGrid.spiral_area(MAP_RADIUS):
		out[cell] = _terrain_for(cell, rng)

	return out


static func _terrain_for(cell: Vector2i, rng: RandomNumberGenerator) -> GameData.Terrain:
	var dist := HexGrid.distance(cell, TOWN_CELL)

	if cell == TOWN_CELL:
		return GameData.Terrain.TOWN

	# The rail line runs east-west straight through town.
	if cell.y == 0 and absi(cell.x) <= 3:
		return GameData.Terrain.RAILWAY

	# Colorado river: a short run north-east of town.
	if cell in [Vector2i(2, -3), Vector2i(2, -2), Vector2i(1, -1), Vector2i(3, -3)]:
		return GameData.Terrain.RIVER

	# Northern rim: mountains, with ore workings just below them.
	if cell.y <= -3:
		return GameData.Terrain.MOUNTAIN
	if cell.y == -2 and dist >= 4:
		return GameData.Terrain.MINE

	# Harlan-Voss holds the southern approach.
	if cell.y >= 3 and cell.x <= 0:
		return GameData.Terrain.ENEMY

	# South-western desert basin.
	if cell.x <= -1 and cell.y >= 1:
		return GameData.Terrain.DESERT

	# Ring of owned land near town, prairie further out; the far edge is unscouted.
	if dist >= 5:
		return GameData.Terrain.FOG
	if dist <= 2:
		return GameData.Terrain.OWNED
	return GameData.Terrain.PRAIRIE


## Rebuilds the visual representation of `tiles` under `terrain_root` / `prop_root`.
static func render(tiles: Dictionary, terrain_root: Node3D, prop_root: Node3D,
		rng: RandomNumberGenerator) -> void:
	for child in terrain_root.get_children():
		child.queue_free()
	for child in prop_root.get_children():
		child.queue_free()

	for cell in tiles:
		var terrain: GameData.Terrain = tiles[cell]
		var mesh_type: TileCatalog.TileType = TERRAIN_MESH[terrain]

		var tile := TileCatalog.terrain_scene(mesh_type).instantiate()
		tile.position = HexGrid.axial_to_world(cell.x, cell.y)
		terrain_root.add_child(tile)

		_scatter_prop(cell, terrain, prop_root, rng)

	var cabin := TileCatalog.settlement_scene().instantiate()
	cabin.position = HexGrid.axial_to_world(TOWN_CELL.x, TOWN_CELL.y)
	cabin.name = "Dustfall"
	terrain_root.add_child(cabin)


static func _scatter_prop(cell: Vector2i, terrain: GameData.Terrain, parent: Node3D,
		rng: RandomNumberGenerator) -> void:
	if not TERRAIN_PROPS.has(terrain):
		return
	if rng.randf() > 0.45:
		return

	var choices: Array = TERRAIN_PROPS[terrain]
	var prop := TileCatalog.prop_scene(choices[rng.randi_range(0, choices.size() - 1)]).instantiate()
	var base := HexGrid.axial_to_world(cell.x, cell.y)
	var jitter := Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.22, 0.22))
	prop.position = base + jitter + Vector3(0.0, TileCatalog.TILE_TOP_Y, 0.0)
	prop.rotation.y = rng.randf_range(0.0, TAU)
	parent.add_child(prop)
