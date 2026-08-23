extends Node

const packets := preload("res://packets.gd")
const SupportReportUI := preload("res://classes/support_report/support_report_ui.gd")

var _action_on_on_received: Callable
var _support_report_ui: SupportReportUI

@onready var _nickname: LineEdit = $UI/VBoxContainer/Nickname
@onready var _email: LineEdit = $UI/VBoxContainer/Email
@onready var _password: LineEdit = $UI/VBoxContainer/Password
@onready var _password_re: LineEdit = $UI/VBoxContainer/PasswordRe
@onready var _register_button: Button = $UI/VBoxContainer/HBoxContainer/RegisterButton
@onready var _goto_login: Button = $UI/VBoxContainer/HBoxContainer/GotoLogin
@onready var _log: Log = $UI/VBoxContainer/Log


func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_register_button.pressed.connect(_on_register_button_pressed)
	_goto_login.pressed.connect(_on_goto_login_pressed)
	_setup_support_report_button()


func _setup_support_report_button() -> void:
	_support_report_ui = SupportReportUI.new()
	_support_report_ui.setup("register", ["Report Bug"])
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
	
func _on_register_button_pressed() -> void:
	if _password.text != _password_re.text:
		_log.clear()
		_log.warn("Password Missmatch!")
		return
	
	var packet := packets.Packet.new()
	var register_req_msg := packet.new_register_request()
	register_req_msg.set_nickname(_nickname.text)
	register_req_msg.set_email(_email.text)
	register_req_msg.set_password(_password.text)
	WS.send(packet)
	_action_on_on_received = func(): 
		_log.clear()
		_log.success("Registration Complete.")
	
func _on_goto_login_pressed() -> void:
	GameManager.set_state(GameManager.State.CONNECTED)
