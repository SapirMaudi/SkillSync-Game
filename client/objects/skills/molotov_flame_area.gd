extends Node2D
class_name MolotovFlameArea

const FLAME_COLOR := Color(1.0, 0.25, 0.02, 0.35)
const FLAME_EDGE_COLOR := Color(1.0, 0.75, 0.05, 0.75)

var radius_pixels: float = 48.0
var lifetime_seconds: float = 5.0
var age_seconds: float = 0.0


func setup(start_world_position: Vector2, new_radius_pixels: float, new_lifetime_seconds: float) -> void:
	global_position = start_world_position
	radius_pixels = new_radius_pixels
	lifetime_seconds = max(0.1, new_lifetime_seconds)
	age_seconds = 0.0
	z_index = 40
	queue_redraw()


func _process(delta: float) -> void:
	age_seconds += delta

	var alpha: float = 1.0 - clampf(age_seconds / lifetime_seconds, 0.0, 1.0)
	modulate.a = alpha

	queue_redraw()

	if age_seconds >= lifetime_seconds:
		queue_free()


func _draw() -> void:
	var pulse: float = 1.0 + sin(age_seconds * 12.0) * 0.08
	var r: float = radius_pixels * pulse

	draw_circle(Vector2.ZERO, r, FLAME_COLOR)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, FLAME_EDGE_COLOR, 3.0, true)

	for i in range(10):
		var angle: float = float(i) / 10.0 * TAU + age_seconds * 2.0
		var flame_pos := Vector2(cos(angle), sin(angle)) * r * 0.65
		draw_circle(flame_pos, 4.0 + sin(age_seconds * 10.0 + float(i)) * 1.5, FLAME_EDGE_COLOR)
