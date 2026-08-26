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

## Etapa 1c: Otevřený svět — ostrovní mapa (poloměr 21, 1387 dlaždic) obklopená
## oceánem. Svět je výrazně větší, dlaždice jsou v měřítku WORLD_SCALE (0.8),
## řeka Colorado i železnice se klikatí a napojují podle 6bitové masky sousedů.
const MAP_RADIUS := 21
const VISIBLE_RADIUS := 7
const OWNED_RADIUS_CORE := 2
const OWNED_RADIUS_BASE := 5.0
const WORLD_SCALE := 0.8

const ISLAND_RADIUS_BASE := 17.5
const ISLAND_RADIUS_AMP := 2.5

const RAILWAY_REACH := 16
const RIVER_REACH := 40

## Cíle klikatého random walku — taženy dovnitř od skutečné pobřežní čáry
## (island_r ~15-20), ať se trasa spolehlivě nezakousne do oceánu.
const RAILWAY_WEST_TARGET := Vector2i(-13, 4)
const RAILWAY_EAST_TARGET := Vector2i(13, -4)
const RIVER_NORTH_TARGET := Vector2i(1, -13)
const RIVER_SOUTH_TARGET := Vector2i(-8, 13)

## Vyšší = rovnější trasa (upřednostní pokračovat rovně). Železnice je
## postavená trať (mírné zatáčky), řeka je divoká (širší, klikatější).
const RAILWAY_STRAIGHT_BIAS := 0.85
const RIVER_STRAIGHT_BIAS := 0.35
const RIVER_WIDEN_CHANCE := 0.22

const TOWN_CELL := Vector2i(0, 0)
## Dustfall opens as a Kolonie — enough supply range to build around town.
const TOWN_SETTLEMENT_LEVEL := 2

## Hand-placed ore workings; two sit in plain sight, three reward exploring.
const MINE_CELLS: Array[Vector2i] = [
	Vector2i(4, -3), Vector2i(-1, -3), Vector2i(6, -4), Vector2i(-3, -2), Vector2i(-4, -1),
]

## Gameplay terrain -> visual tile. Several gameplay types can share a mesh.
const TERRAIN_MESH := {
	GameData.Terrain.FOG: TileCatalog.TileType.STONE,
	GameData.Terrain.PRAIRIE: TileCatalog.TileType.GRASS,
	GameData.Terrain.OWNED: TileCatalog.TileType.GRASS,
	GameData.Terrain.RAILWAY: TileCatalog.TileType.ROAD,
	GameData.Terrain.TOWN: TileCatalog.TileType.DIRT,
	GameData.Terrain.DESERT: TileCatalog.TileType.SAND_DESERT,
	GameData.Terrain.RIVER: TileCatalog.TileType.RIVER_STRAIGHT,
	GameData.Terrain.MOUNTAIN: TileCatalog.TileType.STONE_MOUNTAIN,
	GameData.Terrain.MINE: TileCatalog.TileType.MINE_SITE,
	GameData.Terrain.ENEMY: TileCatalog.TileType.ENEMY_CAMP,
	GameData.Terrain.OCEAN: TileCatalog.TileType.OCEAN,
}

## Weighted mesh pools so a large stretch of one terrain does not tile flat.
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
		TileCatalog.TileType.SAND_ROCKS,
	],
	GameData.Terrain.MOUNTAIN: [
		TileCatalog.TileType.STONE_MOUNTAIN,
		TileCatalog.TileType.STONE_MOUNTAIN,
		TileCatalog.TileType.STONE_HILL,
		TileCatalog.TileType.STONE_ROCKS,
	],
	GameData.Terrain.ENEMY: [
		TileCatalog.TileType.ENEMY_CAMP,
		TileCatalog.TileType.ENEMY_WALL,
	],
	GameData.Terrain.OCEAN: [
		TileCatalog.TileType.OCEAN,
		TileCatalog.TileType.WATER_ROCKS,
	],
}

## Scattered decoration per gameplay terrain.
const TERRAIN_PROPS := {
	GameData.Terrain.PRAIRIE: [
		"bush_small", "bush", "grass_tuft", "grass_large", "weed_short",
		"rock_smallB", "rock_smallC", "rock_flatA", "stump_old", "tree_thin",
	],
	GameData.Terrain.OWNED: [
		"grass_tuft", "weed_short", "rock_flatB", "crops_rows", "crops_wheat",
	],
	GameData.Terrain.DESERT: [
		"cactus_tall", "cactus_short", "rock_smallA", "rock_smallE",
		"rock_flatA", "stump_old", "weed_tall", "rock_smallG",
	],
	GameData.Terrain.MOUNTAIN: [
		"rock_largeA", "rock_largeB", "rock_largeD", "rock_largeE",
		"rock_tallA", "rock_tallC", "tree_pine_tall", "tree_pine_small",
	],
	GameData.Terrain.RIVER: ["rock_flatA", "grass_large", "bush_small"],
	GameData.Terrain.RAILWAY: ["weed_short", "rock_smallC", "log", "sign"],
	GameData.Terrain.ENEMY: [
		"fence_planks", "fence_planks_double", "fence_simple", "tent_small",
		"campfire", "log_stack", "sign", "weed_short",
	],
}

