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

const SCENARIOS: Array[String] = ["battle", "placement", "market"]
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
