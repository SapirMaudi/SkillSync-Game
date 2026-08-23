extends Node

const packets := preload("res://packets.gd")
const SupportReportUI := preload("res://classes/support_report/support_report_ui.gd")
const NetworkPlayerVisualScript := preload("res://objects/player/player.gd")
const PlayerBulletVisualScript := preload("res://objects/player/player_bullet_visual.gd")
const PlayerDamageNumberScript := preload("res://objects/player/player_damage_number.gd")
const MolotovFlameAreaScript := preload("res://objects/skills/molotov_flame_area.gd")
const TEAM_FLAG_SCENE := preload("res://objects/Flags/flag.tscn")

const TILE_SIZE := 16.0
const PLAYER_SPEED := 140.0
const HASTE_SPEED_MULTIPLIER := 1.2

const SEND_INTERVAL := 0.05
const SEND_DISTANCE_THRESHOLD := 0.02

const AIM_SEND_INTERVAL := 0.05
const AIM_DIRECTION_SEND_THRESHOLD := 0.01

const SHOOT_COOLDOWN_SECONDS := 0.16

const TEAM_RED := 1
const TEAM_BLUE := 2

const FLAG_STATUS_AT_BASE := 0
const FLAG_STATUS_CARRIED := 1
const FLAG_STATUS_DROPPED := 2

const SKILL_HASTE := 1
const SKILL_HEAL := 2
const SKILL_MOLOTOV := 3

const SKILL_READY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const SKILL_ACTIVE_COLOR := Color(1.0, 0.9, 0.15, 1.0)
const SKILL_COOLDOWN_COLOR := Color(0.35, 0.35, 0.35, 0.95)

const HASTE_READY_TEXT := "Shift"
const HEAL_READY_TEXT := "E"
const MOLOTOV_READY_TEXT := "F"

const SFX_DEATH_PATH := "res://assets/sfx/death.wav"
const SFX_FLAG_CAPTURED_PATH := "res://assets/sfx/flagCaptured.wav"
const SFX_FLAG_DROPPED_PATH := "res://assets/sfx/flagDropped.wav"
const SFX_FLAG_PICKUP_PATH := "res://assets/sfx/flagPickup.wav"
const SFX_GAME_LOST_PATH := "res://assets/sfx/gameLost.wav"
const SFX_GAME_WON_PATH := "res://assets/sfx/gameWon.wav"
const SFX_SHOOT_PATH := "res://assets/sfx/shoot.wav"

@onready var _world: Node2D = $World
@onready var _players_root: Node2D = $World/Players
@onready var _camera: Camera2D = $World/Camera2D

@onready var _red_score_label: Label = $UI/GameUiBox/HBoxContainer/RedTeamScore
@onready var _timer_label: Label = $UI/GameUiBox/HBoxContainer/TimerDisplay
@onready var _blue_score_label: Label = $UI/GameUiBox/HBoxContainer/BlueTeamScore
@onready var _main_hp_bar: ProgressBar = $UI/GameUiBox/HBoxContainer2/HpBar

@onready var _speed_art: Sprite2D = $UI/GameUiBox/HBoxContainer3/SpeedArt
@onready var _heal_art: Sprite2D = $UI/GameUiBox/HBoxContainer3/HealArt
@onready var _molotov_art: Sprite2D = $UI/GameUiBox/HBoxContainer3/MolotovArt

@onready var _speed_text: Label = $UI/GameUiBox/HBoxContainer3/SpeedArt/SpeedText
@onready var _heal_text: Label = $UI/GameUiBox/HBoxContainer3/HealArt/HealText
@onready var _molotov_text: Label = $UI/GameUiBox/HBoxContainer3/MolotovArt/MolotovText

var _flags_root: Node2D
var _bullets_root: Node2D
var _damage_numbers_root: Node2D
var _skills_root: Node2D

var _death_ui_layer: CanvasLayer
var _respawn_label: Label

var _result_ui_layer: CanvasLayer
var _result_panel: PanelContainer
var _result_title: Label
var _result_score: Label
var _result_rows: VBoxContainer
var _return_lobby_button: Button
var _support_report_ui: SupportReportUI

var _sfx_death: AudioStreamPlayer
var _sfx_flag_captured: AudioStreamPlayer
var _sfx_flag_dropped: AudioStreamPlayer
var _sfx_flag_pickup: AudioStreamPlayer
var _sfx_game_lost: AudioStreamPlayer
var _sfx_game_won: AudioStreamPlayer
var _sfx_shoot: AudioStreamPlayer

var _last_red_score: int = 0
var _last_blue_score: int = 0

