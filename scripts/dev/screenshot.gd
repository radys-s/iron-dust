extends SceneTree

# Dev helper for verifying scenes without a human at the keyboard: loads a scene,
# lets it settle, saves a PNG, quits. Headless mode renders nothing, so this is the
# only way to actually look at a scene from a script.
#
# godot --path . --script res://scripts/dev/screenshot.gd -- <scene> <out.png> [frames] [keys] [click]
#
# `keys`  comma-separated key names pressed once the scene is up, e.g. "t" or
#         "enter,enter,t". Used to reach a specific UI state.
# `click` "x,y" as fractions of the window, e.g. "0.5,0.5" clicks the centre.

const KEY_NAMES := {
	"space": KEY_SPACE,
	"enter": KEY_ENTER,
	"escape": KEY_ESCAPE,
	"t": KEY_T,
	"b": KEY_B,
	"o": KEY_O,
	"f5": KEY_F5,
	"w": KEY_W,
	"a": KEY_A,
	"s": KEY_S,
	"d": KEY_D,
}

var _frames := 0
var _warmup := 20
var _out := "user://shot.png"
var _keys: Array[String] = []
var _click := Vector2.INF
var _pressed := false


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() < 2:
		push_error("need: <scene_path> <out_png> [frames] [keys]")
		quit(1)
		return

	_out = argv[1]
	if argv.size() >= 3:
		_warmup = int(argv[2])
	if argv.size() >= 4 and argv[3] != "" and argv[3] != "0":
		for name in argv[3].split(","):
			var trimmed := name.strip_edges().to_lower()
			if not KEY_NAMES.has(trimmed):
				push_error("unknown key name '%s'" % trimmed)
				quit(1)
				return
			_keys.append(trimmed)

	if argv.size() >= 5 and argv[4] != "":
		var parts := argv[4].split(",")
		if parts.size() != 2:
			push_error("click must be 'x,y' fractions")
			quit(1)
			return
		_click = Vector2(float(parts[0]), float(parts[1]))

	var packed: PackedScene = load(argv[0])
	if packed == null:
		push_error("cannot load scene %s" % argv[0])
		quit(1)
		return
	change_scene_to_packed(packed)


func _process(_delta: float) -> bool:
	_frames += 1

	if not _pressed and _frames == 5:
		_pressed = true
		for name in _keys:
			var ev := InputEventKey.new()
			ev.keycode = KEY_NAMES[name]
			ev.pressed = true
			root.push_input(ev)

		if _click != Vector2.INF:
			# push_input takes window-space coords; the stretch system scales
			# them to the logical viewport just like a real mouse event.
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(DisplayServer.window_get_size()) * _click
			root.push_input(click)

	if _frames < _warmup:
		return false

	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("[shot] saved %s (%dx%d)" % [_out, img.get_width(), img.get_height()])
	return true
