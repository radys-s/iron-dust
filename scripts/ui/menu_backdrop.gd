class_name MenuBackdrop
extends Control

## Pozadi menu: zapad slunce nad stolovymi horami, skladany z vrstev.
##
## Proc kreslene a ne screenshot nebo 3D scena: 3D pozadi by si vynutilo
## rozehranou GameState uz v menu (mapa se generuje az ve start_new_game),
## a statickym obrazkem by se vzhled rozesel s hrou, jakmile se zmeni paleta.
## Tohle cte barvy z UITheme, takze se drzi zbytku hry samo.
##
## Vrstvy jsou serazene od nejvzdalenejsi po nejblizsi a s rostouci blizkosti
## tmavnou — vzdusna perspektiva je to jedine, co ze tri barevnych pasu udela
## dojem hloubky.

## Zlomky vysky obrazovky, kde lezi obzor a kde dosedne nejblizsi hreben.
const HORIZON := 0.52
const SUN_CENTER := Vector2(0.62, 0.46)
const SUN_RADIUS := 0.085

const SKY_TOP := Color(0.118, 0.086, 0.098)
const SKY_HORIZON := Color(0.706, 0.361, 0.180)
const SUN_COLOR := Color(0.980, 0.780, 0.420)

## Kazda vrstva: profil hrebene (zlomky sirky a vysky) a jeji barva.
##
## Mesy jsou zamerne siroke a ploche s ostrymi hranami — to je silueta
## amerického jihozapadu. Uzke caste zuby by delaly sloupcovy graf, ne krajinu.
const RIDGES := [
	{
		"color": Color(0.392, 0.239, 0.192),
		"base": 0.63,
		"points": [
			Vector2(0.00, 0.052), Vector2(0.14, 0.052), Vector2(0.14, 0.104),
			Vector2(0.31, 0.104), Vector2(0.31, 0.040), Vector2(0.55, 0.040),
			Vector2(0.55, 0.086), Vector2(0.68, 0.086), Vector2(0.68, 0.030),
			Vector2(1.00, 0.030),
		],
	},
	{
		"color": Color(0.259, 0.157, 0.137),
		"base": 0.75,
		"points": [
			Vector2(0.00, 0.038), Vector2(0.09, 0.038), Vector2(0.09, 0.112),
			Vector2(0.26, 0.112), Vector2(0.26, 0.050), Vector2(0.46, 0.050),
			Vector2(0.46, 0.020), Vector2(0.74, 0.020), Vector2(0.74, 0.094),
			Vector2(0.92, 0.094), Vector2(0.92, 0.044), Vector2(1.00, 0.044),
		],
	},
	{
		"color": Color(0.137, 0.090, 0.082),
		"base": 0.89,
		"points": [
			Vector2(0.00, 0.062), Vector2(0.20, 0.062), Vector2(0.20, 0.016),
			Vector2(0.38, 0.016), Vector2(0.38, 0.082), Vector2(0.62, 0.082),
			Vector2(0.62, 0.034), Vector2(0.84, 0.034), Vector2(0.84, 0.070),
			Vector2(1.00, 0.070),
		],
	},
]


func _ready() -> void:
	# Musi to byt set_anchors_AND_OFFSETS_preset: samotne set_anchors_preset()
	# nastavi kotvy, ale nechá offsety, takze rect zustane nulovy a _draw()
	# nema do ceho kreslit. Stalo se presne tohle a pozadi bylo prazdne.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Prekresluje se jen pri zmene velikosti okna, ne kazdy snimek.
	resized.connect(queue_redraw)


func _draw() -> void:
	var view := size
	_draw_sky(view)
	_draw_sun(view)
	_draw_ridges(view)
	_draw_ground(view)
	_draw_text_scrim(view)
	_draw_vignette(view)


## Ztmaveni leve tretiny, kde sedi titul a nabidka. Bez nej by mosazny nadpis
## lezel na rozsvicene oranzove obloze a ztracel kontrast.
func _draw_text_scrim(view: Vector2) -> void:
	var width := view.x * 0.46
	var dark := Color(0.043, 0.035, 0.031, 0.74)
	var clear := Color(0.043, 0.035, 0.031, 0.0)
	# Dva pasy, aby ubyvani nebylo linearni a scrim se u textu drzel dele.
	var middle := Color(0.043, 0.035, 0.031, 0.26)

	for span in [[0.0, width * 0.5, dark, middle], [width * 0.5, width, middle, clear]]:
		var points := PackedVector2Array([
			Vector2(span[0], 0.0), Vector2(span[1], 0.0),
			Vector2(span[1], view.y), Vector2(span[0], view.y),
		])
		draw_polygon(points, PackedColorArray([span[2], span[3], span[3], span[2]]))


