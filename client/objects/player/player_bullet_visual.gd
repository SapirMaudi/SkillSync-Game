extends Node2D
class_name PlayerBulletVisual

const BULLET_TEXTURE := preload("res://assets/gun/bullet.png")

# Your bullet image is already angled.
# If the bullet visually flies sideways/wrong, change this value.
# Use 0.0 if your texture points directly right.
# Use 45.0 if your texture points diagonally up-right.
const BULLET_TEXTURE_FORWARD_ANGLE_DEGREES := 45.0

var bullet_id: int = 0
var owner_player_id: int = 0

var _direction: Vector2 = Vector2.RIGHT
var _speed_pixels_per_second: float = 280.0
var _lifetime_seconds: float = 1.2
var _age_seconds: float = 0.0

var _sprite: Sprite2D


func _ready() -> void:
	z_index = 80

	_sprite = Sprite2D.new()
	_sprite.texture = BULLET_TEXTURE
	_sprite.centered = true
	_sprite.z_index = 81

	add_child(_sprite)


func setup(
		new_bullet_id: int,
		new_owner_player_id: int,
		start_world_position: Vector2,
		direction: Vector2,
		speed_tiles_per_second: float,
		lifetime_seconds: float,
		tile_size: float
	) -> void:
	bullet_id = new_bullet_id
	owner_player_id = new_owner_player_id
	global_position = start_world_position

	if direction.length_squared() > 0.001:
		_direction = direction.normalized()
	else:
		_direction = Vector2.RIGHT

	_speed_pixels_per_second = speed_tiles_per_second * tile_size
	_lifetime_seconds = max(0.05, lifetime_seconds)
	_age_seconds = 0.0

	_update_rotation()


func _process(delta: float) -> void:
	global_position += _direction * _speed_pixels_per_second * delta

	_age_seconds += delta
	if _age_seconds >= _lifetime_seconds:
		queue_free()


func _update_rotation() -> void:
	var texture_forward_angle := deg_to_rad(BULLET_TEXTURE_FORWARD_ANGLE_DEGREES)
	rotation = _direction.angle() - texture_forward_angle
