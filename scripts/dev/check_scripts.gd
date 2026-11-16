extends SceneTree

## CI check: load every script in the project with autoloads registered, so a parse
## or compile error anywhere fails the run (plain --import exits 0 on those).
##
## godot --headless --path . --script res://scripts/dev/check_scripts.gd

var _checked := 0
var _broken: Array[String] = []


func _initialize() -> void:
	_scan("res://")
	print("checked %d scripts, %d broken" % [_checked, _broken.size()])
	for path in _broken:
		printerr("BROKEN: " + path)
	quit(1 if not _broken.is_empty() or _checked == 0 else 0)


func _scan(dir_path: String) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			_scan(dir_path.path_join(sub))
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			_check(dir_path.path_join(file))


func _check(path: String) -> void:
	_checked += 1
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_broken.append(path)
