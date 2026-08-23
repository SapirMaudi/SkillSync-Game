extends Node

enum State {
	ENTERED,
	CONNECTED,
	REGISTER,
	LOBBY,
	SETTINGS,
	INQUEUE,
	INGAME,
}

var _state_scenes: Dictionary[State, String] = {
	State.ENTERED: "res://states/entered/entered.tscn",
	State.CONNECTED: "res://states/connected/connected.tscn",
	State.REGISTER: "res://states/connected/register.tscn",
	State.LOBBY: "res://states/lobby/lobby.tscn",
	State.SETTINGS: "res://states/settings/Settings.tscn",
	State.INQUEUE: "res://states/inqueue/inqueue.tscn",
	State.INGAME: "res://states/ingame/ingame.tscn",
}

var client_id: int
var current_game_id: int = 0
var current_team: int = 0
var current_team_ids: Array = []
var current_enemy_ids: Array = []

var _current_scene_root: Node

func set_match_context(game_id: int, team: int, team_ids: Array, enemy_ids: Array) -> void:
	current_game_id = game_id
	current_team = team
	current_team_ids = team_ids.duplicate()
	current_enemy_ids = enemy_ids.duplicate()

func clear_match_context() -> void:
	current_game_id = 0
	current_team = 0
	current_team_ids = []
	current_enemy_ids = []

func set_state(state: State) -> void:
	if state != State.INGAME:
		if _current_scene_root != null and _current_scene_root.get_name() == "Ingame":
			clear_match_context()

	if _current_scene_root != null:
		_current_scene_root.queue_free()

	var scene: PackedScene = load(_state_scenes[state])
	_current_scene_root = scene.instantiate()
	add_child(_current_scene_root)