## Území, kde Harlan-Voss opravdu sídlí — hustší tábor se strážnou věží.
const ENEMY_BASE_PROPS: Array[String] = [
	"watchtower", "tent_closed", "tent_open", "fence_planks_double",
	"fence_high", "campfire_logs", "log_stack", "sign",
]

const PROP_DENSITY := {
	GameData.Terrain.PRAIRIE: 2,
	GameData.Terrain.OWNED: 1,
	GameData.Terrain.DESERT: 3,
	GameData.Terrain.MOUNTAIN: 2,
	GameData.Terrain.RIVER: 1,
	GameData.Terrain.RAILWAY: 1,
	GameData.Terrain.ENEMY: 3,
}

const PROP_CHANCE := 0.5
const PROP_MIN_SPACING := 0.30

## Přebarvení dlaždic a dekorace do vyprahlé palety.
const TERRAIN_TINT := {
	GameData.Terrain.PRAIRIE: Color(0.80, 0.88, 0.56),
	GameData.Terrain.OWNED: Color(1.00, 0.86, 0.52),
	GameData.Terrain.RIVER: Color(0.78, 0.92, 0.97),
	GameData.Terrain.DESERT: Color(1.08, 0.76, 0.48),
	GameData.Terrain.MOUNTAIN: Color(0.82, 0.82, 0.90),
	GameData.Terrain.ENEMY: Color(0.90, 0.80, 0.76),
	GameData.Terrain.RAILWAY: Color(0.98, 0.90, 0.76),
	GameData.Terrain.TOWN: Color(1.0, 0.94, 0.82),
	GameData.Terrain.MINE: Color(0.96, 0.90, 0.80),
	GameData.Terrain.OCEAN: Color(0.48, 0.68, 0.88),
}

static var _tint_cache: Dictionary = {}

const FOG_COLOR := Color(0.18, 0.17, 0.19)
const OWNED_RING_COLOR := Color(0.85, 0.70, 0.32)
const ENEMY_RING_COLOR := Color(0.86, 0.14, 0.11)

const _EDGE_ANGLES_DEG := [0.0, -60.0, -120.0, 180.0, 120.0, 60.0]

static var _owned_border_material: StandardMaterial3D
static var _enemy_border_material: StandardMaterial3D
static var _owned_glow_material: StandardMaterial3D
static var _enemy_glow_material: StandardMaterial3D
static var _border_box: BoxMesh
static var _border_cylinder: CylinderMesh
static var _border_glow_cylinder: CylinderMesh

static var _cached_railway_cells: Array[Vector2i] = []
static var _cached_railway_dict: Dictionary = {}
static var _cached_river_cells: Array[Vector2i] = []
static var _cached_river_dict: Dictionary = {}

## Etapa 1c výkon: pro každý TileType zjištěno jednou, jestli jeho scéna má
## jedinou MeshInstance3D — takové jde bezpečně vsadit do MultiMesh. Scény
## s víc kusy (různé lokální transformace) by MultiMesh rozbil; ty se dál
## kreslí po jedné (fallback, žádná vizuální regrese, jen bez zrychlení).
static var _fog_batch_cache: Dictionary = {}  # TileType -> {mesh, xform} nebo null
static var _fog_mesh_cache: Dictionary = {}  # TileType -> Mesh (zamlžená barva) nebo null


const AmbientCritterScript = preload("res://scripts/world/ambient_critter.gd")
const AmbientVillagerScript = preload("res://scripts/world/ambient_villager.gd")


# --- Network generators ------------------------------------------------------

static func railway_cells() -> Array[Vector2i]:
	if not _cached_railway_cells.is_empty():
		return _cached_railway_cells

	var cells := _compute_railway_cells()

	_cached_railway_cells = cells
	_cached_railway_dict.clear()
	for c in cells:
		_cached_railway_dict[c] = true
	return _cached_railway_cells


