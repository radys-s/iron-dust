class_name IsoCameraRig
extends Node3D

## Orthographic isometric camera. The rig node is the pan pivot; the child Camera3D
## sits back along the view axis and only ever changes its `size` (zoom).

const PITCH_DEG := -35.264
const YAW_DEG := -45.0
const CAMERA_DISTANCE := 40.0

const ZOOM_MIN := 4.0
const ZOOM_MAX := 40.0
const ZOOM_STEP := 1.15
const PAN_SPEED := 8.0

@export var zoom_size: float = 9.5

var _camera: Camera3D
var _dragging := false


func _ready() -> void:
	rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0.0)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = zoom_size
	_camera.near = 0.05
	_camera.far = 200.0
	_camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	add_child(_camera)
	_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_zoom(zoom_size / ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_zoom(zoom_size * ZOOM_STEP)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		# Screen pixels -> world units: ortho size maps to viewport height.
		var units_per_px := zoom_size / float(get_viewport().get_visible_rect().size.y)
		_pan(-event.relative * units_per_px)


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if move != Vector2.ZERO:
		_pan(move.normalized() * PAN_SPEED * delta * (zoom_size / 10.0))


## Moves the pivot along the ground plane, in screen-relative directions.
func _pan(delta_screen: Vector2) -> void:
	var yaw := deg_to_rad(YAW_DEG)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	position += right * delta_screen.x + forward * delta_screen.y


func _set_zoom(value: float) -> void:
	zoom_size = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_camera.size = zoom_size


func get_camera() -> Camera3D:
	return _camera


## Screen position -> point on the ground plane (Y = height). Returns Vector3.INF on miss.
func screen_to_ground(screen_pos: Vector2, height: float = 0.0) -> Vector3:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (height - origin.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t
