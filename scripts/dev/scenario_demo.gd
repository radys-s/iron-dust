extends Node

## Loads the real play scene and drives it into a situation that only shows up
## mid-game, so the UI around it can actually be looked at instead of assumed.
##
## The scenario name is the 6th user argument of screenshot.gd:
##   --script res://scripts/dev/screenshot.gd -- \
##       res://scenes/dev/scenario_demo.tscn out.png 60 "" "" battle
##
## battle    — stacks the odds, attacks Harlan-Voss, leaves the report banner up
## placement — puts the build cursor in hand so the green legal-tile hints show
## market    — parks the coach in town and opens the trade panel with contracts
## ai_turn   — funds Harlan-Voss and weakens the frontier so its own turn raids
##             a player cell: the combat banner plus a freshly walled tile
## defeat    — forces a funded Harlan-Voss attack straight at Dustfall, showing
##             the game-over overlay
## victory   — clears every Harlan-Voss cell but one, then wins the last fight,
##             showing the victory overlay

const SCENARIOS: Array[String] = ["battle", "placement", "market", "ai_turn", "defeat", "victory"]
const TRIGGER_FRAME := 12
const ENEMY_CELL := Vector2i(0, 3)

var _game: Node3D
var _scenario := "battle"
var _frames := 0
var _fired := false


func _ready() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() >= 6 and SCENARIOS.has(argv[5]):
		_scenario = argv[5]

	_game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	if _fired or _frames < TRIGGER_FRAME:
		return
	_fired = true

	match _scenario:
		"battle":
			_battle()
		"placement":
			_placement()
		"market":
			_market()
		"ai_turn":
			_ai_turn()
		"defeat":
			_defeat()
		"victory":
			_victory()


## Overwhelming force, so the banner shows a win rather than a random result.
func _battle() -> void:
	GameState.reputation["soldiers"] = 100
	for id in ["militia", "escort", "artillery", "weapons"]:
		if not GameState.has_tech(id):
			GameState.researched_techs.append(id)
	GameState.settlements[Vector2i(0, 2)] = 3
	GameState.perform_action("attack", ENEMY_CELL)


func _placement() -> void:
	_game._begin_placement("Farma")


func _market() -> void:
	GameState.coach_stay = GameData.COACH_STAY_TURNS
	GameState.turn_count = GameData.CONTRACT_INTERVAL
	GameState._tick_contracts()
	GameState.market_changed.emit()

	var hud := _game.get_node("GameHUD")
	hud._toggle_overlay(hud._trade_overlay)


## A funded, unopposed Harlan-Voss takes its own turn and raids the weakest
## thing it can reach — the ordinary case, distinct from _defeat() below.
func _ai_turn() -> void:
	GameState.reputation["soldiers"] = 0
	GameState.researched_techs.clear()
	GameState.ai_resources["gold"] = 400
	GameState.advance_turn()


## Harlan-Voss already holds ground right next to Dustfall and has the
## treasury to guarantee the roll — called directly rather than through a
## natural turn so the demo always lands on the capital, not whichever
## frontier cell EnemyAI would otherwise judge weakest.
func _defeat() -> void:
	GameState.tiles[Vector2i(0, 1)] = GameData.Terrain.ENEMY
	GameState.ai_resources["gold"] = 1000000
	GameState._ai_attack_player_cell(MapBuilder.TOWN_CELL, Vector2i(0, 1))


## Every Harlan-Voss cell but one is already flipped to owned territory, as if
## already captured; the last one falls to overwhelming force. The target is
## whichever enemy cell has the most enemy neighbors, so once the rest convert
## it is guaranteed to end up adjacent to owned land — same adjacency rule a
## real attack has to satisfy.
func _victory() -> void:
	var enemy_cells: Array[Vector2i] = []
	for cell in GameState.tiles:
		if GameState.tiles[cell] == GameData.Terrain.ENEMY:
			enemy_cells.append(cell)

	var target := enemy_cells[0]
	var best_neighbor_count := -1
	for cell in enemy_cells:
		var count := 0
		for neighbor in HexGrid.get_neighbors(cell.x, cell.y):
			if enemy_cells.has(neighbor):
				count += 1
		if count > best_neighbor_count:
			best_neighbor_count = count
			target = cell

	for cell in enemy_cells:
		if cell != target:
			GameState.tiles[cell] = GameData.Terrain.OWNED
			GameState.owned[cell] = true

	GameState.reputation["soldiers"] = 100
	for id in ["militia", "escort", "artillery", "weapons"]:
		if not GameState.has_tech(id):
			GameState.researched_techs.append(id)
	GameState.perform_action("attack", target)