static func river_cells() -> Array[Vector2i]:
	if not _cached_river_cells.is_empty():
		return _cached_river_cells

	var cells := _compute_river_cells()

	_cached_river_cells = cells
	_cached_river_dict.clear()
	for c in cells:
		_cached_river_dict[c] = true

	# Meandr: dlaždice u dlaždice se řeka příležitostně rozšíří na 2 pole.
	# Rozšíření jde jen do slovníku (vykreslení), ne do pořadové cesty
	# (ta musí zůstat souvislý řetězec sousedních hexů pro connectivity_test).
	for c in cells:
		if _noise(c, 5501) >= RIVER_WIDEN_CHANCE:
			continue
		var pick := int(_noise(c, 5502) * 6.0) % 6
		var extra: Vector2i = c + HexGrid.NEIGHBOR_DIRS[pick]
		if extra == TOWN_CELL:
			continue
		_cached_river_dict[extra] = true

	return _cached_river_cells


## Deterministický vážený random walk z `start` směrem k `target`: v každém
## kroku oboduje 5 nezpětných směrů (jak moc přiblíží k cíli, bonus za
## pokračování rovně vážený `straight_bias`, penalizaci za `avoid`, a šumový
## člen z `_noise()`), a vybere nejlépe obodovaný. Žádná živá RNG — stejné
## volání dá vždy stejnou cestu.
static func _weighted_walk(start: Vector2i, target: Vector2i, max_steps: int,
		straight_bias: float, avoid: Vector2i, salt_base: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	var current := start
	var last_dir := -1

	for step in range(max_steps):
		if current == target:
			break

		var best_idx := -1
		var best_score := -INF
		for i in HexGrid.NEIGHBOR_DIRS.size():
			if last_dir != -1 and i == (last_dir + 3) % 6:
				continue
			var dir: Vector2i = HexGrid.NEIGHBOR_DIRS[i]
			var candidate := current + dir
			var progress := float(HexGrid.distance(current, target) - HexGrid.distance(candidate, target))
			var straight := straight_bias if i == last_dir else 0.0
			var avoid_penalty := -5.0 if candidate == avoid else 0.0
			var noise_val := _noise(candidate, salt_base + step * 37 + i)
			var score := progress * 1.4 + straight + avoid_penalty + (noise_val - 0.5) * 1.6
			if score > best_score:
				best_score = score
				best_idx = i

		last_dir = best_idx
		current += HexGrid.NEIGHBOR_DIRS[best_idx]
		cells.append(current)

	return cells


## Čistý (necachovaný) výpočet — oddělený od railway_cells(), aby testy mohly
## zavolat dvakrát a ověřit, že je deterministický samotný algoritmus, ne jen
## že statická cache vrací tutéž referenci.
static func _compute_railway_cells() -> Array[Vector2i]:
	var no_avoid := Vector2i(99999, 99999)
	var west := _weighted_walk(TOWN_CELL, RAILWAY_WEST_TARGET, RAILWAY_REACH,
		RAILWAY_STRAIGHT_BIAS, no_avoid, 4001)
	var east := _weighted_walk(TOWN_CELL, RAILWAY_EAST_TARGET, RAILWAY_REACH,
		RAILWAY_STRAIGHT_BIAS, no_avoid, 4101)

	var cells: Array[Vector2i] = []
	for i in range(west.size() - 1, 0, -1):
		cells.append(west[i])
	cells.append(TOWN_CELL)
	for i in range(1, east.size()):
		cells.append(east[i])
	return cells


static func _compute_river_cells() -> Array[Vector2i]:
	return _weighted_walk(RIVER_NORTH_TARGET, RIVER_SOUTH_TARGET, RIVER_REACH,
		RIVER_STRAIGHT_BIAS, TOWN_CELL, 5001)


static func connectivity_mask(cell: Vector2i, network: Dictionary) -> int:
	var mask := 0
	for i in HexGrid.NEIGHBOR_DIRS.size():
		var n: Vector2i = cell + HexGrid.NEIGHBOR_DIRS[i]
		if network.has(n):
			mask |= (1 << i)
	return mask


static func connectivity_config(terrain: GameData.Terrain, mask: int) -> Dictionary:
	var is_rail := (terrain == GameData.Terrain.RAILWAY)
	if mask == 0:
		return {
			"type": TileCatalog.TileType.ROAD if is_rail else TileCatalog.TileType.RIVER_STRAIGHT,
			"yaw": 90.0,
		}

	# Count bits
	var bits: Array[int] = []
	for i in range(6):
		if (mask & (1 << i)) != 0:
			bits.append(i)

	if bits.size() == 1:
		var dir := bits[0]
		return {
			"type": TileCatalog.TileType.ROAD_START if is_rail else TileCatalog.TileType.RIVER_START,
			"yaw": _EDGE_ANGLES_DEG[dir] + 90.0,
		}

	if bits.size() == 2:
		var a := bits[0]
		var b := bits[1]
		var delta := (b - a) % 6

		if delta == 3:
			# Straight opposite line
			return {
				"type": TileCatalog.TileType.ROAD if is_rail else TileCatalog.TileType.RIVER_STRAIGHT,
				"yaw": _EDGE_ANGLES_DEG[a] + 90.0,
			}
		elif delta == 2 or delta == 4:
			# Wide corner (120 degrees)
			var intermediate_idx := (a + 1) % 6 if delta == 2 else (b + 1) % 6
			return {
				"type": TileCatalog.TileType.ROAD_CORNER if is_rail else TileCatalog.TileType.RIVER_CORNER,
				"yaw": _EDGE_ANGLES_DEG[intermediate_idx] + 90.0,
			}
		elif delta == 1 or delta == 5:
			# Sharp corner (60 degrees)
			var base_dir := a if delta == 1 else b
			return {
				"type": TileCatalog.TileType.ROAD_CORNER_SHARP if is_rail else TileCatalog.TileType.RIVER_CORNER_SHARP,
				"yaw": _EDGE_ANGLES_DEG[base_dir] + 60.0,
			}

	# 3+ connections: crossing
	return {
		"type": TileCatalog.TileType.ROAD_CROSSING if is_rail else TileCatalog.TileType.RIVER_STRAIGHT,
		"yaw": 0.0,
	}


# --- Radial warp & Terrain rules ---------------------------------------------

static func _radial_warp_radius(angle: float, base_r: float, amp: float, lobes: int = 6, seed_val: int = 1872) -> float:
	var a1 := sin(angle * float(lobes) + float(seed_val) * 0.1)
	var a2 := cos(angle * float(maxi(lobes / 2, 1)) + float(seed_val) * 0.37)
	var a3 := sin(angle * 2.0 + float(seed_val) * 0.73)
	var warp := (a1 * 0.5 + a2 * 0.3 + a3 * 0.2)
	return base_r + amp * warp


static func _is_ocean(cell: Vector2i) -> bool:
	var dist := HexGrid.distance(cell, TOWN_CELL)
	if dist >= MAP_RADIUS:
		return true
	var pos := HexGrid.axial_to_world(cell.x, cell.y)
	var angle := atan2(pos.z, pos.x)
	var island_r := _radial_warp_radius(angle, ISLAND_RADIUS_BASE, ISLAND_RADIUS_AMP, 7, 42)
	return float(dist) > island_r


static func _is_owned(cell: Vector2i) -> bool:
	var dist := HexGrid.distance(cell, TOWN_CELL)
	if dist <= OWNED_RADIUS_CORE:
		return true
	var pos := HexGrid.axial_to_world(cell.x, cell.y)
	var angle := atan2(pos.z, pos.x)
	var r := _radial_warp_radius(angle, OWNED_RADIUS_BASE, 1.2, 5, 87)
	return float(dist) <= r


## Hand-authored layout of the Dustfall island.
static func base_terrain(cell: Vector2i) -> GameData.Terrain:
	if cell == TOWN_CELL:
		return GameData.Terrain.TOWN

	if _is_ocean(cell):
		return GameData.Terrain.OCEAN

	if MINE_CELLS.has(cell):
		return GameData.Terrain.MINE

	# Check railway & river
	if _cached_railway_dict.is_empty():
		railway_cells()
	if _cached_railway_dict.has(cell):
		return GameData.Terrain.RAILWAY

	if _cached_river_dict.is_empty():
		river_cells()
	if _cached_river_dict.has(cell):
		return GameData.Terrain.RIVER

	# Northern rim: mountain range
	if cell.y <= -4 or (cell.y <= -3 and (cell.x <= -2 or cell.x >= 2)):
		return GameData.Terrain.MOUNTAIN

	# Harlan-Voss holds the southern and south-eastern approaches
	if (cell.y >= 3 and cell.x >= -1) or (cell.y >= 4 and cell.x >= -4):
		return GameData.Terrain.ENEMY

	# South-western desert basin
	if (cell.x <= -2 and cell.y >= 1) or (cell.x <= -4 and cell.y >= -1):
		return GameData.Terrain.DESERT

	# Eastern spur of the range
	if cell.x >= 5 and cell.y >= 1:
		return GameData.Terrain.MOUNTAIN

	if _is_owned(cell):
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

	if _cached_railway_dict.is_empty():
		railway_cells()
	if _cached_river_dict.is_empty():
		river_cells()

	# Zamlžené dlaždice tvoří naprostou většinu z 1387 buněk (obvykle přes
	# 1000 na MAP_RADIUS 21) — instancovat je po jedné (měřeno: přes 80 ms na
	# jedno render() volání, tedy po každé akci hráče) bylo neúnosné. Sbírají
	# se proto po výsledném typu meshe a vykreslí naráz přes jeden
	# MultiMeshInstance3D na typ — méně uzlů, žádné opakované instantiate().
	var fog_batches: Dictionary = {}  # TileCatalog.TileType -> Array[Transform3D]

	for cell in gs.tiles:
		var terrain: GameData.Terrain = gs.tiles[cell]
		var structure := _structure_scene(gs, cell)
		var position := HexGrid.axial_to_world(cell.x, cell.y) * WORLD_SCALE

		if structure == null:
			var tile: Node3D
			var yaw := 0.0

			if terrain == GameData.Terrain.FOG:
				# Etapa 1c: Mlha ukazuje siluety terénu pod sebou v tmavém odstínu
				var hidden_terrain: GameData.Terrain = gs.hidden_tiles.get(cell, GameData.Terrain.PRAIRIE)
				var mesh_type: TileCatalog.TileType
				if hidden_terrain == GameData.Terrain.RAILWAY:
					var mask := connectivity_mask(cell, _cached_railway_dict)
					var cfg := connectivity_config(hidden_terrain, mask)
					mesh_type = cfg["type"]
					yaw = cfg["yaw"]
				elif hidden_terrain == GameData.Terrain.RIVER:
					var mask := connectivity_mask(cell, _cached_river_dict)
					var cfg := connectivity_config(hidden_terrain, mask)
					mesh_type = cfg["type"]
					yaw = cfg["yaw"]
				else:
					mesh_type = _mesh_for(cell, hidden_terrain)

				var fog_xform := Transform3D(
					Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * WORLD_SCALE),
					position
				)
				if not fog_batches.has(mesh_type):
					fog_batches[mesh_type] = []
				(fog_batches[mesh_type] as Array).append(fog_xform)
			else:
				var mesh_type: TileCatalog.TileType
				if terrain == GameData.Terrain.RAILWAY:
					var mask := connectivity_mask(cell, _cached_railway_dict)
					var cfg := connectivity_config(terrain, mask)
					mesh_type = cfg["type"]
					yaw = cfg["yaw"]
				elif terrain == GameData.Terrain.RIVER:
					var mask := connectivity_mask(cell, _cached_river_dict)
					var cfg := connectivity_config(terrain, mask)
					mesh_type = cfg["type"]
					yaw = cfg["yaw"]
				else:
					mesh_type = _mesh_for(cell, terrain)

				tile = TileCatalog.terrain_scene(mesh_type).instantiate()
				tile.position = position
				tile.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
				tile.rotation.y = deg_to_rad(yaw)
				terrain_root.add_child(tile)

				if TERRAIN_TINT.has(terrain):
					_tint_surfaces(tile, TERRAIN_TINT[terrain])
				_scatter_props(gs, cell, terrain, prop_root)

				# Ambient critters (wildlife) on revealed land
				if (terrain == GameData.Terrain.PRAIRIE or terrain == GameData.Terrain.DESERT) \
						and _noise(cell, 149) < 0.08:
					var critter: Node3D = AmbientCritterScript.new()
					var jitter := Vector3(
						(_noise(cell, 157) - 0.5) * 0.4 * WORLD_SCALE,
						TileCatalog.TILE_TOP_Y * WORLD_SCALE,
						(_noise(cell, 163) - 0.5) * 0.4 * WORLD_SCALE
					)
					critter.position = position + jitter
					critter.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
					critter.setup(int(_noise(cell, 173) * 1000.0))
					prop_root.add_child(critter)

				# Ambient villagers (settlers) on owned land only
				if terrain == GameData.Terrain.OWNED and _noise(cell, 181) < 0.05:
					var villager: Node3D = AmbientVillagerScript.new()
					var villager_jitter := Vector3(
						(_noise(cell, 191) - 0.5) * 0.4 * WORLD_SCALE,
						TileCatalog.TILE_TOP_Y * WORLD_SCALE,
						(_noise(cell, 193) - 0.5) * 0.4 * WORLD_SCALE
					)
					villager.position = position + villager_jitter
					villager.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
					villager.setup(int(_noise(cell, 197) * 1000.0))
					prop_root.add_child(villager)
		else:
			var built := structure.instantiate()
			built.position = position
			built.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
			if TERRAIN_TINT.has(terrain):
				_tint_surfaces(built, TERRAIN_TINT[terrain])
			structure_root.add_child(built)
			if gs.is_ai_territory(cell):
				_scatter_props(gs, cell, terrain, prop_root)

	_render_fog_batches(fog_batches, terrain_root)
	_add_territory_borders(gs, overlay_root)


