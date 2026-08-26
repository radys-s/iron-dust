class_name AmbientVillager
extends Node3D

## Simple procedural settler figure that adds subtle life to owned land.
## Built from primitive meshes, animated with a gentle idle sway/bob (no
## walking, no skeleton) — mirrors the AmbientCritter pattern.

var _time_offset := 0.0
var _base_y := 0.0
var _sway_speed := 1.8
var _sway_amount := 0.05


func _ready() -> void:
	_base_y = position.y
	_build_villager()


func setup(seed_val: int) -> void:
	_time_offset = float(seed_val % 1000) * 0.01
	_sway_speed = 1.4 + float((seed_val / 10) % 15) * 0.05
	_sway_amount = 0.03 + float((seed_val / 100) % 10) * 0.003


func _process(delta: float) -> void:
	_time_offset += delta * _sway_speed
	rotation.y = sin(_time_offset) * _sway_amount
	position.y = _base_y + absf(sin(_time_offset * 0.5)) * 0.01


func _build_villager() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.045
	body_mesh.height = 0.16
	body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	body_mat.albedo_color = Color(0.36, 0.28, 0.18)
	body.material_override = body_mat
	body.position = Vector3(0.0, 0.10, 0.0)
	add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.032
	head_mesh.height = 0.064
	head.mesh = head_mesh
	var head_mat := StandardMaterial3D.new()
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	head_mat.albedo_color = Color(0.75, 0.58, 0.45)
	head.material_override = head_mat
	head.position = Vector3(0.0, 0.19, 0.0)
	add_child(head)

	var hat := MeshInstance3D.new()
	var hat_mesh := BoxMesh.new()
	hat_mesh.size = Vector3(0.09, 0.012, 0.09)
	hat.mesh = hat_mesh
	var hat_mat := StandardMaterial3D.new()
	hat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	hat_mat.albedo_color = Color(0.30, 0.20, 0.12)
	hat.material_override = hat_mat
	hat.position = Vector3(0.0, 0.21, 0.0)
	add_child(hat)
