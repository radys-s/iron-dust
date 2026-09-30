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
		"bush_small", "bush", "grass_tuft", "grass_tuft", "grass_large",
		"grass_leafs", "grass_leafs_large", "weed_short",
		"rock_smallB", "rock_smallC", "rock_flatA", "stump_old", "tree_thin",
	],
	GameData.Terrain.OWNED: [
		"grass_tuft", "grass_tuft", "grass_leafs", "grass_large", "weed_short",
		"rock_flatB", "crops_rows", "crops_wheat", "crops_corn", "log_stack", "stump_old",
	],
	GameData.Terrain.DESERT: [
		"cactus_tall", "cactus_short", "rock_smallA", "rock_smallE",
		"rock_flatA", "stump_old", "weed_tall", "rock_smallG",
	],
	GameData.Terrain.MOUNTAIN: [
		"rock_largeA", "rock_largeB", "rock_largeC", "rock_largeD", "rock_largeE", "rock_largeF",
		"rock_tallA", "rock_tallB", "rock_tallC", "rock_tallD",
		"tree_pine_tall", "tree_pine_small",
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
	GameData.Terrain.PRAIRIE: 3,
	GameData.Terrain.OWNED: 3,
	GameData.Terrain.DESERT: 3,
	GameData.Terrain.MOUNTAIN: 3,
	GameData.Terrain.RIVER: 1,
	GameData.Terrain.RAILWAY: 1,
	GameData.Terrain.ENEMY: 3,
}

const PROP_CHANCE := 0.5
const PROP_MIN_SPACING := 0.42

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
## Meandrove rozsireni: gameplayove RIVER, ale MIMO connectivity_mask() — jinak
## by je sousedni dilky bralo jako dalsi napojeni (falesne krizovatky).
static var _cached_river_widen: Dictionary = {}

## Etapa 1c výkon: pro každý TileType zjištěno jednou, jestli jeho scéna má
## jedinou MeshInstance3D — takové jde bezpečně vsadit do MultiMesh. Scény
## s víc kusy (různé lokální transformace) by MultiMesh rozbil; ty se dál
## kreslí po jedné (fallback, žádná vizuální regrese, jen bez zrychlení).
static var _fog_batch_cache: Dictionary = {}  # TileType -> {mesh, xform} nebo null
static var _fog_mesh_cache: Dictionary = {}  # TileType -> Mesh (zamlžená barva) nebo null


const AmbientCritterScript = preload("res://scripts/world/ambient_critter.gd")
const AmbientVillagerScript = preload("res://scripts/world/ambient_villager.gd")
const AmbientSheepScript = preload("res://scripts/world/ambient_sheep.gd")

## Mezifáze 2: jeden knoflík na doladění velikosti napříč kritterem,
## vesničanem i ovcí (Tomáš: "velikost o trochu menší, ale to je detail").
const AMBIENT_SCALE_TWEAK := 0.9


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
	_cached_river_widen.clear()
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
		if _cached_river_dict.has(extra):
			continue
		_cached_river_widen[extra] = true

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


## _EDGE_ANGLES_DEG meri uhel v konvenci "+X k +Z" (viz _hex_corner()). Godotova
## rotation.y otaci +X k -Z — presny opak. Kazda hodnota odvozena z
## _EDGE_ANGLES_DEG, ktera jde primo do rotation.y, musi projit touhle negaci,
## jinak sedi jen symetricke (rovne E-Z) dily a vsechno ostatni je pootocene.
static func _world_yaw(edge_angle_deg: float) -> float:
	return -edge_angle_deg


## Offsety natoceni dilu, odvozene z REALNE geometrie .glb (vrcholy u stredu
## hran hexu, viz connectivity_gallery.gd), ne odhadnute. Nativne (yaw 0)
## spojuji: rovny = hrany 0+3, siroka zatacka = 1+3 (osa = hrana 2), ostra
## zatacka = 2+3 (osa mezi nimi), konec = hrana 3. Pricitaji se k uhlu cilove
## hrany (osy) pred negaci v _world_yaw().
const YAW_OFFSET_STRAIGHT := 0.0
const YAW_OFFSET_WIDE := 120.0
const YAW_OFFSET_SHARP := 120.0
const YAW_OFFSET_END := 180.0


## path-*.glb jsou tenke nasivky (vyska 0.025, jen prouzek), ne cele hexy —
## kolej se proto kresli jako nasivka nad zakladovou dlazdici.
const RAIL_BASE_TILE := TileCatalog.TileType.GRASS


