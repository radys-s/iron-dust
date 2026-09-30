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
	WATER_ROCKS,
	DIRT,
	MINE_SITE,
	ENEMY_CAMP,
	ENEMY_WALL,
	ROAD,
	ROAD_CORNER,
	ROAD_CORNER_SHARP,
	ROAD_START,
	ROAD_END,
	ROAD_CROSSING,
	RIVER_STRAIGHT,
	RIVER_CORNER,
	RIVER_CORNER_SHARP,
	RIVER_START,
	RIVER_END,
	OCEAN,
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
	TileType.WATER_ROCKS: "res://assets/kenney/hexagon-kit/water-rocks.glb",
	TileType.DIRT: "res://assets/kenney/hexagon-kit/dirt.glb",
	TileType.MINE_SITE: "res://assets/kenney/hexagon-kit/building-mine.glb",
	# Harlan-Voss is a railway corporation in 1872, not a medieval castle. Its
	# ground is cleared dirt; what marks it as theirs is the camp scattered on
	# top (plank fence, tents, campfire) plus the red border ring. The old
	# building-walls.glb read as a keep and looked absurd beside pine trees.
	TileType.ENEMY_CAMP: "res://assets/kenney/hexagon-kit/dirt.glb",
	TileType.ENEMY_WALL: "res://assets/kenney/hexagon-kit/dirt-lumber.glb",
	TileType.ROAD: "res://assets/kenney/hexagon-kit/path-straight.glb",
	TileType.ROAD_CORNER: "res://assets/kenney/hexagon-kit/path-corner.glb",
	TileType.ROAD_CORNER_SHARP: "res://assets/kenney/hexagon-kit/path-corner-sharp.glb",
	TileType.ROAD_START: "res://assets/kenney/hexagon-kit/path-start.glb",
	TileType.ROAD_END: "res://assets/kenney/hexagon-kit/path-end.glb",
	TileType.ROAD_CROSSING: "res://assets/kenney/hexagon-kit/path-crossing.glb",
	TileType.RIVER_STRAIGHT: "res://assets/kenney/hexagon-kit/river-straight.glb",
	TileType.RIVER_CORNER: "res://assets/kenney/hexagon-kit/river-corner.glb",
	TileType.RIVER_CORNER_SHARP: "res://assets/kenney/hexagon-kit/river-corner-sharp.glb",
	TileType.RIVER_START: "res://assets/kenney/hexagon-kit/river-start.glb",
	TileType.RIVER_END: "res://assets/kenney/hexagon-kit/river-end.glb",
	TileType.OCEAN: "res://assets/kenney/hexagon-kit/water.glb",
}

