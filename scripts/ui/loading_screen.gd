extends Control

## Uvodni obrazovka pri startu aplikace.
##
## Neni to jen kosmetika: prvni snimek Godotu trva, nez se nahraje font, postavi
## Theme a naimportuji GLB modely, a bez teto obrazovky hrac zira do cerneho
## okna a nevi, jestli se hra spustila. Proto se ukazuje HNED (je to hlavni
## scena projektu) a teprve pak se na pozadi chysta menu.
##
## Zamerne se ceka i minimalni dobu, i kdyz je nacteno driv — probliknuti
## obrazovky na dva snimky pusobi jako chyba, ne jako start.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const MIN_SECONDS := 1.1

const LINES: Array[String] = [
	"Rozvěšují se telegrafní dráty…",
	"Počítá se dobytek…",
	"Zahřívá se lokomotiva…",
	"Smlouvá se o cenu soli…",
	"Zametá se prach ze schodů saloonu…",
]

var _elapsed := 0.0
var _ready_to_go := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build_theme()

	var background := ColorRect.new()
	background.color = UITheme.INK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := UITheme.column(UITheme.GAP)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title := UITheme.logotype(64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(360, 0)
	column.add_child(rule)

	# Hláška se vybírá podle času startu, ne RNG — GameState._rng je herní seed
	# a sahat na něj kvůli kosmetice by rozbilo determinismus partie.
	var index := int(Time.get_unix_time_from_system()) % LINES.size()
	var line := UITheme.label(LINES[index], UITheme.SIZE_BODY, UITheme.PARCHMENT_DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(360, 0)
	column.add_child(line)

	# Menu se chysta až po prvním vykresleném snímku, aby se tahle obrazovka
	# stihla objevit dřív, než začne nahrávání.
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(MENU_SCENE)
	_ready_to_go = true


func _process(delta: float) -> void:
	if not _ready_to_go:
		return
	_elapsed += delta
	if _elapsed < MIN_SECONDS:
		return
	if ResourceLoader.load_threaded_get_status(MENU_SCENE) != ResourceLoader.THREAD_LOAD_LOADED:
		return

	set_process(false)
	var menu: PackedScene = ResourceLoader.load_threaded_get(MENU_SCENE)
	get_tree().change_scene_to_packed(menu)
