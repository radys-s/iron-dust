class_name HexGrid
extends RefCounted

# Kenney Hexagon Kit tiles measure 1.0 (X) x 1.1547 (Z) => pointy-top hex, circumradius 1/sqrt(3).
const HEX_RADIUS := 0.577350269
const SQRT3 := 1.732050808

const NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func axial_to_world(q: int, r: int) -> Vector3:
	var x := HEX_RADIUS * SQRT3 * (float(q) + float(r) * 0.5)
	var z := HEX_RADIUS * 1.5 * float(r)
	return Vector3(x, 0.0, z)


static func world_to_axial(pos: Vector3) -> Vector2i:
	var qf := (SQRT3 / 3.0 * pos.x - 1.0 / 3.0 * pos.z) / HEX_RADIUS
	var rf := (2.0 / 3.0 * pos.z) / HEX_RADIUS
	return _axial_round(qf, rf)


static func get_neighbors(q: int, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in NEIGHBOR_DIRS:
		out.append(Vector2i(q + d.x, r + d.y))
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2.0)


# All cells within `radius` steps of origin, as a filled hexagonal area.
static func spiral_area(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r_lo := maxi(-radius, -q - radius)
		var r_hi := mini(radius, -q + radius)
		for r in range(r_lo, r_hi + 1):
			out.append(Vector2i(q, r))
	return out


# Cube rounding: fractional axial -> nearest valid hex.
static func _axial_round(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundi(qf)
	var r := roundi(rf)
	var s := roundi(sf)

	var dq := absf(float(q) - qf)
	var dr := absf(float(r) - rf)
	var ds := absf(float(s) - sf)

	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s

	return Vector2i(q, r)