static func _structure_scene(gs, cell: Vector2i) -> PackedScene:
	var level: int = gs.settlement_at(cell)
	if level > 0:
		return TileCatalog.settlement_scene(level)

	if int(gs.ai_settlements.get(cell, 0)) > 0:
		return TileCatalog.terrain_scene(TileCatalog.TileType.ENEMY_CAMP)

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


static func _scatter_props(gs, cell: Vector2i, terrain: GameData.Terrain, parent: Node3D) -> void:
	var choices: Array = _prop_choices(gs, cell, terrain)
	if choices.is_empty():
		return

	var density: int = PROP_DENSITY.get(terrain, 1)
	var placed: Array[Vector2] = []
	for slot in density:
		var salt := slot * 100
		if _noise(cell, 23 + salt) > PROP_CHANCE:
			continue

		var index := int(_noise(cell, 31 + salt) * float(choices.size())) % choices.size()
		var scene := TileCatalog.prop_scene(String(choices[index]))
		if scene == null:
			continue

		var base := HexGrid.axial_to_world(cell.x, cell.y) * WORLD_SCALE
		var jitter := Vector3(
			(_noise(cell, 41 + salt) - 0.5) * 0.62 * WORLD_SCALE,
			0.0,
			(_noise(cell, 53 + salt) - 0.5) * 0.62 * WORLD_SCALE
		)
		var flat := Vector2(jitter.x, jitter.z)
		var too_close := false
		for existing in placed:
			if existing.distance_to(flat) < (PROP_MIN_SPACING * WORLD_SCALE):
				too_close = true
				break
		if too_close:
			continue
		placed.append(flat)

		var prop := scene.instantiate()
		prop.position = base + jitter + Vector3(0.0, TileCatalog.TILE_TOP_Y * WORLD_SCALE, 0.0)
		prop.rotation.y = _noise(cell, 67 + salt) * TAU
		var scale := TileCatalog.prop_scale(String(choices[index])) \
			* (0.85 + _noise(cell, 79 + salt) * 0.34) * WORLD_SCALE
		prop.scale = Vector3(scale, scale, scale)
		if TERRAIN_TINT.has(terrain):
			_tint_surfaces(prop, TERRAIN_TINT[terrain])
		parent.add_child(prop)


