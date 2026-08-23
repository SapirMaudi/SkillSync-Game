extends CharacterBody2D
class_name NetworkPlayerVisual

const REMOTE_INTERPOLATION_SPEED := 10.0

const CATMAN_SCENE := preload("res://objects/playable_characters/catman/catman.tscn")
const OLDMAN_SCENE := preload("res://objects/playable_characters/oldman/oldman.tscn")
const HEALTH_BAR_SCRIPT := preload("res://objects/player/player_health_bar.gd")
const WEAPON_ORBIT_SCRIPT := preload("res://objects/player/player_weapon_orbit.gd")

const TEAM_RED := Color(1.0, 0.2, 0.2, 1.0)
const TEAM_BLUE := Color(0.2, 0.45, 1.0, 1.0)
const TEAM_NEUTRAL := Color(1.0, 1.0, 1.0, 1.0)


const PLAYER_COLLISION_LAYER := 2
const WALL_COLLISION_MASK := 1
const PLAYER_COLLISION_RADIUS := 5.0
const PLAYER_COLLISION_HEIGHT := 22.0

var player_id: int = 0
var team: int = 0
var slot: int = 0
var is_local_player: bool = false
var nickname: String = ""
var skin_id: int = 0
var target_position: Vector2 = Vector2.ZERO

var current_hp: int = 100
var max_hp: int = 100
var is_dead: bool = false

var _character_instance: Node2D
var _health_bar: PlayerHealthBar
var _weapon_orbit: PlayerWeaponOrbit
var _body_collision_shape: CollisionShape2D

@onready var _label: Label = Label.new()


func _ready() -> void:
	_create_body_collision()

	_weapon_orbit = WEAPON_ORBIT_SCRIPT.new()
	add_child(_weapon_orbit)

	_health_bar = HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	_health_bar.position = Vector2(0, -34)
	_health_bar.set_health(current_hp, max_hp)

	add_child(_label)
	_label.position = Vector2(-55, -55)
	_label.size = Vector2(110, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.scale = Vector2(0.8, 0.8)

	update_label()
	_refresh_skin()
	_refresh_team_visuals()
	set_dead_visual(is_dead)


func setup(
		new_player_id: int,
		new_team: int,
		new_slot: int,
		new_is_local: bool,
		start_position: Vector2,
		new_nickname: String,
		new_skin_id: int,
		new_current_hp: int = 100,
		new_max_hp: int = 100,
		new_aim_x: float = 1.0,
		new_aim_y: float = 0.0
	) -> void:
	player_id = new_player_id
	team = new_team
	slot = new_slot
	is_local_player = new_is_local
	nickname = new_nickname
	skin_id = new_skin_id
	current_hp = new_current_hp
	max_hp = max(1, new_max_hp)
	is_dead = current_hp <= 0

	global_position = start_position
	target_position = start_position
	velocity = Vector2.ZERO

	if is_node_ready():
		update_label()
		set_health(current_hp, max_hp)
		set_aim_direction(Vector2(new_aim_x, new_aim_y))
		_refresh_skin()
		_refresh_team_visuals()
		set_dead_visual(is_dead)


func update_label() -> void:
	if nickname.strip_edges().is_empty():
		_label.text = "P" + str(player_id)
	else:
		_label.text = nickname


func set_health(new_current_hp: int, new_max_hp: int = max_hp) -> void:
	max_hp = max(1, new_max_hp)
	current_hp = clamp(new_current_hp, 0, max_hp)

	if _health_bar != null:
		_health_bar.set_health(current_hp, max_hp)


func apply_health_delta(delta_hp: int) -> void:
	set_health(current_hp + delta_hp, max_hp)


func set_dead_visual(dead: bool) -> void:
	is_dead = dead

	if _character_instance != null:
		if is_dead:
			_character_instance.rotation_degrees = 90.0
			_character_instance.modulate = Color(0.65, 0.65, 0.65, 0.9)
		else:
			_character_instance.rotation_degrees = 0.0
			_character_instance.modulate = Color.WHITE

	if _weapon_orbit != null:
		_weapon_orbit.visible = not is_dead

	if _health_bar != null:
		_health_bar.visible = not is_dead


func aim_at_world_position(world_position: Vector2) -> void:
	if _weapon_orbit == null:
		return

	if is_dead:
		return

	_weapon_orbit.set_aim_world_position(world_position)


func set_aim_direction(direction: Vector2) -> void:
	if _weapon_orbit == null:
		return

	if is_dead:
		return

	_weapon_orbit.set_aim_direction(direction)


func get_aim_direction() -> Vector2:
	if _weapon_orbit == null:
		return Vector2.RIGHT

	return _weapon_orbit.get_aim_direction()


func set_target_world_position(world_pos: Vector2) -> void:
	target_position = world_pos

	if is_local_player:
		global_position = world_pos


func set_world_position_immediate(world_pos: Vector2) -> void:
	global_position = world_pos
	target_position = world_pos
	velocity = Vector2.ZERO


func _process(delta: float) -> void:
	if is_local_player:
		return

	global_position = global_position.lerp(
		target_position,
		clamp(REMOTE_INTERPOLATION_SPEED * delta, 0.0, 1.0)
	)


func _create_body_collision() -> void:
	if _body_collision_shape != null:
		return

	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = WALL_COLLISION_MASK

	var capsule := CapsuleShape2D.new()
	capsule.radius = PLAYER_COLLISION_RADIUS
	capsule.height = PLAYER_COLLISION_HEIGHT

	_body_collision_shape = CollisionShape2D.new()
	_body_collision_shape.name = "PlayerCollisionShape"
	_body_collision_shape.shape = capsule
	add_child(_body_collision_shape)


func _refresh_skin() -> void:
	if not is_node_ready():
		return

	if _character_instance != null:
		_character_instance.queue_free()
		_character_instance = null

	var scene: PackedScene = CATMAN_SCENE

	if skin_id == 1:
		scene = OLDMAN_SCENE

	var instance: Node = scene.instantiate()
	var character_instance: Node2D = instance as Node2D

	if character_instance == null:
		return

	_character_instance = character_instance


	_disable_visual_collision(_character_instance)

	add_child(_character_instance)

	move_child(_character_instance, 0)

	_character_instance.position = Vector2.ZERO
	set_dead_visual(is_dead)


func _disable_visual_collision(node: Node) -> void:
	var collision_object := node as CollisionObject2D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	var collision_shape := node as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true

	for child in node.get_children():
		_disable_visual_collision(child)


func _refresh_team_visuals() -> void:
	var team_color := TEAM_NEUTRAL

	match team:
		1:
			team_color = TEAM_RED
		2:
			team_color = TEAM_BLUE

	_label.modulate = team_color
