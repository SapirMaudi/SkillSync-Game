extends Area2D
class_name TeamFlagVisual

const TEAM_RED := 1
const TEAM_BLUE := 2

const STATUS_AT_BASE := 0
const STATUS_CARRIED := 1
const STATUS_DROPPED := 2

var team: int = TEAM_RED
var status: int = STATUS_AT_BASE
var carrier_player_id: int = 0

@onready var _red_flag: Sprite2D = $RedFlag
@onready var _blue_flag: Sprite2D = $BlueFlag


func _ready() -> void:
	_apply_team_visual()


func setup(new_team: int, start_position: Vector2, new_status: int, new_carrier_player_id: int) -> void:
	team = new_team
	global_position = start_position
	status = new_status
	carrier_player_id = new_carrier_player_id

	if is_node_ready():
		_apply_team_visual()


func set_state(new_position: Vector2, new_status: int, new_carrier_player_id: int) -> void:
	global_position = new_position
	status = new_status
	carrier_player_id = new_carrier_player_id

	if is_node_ready():
		_apply_team_visual()


func is_carried() -> bool:
	return status == STATUS_CARRIED and carrier_player_id != 0


func _apply_team_visual() -> void:
	_red_flag.visible = team == TEAM_RED
	_blue_flag.visible = team == TEAM_BLUE
