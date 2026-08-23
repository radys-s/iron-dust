extends SceneTree

# Dev helper for verifying scenes without a human at the keyboard: loads a scene,
# lets it settle, saves a PNG, quits. Headless mode renders nothing, so this is the
# only way to actually look at a scene from a script.
#
# godot --path . --script res://scripts/dev/screenshot.gd -- <scene> <out.png> [frames] [space_presses]

var _frames := 0
var _warmup := 20
var _out := "user://shot.png"
var _space_presses := 0
var _pressed := false


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() < 2:
		push_error("need: <scene_path> <out_png> [frames] [space_presses]")
		quit(1)
		return

	_out = argv[1]
	if argv.size() >= 3:
		_warmup = int(argv[2])
	if argv.size() >= 4:
		_space_presses = int(argv[3])

	var packed: PackedScene = load(argv[0])
	if packed == null:
		push_error("cannot load scene %s" % argv[0])
		quit(1)
		return
	change_scene_to_packed(packed)


func _process(_delta: float) -> bool:
	_frames += 1

	if not _pressed and _frames == 5 and _space_presses > 0:
		_pressed = true
		for i in _space_presses:
			var ev := InputEventKey.new()
			ev.keycode = KEY_SPACE
			ev.pressed = true
			root.push_input(ev)

	if _frames < _warmup:
		return false

	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("[shot] saved %s (%dx%d)" % [_out, img.get_width(), img.get_height()])
	return true