## Loose decoration that stacks on top of a terrain hex (unlike building-*.glb,
## which replaces it). Grouped by what the scatter uses them for.
const PROP_PATHS := {
	# Poušť a prérie
	"cactus_short": "res://assets/kenney/nature-kit/cactus_short.glb",
	"cactus_tall": "res://assets/kenney/nature-kit/cactus_tall.glb",
	"bush_small": "res://assets/kenney/nature-kit/plant_bushSmall.glb",
	"bush": "res://assets/kenney/nature-kit/plant_bush.glb",
	"bush_large": "res://assets/kenney/nature-kit/plant_bushLarge.glb",
	"grass_tuft": "res://assets/kenney/nature-kit/grass.glb",
	"grass_large": "res://assets/kenney/nature-kit/grass_large.glb",
	"grass_leafs": "res://assets/kenney/nature-kit/grass_leafs.glb",
	"grass_leafs_large": "res://assets/kenney/nature-kit/grass_leafsLarge.glb",
	"weed_short": "res://assets/kenney/nature-kit/plant_flatShort.glb",
	"weed_tall": "res://assets/kenney/nature-kit/plant_flatTall.glb",

	# Kameny
	"rock_smallA": "res://assets/kenney/nature-kit/rock_smallA.glb",
	"rock_smallB": "res://assets/kenney/nature-kit/rock_smallB.glb",
	"rock_smallC": "res://assets/kenney/nature-kit/rock_smallC.glb",
	"rock_smallD": "res://assets/kenney/nature-kit/rock_smallD.glb",
	"rock_smallE": "res://assets/kenney/nature-kit/rock_smallE.glb",
	"rock_smallF": "res://assets/kenney/nature-kit/rock_smallF.glb",
	"rock_smallG": "res://assets/kenney/nature-kit/rock_smallG.glb",
	"rock_smallH": "res://assets/kenney/nature-kit/rock_smallH.glb",
	"rock_flatA": "res://assets/kenney/nature-kit/rock_smallFlatA.glb",
	"rock_flatB": "res://assets/kenney/nature-kit/rock_smallFlatB.glb",
	"rock_largeA": "res://assets/kenney/nature-kit/rock_largeA.glb",
	"rock_largeB": "res://assets/kenney/nature-kit/rock_largeB.glb",
	"rock_largeC": "res://assets/kenney/nature-kit/rock_largeC.glb",
	"rock_largeD": "res://assets/kenney/nature-kit/rock_largeD.glb",
	"rock_largeE": "res://assets/kenney/nature-kit/rock_largeE.glb",
	"rock_largeF": "res://assets/kenney/nature-kit/rock_largeF.glb",
	"rock_tallA": "res://assets/kenney/nature-kit/rock_tallA.glb",
	"rock_tallB": "res://assets/kenney/nature-kit/rock_tallB.glb",
	"rock_tallC": "res://assets/kenney/nature-kit/rock_tallC.glb",
	"rock_tallD": "res://assets/kenney/nature-kit/rock_tallD.glb",

	# Stromy a pařezy — sušší, řidší druhy, ne bujné listnáče
	"tree_thin": "res://assets/kenney/nature-kit/tree_thin.glb",
	"tree_thin_dark": "res://assets/kenney/nature-kit/tree_thin_dark.glb",
	"tree_plateau": "res://assets/kenney/nature-kit/tree_plateau.glb",
	"tree_plateau_dark": "res://assets/kenney/nature-kit/tree_plateau_dark.glb",
	"tree_blocks": "res://assets/kenney/nature-kit/tree_blocks.glb",
	"tree_pine_tall": "res://assets/kenney/nature-kit/tree_pineTallA.glb",
	"tree_pine_small": "res://assets/kenney/nature-kit/tree_pineSmallA.glb",
	"stump_old": "res://assets/kenney/nature-kit/stump_old.glb",
	"stump_tall": "res://assets/kenney/nature-kit/stump_oldTall.glb",
	"stump_round": "res://assets/kenney/nature-kit/stump_round.glb",
	"log": "res://assets/kenney/nature-kit/log.glb",
	"log_stack": "res://assets/kenney/nature-kit/log_stack.glb",

	# Tábor Harlan-Voss
	"fence_planks": "res://assets/kenney/nature-kit/fence_planks.glb",
	"fence_planks_double": "res://assets/kenney/nature-kit/fence_planksDouble.glb",
	"fence_simple": "res://assets/kenney/nature-kit/fence_simple.glb",
	"fence_high": "res://assets/kenney/nature-kit/fence_simpleHigh.glb",
	"tent_closed": "res://assets/kenney/nature-kit/tent_detailedClosed.glb",
	"tent_open": "res://assets/kenney/nature-kit/tent_detailedOpen.glb",
	"tent_small": "res://assets/kenney/nature-kit/tent_smallClosed.glb",
	"campfire": "res://assets/kenney/nature-kit/campfire_stones.glb",
	"campfire_logs": "res://assets/kenney/nature-kit/campfire_logs.glb",
	"sign": "res://assets/kenney/nature-kit/sign.glb",
	"watchtower": "res://assets/kenney/hexagon-kit/unit-wall-tower.glb",

	# Pole
	"crops_wheat": "res://assets/kenney/nature-kit/crops_wheatStageB.glb",
	"crops_corn": "res://assets/kenney/nature-kit/crops_cornStageC.glb",
	"crops_rows": "res://assets/kenney/nature-kit/crops_dirtDoubleRow.glb",

	# Ohrady na kraji vlastněného území (Mezifáze 2)
	"fence_bend": "res://assets/kenney/nature-kit/fence_bend.glb",
	"fence_bend_center": "res://assets/kenney/nature-kit/fence_bendCenter.glb",
	"fence_corner": "res://assets/kenney/nature-kit/fence_corner.glb",
	"fence_gate": "res://assets/kenney/nature-kit/fence_gate.glb",
	"fence_simple_center": "res://assets/kenney/nature-kit/fence_simpleCenter.glb",
	"fence_simple_diagonal": "res://assets/kenney/nature-kit/fence_simpleDiagonal.glb",
	"fence_simple_diagonal_center": "res://assets/kenney/nature-kit/fence_simpleDiagonalCenter.glb",
	"fence_simple_low": "res://assets/kenney/nature-kit/fence_simpleLow.glb",

	# Zvířata (Mezifáze 3) — Quaternius Farm Animal Pack, CC0
	"sheep": "res://assets/quaternius/farm-animal-pack/Sheep.glb",
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
	TileType.WATER_ROCKS: 0.1,
	TileType.OCEAN: 0.1,
	TileType.ENEMY_CAMP: 0.1,
	TileType.ENEMY_WALL: 0.1,
}