var _players: Dictionary = {}
var _flags: Dictionary = {}
var _bullets: Dictionary = {}

var _send_accumulator: float = 0.0
var _last_sent_tile_position: Vector2 = Vector2.ZERO

var _aim_send_accumulator: float = 0.0
var _last_sent_aim_direction: Vector2 = Vector2.RIGHT

var _shoot_cooldown_remaining: float = 0.0

var _local_is_dead: bool = false
var _local_respawn_remaining: float = 0.0
var _match_ended: bool = false

var _skill_active_remaining: Dictionary = {
	SKILL_HASTE: 0.0,
	SKILL_HEAL: 0.0,
	SKILL_MOLOTOV: 0.0,
}

var _skill_cooldown_remaining: Dictionary = {
	SKILL_HASTE: 0.0,
	SKILL_HEAL: 0.0,
	SKILL_MOLOTOV: 0.0,
}


func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)

	_flags_root = Node2D.new()
	_flags_root.name = "Flags"
	_world.add_child(_flags_root)

	_bullets_root = Node2D.new()
	_bullets_root.name = "Bullets"
	_world.add_child(_bullets_root)

	_damage_numbers_root = Node2D.new()
	_damage_numbers_root.name = "DamageNumbers"
	_world.add_child(_damage_numbers_root)

	_skills_root = Node2D.new()
	_skills_root.name = "Skills"
	_world.add_child(_skills_root)

	_create_death_ui()
	_create_result_ui()
	_setup_support_report_button()
	_setup_sfx()

	_red_score_label.text = "0"
	_blue_score_label.text = "0"
	_timer_label.text = "03:00"
	_update_main_hp_bar(100, 100)

	_update_skill_ui()

	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.make_current()


func _setup_support_report_button() -> void:
	_support_report_ui = SupportReportUI.new()
	_support_report_ui.setup("ingame", ["Report Bug", "Connection Problem", "Gameplay Problem", "Other"])
	add_child(_support_report_ui)


func _setup_sfx() -> void:
	_sfx_death = _create_sfx_player(SFX_DEATH_PATH, "SfxDeath")
	_sfx_flag_captured = _create_sfx_player(SFX_FLAG_CAPTURED_PATH, "SfxFlagCaptured")
	_sfx_flag_dropped = _create_sfx_player(SFX_FLAG_DROPPED_PATH, "SfxFlagDropped")
	_sfx_flag_pickup = _create_sfx_player(SFX_FLAG_PICKUP_PATH, "SfxFlagPickup")
	_sfx_game_lost = _create_sfx_player(SFX_GAME_LOST_PATH, "SfxGameLost")
	_sfx_game_won = _create_sfx_player(SFX_GAME_WON_PATH, "SfxGameWon")
	_sfx_shoot = _create_sfx_player(SFX_SHOOT_PATH, "SfxShoot")


