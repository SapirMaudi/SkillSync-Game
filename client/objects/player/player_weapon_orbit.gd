extends Node2D
class_name PlayerWeaponOrbit

const GUN_TEXTURE := preload("res://assets/gun/gun.png")

const ORBIT_RADIUS := 18.0
const CIRCLE_RADIUS := 21.0
const CIRCLE_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const CIRCLE_WIDTH := 1.5

var aim_direction: Vector2 = Vector2.RIGHT

var _gun_sprite: Sprite2D


func _ready() -> void:
	z_index = 30

	_gun_sprite = Sprite2D.new()
	_gun_sprite.texture = GUN_TEXTURE
	_gun_sprite.centered = true
	_gun_sprite.z_index = 31

	add_child(_gun_sprite)

	set_aim_direction(Vector2.RIGHT)
	queue_redraw()


func set_aim_world_position(world_position: Vector2) -> void:
	var direction := world_position - global_position

	if direction.length_squared() <= 0.001:
		return

	set_aim_direction(direction.normalized())


func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return

	aim_direction = direction.normalized()

	if _gun_sprite == null:
		return

	_gun_sprite.position = aim_direction * ORBIT_RADIUS
	_gun_sprite.rotation = aim_direction.angle()

	if aim_direction.x < 0.0:
		_gun_sprite.flip_v = true
	else:
		_gun_sprite.flip_v = false


func get_aim_direction() -> Vector2:
	return aim_direction


func _draw() -> void:
	draw_arc(
		Vector2.ZERO,
		CIRCLE_RADIUS,
		0.0,
		TAU,
		64,
		CIRCLE_COLOR,
		CIRCLE_WIDTH,
		true
	)