## Kam se má dekorace vejít, v jednotkách světa. Hex má na šířku 1.155, takže
## prop širší než ~0.45 už dlaždici opticky přerůstá.
##
## Proč se to počítá a nevypisuje ručně: nature-kit je authorovaný v úplně
## jiném měřítku než hexagon-kit — `tree_thin` je 1.49 vysoký, `unit-wall-tower`
## jen 0.35. Ručně udržovaná tabulka měřítek by u 60+ modelů byla zdroj chyb
## a každý nový model by se musel doměřovat. Tohle se přizpůsobí samo.
## Etapa 1b: zmenseno (0.45/0.70 -> 0.34/0.54) — propy pusobily proti hexum
## prevelke a spolu s hustsim rozestavenim se prekryvaly. Mensi strop plati
## spolu s PROP_MIN_SPACING v map_builder.gd.
const PROP_MAX_FOOTPRINT := 0.34
const PROP_MAX_HEIGHT := 0.54

## Umělecké odchylky od automatického měřítka, tam kde má model záměrně
## vystupovat (strážní věž) nebo naopak splynout se zemí (koleje polí).
const PROP_SCALE_TWEAKS := {
	"watchtower": 1.35,
	"crops_rows": 1.5,
	"campfire": 1.2,
	"campfire_logs": 1.2,
	"sign": 1.1,
}

static var _cache: Dictionary = {}
static var _prop_scales: Dictionary = {}


static func terrain_scene(type: TileType) -> PackedScene:
	return _load_cached(TERRAIN_PATHS[type])


static func prop_scene(name: String) -> PackedScene:
	if not PROP_PATHS.has(name):
		return null
	return _load_cached(PROP_PATHS[name])


## Měřítko, po kterém se dekorace vejde na hex. Počítá se jednou z reálných
## rozměrů modelu a cachuje — instancovat a měřit při každém překreslení mapy
## by bylo drahé, protože render() běží po každé akci.
static func prop_scale(name: String) -> float:
	if _prop_scales.has(name):
		return _prop_scales[name]

	var scene := prop_scene(name)
	if scene == null:
		_prop_scales[name] = 1.0
		return 1.0

	var probe := scene.instantiate()
	var bounds := _mesh_bounds(probe, AABB())
	probe.free()

	var scale := 1.0
	var footprint := maxf(bounds.size.x, bounds.size.z)
	if footprint > 0.0:
		scale = PROP_MAX_FOOTPRINT / footprint
	if bounds.size.y > 0.0:
		scale = minf(scale, PROP_MAX_HEIGHT / bounds.size.y)
	scale *= float(PROP_SCALE_TWEAKS.get(name, 1.0))

	_prop_scales[name] = scale
	return scale


static var _prop_bounds: Dictionary = {}