static func rail_decal_lift() -> float:
	return TileCatalog.rim_height(RAIL_BASE_TILE) + 0.004


## Krizovatka (3+ napojeni) nema jediny prirozeny smer. Kdyz je mezi napojenymi
## smery protejsi par (rozdil 3), zarovna se s nim stejne jako rovny usek;
## jinak padne na smer nejnizsiho bitu jako na osamoceny konec.
static func _crossing_yaw(bits: Array[int]) -> float:
	for i in bits.size():
		for j in range(i + 1, bits.size()):
			if (bits[j] - bits[i]) % 6 == 3:
				return _world_yaw(_EDGE_ANGLES_DEG[bits[i]] + YAW_OFFSET_STRAIGHT)
	return _world_yaw(_EDGE_ANGLES_DEG[bits[0]] + YAW_OFFSET_STRAIGHT)


static func connectivity_config(terrain: GameData.Terrain, mask: int) -> Dictionary:
	var is_rail := (terrain == GameData.Terrain.RAILWAY)
	if mask == 0:
		return {
			"type": TileCatalog.TileType.ROAD if is_rail else TileCatalog.TileType.RIVER_STRAIGHT,
			"yaw": _world_yaw(YAW_OFFSET_STRAIGHT),
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
			"yaw": _world_yaw(_EDGE_ANGLES_DEG[dir] + YAW_OFFSET_END),
		}

	if bits.size() == 2:
		var a := bits[0]
		var b := bits[1]
		var delta := (b - a) % 6

		if delta == 3:
			# Straight opposite line
			return {
				"type": TileCatalog.TileType.ROAD if is_rail else TileCatalog.TileType.RIVER_STRAIGHT,
				"yaw": _world_yaw(_EDGE_ANGLES_DEG[a] + YAW_OFFSET_STRAIGHT),
			}
		elif delta == 2 or delta == 4:
			# Wide corner (120 degrees)
			var intermediate_idx := (a + 1) % 6 if delta == 2 else (b + 1) % 6
			return {
				"type": TileCatalog.TileType.ROAD_CORNER if is_rail else TileCatalog.TileType.RIVER_CORNER,
				"yaw": _world_yaw(_EDGE_ANGLES_DEG[intermediate_idx] + YAW_OFFSET_WIDE),
			}
		elif delta == 1 or delta == 5:
			# Sharp corner (60 degrees)
			var base_dir := a if delta == 1 else b
			return {
				"type": TileCatalog.TileType.ROAD_CORNER_SHARP if is_rail else TileCatalog.TileType.RIVER_CORNER_SHARP,
				"yaw": _world_yaw(_EDGE_ANGLES_DEG[base_dir] + YAW_OFFSET_SHARP),
			}

	# 3+ connections: crossing — zarovna se s protejsim parem, jinak nejnizsi bit
	return {
		"type": TileCatalog.TileType.ROAD_CROSSING if is_rail else TileCatalog.TileType.RIVER_STRAIGHT,
		"yaw": _crossing_yaw(bits),
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
	if _cached_river_dict.has(cell) or _cached_river_widen.has(cell):
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
					# nasivka by v mlze nechala diru; staci silueta zakladu
					mesh_type = RAIL_BASE_TILE
				elif hidden_terrain == GameData.Terrain.RIVER and _cached_river_widen.has(cell):
					mesh_type = TileCatalog.TileType.WATER
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
				var rail_decal: Dictionary = {}
				if terrain == GameData.Terrain.RAILWAY:
					var mask := connectivity_mask(cell, _cached_railway_dict)
					rail_decal = connectivity_config(terrain, mask)
					mesh_type = RAIL_BASE_TILE
				elif terrain == GameData.Terrain.RIVER and _cached_river_widen.has(cell):
					mesh_type = TileCatalog.TileType.WATER
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
				if not rail_decal.is_empty():
					var decal: Node3D = TileCatalog.terrain_scene(rail_decal["type"]).instantiate()
					decal.position = Vector3(0.0, rail_decal_lift(), 0.0)
					decal.rotation.y = deg_to_rad(rail_decal["yaw"])
					tile.add_child(decal)
				terrain_root.add_child(tile)

				if TERRAIN_TINT.has(terrain):
					_tint_surfaces(tile, TERRAIN_TINT[terrain])
				_scatter_props(gs, cell, terrain, prop_root, mesh_type)

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
					critter.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE) * AMBIENT_SCALE_TWEAK
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
					villager.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE) * AMBIENT_SCALE_TWEAK
					villager.setup(int(_noise(cell, 197) * 1000.0))
					prop_root.add_child(villager)

				# Ambient sheep (real downloaded model) on owned pasture edges —
				# Mezifáze 2 bod 3. TileCatalog.prop_scene("sheep") vrací null,
				# dokud model není stažený a zapsaný do PROP_PATHS, takže tahle
				# větev je do té doby neškodný mrtvý kód.
				if terrain == GameData.Terrain.OWNED and TileCatalog.prop_scene("sheep") != null \
						and _is_owned_pasture_edge(gs, cell) and _noise(cell, 311) < 0.10:
					var sheep: Node3D = AmbientSheepScript.new()
					var sheep_jitter := Vector3(
						(_noise(cell, 317) - 0.5) * 0.5 * WORLD_SCALE,
						TileCatalog.TILE_TOP_Y * WORLD_SCALE,
						(_noise(cell, 331) - 0.5) * 0.5 * WORLD_SCALE
					)
					sheep.position = position + sheep_jitter
					sheep.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE) * AMBIENT_SCALE_TWEAK
					sheep.setup(int(_noise(cell, 337) * 1000.0))
					prop_root.add_child(sheep)
		else:
			var built := structure.instantiate()
			built.position = position
			built.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
			if TERRAIN_TINT.has(terrain):
				_tint_surfaces(built, TERRAIN_TINT[terrain])
			structure_root.add_child(built)
			if gs.is_ai_territory(cell):
				_scatter_props(gs, cell, terrain, prop_root, TileCatalog.TileType.ENEMY_CAMP)

	_render_fog_batches(fog_batches, terrain_root)
	_add_territory_borders(gs, overlay_root)
	_add_pasture_fences(gs, prop_root)


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


