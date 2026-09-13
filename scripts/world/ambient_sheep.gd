class_name AmbientSheep
extends Node3D

## Ovce na pastvinovém okraji vlastněného území — jediný ambientní tvor, co
## místo primitiv (viz AmbientCritter/AmbientVillager) instancuje skutečný
## stažený model. Volající (MapBuilder.render()) musí předem ověřit, že
## TileCatalog.prop_scene("sheep") existuje — dokud model není stažený a
## zapsaný do TileCatalog.PROP_PATHS, se AmbientSheep vůbec nevytváří.

var _time_offset := 0.0
var _base_y := 0.0
var _graze_speed := 1.6
var _graze_amount := 0.10


func _ready() -> void:
	_base_y = position.y
	var scene := TileCatalog.prop_scene("sheep")
	if scene == null:
		return
	var model := scene.instantiate()
	var model_scale := TileCatalog.prop_scale("sheep")
	model.scale = Vector3(model_scale, model_scale, model_scale)
	add_child(model)


func setup(seed_val: int) -> void:
	_time_offset = float(seed_val % 1000) * 0.01
	_graze_speed = 1.2 + float((seed_val / 10) % 15) * 0.05
	_graze_amount = 0.06 + float((seed_val / 100) % 10) * 0.006


func _process(delta: float) -> void:
	_time_offset += delta * _graze_speed
	rotation.x = -0.05 + maxf(sin(_time_offset), 0.0) * _graze_amount
	position.y = _base_y + absf(sin(_time_offset * 0.5)) * 0.008