## Nativní obálka modelu (bez měřítka), cachovaná — pro věci, co se musí
## vycentrovat/roztáhnout přesně (ploty), ne jen vejít na hex.
static func prop_bounds(name: String) -> AABB:
	if _prop_bounds.has(name):
		return _prop_bounds[name]
	var scene := prop_scene(name)
	var bounds := AABB()
	if scene != null:
		var probe := scene.instantiate()
		bounds = _mesh_bounds(probe, AABB())
		probe.free()
	_prop_bounds[name] = bounds
	return bounds


## Obálka všech meshů ve stromu. Prázdné AABB znamená "ještě nic nenalezeno",
## takže první nalezený mesh obálku založí místo aby ji sloučil s nulou v počátku.
static func _mesh_bounds(node: Node, acc: AABB) -> AABB:
	if node is MeshInstance3D and node.mesh != null:
		var box: AABB = node.mesh.get_aabb()
		acc = box if acc.size == Vector3.ZERO else acc.merge(box)
	for child in node.get_children():
		acc = _mesh_bounds(child, acc)
	return acc


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


## Dlaždice s kopcem/horou/kameny nemají jednu výšku povrchu (hora: 0.2 u
## okraje, 1.09 na vrcholu), takže jediná hodnota v RIM_HEIGHTS by dekoraci
## buď zahrabala, nebo nechala vznášet. Pro ně se výška zjistí z reálného meshe.
const BUMPY_TILES := [
	TileType.GRASS_HILL, TileType.SAND_DESERT, TileType.SAND_ROCKS,
	TileType.STONE_HILL, TileType.STONE_MOUNTAIN, TileType.STONE_ROCKS,
]
const HEIGHT_STEP := 0.05
const HEIGHT_NX := 21  # x od -0.5 do 0.5
const HEIGHT_NZ := 25  # z od -0.6 do 0.6

static var _height_grids: Dictionary = {}


## Výška povrchu dlaždice `type` v bodě `flat` (x, z od středu, v jednotkách
## hexu, bez měřítka). Ploché typy vrací rim_height().
static func surface_height(type: TileType, flat: Vector2) -> float:
	if not BUMPY_TILES.has(type):
		return rim_height(type)
	if not _height_grids.has(type):
		_height_grids[type] = _build_height_grid(type)
	var grid: PackedFloat32Array = _height_grids[type]
	var ix := clampi(roundi((flat.x + 0.5) / HEIGHT_STEP), 0, HEIGHT_NX - 1)
	var iz := clampi(roundi((flat.y + 0.6) / HEIGHT_STEP), 0, HEIGHT_NZ - 1)
	return grid[iz * HEIGHT_NX + ix]


static func _build_height_grid(type: TileType) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(HEIGHT_NX * HEIGHT_NZ)
	grid.fill(rim_height(type))

	var probe := terrain_scene(type).instantiate()
	var parts: Array = []  # [{tri: TriangleMesh, xf: Transform3D}]
	_collect_triangle_meshes(probe, Transform3D.IDENTITY, parts)

	for iz in HEIGHT_NZ:
		for ix in HEIGHT_NX:
			var x := -0.5 + float(ix) * HEIGHT_STEP
			var z := -0.6 + float(iz) * HEIGHT_STEP
			var best := -INF
			for part in parts:
				var xf: Transform3D = part["xf"]
				var inv := xf.affine_inverse()
				var hit: Dictionary = (part["tri"] as TriangleMesh).intersect_ray(
					inv * Vector3(x, 3.0, z), inv.basis * Vector3.DOWN)
				if not hit.is_empty():
					best = maxf(best, (xf * (hit["position"] as Vector3)).y)
			if best > -INF:
				grid[iz * HEIGHT_NX + ix] = best
	probe.free()
	return grid


static func _collect_triangle_meshes(node: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and node.mesh != null:
		out.append({"tri": (node.mesh as Mesh).generate_triangle_mesh(), "xf": xf})
	for child in node.get_children():
		_collect_triangle_meshes(child, xf, out)


static func _load_cached(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