func _create_sfx_player(path: String, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Master"

	if ResourceLoader.exists(path):
		player.stream = load(path)
	else:
		push_warning("Missing sound effect file: " + path)

	add_child(player)
	return player


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	if player.stream == null:
		return

	player.stop()
	player.play()


func _update_main_hp_bar(current_hp: int, max_hp: int) -> void:
	if _main_hp_bar == null:
		return

	var safe_max_hp: int = max(1, max_hp)
	var safe_current_hp: int = clamp(current_hp, 0, safe_max_hp)

	_main_hp_bar.min_value = 0.0
	_main_hp_bar.max_value = float(safe_max_hp)
	_main_hp_bar.value = float(safe_current_hp)
	_main_hp_bar.tooltip_text = "%d / %d HP" % [safe_current_hp, safe_max_hp]


func _update_main_hp_bar_if_local(player_id: int, current_hp: int, max_hp: int) -> void:
	if player_id != int(GameManager.client_id):
		return

	_update_main_hp_bar(current_hp, max_hp)


func _create_death_ui() -> void:
	_death_ui_layer = CanvasLayer.new()
	_death_ui_layer.name = "DeathUI"
	add_child(_death_ui_layer)

	_respawn_label = Label.new()
	_respawn_label.visible = false
	_respawn_label.text = ""
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_respawn_label.anchor_left = 0.0
	_respawn_label.anchor_top = 0.0
	_respawn_label.anchor_right = 1.0
	_respawn_label.anchor_bottom = 1.0
	_respawn_label.offset_left = 0.0
	_respawn_label.offset_top = -40.0
	_respawn_label.offset_right = 0.0
	_respawn_label.offset_bottom = 0.0
	_respawn_label.add_theme_font_size_override("font_size", 32)
	_respawn_label.add_theme_constant_override("outline_size", 5)
	_respawn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	_respawn_label.add_theme_color_override("font_outline_color", Color.BLACK)

	_death_ui_layer.add_child(_respawn_label)


func _create_result_ui() -> void:
	_result_ui_layer = CanvasLayer.new()
	_result_ui_layer.name = "ResultUI"
	add_child(_result_ui_layer)

	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.anchor_left = 0.5
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_right = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.offset_left = -360
	_result_panel.offset_top = -245
	_result_panel.offset_right = 360
	_result_panel.offset_bottom = 245

	_result_ui_layer.add_child(_result_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(720, 490)
	root.add_theme_constant_override("separation", 10)
	_result_panel.add_child(root)

	_result_title = Label.new()
	_result_title.text = "Match Ended"
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 30)
	_result_title.add_theme_constant_override("outline_size", 4)
	_result_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	_result_title.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_result_title)

	_result_score = Label.new()
	_result_score.text = "Red 0 - 0 Blue"
	_result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score.add_theme_font_size_override("font_size", 22)
	root.add_child(_result_score)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	_add_result_header_label(header, "Player", 170)
	_add_result_header_label(header, "K", 45)
	_add_result_header_label(header, "D", 45)
	_add_result_header_label(header, "Cap", 55)
	_add_result_header_label(header, "Result", 100)
	_add_result_header_label(header, "Report", 90)

	_result_rows = VBoxContainer.new()
	_result_rows.add_theme_constant_override("separation", 4)
	root.add_child(_result_rows)

	_return_lobby_button = Button.new()
	_return_lobby_button.text = "Back To Lobby"
	_return_lobby_button.custom_minimum_size = Vector2(220, 44)
	_return_lobby_button.pressed.connect(_on_return_lobby_pressed)
	root.add_child(_return_lobby_button)

func _add_result_header_label(parent: Control, text: String, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)


func _add_result_value_label(parent: Control, text: String, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)


func _add_result_report_button(
	parent: Control,
	reported_player_id: int,
	reported_player_name: String,
	game_id: int
) -> void:
	var button := Button.new()
	button.text = "Report"
	button.custom_minimum_size = Vector2(90, 28)

	if reported_player_id == int(GameManager.client_id):
		button.disabled = true
		button.text = "You"
	else:
		button.pressed.connect(func(): _on_report_player_pressed(
			reported_player_id,
			reported_player_name,
			game_id
		))

	parent.add_child(button)


func _on_report_player_pressed(
	reported_player_id: int,
	reported_player_name: String,
	game_id: int
) -> void:
	if _support_report_ui == null:
		return

	_support_report_ui.open_player_report(
		reported_player_id,
		reported_player_name,
		game_id
	)


func _process(delta: float) -> void:
	if _shoot_cooldown_remaining > 0.0:
		_shoot_cooldown_remaining = max(0.0, _shoot_cooldown_remaining - delta)

	if _match_ended:
		return

	_update_respawn_ui(delta)
	_update_skill_timers(delta)

	if not _local_is_dead:
		_handle_skill_input()
		_update_local_player_aim(delta)

		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_send_shoot_request()

	_update_carried_flags()
	_cleanup_dead_bullet_references()


func _physics_process(delta: float) -> void:
	if _match_ended:
		return

	if _local_is_dead:
		return

	var local_player_variant: Variant = _players.get(GameManager.client_id)
	var local_player: NetworkPlayerVisual = local_player_variant as NetworkPlayerVisual

	if local_player == null:
		return

	var input_dir: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	var movement_speed := PLAYER_SPEED

	if float(_skill_active_remaining[SKILL_HASTE]) > 0.0:
		movement_speed *= HASTE_SPEED_MULTIPLIER

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()

	local_player.velocity = input_dir * movement_speed
	local_player.move_and_slide()

	_send_accumulator += delta

	if _send_accumulator < SEND_INTERVAL:
		return

	_send_accumulator = 0.0

	var tile_position: Vector2 = world_to_tile(local_player.global_position)

	if tile_position.distance_to(_last_sent_tile_position) < SEND_DISTANCE_THRESHOLD:
		return

	_last_sent_tile_position = tile_position

	var packet := packets.Packet.new()
	var movement := packet.new_movement_input()

	movement.set_game_id(GameManager.current_game_id)
	movement.set_x(tile_position.x)
	movement.set_y(tile_position.y)

	WS.send(packet)