static func _prop_choices(gs, cell: Vector2i, terrain: GameData.Terrain) -> Array:
	if terrain != GameData.Terrain.ENEMY:
		return TERRAIN_PROPS.get(terrain, [])
	if int(gs.ai_settlements.get(cell, 0)) > 0:
		return ENEMY_BASE_PROPS
	return TERRAIN_PROPS.get(terrain, [])


static func _tint_surfaces(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface)
			if source == null:
				continue
			var key := "%d|%s|%s" % [source.get_instance_id(), color, surface]
			if not _tint_cache.has(key):
				var tinted := source.duplicate() as BaseMaterial3D
				if tinted == null:
					continue
				tinted.albedo_color = tinted.albedo_color * color
				_tint_cache[key] = tinted
			node.set_surface_override_material(surface, _tint_cache[key])
	for child in node.get_children():
		_tint_surfaces(child, color)


## Vykreslí nahromaděné zamlžené dlaždice: jeden MultiMeshInstance3D na typ
## meshe místo instancování scény pro každou buňku zvlášť (viz komentář
## u fog_batches v render()). Typy, jejichž scéna má víc než jednu
## MeshInstance3D, jde do MultiMesh vsadit jen se ztrátou (jedna sdílená
## transformace na celou instanci) — ty se dál kreslí postaru, po jedné.
static func _render_fog_batches(fog_batches: Dictionary, terrain_root: Node3D) -> void:
	for mesh_type in fog_batches:
		var transforms: Array = fog_batches[mesh_type]
		var tinted_mesh: Mesh = _fog_tinted_mesh(mesh_type)

		if tinted_mesh == null:
			for xform in transforms:
				var tile: Node3D = TileCatalog.terrain_scene(mesh_type).instantiate()
				tile.transform = xform
				terrain_root.add_child(tile)
				_tint_surfaces(tile, FOG_COLOR)
			continue

		# MultiMesh kreslí surový Mesh resource, ne uzel scény — lokální
		# transformace MeshInstance3D vůči kořeni scény (u některých modelů
		# nenulová) se proto musí přičíst ručně, jinak by mesh nesel offset,
		# který root-transform v jednoduchém instantiate() dřív zdědil zdarma.
		var local_xform: Transform3D = _fog_batch_info(mesh_type)["xform"]

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tinted_mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, (transforms[i] as Transform3D) * local_xform)

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		terrain_root.add_child(mmi)