## Hrubost plošky pro sdílení mesh varianty (v hexech). Menší = jemnější
## mozaika, ale výraznější mřížka na hranici plošky — dolaďuje se vizuálně.
const MESH_VARIANT_BUCKET := 2

## Hrubší, sdílená prostorová buňka místo syrové `cell` — sousedící hexy ve
## stejné plošce dostanou stejnou mesh variantu, takže vznikne pár-hexů
## velká skvrna terénu místo šumu na úrovni jednoho hexu (Mezifáze 3, bod 3).
static func _variant_bucket(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori((cell.x + 1) / float(MESH_VARIANT_BUCKET)),  # posun o 1: šev neprochází městem (0,0)
		floori((cell.y + 1) / float(MESH_VARIANT_BUCKET))
	)


static func _mesh_for(cell: Vector2i, terrain: GameData.Terrain) -> TileCatalog.TileType:
	if not TERRAIN_MESH_VARIANTS.has(terrain):
		return TERRAIN_MESH[terrain]
	var options: Array = TERRAIN_MESH_VARIANTS[terrain]
	return options[int(_noise(_variant_bucket(cell), 11) * float(options.size())) % options.size()]


static func _scatter_props(gs, cell: Vector2i, terrain: GameData.Terrain, parent: Node3D,
		mesh_type: TileCatalog.TileType) -> void:
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
		if _near_pasture_fence(gs, cell, flat / WORLD_SCALE):
			continue
		var too_close := false
		for existing in placed:
			if existing.distance_to(flat) < (PROP_MIN_SPACING * WORLD_SCALE):
				too_close = true
				break
		if too_close:
			continue
		placed.append(flat)

		var prop := scene.instantiate()
		prop.position = base + jitter + Vector3(0.0, TileCatalog.surface_height(mesh_type, flat / WORLD_SCALE) * WORLD_SCALE, 0.0)
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


## True, pokud vlastněná buňka sousedí s aspoň jednou nevlastněnou — okraj
## ranče, kam patří deterministický plot (_add_pasture_fences) a ovce.
static func _is_owned_pasture_edge(gs, cell: Vector2i) -> bool:
	for dir in HexGrid.NEIGHBOR_DIRS:
		if not gs.is_owned(cell + dir):
			return true
	return false


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