func _update_respawn_ui(delta: float) -> void:
	if not _local_is_dead:
		if _respawn_label != null:
			_respawn_label.visible = false
		return

	_local_respawn_remaining = max(0.0, _local_respawn_remaining - delta)

	if _respawn_label == null:
		return

	_respawn_label.visible = true
	_respawn_label.text = "Respawning in: %d" % max(1, int(ceil(_local_respawn_remaining)))


func _handle_skill_input() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_try_send_skill_request(SKILL_HASTE)

	if Input.is_key_pressed(KEY_E):
		_try_send_skill_request(SKILL_HEAL)

	if Input.is_key_pressed(KEY_F):
		_try_send_skill_request(SKILL_MOLOTOV)


func _try_send_skill_request(skill_id: int) -> void:
	if GameManager.current_game_id == 0:
		return

	if _match_ended:
		return

	if _local_is_dead:
		return

	if float(_skill_cooldown_remaining[skill_id]) > 0.0:
		return

	var target_tile := Vector2.ZERO

	if skill_id == SKILL_MOLOTOV:
		target_tile = world_to_tile(_get_mouse_world_position())

	var packet := packets.Packet.new()
	var request := packet.new_skill_request()

	request.set_game_id(GameManager.current_game_id)
	request.set_skill_id(skill_id)
	request.set_target_x(target_tile.x)
	request.set_target_y(target_tile.y)

	WS.send(packet)

	_skill_cooldown_remaining[skill_id] = 0.25
	_update_skill_ui()


func _update_skill_timers(delta: float) -> void:
	for skill_id in _skill_active_remaining.keys():
		var active_left: float = float(_skill_active_remaining[skill_id])
		if active_left > 0.0:
			_skill_active_remaining[skill_id] = max(0.0, active_left - delta)

	for skill_id in _skill_cooldown_remaining.keys():
		var cooldown_left: float = float(_skill_cooldown_remaining[skill_id])
		if cooldown_left > 0.0:
			_skill_cooldown_remaining[skill_id] = max(0.0, cooldown_left - delta)

	_update_skill_ui()


func _update_skill_ui() -> void:
	_apply_skill_ui(SKILL_HASTE, _speed_art, _speed_text, HASTE_READY_TEXT)
	_apply_skill_ui(SKILL_HEAL, _heal_art, _heal_text, HEAL_READY_TEXT)
	_apply_skill_ui(SKILL_MOLOTOV, _molotov_art, _molotov_text, MOLOTOV_READY_TEXT)


func _apply_skill_ui(skill_id: int, art: Sprite2D, label: Label, ready_text: String) -> void:
	if art == null or label == null:
		return

	var active_left: float = float(_skill_active_remaining[skill_id])
	var cooldown_left: float = float(_skill_cooldown_remaining[skill_id])

	if active_left > 0.0:
		art.modulate = SKILL_ACTIVE_COLOR
	elif cooldown_left > 0.0:
		art.modulate = SKILL_COOLDOWN_COLOR
	else:
		art.modulate = SKILL_READY_COLOR

	if cooldown_left > 0.0:
		label.text = _format_cooldown_text(cooldown_left)
	else:
		label.text = ready_text


func _format_cooldown_text(seconds_left: float) -> String:
	var rounded_seconds: int = int(ceil(seconds_left))
	return str(max(1, rounded_seconds))


func _on_ws_packet_received(packet: packets.Packet) -> void:
	if packet.has_spawn_player():
		_handle_spawn_player(packet.get_spawn_player())
	elif packet.has_despawn_player():
		_handle_despawn_player(packet.get_despawn_player())
	elif packet.has_player_moved():
		_handle_player_moved(packet.get_player_moved())
	elif packet.has_player_health_updated():
		_handle_player_health_updated(packet.get_player_health_updated())
	elif packet.has_spawn_flag():
		_handle_spawn_flag(packet.get_spawn_flag())
	elif packet.has_flag_state_updated():
		_handle_flag_state_updated(packet.get_flag_state_updated())
	elif packet.has_score_updated():
		_handle_score_updated(packet.get_score_updated())
	elif packet.has_game_time_updated():
		_handle_game_time_updated(packet.get_game_time_updated())
	elif packet.has_player_aim_updated():
		_handle_player_aim_updated(packet.get_player_aim_updated())
	elif packet.has_bullet_spawned():
		_handle_bullet_spawned(packet.get_bullet_spawned())
	elif packet.has_bullet_hit():
		_handle_bullet_hit(packet.get_bullet_hit())
	elif packet.has_skill_activated():
		_handle_skill_activated(packet.get_skill_activated())
	elif packet.has_player_healed():
		_handle_player_healed(packet.get_player_healed())
	elif packet.has_molotov_spawned():
		_handle_molotov_spawned(packet.get_molotov_spawned())
	elif packet.has_skill_damage():
		_handle_skill_damage(packet.get_skill_damage())
	elif packet.has_player_died():
		_handle_player_died(packet.get_player_died())
	elif packet.has_player_respawned():
		_handle_player_respawned(packet.get_player_respawned())
	elif packet.has_match_ended():
		_handle_match_ended(packet.get_match_ended())


