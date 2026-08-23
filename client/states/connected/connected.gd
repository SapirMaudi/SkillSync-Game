extends Node

const packets := preload("res://packets.gd")
const SupportReportUI := preload("res://classes/support_report/support_report_ui.gd")

var _action_on_on_received: Callable
var _support_report_ui: SupportReportUI

@onready var _email_field: LineEdit = $UI/VBoxContainer/Email
@onready var _password_field: LineEdit = $UI/VBoxContainer/Password
@onready var _login_button: Button = $UI/VBoxContainer/HBoxContainer/LoginButton
@onready var _goto_register: Button = $UI/VBoxContainer/HBoxContainer/GotoRegister
@onready var _log: Log = $UI/VBoxContainer/Log


func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_login_button.pressed.connect(_on_login_button_pressed)
	_goto_register.pressed.connect(_on_goto_register_pressed)
	_setup_support_report_button()


func _setup_support_report_button() -> void:
	_support_report_ui = SupportReportUI.new()
	_support_report_ui.setup("login", ["Report Bug"])
	add_child(_support_report_ui)


func _on_ws_packet_received(packet: packets.Packet) -> void:
	var _sender_id := packet.get_sender_id()
	if packet.has_error_response():
		var error_response_msg := packet.get_error_response()
		_log.clear()
		_log.error(error_response_msg.get_reason())
	elif packet.has_ok_response():
		if _action_on_on_received.is_valid():
			_action_on_on_received.call()
	
func _on_ws_connection_closed() -> void:
	_log.warn("Connection closed")
	
func _on_login_button_pressed() -> void:
	var packet := packets.Packet.new()
	var login_req_msg := packet.new_login_request()
	login_req_msg.set_email(_email_field.text)
	login_req_msg.set_password(_password_field.text)
	WS.send(packet)
	_action_on_on_received = func(): GameManager.set_state(GameManager.State.LOBBY)
	
func _on_goto_register_pressed() -> void:
	GameManager.set_state(GameManager.State.REGISTER)