## Zjistí (a cachuje), jestli scéna daného typu má přesně jednu
## MeshInstance3D — pokud ano, vrátí její mesh + lokální transformaci vůči
## kořeni scény (víceřešené modely obvykle nemají mesh přímo v kořeni,
## ale o pár uzlů níž).
static func _fog_batch_info(mesh_type: TileCatalog.TileType):
	if _fog_batch_cache.has(mesh_type):
		return _fog_batch_cache[mesh_type]

	var probe := TileCatalog.terrain_scene(mesh_type).instantiate()
	var info = null
	if _count_mesh_instances(probe) == 1:
		var mi := _find_mesh_instance(probe)
		info = {"mesh": mi.mesh, "xform": mi.transform}
	probe.free()

	_fog_batch_cache[mesh_type] = info
	return info


static func _count_mesh_instances(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and node.mesh != null:
		count += 1
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


## Zamlžená (tmavě probarvená) verze meshe daného typu, sdílená přes všechny
## instance v jednom MultiMesh — stejný princip jako _tint_cache, jen na
## úrovni celého Mesh resource místo jednotlivého uzlu. Vrací null pro typy,
## co nejde bezpečně vsadit do MultiMesh (viz _fog_batch_info).
static func _fog_tinted_mesh(mesh_type: TileCatalog.TileType) -> Mesh:
	if _fog_mesh_cache.has(mesh_type):
		return _fog_mesh_cache[mesh_type]

	var result: Mesh = null
	var info = _fog_batch_info(mesh_type)
	if info != null:
		var source_mesh: Mesh = info["mesh"]
		var tinted := source_mesh.duplicate() as ArrayMesh
		if tinted != null:
			for surface in tinted.get_surface_count():
				var source_mat := tinted.surface_get_material(surface)
				if source_mat == null:
					continue
				var tinted_mat := source_mat.duplicate() as BaseMaterial3D
				if tinted_mat == null:
					continue
				tinted_mat.albedo_color = tinted_mat.albedo_color * FOG_COLOR
				tinted.surface_set_material(surface, tinted_mat)
			result = tinted

	_fog_mesh_cache[mesh_type] = result
	return result


# --- Borders -----------------------------------------------------------------

const BORDER_THICKNESS := 0.09
const BORDER_HEIGHT := 0.07

## Druhá, širší a průhlednější vrstva vedle plné linie — měkká záře navenek
## (princip Civilization), stejný unshaded/no_depth_test/emisní materiál jako
## plná linie, jen s jinými čísly.
const BORDER_GLOW_THICKNESS := 0.24
const BORDER_GLOW_HEIGHT := 0.045
const BORDER_GLOW_ALPHA := 0.24

static func _add_territory_borders(gs, overlay_root: Node3D) -> void:
	var box := _border_mesh()
	var joint_cyl := _border_joint_mesh()
	var glow_joint_cyl := _border_glow_joint_mesh()
	var owned_material := _owned_material()
	var enemy_material := _enemy_material()
	var owned_glow := _owned_glow_material_get()
	var enemy_glow := _enemy_glow_material_get()

	for c in gs.tiles:
		var cell: Vector2i = c
		var terrain: GameData.Terrain = gs.tiles[cell]
		if terrain == GameData.Terrain.FOG:
			continue

		var owned: bool = gs.is_owned(cell)
		var enemy: bool = gs.is_ai_territory(cell)
		if not owned and not enemy:
			continue

		var material := owned_material if owned else enemy_material
		var glow_material := owned_glow if owned else enemy_glow
		var center := HexGrid.axial_to_world(cell.x, cell.y) * WORLD_SCALE
		var height := (TileCatalog.rim_height(TERRAIN_MESH[terrain]) + 0.015) * WORLD_SCALE

		for i in HexGrid.NEIGHBOR_DIRS.size():
			var dir: Vector2i = HexGrid.NEIGHBOR_DIRS[i]
			var neighbor: Vector2i = cell + dir
			var same_side: bool = (owned and gs.is_owned(neighbor)) \
				or (enemy and gs.is_ai_territory(neighbor))
			if same_side:
				continue
			var angle: float = _EDGE_ANGLES_DEG[i]
			var corner_a := _hex_corner(center, angle - 30.0)
			var corner_b := _hex_corner(center, angle + 30.0)

			overlay_root.add_child(
				_border_segment(corner_a, corner_b, height, BORDER_THICKNESS, BORDER_HEIGHT, box, material)
			)
			overlay_root.add_child(
				_border_segment(corner_a, corner_b, height, BORDER_GLOW_THICKNESS, BORDER_GLOW_HEIGHT, box, glow_material)
			)

			# Corner joint cap
			var joint_a := MeshInstance3D.new()
			joint_a.mesh = joint_cyl
			joint_a.material_override = material
			joint_a.position = corner_a + Vector3(0.0, height, 0.0)
			overlay_root.add_child(joint_a)

			var glow_joint_a := MeshInstance3D.new()
			glow_joint_a.mesh = glow_joint_cyl
			glow_joint_a.material_override = glow_material
			glow_joint_a.position = corner_a + Vector3(0.0, height, 0.0)
			overlay_root.add_child(glow_joint_a)


static func _hex_corner(center: Vector3, angle_deg: float) -> Vector3:
	var rad := deg_to_rad(angle_deg)
	return center + Vector3(cos(rad), 0.0, sin(rad)) * (HexGrid.HEX_RADIUS * WORLD_SCALE)


static func _border_segment(corner_a: Vector3, corner_b: Vector3, height: float,
		thickness: float, wall_height: float,
		box: BoxMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var along := corner_b - corner_a
	var length := along.length()
	var x_axis := along / length
	var z_axis := x_axis.cross(Vector3.UP).normalized()

	var marker := MeshInstance3D.new()
	marker.mesh = box
	marker.material_override = material
	marker.transform = Transform3D(
		Basis(x_axis * length, Vector3.UP * (wall_height * WORLD_SCALE), z_axis * (thickness * WORLD_SCALE)),
		(corner_a + corner_b) * 0.5 + Vector3(0.0, height, 0.0)
	)
	return marker


static func _border_mesh() -> BoxMesh:
	if _border_box == null:
		_border_box = BoxMesh.new()
		_border_box.size = Vector3.ONE
	return _border_box


static func _border_joint_mesh() -> CylinderMesh:
	if _border_cylinder == null:
		_border_cylinder = CylinderMesh.new()
		_border_cylinder.top_radius = (BORDER_THICKNESS * 0.55 * WORLD_SCALE)
		_border_cylinder.bottom_radius = (BORDER_THICKNESS * 0.55 * WORLD_SCALE)
		_border_cylinder.height = (BORDER_HEIGHT * WORLD_SCALE)
		_border_cylinder.radial_segments = 8
	return _border_cylinder


static func _border_glow_joint_mesh() -> CylinderMesh:
	if _border_glow_cylinder == null:
		_border_glow_cylinder = CylinderMesh.new()
		_border_glow_cylinder.top_radius = (BORDER_GLOW_THICKNESS * 0.55 * WORLD_SCALE)
		_border_glow_cylinder.bottom_radius = (BORDER_GLOW_THICKNESS * 0.55 * WORLD_SCALE)
		_border_glow_cylinder.height = (BORDER_GLOW_HEIGHT * WORLD_SCALE)
		_border_glow_cylinder.radial_segments = 8
	return _border_glow_cylinder


static func _owned_material() -> StandardMaterial3D:
	if _owned_border_material == null:
		_owned_border_material = _border_material(OWNED_RING_COLOR, 0.6, 0.92)
	return _owned_border_material


static func _enemy_material() -> StandardMaterial3D:
	if _enemy_border_material == null:
		_enemy_border_material = _border_material(ENEMY_RING_COLOR, 0.95, 0.92)
	return _enemy_border_material


static func _owned_glow_material_get() -> StandardMaterial3D:
	if _owned_glow_material == null:
		_owned_glow_material = _border_material(OWNED_RING_COLOR, 0.35, BORDER_GLOW_ALPHA)
	return _owned_glow_material


static func _enemy_glow_material_get() -> StandardMaterial3D:
	if _enemy_glow_material == null:
		_enemy_glow_material = _border_material(ENEMY_RING_COLOR, 0.55, BORDER_GLOW_ALPHA)
	return _enemy_glow_material


static func _border_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


# --- Helpers -----------------------------------------------------------------

static func _ensure_child(parent: Node3D, name: String) -> Node3D:
	var existing := parent.get_node_or_null(NodePath(name))
	if existing != null:
		return existing
	var node := Node3D.new()
	node.name = name
	parent.add_child(node)
	return node


static func _noise(cell: Vector2i, salt: int) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