## Mezifáze 2: sporná hrana (vlastněná sousedí s nepřátelskou) se dřív
## kreslila dvakrát — jednou z každé strany, stejná geometrie, no_depth_test
## bez tiebreakeru → problikávání. Teď ji kreslí jen vlastněná strana, jako
## přerušovanou zlato-červenou čáru.
const CONTESTED_DASH_COUNT := 4

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
			var neighbor_owned: bool = gs.is_owned(neighbor)
			var neighbor_enemy: bool = gs.is_ai_territory(neighbor)
			if enemy and neighbor_owned:
				continue  # sporná hrana: nakreslí ji jen vlastněná strana níže

			var angle: float = _EDGE_ANGLES_DEG[i]
			var corner_a := _hex_corner(center, angle - 30.0)
			var corner_b := _hex_corner(center, angle + 30.0)

			if owned and neighbor_enemy:
				_add_contested_edge(overlay_root, corner_a, corner_b, height, box,
					owned_material, enemy_material, owned_glow, enemy_glow)
				continue

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


## Sporná hrana (vlastněná vs. nepřátelská): místo jedné plné barvy
## CONTESTED_DASH_COUNT střídavých segmentů zlato/červená. Rohový joint
## se u sporné hrany nekreslí (zjednodušení — sousední nesporné hrany
## stejného hexu ho na sdíleném rohu stejně dodají).
static func _add_contested_edge(overlay_root: Node3D, corner_a: Vector3, corner_b: Vector3,
		height: float, box: BoxMesh,
		owned_material: StandardMaterial3D, enemy_material: StandardMaterial3D,
		owned_glow: StandardMaterial3D, enemy_glow: StandardMaterial3D) -> void:
	for d in CONTESTED_DASH_COUNT:
		var t0 := float(d) / float(CONTESTED_DASH_COUNT)
		var t1 := float(d + 1) / float(CONTESTED_DASH_COUNT)
		var dash_a := corner_a.lerp(corner_b, t0)
		var dash_b := corner_a.lerp(corner_b, t1)
		var mat := owned_material if d % 2 == 0 else enemy_material
		var glow := owned_glow if d % 2 == 0 else enemy_glow
		overlay_root.add_child(
			_border_segment(dash_a, dash_b, height, BORDER_THICKNESS, BORDER_HEIGHT, box, mat)
		)
		overlay_root.add_child(
			_border_segment(dash_a, dash_b, height, BORDER_GLOW_THICKNESS, BORDER_GLOW_HEIGHT, box, glow)
		)


static func _hex_corner(center: Vector3, angle_deg: float) -> Vector3:
	var rad := deg_to_rad(angle_deg)
	return center + Vector3(cos(rad), 0.0, sin(rad)) * (HexGrid.HEX_RADIUS * WORLD_SCALE)


# --- Pasture fences (Mezifáze 3) ----------------------------------------------

## Rovné kusy plotu na pastvinové hraně — pár vizuálně blízkých variant (obě
## plaňkové, stejná výška), ne jeden model porád dokola.
const PASTURE_FENCE_STRAIGHT := ["fence_simple", "fence_planks"]

## Kus plotu se lehce prodlouží, ať se sousední kusy u sloupku překrývají.
const FENCE_LENGTH_OVERLAP := 1.03
const FENCE_POST_WIDTH := 0.035
const FENCE_POST_HEIGHT := 0.19
## Pás u hranice (hex jednotky), kam _scatter_props() nesází — plot tam stojí.
const FENCE_CLEARANCE := 0.15

## Čistá funkce nad množinou vlastněných buněk (Dictionary buňka -> true):
## projde každou hranu vlastněná -> nevlastněná (stejné vyčíslení jako
## _add_territory_borders) a vrátí {"edges": [{cell, dir, a, b}], "posts":
## {klíč vrcholu: pozice}}. Sloupek stojí na KAŽDÉM unikátním vrcholu hranice,
## bez ohledu na to, která buňka ho přispěla — na rozdíl od dřívějších
## per-buňka rohových bitů tak nechybí na přechodech mezi sousedy.
static func _pasture_boundary(owned: Dictionary) -> Dictionary:
	var edges: Array = []
	var posts: Dictionary = {}
	for c in owned:
		var cell: Vector2i = c
		var center := HexGrid.axial_to_world(cell.x, cell.y) * WORLD_SCALE
		for i in HexGrid.NEIGHBOR_DIRS.size():
			if owned.has(cell + HexGrid.NEIGHBOR_DIRS[i]):
				continue
			var a := _hex_corner(center, _EDGE_ANGLES_DEG[i] - 30.0)
			var b := _hex_corner(center, _EDGE_ANGLES_DEG[i] + 30.0)
			edges.append({"cell": cell, "dir": i, "a": a, "b": b})
			posts[_vertex_key(a)] = a
			posts[_vertex_key(b)] = b
	return {"edges": edges, "posts": posts}


