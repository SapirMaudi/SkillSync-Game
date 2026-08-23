extends Node2D
class_name PlayerHealthBar

const BAR_WIDTH := 42.0
const BAR_HEIGHT := 6.0
const BORDER_SIZE := 1.0

const BACKGROUND_COLOR := Color(0.05, 0.05, 0.05, 0.85)
const EMPTY_COLOR := Color(0.35, 0.05, 0.05, 0.85)

const HEALTH_HIGH_COLOR := Color(0.15, 0.85, 0.25, 0.95)
const HEALTH_MEDIUM_COLOR := Color(0.95, 0.75, 0.15, 0.95)
const HEALTH_LOW_COLOR := Color(0.95, 0.2, 0.15, 0.95)

var current_hp: int = 100
var max_hp: int = 100


func _ready() -> void:
	z_index = 100
	queue_redraw()


func set_health(new_current_hp: int, new_max_hp: int = max_hp) -> void:
	max_hp = max(1, new_max_hp)
	current_hp = clamp(new_current_hp, 0, max_hp)

	queue_redraw()


func get_health_ratio() -> float:
	return float(current_hp) / float(max_hp)


func _draw() -> void:
	var outer_top_left := Vector2(-BAR_WIDTH * 0.5, -BAR_HEIGHT * 0.5)
	var outer_size := Vector2(BAR_WIDTH, BAR_HEIGHT)

	var inner_top_left := outer_top_left + Vector2(BORDER_SIZE, BORDER_SIZE)
	var inner_size := outer_size - Vector2(BORDER_SIZE * 2.0, BORDER_SIZE * 2.0)

	draw_rect(
		Rect2(outer_top_left, outer_size),
		BACKGROUND_COLOR
	)

	draw_rect(
		Rect2(inner_top_left, inner_size),
		EMPTY_COLOR
	)

	var ratio := get_health_ratio()

	if ratio <= 0.0:
		return

	var fill_color := HEALTH_HIGH_COLOR

	if ratio <= 0.30:
		fill_color = HEALTH_LOW_COLOR
	elif ratio <= 0.60:
		fill_color = HEALTH_MEDIUM_COLOR

	var fill_size := Vector2(inner_size.x * ratio, inner_size.y)

	draw_rect(
		Rect2(inner_top_left, fill_size),
		fill_color
	)