func _on_ws_connection_closed() -> void:
	GameManager.clear_match_context()
	GameManager.set_state(GameManager.State.ENTERED)


func _handle_match_ended(msg: packets.MatchEndedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	_match_ended = true
	_local_is_dead = false

	if _respawn_label != null:
		_respawn_label.visible = false

	_red_score_label.text = str(int(msg.get_red_score()))
	_blue_score_label.text = str(int(msg.get_blue_score()))
	_timer_label.text = "00:00"

	if _result_panel != null:
		_result_panel.visible = true

	var winning_team: int = int(msg.get_winning_team())

	if winning_team == 0:
		_result_title.text = "Tie - Both Teams Lost"
	elif winning_team == TEAM_RED:
		_result_title.text = "Red Team Wins"
	else:
		_result_title.text = "Blue Team Wins"

	var local_won := false
	for result in msg.get_results():
		if int(result.get_player_id()) == GameManager.client_id:
			local_won = result.get_won()
			break

	if local_won:
		_play_sfx(_sfx_game_won)
	else:
		_play_sfx(_sfx_game_lost)

	_result_score.text = "Red %d - %d Blue" % [
		int(msg.get_red_score()),
		int(msg.get_blue_score())
	]

	for child in _result_rows.get_children():
		child.queue_free()

	for result in msg.get_results():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_result_rows.add_child(row)

		var result_text := "Loss"
		if result.get_won():
			result_text = "Win"

		var team_prefix := "R"
		if int(result.get_team()) == TEAM_BLUE:
			team_prefix = "B"

		var reported_player_id := int(result.get_player_id())
		var reported_player_name := str(result.get_nickname())

		_add_result_value_label(row, "%s - %s" % [team_prefix, reported_player_name], 170)
		_add_result_value_label(row, str(int(result.get_kills())), 45)
		_add_result_value_label(row, str(int(result.get_deaths())), 45)
		_add_result_value_label(row, str(int(result.get_captures())), 55)
		_add_result_value_label(row, result_text, 100)
		_add_result_report_button(
			row,
			reported_player_id,
			reported_player_name,
			int(msg.get_game_id())
		)


func _on_return_lobby_pressed() -> void:
	var packet := packets.Packet.new()
	packet.new_request_return_to_lobby()
	WS.send(packet)

	GameManager.clear_match_context()
	GameManager.set_state(GameManager.State.LOBBY)


func _handle_player_died(msg: packets.PlayerDiedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())

	var player_variant: Variant = _players.get(player_id)
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player != null:
		player.set_health(0, player.max_hp)
		player.set_dead_visual(true)

	if player_id == GameManager.client_id:
		_play_sfx(_sfx_death)

		var local_max_hp := 100
		if player != null:
			local_max_hp = player.max_hp
		_update_main_hp_bar(0, local_max_hp)

		_local_is_dead = true
		_local_respawn_remaining = float(msg.get_respawn_seconds())
		_shoot_cooldown_remaining = 0.0
		_skill_active_remaining[SKILL_HASTE] = 0.0
		_update_skill_ui()


func _handle_player_respawned(msg: packets.PlayerRespawnedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())
	var world_pos := tile_to_world(Vector2(float(msg.get_x()), float(msg.get_y())))

	var player_variant: Variant = _players.get(player_id)
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player == null:
		return

	player.set_world_position_immediate(world_pos)
	player.set_health(int(msg.get_current_hp()), int(msg.get_max_hp()))
	player.set_dead_visual(false)

	if player_id == GameManager.client_id:
		_update_main_hp_bar(int(msg.get_current_hp()), int(msg.get_max_hp()))
		_local_is_dead = false
		_local_respawn_remaining = 0.0

		if _respawn_label != null:
			_respawn_label.visible = false

		_last_sent_tile_position = Vector2(float(msg.get_x()), float(msg.get_y()))


func _handle_skill_activated(msg: packets.SkillActivatedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())
	var skill_id: int = int(msg.get_skill_id())

	if player_id == GameManager.client_id:
		_skill_active_remaining[skill_id] = float(msg.get_active_ms()) / 1000.0
		_skill_cooldown_remaining[skill_id] = float(msg.get_cooldown_ms()) / 1000.0
		_update_skill_ui()


func _handle_player_healed(msg: packets.PlayerHealedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var target_player_id: int = int(msg.get_target_player_id())

	var target_variant: Variant = _players.get(target_player_id)
	var target: NetworkPlayerVisual = target_variant as NetworkPlayerVisual

	if target != null:
		target.set_health(int(msg.get_current_hp()), int(msg.get_max_hp()))
		_update_main_hp_bar_if_local(target_player_id, int(msg.get_current_hp()), int(msg.get_max_hp()))

	var heal_world_position := tile_to_world(Vector2(float(msg.get_x()), float(msg.get_y())))

	_spawn_damage_number(int(msg.get_amount()), heal_world_position + Vector2(0, -28), true)


func _handle_molotov_spawned(msg: packets.MolotovSpawnedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var molotov := MolotovFlameAreaScript.new() as MolotovFlameArea
	_skills_root.add_child(molotov)

	molotov.setup(
		tile_to_world(Vector2(float(msg.get_x()), float(msg.get_y()))),
		float(msg.get_radius_tiles()) * TILE_SIZE,
		float(msg.get_duration_seconds())
	)


func _handle_skill_damage(msg: packets.SkillDamageMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var victim_player_id: int = int(msg.get_victim_player_id())

	var victim_variant: Variant = _players.get(victim_player_id)
	var victim: NetworkPlayerVisual = victim_variant as NetworkPlayerVisual

	if victim != null:
		victim.set_health(int(msg.get_current_hp()), int(msg.get_max_hp()))
		_update_main_hp_bar_if_local(victim_player_id, int(msg.get_current_hp()), int(msg.get_max_hp()))

	var damage_world_position := tile_to_world(Vector2(float(msg.get_x()), float(msg.get_y())))
	_spawn_damage_number(int(msg.get_damage()), damage_world_position + Vector2(0, -28), false)


func _handle_spawn_player(msg: packets.SpawnPlayerMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())
	var world_pos: Vector2 = tile_to_world(Vector2(msg.get_x(), msg.get_y()))

	var player_variant: Variant = _players.get(player_id)
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player == null:
		player = NetworkPlayerVisualScript.new()
		_players_root.add_child(player)
		_players[player_id] = player

	player.setup(
		player_id,
		int(msg.get_team()),
		int(msg.get_slot()),
		player_id == GameManager.client_id,
		world_pos,
		msg.get_nickname(),
		int(msg.get_skin_id()),
		int(msg.get_current_hp()),
		int(msg.get_max_hp()),
		float(msg.get_aim_x()),
		float(msg.get_aim_y())
	)

	if player_id == GameManager.client_id:
		_update_main_hp_bar(int(msg.get_current_hp()), int(msg.get_max_hp()))
		_last_sent_tile_position = Vector2(msg.get_x(), msg.get_y())

		var spawn_aim := Vector2(float(msg.get_aim_x()), float(msg.get_aim_y()))
		if spawn_aim.length_squared() > 0.001:
			_last_sent_aim_direction = spawn_aim.normalized()
		else:
			_last_sent_aim_direction = Vector2.RIGHT

		_camera.reparent(player)
		_camera.position = Vector2.ZERO
		_camera.make_current()


func _handle_despawn_player(msg: packets.DespawnPlayerMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())

	if not _players.has(player_id):
		return

	var player_variant: Variant = _players[player_id]
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player == null:
		_players.erase(player_id)
		return

	player.queue_free()
	_players.erase(player_id)


func _handle_player_moved(msg: packets.PlayerMovedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())

	if player_id == GameManager.client_id:
		return

	var player_variant: Variant = _players.get(player_id)
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player == null:
		return

	player.set_target_world_position(tile_to_world(Vector2(msg.get_x(), msg.get_y())))


func _handle_player_health_updated(msg: packets.PlayerHealthUpdatedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())

	var player_variant: Variant = _players.get(player_id)
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player == null:
		return

	player.set_health(int(msg.get_current_hp()), int(msg.get_max_hp()))
	_update_main_hp_bar_if_local(player_id, int(msg.get_current_hp()), int(msg.get_max_hp()))


func _handle_spawn_flag(msg: packets.SpawnFlagMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var flag_team: int = int(msg.get_team())
	var world_pos: Vector2 = tile_to_world(Vector2(msg.get_x(), msg.get_y()))

	var flag_variant: Variant = _flags.get(flag_team)
	var flag: TeamFlagVisual = flag_variant as TeamFlagVisual

	if flag == null:
		flag = TEAM_FLAG_SCENE.instantiate() as TeamFlagVisual
		_flags_root.add_child(flag)
		_flags[flag_team] = flag

	flag.setup(flag_team, world_pos, int(msg.get_status()), int(msg.get_carrier_player_id()))


func _handle_flag_state_updated(msg: packets.FlagStateUpdatedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var flag_team: int = int(msg.get_team())
	var world_pos: Vector2 = tile_to_world(Vector2(msg.get_x(), msg.get_y()))
	var new_status: int = int(msg.get_status())
	var new_carrier_player_id: int = int(msg.get_carrier_player_id())

	var flag_variant: Variant = _flags.get(flag_team)
	var flag: TeamFlagVisual = flag_variant as TeamFlagVisual

	if flag == null:
		flag = TEAM_FLAG_SCENE.instantiate() as TeamFlagVisual
		_flags_root.add_child(flag)
		_flags[flag_team] = flag
		flag.setup(flag_team, world_pos, new_status, new_carrier_player_id)
		return

	var old_status: int = flag.status
	var old_carrier_player_id: int = flag.carrier_player_id

	flag.set_state(world_pos, new_status, new_carrier_player_id)

	if new_status == FLAG_STATUS_CARRIED and new_carrier_player_id != 0:
		if old_status != FLAG_STATUS_CARRIED or old_carrier_player_id != new_carrier_player_id:
			_play_sfx(_sfx_flag_pickup)

	if old_status == FLAG_STATUS_CARRIED and new_status == FLAG_STATUS_DROPPED:
		_play_sfx(_sfx_flag_dropped)


func _handle_score_updated(msg: packets.ScoreUpdatedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var new_red_score: int = int(msg.get_red_score())
	var new_blue_score: int = int(msg.get_blue_score())

	if new_red_score > _last_red_score or new_blue_score > _last_blue_score:
		_play_sfx(_sfx_flag_captured)

	_last_red_score = new_red_score
	_last_blue_score = new_blue_score

	_red_score_label.text = str(new_red_score)
	_blue_score_label.text = str(new_blue_score)


func _handle_game_time_updated(msg: packets.GameTimeUpdatedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	if _match_ended:
		return

	var remaining_seconds: int = max(0, int(msg.get_remaining_seconds()))
	_timer_label.text = _format_seconds_as_timer(remaining_seconds)


func _handle_player_aim_updated(msg: packets.PlayerAimUpdatedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var player_id: int = int(msg.get_player_id())

	var player_variant: Variant = _players.get(player_id)
	var player: NetworkPlayerVisual = player_variant as NetworkPlayerVisual

	if player == null:
		return

	player.set_aim_direction(Vector2(float(msg.get_aim_x()), float(msg.get_aim_y())))


func _handle_bullet_spawned(msg: packets.BulletSpawnedMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	if _match_ended:
		return

	var bullet_id: int = int(msg.get_bullet_id())

	var bullet := PlayerBulletVisualScript.new() as PlayerBulletVisual
	_bullets_root.add_child(bullet)

	bullet.setup(
		bullet_id,
		int(msg.get_owner_player_id()),
		tile_to_world(Vector2(float(msg.get_x()), float(msg.get_y()))),
		Vector2(float(msg.get_dir_x()), float(msg.get_dir_y())),
		float(msg.get_speed_tiles_per_second()),
		float(msg.get_lifetime_seconds()),
		TILE_SIZE
	)

	_bullets[bullet_id] = bullet


func _handle_bullet_hit(msg: packets.BulletHitMessage) -> void:
	if msg.get_game_id() != GameManager.current_game_id:
		return

	var bullet_id: int = int(msg.get_bullet_id())
	var victim_player_id: int = int(msg.get_victim_player_id())

	if _bullets.has(bullet_id):
		var bullet_variant: Variant = _bullets[bullet_id]

		if bullet_variant != null and is_instance_valid(bullet_variant):
			var bullet: PlayerBulletVisual = bullet_variant as PlayerBulletVisual
			if bullet != null:
				bullet.queue_free()

		_bullets.erase(bullet_id)

	var victim_variant: Variant = _players.get(victim_player_id)
	var victim: NetworkPlayerVisual = victim_variant as NetworkPlayerVisual

	if victim != null:
		victim.set_health(int(msg.get_current_hp()), int(msg.get_max_hp()))
		_update_main_hp_bar_if_local(victim_player_id, int(msg.get_current_hp()), int(msg.get_max_hp()))

	var damage_world_position := tile_to_world(Vector2(float(msg.get_x()), float(msg.get_y())))
	_spawn_damage_number(int(msg.get_damage()), damage_world_position + Vector2(0, -28), false)


func _spawn_damage_number(value: int, world_position: Vector2, is_heal: bool) -> void:
	var damage_number := PlayerDamageNumberScript.new() as PlayerDamageNumber
	_damage_numbers_root.add_child(damage_number)
	damage_number.setup(value, world_position, is_heal)


func _format_seconds_as_timer(total_seconds: int) -> String:
	var minutes: int = int(total_seconds / 60)
	var seconds: int = total_seconds % 60

	return "%02d:%02d" % [minutes, seconds]


func _update_local_player_aim(delta: float) -> void:
	var local_player_variant: Variant = _players.get(GameManager.client_id)
	var local_player: NetworkPlayerVisual = local_player_variant as NetworkPlayerVisual

	if local_player == null:
		return

	var mouse_world_position := _get_mouse_world_position()
	var direction := mouse_world_position - local_player.global_position

	if direction.length_squared() <= 0.001:
		return

	var aim_direction := direction.normalized()

	local_player.set_aim_direction(aim_direction)

	_aim_send_accumulator += delta

	if _aim_send_accumulator < AIM_SEND_INTERVAL:
		return

	_aim_send_accumulator = 0.0

	if aim_direction.distance_to(_last_sent_aim_direction) < AIM_DIRECTION_SEND_THRESHOLD:
		return

	_last_sent_aim_direction = aim_direction

	var packet := packets.Packet.new()
	var aim_input := packet.new_aim_input()

	aim_input.set_game_id(GameManager.current_game_id)
	aim_input.set_aim_x(aim_direction.x)
	aim_input.set_aim_y(aim_direction.y)

	WS.send(packet)


func _send_shoot_request() -> void:
	if GameManager.current_game_id == 0:
		return

	if _match_ended:
		return

	if _local_is_dead:
		return

	if _shoot_cooldown_remaining > 0.0:
		return

	var local_player_variant: Variant = _players.get(GameManager.client_id)
	var local_player: NetworkPlayerVisual = local_player_variant as NetworkPlayerVisual

	if local_player == null:
		return

	var aim_direction := local_player.get_aim_direction()

	if aim_direction.length_squared() <= 0.001:
		return

	aim_direction = aim_direction.normalized()

	_shoot_cooldown_remaining = SHOOT_COOLDOWN_SECONDS

	var packet := packets.Packet.new()
	var shoot_request := packet.new_shoot_request()

	shoot_request.set_game_id(GameManager.current_game_id)
	shoot_request.set_aim_x(aim_direction.x)
	shoot_request.set_aim_y(aim_direction.y)

	WS.send(packet)
	_play_sfx(_sfx_shoot)


func _update_carried_flags() -> void:
	for flag_team in _flags.keys():
		var flag_variant: Variant = _flags[flag_team]
		var flag: TeamFlagVisual = flag_variant as TeamFlagVisual

		if flag == null:
			continue

		if not flag.is_carried():
			continue

		var carrier_variant: Variant = _players.get(flag.carrier_player_id)
		var carrier: NetworkPlayerVisual = carrier_variant as NetworkPlayerVisual

		if carrier == null:
			continue

		flag.global_position = carrier.global_position + Vector2(0, -22)


func _cleanup_dead_bullet_references() -> void:
	var bullet_ids_to_remove: Array = []

	for bullet_id in _bullets.keys():
		var bullet_variant: Variant = _bullets[bullet_id]

		if bullet_variant == null:
			bullet_ids_to_remove.append(bullet_id)
			continue

		if not is_instance_valid(bullet_variant):
			bullet_ids_to_remove.append(bullet_id)
			continue

		var bullet: PlayerBulletVisual = bullet_variant as PlayerBulletVisual

		if bullet == null:
			bullet_ids_to_remove.append(bullet_id)
			continue

		if bullet.is_queued_for_deletion():
			bullet_ids_to_remove.append(bullet_id)

	for bullet_id in bullet_ids_to_remove:
		_bullets.erase(bullet_id)


func _get_mouse_world_position() -> Vector2:
	var mouse_screen_position: Vector2 = get_viewport().get_mouse_position()
	return _camera.get_canvas_transform().affine_inverse() * mouse_screen_position


func tile_to_world(tile_pos: Vector2) -> Vector2:
	return Vector2(
		tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func world_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		(world_pos.x - TILE_SIZE * 0.5) / TILE_SIZE,
		(world_pos.y - TILE_SIZE * 0.5) / TILE_SIZE
	)
