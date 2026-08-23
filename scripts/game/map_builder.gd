class_name MapBuilder
extends RefCounted

## Builds the Dustfall region: decides which gameplay terrain sits on each hex,
## then renders the world — terrain, decoration, structures and the ownership
## outline — under a single container node it manages itself.
##
## Gameplay terrain (GameData.Terrain) and visual mesh (TileCatalog.TileType) are
## deliberately separate — yields come from the former, looks from the latter, so
## a re-skin never changes the economy.
##
## Rendering is *deterministic per cell*: prop choice, jitter and mesh variants
## come from a hash of the coordinates, not from a running RNG. render() is
## called after every action, and a live RNG would make the scenery jump around
## each time the player claims a tile.

const MAP_RADIUS := 7
## Everything further out than this starts the game under fog.
const VISIBLE_RADIUS := 4
const OWNED_RADIUS := 2
const RAILWAY_REACH := 6

const TOWN_CELL := Vector2i(0, 0)
## Dustfall opens as a Kolonie — enough supply range to build around town.
const TOWN_SETTLEMENT_LEVEL := 2

## Hand-placed ore workings; two sit in plain sight, three reward exploring.
const MINE_CELLS: Array[Vector2i] = [
	Vector2i(4, -3), Vector2i(-1, -3), Vector2i(6, -4), Vector2i(-3, -2), Vector2i(-4, -1),
]

## Gameplay terrain -> visual tile. Several gameplay types can share a mesh.
##
## The visual language: land you hold is *cleared* (flat pasture under a gold
## outline), wild land is overgrown or rocky, and Harlan-Voss ground is walled
## off — so taking a hex visibly tears the walls down and levels it.
const TERRAIN_MESH := {
	GameData.Terrain.FOG: TileCatalog.TileType.STONE,
	GameData.Terrain.PRAIRIE: TileCatalog.TileType.GRASS,
	GameData.Terrain.OWNED: TileCatalog.TileType.GRASS,
	GameData.Terrain.RAILWAY: TileCatalog.TileType.DIRT,
	GameData.Terrain.TOWN: TileCatalog.TileType.DIRT,
	GameData.Terrain.DESERT: TileCatalog.TileType.SAND_DESERT,
	GameData.Terrain.RIVER: TileCatalog.TileType.WATER,
	GameData.Terrain.MOUNTAIN: TileCatalog.TileType.STONE_MOUNTAIN,
	GameData.Terrain.MINE: TileCatalog.TileType.MINE_SITE,
	GameData.Terrain.ENEMY: TileCatalog.TileType.ENEMY_CAMP,
}

## Weighted mesh pools so a large stretch of one terrain does not tile flat.
## Repeating an entry raises its share; the pick is a hash of the cell, so the
## same hex always draws the same mesh. Terrain that is not listed here always
## uses its TERRAIN_MESH entry — owned land stays deliberately uniform, since
## "cleared and fenced" is what tells the player the hex is theirs.
const TERRAIN_MESH_VARIANTS := {
	GameData.Terrain.PRAIRIE: [
		TileCatalog.TileType.GRASS,
		TileCatalog.TileType.GRASS,
		TileCatalog.TileType.GRASS_HILL,
		TileCatalog.TileType.GRASS_FOREST,
	],
	GameData.Terrain.DESERT: [
		TileCatalog.TileType.SAND_DESERT,
		TileCatalog.TileType.SAND_DESERT,
		TileCatalog.TileType.SAND,
	],
	GameData.Terrain.MOUNTAIN: [
		TileCatalog.TileType.STONE_MOUNTAIN,
		TileCatalog.TileType.STONE_MOUNTAIN,
		TileCatalog.TileType.STONE_HILL,
	],
	GameData.Terrain.ENEMY: [
		TileCatalog.TileType.ENEMY_CAMP,
		TileCatalog.TileType.ENEMY_WALL,
	],
}

## Scattered decoration per gameplay terrain. Terrain whose mesh already carries
## structures (mines, Harlan-Voss walls) is left alone so nothing clips.
const TERRAIN_PROPS := {
	GameData.Terrain.PRAIRIE: ["bush_small", "rock_smallB", "rock_smallC"],
	GameData.Terrain.OWNED: ["bush_small", "rock_smallC"],
	GameData.Terrain.DESERT: ["cactus_tall", "cactus_short", "rock_smallA", "stump_old"],
	GameData.Terrain.MOUNTAIN: ["rock_largeA", "rock_largeB"],
}

const PROP_CHANCE := 0.45

const FOG_COLOR := Color(0.16, 0.14, 0.13)
const OWNED_RING_COLOR := Color(0.85, 0.70, 0.32)


# --- Terrain -----------------------------------------------------------------

## Hand-authored layout of the Dustfall basin, ignoring fog.
static func base_terrain(cell: Vector2i) -> GameData.Terrain:
	var dist := HexGrid.distance(cell, TOWN_CELL)

	if cell == TOWN_CELL:
		return GameData.Terrain.TOWN

	# The rail line runs east-west straight through town.
	if cell.y == 0 and absi(cell.x) <= RAILWAY_REACH:
		return GameData.Terrain.RAILWAY

	# Colorado: one long north-east watercourse that cuts a canyon through the
	# northern range. Checked before the mountains so the canyon survives.
	if cell.x + cell.y == -1 and cell.y <= -1:
		return GameData.Terrain.RIVER

	if MINE_CELLS.has(cell):
		return GameData.Terrain.MINE

	# Northern rim: the range that hides the deep workings.
	if cell.y <= -4:
		return GameData.Terrain.MOUNTAIN

	# Harlan-Voss holds the southern and south-eastern approaches.
	if cell.y >= 3 and cell.x >= -1:
		return GameData.Terrain.ENEMY

	# South-western desert basin.
	if cell.x <= -2 and cell.y >= 1:
		return GameData.Terrain.DESERT

	# Eastern spur of the range, only reachable after scouting.
	if cell.x >= 5 and cell.y >= 1:
		return GameData.Terrain.MOUNTAIN

	if dist <= OWNED_RADIUS:
		return GameData.Terrain.OWNED
	return GameData.Terrain.PRAIRIE


