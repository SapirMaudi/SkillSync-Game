extends Node2D
class_name PlayerDamageNumber

const FLOAT_SPEED := 22.0
const LIFETIME_SECONDS := 0.75
const DAMAGE_COLOR := Color(1.0, 0.45, 0.05, 1.0)
const HEAL_COLOR := Color(0.25, 1.0, 0.35, 1.0)

var _age_seconds: float = 0.0
var _label: Label


func _ready() -> void:
	z_index = 200

	_label = Label.new()
	_label.position = Vector2(-24, -10)
	_label.size = Vector2(48, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)

	add_child(_label)


func setup(value: int, start_world_position: Vector2, is_heal: bool = false) -> void:
	global_position = start_world_position
	_age_seconds = 0.0

	if _label == null:
		return

	if is_heal:
		_label.text = "+" + str(value)
		_label.add_theme_color_override("font_color", HEAL_COLOR)
	else:
		_label.text = str(value)
		_label.add_theme_color_override("font_color", DAMAGE_COLOR)

	_label.modulate.a = 1.0
	modulate.a = 1.0


func _process(delta: float) -> void:
	_age_seconds += delta

	global_position.y -= FLOAT_SPEED * delta

	var alpha: float = 1.0 - clampf(_age_seconds / LIFETIME_SECONDS, 0.0, 1.0)
	modulate.a = alpha

	if _age_seconds >= LIFETIME_SECONDS:
		queue_free()
