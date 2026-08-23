extends Node

const packets := preload("res://packets.gd")

@onready var _timer_label: Label = $UI/VBoxContainer/TimerLabel
@onready var _status_label: Label = $UI/VBoxContainer/StatusLabel
@onready var _quit_button: Button = $UI/VBoxContainer/QuitButton
@onready var _timer: Timer = $UI/VBoxContainer/Timer

var cur_time = 0

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_timer.timeout.connect(_on_timer_out)
	_quit_button.pressed.connect(_on_quit_button_pressed)

func _on_ws_packet_received(packet: packets.Packet) -> void:
	var _sender_id := packet.get_sender_id()

	if packet.has_queue_left():
		GameManager.set_state(GameManager.State.LOBBY)
	elif packet.has_queue_joined():
		if packet.get_queue_joined().get_position() == 0:
			_status_label.text = "Team-mate found. Looking for the other team..."
		else:
			_status_label.text = "Looking For a Team Mate..."
	elif packet.has_match_found():
		var match := packet.get_match_found()
		GameManager.set_match_context(
			match.get_game_id(),
			match.get_team(),
			match.get_team_ids(),
			match.get_enemy_ids(),
		)
		GameManager.set_state(GameManager.State.INGAME)

func _on_ws_connection_closed() -> void:
	pass

func _on_timer_out() -> void:
	cur_time += 1
	_timer_label.text = str(cur_time) + " secs in-queue."

func _on_quit_button_pressed() -> void:
	var quit_packet := packets.Packet.new()
	var _req_nick := quit_packet.new_request_leave_queue()
	WS.send(quit_packet)