## The whole region with nothing hidden — used by the map tests.
static func full_terrain() -> Dictionary:
	var out: Dictionary = {}
	for cell in HexGrid.spiral_area(MAP_RADIUS):
		out[cell] = base_terrain(cell)
	return out


## Starting map: {"tiles": what the player sees, "hidden": what fog conceals}.
static func generate() -> Dictionary:
	var visible: Dictionary = {}
	var hidden: Dictionary = {}

	for cell in HexGrid.spiral_area(MAP_RADIUS):
		var terrain := base_terrain(cell)
		if HexGrid.distance(cell, TOWN_CELL) > VISIBLE_RADIUS:
			visible[cell] = GameData.Terrain.FOG
			hidden[cell] = terrain
		else:
			visible[cell] = terrain

	return {"tiles": visible, "hidden": hidden}


# --- Rendering ---------------------------------------------------------------

## Rebuilds the whole visual world under `world` from the current GameState.
static func render(gs, world: Node3D) -> void:
	var terrain_root := _ensure_child(world, "Terrain")
	var prop_root := _ensure_child(world, "Props")
	var structure_root := _ensure_child(world, "Structures")
	var overlay_root := _ensure_child(world, "Ownership")

	for root in [terrain_root, prop_root, structure_root, overlay_root]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()

	var ring_mesh := _ownership_ring_mesh()

	for cell in gs.tiles:
		var terrain: GameData.Terrain = gs.tiles[cell]
		var structure := _structure_scene(gs, cell)
		var position := HexGrid.axial_to_world(cell.x, cell.y)

		if structure == null:
			var mesh_type := _mesh_for(cell, terrain)
			var tile := TileCatalog.terrain_scene(mesh_type).instantiate()
			tile.position = position
			terrain_root.add_child(tile)
			if terrain == GameData.Terrain.FOG:
				_tint(tile, FOG_COLOR)
			else:
				_scatter_prop(cell, terrain, prop_root)
		else:
			var built := structure.instantiate()
			built.position = position
			structure_root.add_child(built)

		if terrain != GameData.Terrain.FOG and gs.is_owned(cell):
			overlay_root.add_child(_ownership_ring(cell, terrain, ring_mesh))


## Settlements and buildings replace the terrain tile; null means plain terrain.
static func _structure_scene(gs, cell: Vector2i) -> PackedScene:
	var level: int = gs.settlement_at(cell)
	if level > 0:
		return TileCatalog.settlement_scene(level)

	var building: Dictionary = gs.building_at(cell)
	if not building.is_empty():
		var scene := TileCatalog.building_scene(String(building["name"]))
		if scene != null:
			return scene
	return null


static func _mesh_for(cell: Vector2i, terrain: GameData.Terrain) -> TileCatalog.TileType:
	if not TERRAIN_MESH_VARIANTS.has(terrain):
		return TERRAIN_MESH[terrain]
	var options: Array = TERRAIN_MESH_VARIANTS[terrain]
	return options[int(_noise(cell, 11) * float(options.size())) % options.size()]


static func _scatter_prop(cell: Vector2i, terrain: GameData.Terrain, parent: Node3D) -> void:
	if not TERRAIN_PROPS.has(terrain):
		return
	if _noise(cell, 23) > PROP_CHANCE:
		return

	var choices: Array = TERRAIN_PROPS[terrain]
	var index := int(_noise(cell, 31) * float(choices.size())) % choices.size()
	var prop := TileCatalog.prop_scene(choices[index]).instantiate()

	var base := HexGrid.axial_to_world(cell.x, cell.y)
	var jitter := Vector3(
		(_noise(cell, 41) - 0.5) * 0.44, 0.0, (_noise(cell, 53) - 0.5) * 0.44
	)
	prop.position = base + jitter + Vector3(0.0, TileCatalog.TILE_TOP_Y, 0.0)
	prop.rotation.y = _noise(cell, 67) * TAU
	parent.add_child(prop)


static func _ownership_ring(cell: Vector2i, terrain: GameData.Terrain, mesh: Mesh) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	var height := TileCatalog.rim_height(TERRAIN_MESH[terrain]) + 0.015
	marker.position = HexGrid.axial_to_world(cell.x, cell.y) + Vector3(0.0, height, 0.0)
	return marker


static func _ownership_ring_mesh() -> Mesh:
	var ring := TorusMesh.new()
	ring.inner_radius = HexGrid.HEX_RADIUS * 0.80
	ring.outer_radius = HexGrid.HEX_RADIUS * 0.85
	ring.rings = 6
	ring.ring_segments = 6

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(OWNED_RING_COLOR.r, OWNED_RING_COLOR.g, OWNED_RING_COLOR.b, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = mat
	return ring


# --- Helpers -----------------------------------------------------------------

static func _ensure_child(parent: Node3D, name: String) -> Node3D:
	var existing := parent.get_node_or_null(NodePath(name))
	if existing != null:
		return existing
	var node := Node3D.new()
	node.name = name
	parent.add_child(node)
	return node


## Fog tiles keep their silhouette but lose all detail.
static func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		node.material_override = mat
	for child in node.get_children():
		_tint(child, color)


## Stable pseudo-random value in [0, 1) for a cell, so re-renders look identical.
static func _noise(cell: Vector2i, salt: int) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