## Vodorovny pas s plynulym prechodem mezi dvema barvami.
##
## Kresli se jako polygon s vrcholovymi barvami, ne jako stoh pruhlednych
## obdelniku: prekryvajici se alfa pasy delaly viditelne svisle svy. Godot 2D
## nema gradientni draw_rect a shader by kvuli jednomu pozadi byl zbytecny.
func _draw_band(view: Vector2, top: float, bottom: float,
		top_color: Color, bottom_color: Color) -> void:
	var points := PackedVector2Array([
		Vector2(0.0, top), Vector2(view.x, top),
		Vector2(view.x, bottom), Vector2(0.0, bottom),
	])
	var colors := PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	draw_polygon(points, colors)


func _draw_sky(view: Vector2) -> void:
	# Obloha se kresli pres CELOU vysku, ne jen po obzor: hrebeny ji stejne
	# prekryji zdola. Kdyz se kreslila jen po HORIZON, zustal mezi spodni hranou
	# oblohy a vrcholky mes nevykresleny pruh a prosvital jim sedy podklad.
	#
	# Tri pasy misto jednoho, aby prechod nebyl linearni — barva se ma hromadit
	# az tesne u obzoru, jako pri skutecnem zapadu.
	var horizon := view.y * HORIZON
	var mid := SKY_TOP.lerp(SKY_HORIZON, 0.25)
	var low := SKY_TOP.lerp(SKY_HORIZON, 0.62)

	_draw_band(view, 0.0, horizon * 0.55, SKY_TOP, mid)
	_draw_band(view, horizon * 0.55, horizon * 0.85, mid, low)
	_draw_band(view, horizon * 0.85, view.y, low, SKY_HORIZON)


func _draw_sun(view: Vector2) -> void:
	var center := Vector2(SUN_CENTER.x * view.x, SUN_CENTER.y * view.y)
	var radius := SUN_RADIUS * view.y

	# Zare kolem kotouce: nekolik pruhlednych kruhu misto shaderu.
	for step in 8:
		var t := float(step) / 7.0
		var glow := SUN_COLOR
		glow.a = 0.055 * (1.0 - t)
		draw_circle(center, radius * (1.0 + t * 2.6), glow)

	draw_circle(center, radius, SUN_COLOR)


func _draw_ridges(view: Vector2) -> void:
	for layer in RIDGES:
		var base: float = float(layer["base"]) * view.y
		var profile: Array = layer["points"]

		var polygon := PackedVector2Array()
		for point in profile:
			var p: Vector2 = point
			polygon.append(Vector2(p.x * view.x, base - p.y * view.y))
		# Uzavrit dolu za spodni hranu, aby vrstva vyplnila vse pod hrebenem.
		polygon.append(Vector2(view.x, view.y))
		polygon.append(Vector2(0.0, view.y))

		draw_colored_polygon(polygon, layer["color"])


func _draw_ground(view: Vector2) -> void:
	var top: float = float(RIDGES[RIDGES.size() - 1]["base"]) * view.y
	draw_rect(Rect2(0.0, top, view.x, view.y - top), Color(0.086, 0.059, 0.051))


## Vinjeta stahne pozornost do stredu, kde je titul a nabidka.
func _draw_vignette(view: Vector2) -> void:
	var steps := 10
	var thickness := view.y * 0.055
	for step in steps:
		var t := float(step) / float(steps - 1)
		var shade := Color(0.0, 0.0, 0.0, 0.055 * (1.0 - t))
		var inset := thickness * t
		draw_rect(Rect2(0.0, inset, view.x, thickness), shade)
		draw_rect(Rect2(0.0, view.y - inset - thickness, view.x, thickness), shade)
		draw_rect(Rect2(inset, 0.0, thickness, view.y), shade)
		draw_rect(Rect2(view.x - inset - thickness, 0.0, thickness, view.y), shade)
