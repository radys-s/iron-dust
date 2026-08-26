class_name AmbientCritter
extends Node3D

## Simple procedural ambient creature (prairie dog / bird) that adds subtle life to the map.
## Uses lightweight primitive meshes and simple sine-wave bobbing/hopping.

var _time_offset := 0.0
var _base_y := 0.0
var _hop_speed := 3.5
var _hop_height := 0.06
var _critter_type := 0 # 0 = prairie dog / rodent, 1 = desert bird, 2 = lizard

func _ready() -> void:
	_base_y = position.y
	_build_critter()


func setup(seed_val: int) -> void:
	_time_offset = float(seed_val % 1000) * 0.01
	_critter_type = seed_val % 3
	_hop_speed = 2.5 + float((seed_val / 10) % 20) * 0.1
	_hop_height = 0.03 + float((seed_val / 100) % 10) * 0.005


func _process(delta: float) -> void:
	_time_offset += delta * _hop_speed
	var hop := sin(_time_offset)
	if hop > 0.0:
		position.y = _base_y + hop * _hop_height
	else:
		position.y = _base_y


func _build_critter() -> void:
	var body := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	if _critter_type == 0:
		# Prairie dog / small rodent
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.09, 0.06)
		body.mesh = mesh
		mat.albedo_color = Color(0.65, 0.48, 0.32)
	elif _critter_type == 1:
		# Desert quail / bird
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.07
		body.mesh = mesh
		mat.albedo_color = Color(0.42, 0.45, 0.40)
	else:
		# Lizard, flattened and low to the ground
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.03, 0.045)
		body.mesh = mesh
		mat.albedo_color = Color(0.48, 0.52, 0.30)

	body.material_override = mat
	body.position = Vector3(0.0, 0.04, 0.0)
	add_child(body)
