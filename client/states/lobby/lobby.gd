extends Node

const packets := preload("res://packets.gd")
const SupportReportUI := preload("res://classes/support_report/support_report_ui.gd")

var _support_report_ui: SupportReportUI

@onready var _settings_button: Button = $UI/VBoxContainer/HBoxContainer/SettingsButton
@onready var _welcome_msg: Label = $UI/VBoxContainer/WelcomeMsg
@onready var _user_stats: Label = $UI/VBoxContainer/UserStats
@onready var _catman: CharacterBody2D = $UI/VBoxContainer/VBoxContainer/Catman
@onready var _oldman: CharacterBody2D = $UI/VBoxContainer/VBoxContainer/Oldman
@onready var _play_button: Button = $UI/VBoxContainer/HBoxContainer2/PlayButton

func _ready() -> void:
	WS.connection_closed.connect(_on_ws_connection_closed)
	WS.packet_received.connect(_on_ws_packet_received)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_play_button.pressed.connect(_on_play_button_pressed)
	_setup_support_report_button()

	var packet := packets.Packet.new()
	var req_nick := packet.new_request_general_info()
	req_nick.set_info("nickname")
	WS.send(packet)

	var packet2 := packets.Packet.new()
	var req_stats := packet2.new_request_general_info()
	req_stats.set_info("stats")
	WS.send(packet2)

	var packet3 := packets.Packet.new()
	var req_skin := packet3.new_request_general_info()
	req_skin.set_info("skin")
	WS.send(packet3)


func _setup_support_report_button() -> void:
	_support_report_ui = SupportReportUI.new()
	_support_report_ui.setup("lobby", ["Report Bug", "Connection Problem", "Other"])
	add_child(_support_report_ui)


func _on_ws_connection_closed() -> void:
	print("Connection Lost.")

func _on_ws_packet_received(packet: packets.Packet) -> void:
	var _sender_id := packet.get_sender_id()

	if packet.has_response_user_name():
		var nickname := packet.get_response_user_name().get_nickname()
		_welcome_msg.text = "Welcome, " + nickname
	elif packet.has_response_user_stats():
		var stats := packet.get_response_user_stats()
		_user_stats.text = "Kills: " + str(stats.get_kills()) + " / Deaths: " + str(stats.get_deaths()) + " / Wins: " + str(stats.get_wins()) + " / Losses: " + str(stats.get_losses()) + " / FC: " + str(stats.get_flags_captured())
	elif packet.has_response_user_skin():
		var skin := packet.get_response_user_skin().get_skin_id()
		if skin == 0:
			_oldman.visible = false
			_catman.visible = true
		elif skin == 1:
			_catman.visible = false
			_oldman.visible = true
	elif packet.has_queue_joined():
		GameManager.set_state(GameManager.State.INQUEUE)
	elif packet.has_match_found():
		var match := packet.get_match_found()
		GameManager.set_match_context(
			match.get_game_id(),
			match.get_team(),
			match.get_team_ids(),
			match.get_enemy_ids(),
		)
		GameManager.set_state(GameManager.State.INGAME)

func _on_settings_button_pressed() -> void:
	GameManager.set_state(GameManager.State.SETTINGS)

func _on_play_button_pressed() -> void:
	var packet_play := packets.Packet.new()
	var _req_play := packet_play.new_request_enter_queue()
	WS.send(packet_play)