static func _vertex_key(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x * 1000.0), roundi(p.z * 1000.0))


## Deterministický plot na kraji vlastněného území — rovné kusy roztažené na
## celou délku hrany + sloupek na každém vrcholu. Volá se jednou za render(),
## paralelně k _add_territory_borders().
static func _add_pasture_fences(gs, root: Node3D) -> void:
	var owned: Dictionary = {}
	for c in gs.tiles:
		if gs.is_owned(c):
			owned[c] = true

	var boundary := _pasture_boundary(owned)
	for edge in boundary["edges"]:
		var cell: Vector2i = edge["cell"]
		var variant: String = PASTURE_FENCE_STRAIGHT[
			int(_noise(cell, 401 + int(edge["dir"]) * 11) * PASTURE_FENCE_STRAIGHT.size()) % PASTURE_FENCE_STRAIGHT.size()
		]
		_place_fence_edge(root, variant, edge["a"], edge["b"])

	var post_mesh := _fence_post_mesh()
	var post_mat := _fence_post_material()
	var rim := TileCatalog.rim_height(TileCatalog.TileType.GRASS) * WORLD_SCALE
	for key in boundary["posts"]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = post_mat
		post.position = (boundary["posts"][key] as Vector3) + Vector3(0.0, rim + FENCE_POST_HEIGHT * 0.5 - 0.01, 0.0)
		root.add_child(post)


## Nature-kit ploty jsou nakreslené na dlaždici 1x1: kus je dlouhý 1.0 podél X
## a leží u OKRAJE dlaždice (z ~ -0.47), ne ve středu. Bez vycentrování seděl
## plot vedle hrany a generický prop_scale() ho navíc zmenšil na ~59 % délky
## hrany. Tady se kus obalí, vycentruje a roztáhne přesně na hranu a-b.
static func _place_fence_edge(root: Node3D, name: String, a: Vector3, b: Vector3) -> void:
	var scene := TileCatalog.prop_scene(name)
	if scene == null:
		return
	var bounds := TileCatalog.prop_bounds(name)
	var along := b - a
	var length := along.length()
	var yaw := atan2(-along.z, along.x)

	var holder := Node3D.new()
	holder.position = (a + b) * 0.5 + Vector3(0.0, TileCatalog.rim_height(TileCatalog.TileType.GRASS) * WORLD_SCALE, 0.0)
	holder.rotation.y = yaw
	var s := length / maxf(bounds.size.x, 0.001) * FENCE_LENGTH_OVERLAP
	holder.scale = Vector3(s, s, s)

	var fence := scene.instantiate()
	var center := bounds.get_center()
	fence.position = Vector3(-center.x, 0.0, -center.z)
	holder.add_child(fence)
	if TERRAIN_TINT.has(GameData.Terrain.OWNED):
		_tint_surfaces(fence, TERRAIN_TINT[GameData.Terrain.OWNED])
	root.add_child(holder)


## Buňka leží u hranice vlastnictví: vrací True, pokud bod (v hex jednotkách
## od středu buňky) padá do pásu, kde stojí plot — scatter tam nic nesází.
static func _near_pasture_fence(gs, cell: Vector2i, flat: Vector2) -> bool:
	var here: bool = gs.is_owned(cell)
	for i in HexGrid.NEIGHBOR_DIRS.size():
		if gs.is_owned(cell + HexGrid.NEIGHBOR_DIRS[i]) == here:
			continue
		var rad := deg_to_rad(_EDGE_ANGLES_DEG[i])
		var to_edge := 0.5 - flat.dot(Vector2(cos(rad), sin(rad)))
		if to_edge < FENCE_CLEARANCE:
			return true
	return false


static var _fence_post_mesh_cache: BoxMesh
static var _fence_post_material_cache: StandardMaterial3D


static func _fence_post_mesh() -> BoxMesh:
	if _fence_post_mesh_cache == null:
		_fence_post_mesh_cache = BoxMesh.new()
		_fence_post_mesh_cache.size = Vector3(FENCE_POST_WIDTH, FENCE_POST_HEIGHT, FENCE_POST_WIDTH)
	return _fence_post_mesh_cache


static func _fence_post_material() -> StandardMaterial3D:
	if _fence_post_material_cache == null:
		_fence_post_material_cache = StandardMaterial3D.new()
		_fence_post_material_cache.albedo_color = Color(0.42, 0.28, 0.17)
		_fence_post_material_cache.roughness = 0.9
	return _fence_post_material_cache


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
