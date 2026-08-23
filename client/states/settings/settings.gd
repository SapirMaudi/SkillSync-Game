extends Node

const packets := preload("res://packets.gd")

const SETTINGS_CHANGE_NICKNAME_PREFIX := "SETTINGS_CHANGE_NICKNAME:"
const SETTINGS_CHANGE_PASSWORD_PREFIX := "SETTINGS_CHANGE_PASSWORD:"
const SETTINGS_RESPONSE_PREFIX := "SETTINGS_RESPONSE:"

@onready var _button_left: Button = $UI/VBoxContainer/HBoxContainer/ButtonLeft
@onready var _button_right: Button = $UI/VBoxContainer/HBoxContainer/ButtonRight
@onready var _save_button: Button = $UI/VBoxContainer/HBoxContainer2/SaveButton
@onready var _catman: CharacterBody2D = $UI/VBoxContainer/HBoxContainer/HBoxContainer/Catman
@onready var _oldman: CharacterBody2D = $UI/VBoxContainer/HBoxContainer/HBoxContainer/Oldman

var g_skin_id = 0

var _change_nickname_button: Button
var _change_password_button: Button

var _settings_overlay_layer: CanvasLayer
var _settings_panel: PanelContainer
var _settings_title_label: Label
var _settings_input: LineEdit
var _settings_status_label: Label
var _settings_action: String = ""


func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)

	_save_button.pressed.connect(_on_save_button_pressed)
	_button_left.pressed.connect(_on_left_button_pressed)
	_button_right.pressed.connect(_on_right_button_pressed)

	_create_extra_settings_buttons()
	_create_settings_overlay()

	var packet3 := packets.Packet.new()
	var req_skin := packet3.new_request_general_info()
	req_skin.set_info("skin")
	WS.send(packet3)


func _create_extra_settings_buttons() -> void:
	var parent := _save_button.get_parent()

	_change_nickname_button = Button.new()
	_change_nickname_button.text = "Change Nickname"
	_change_nickname_button.custom_minimum_size = Vector2(170, 40)
	_change_nickname_button.pressed.connect(_on_change_nickname_pressed)
	parent.add_child(_change_nickname_button)

	_change_password_button = Button.new()
	_change_password_button.text = "Change Password"
	_change_password_button.custom_minimum_size = Vector2(170, 40)
	_change_password_button.pressed.connect(_on_change_password_pressed)
	parent.add_child(_change_password_button)


func _create_settings_overlay() -> void:
	_settings_overlay_layer = CanvasLayer.new()
	_settings_overlay_layer.name = "SettingsChangeOverlay"
	add_child(_settings_overlay_layer)

	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left = -230
	_settings_panel.offset_right = 230
	_settings_panel.offset_top = -140
	_settings_panel.offset_bottom = 140
	_settings_overlay_layer.add_child(_settings_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(460, 280)
	root.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(root)

	_settings_title_label = Label.new()
	_settings_title_label.text = "Change Settings"
	_settings_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_title_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_settings_title_label)

	_settings_input = LineEdit.new()
	_settings_input.placeholder_text = "Enter value..."
	root.add_child(_settings_input)

	_settings_status_label = Label.new()
	_settings_status_label.text = ""
	_settings_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_settings_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	var send_button := Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(120, 36)
	send_button.pressed.connect(_on_overlay_send_pressed)
	buttons.add_child(send_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(120, 36)
	cancel_button.pressed.connect(_close_settings_overlay)
	buttons.add_child(cancel_button)


func _on_ws_packet_received(packet: packets.Packet) -> void:
	var _sender_id := packet.get_sender_id()

	if packet.has_response_user_skin():
		var skin := packet.get_response_user_skin().get_skin_id()
		if skin == 0:
			g_skin_id = 0
			_oldman.visible = false
			_catman.visible = true
		elif skin == 1:
			g_skin_id = 1
			_catman.visible = false
			_oldman.visible = true

	elif packet.has_chat():
		var msg := packet.get_chat().get_msg()
		if msg.begins_with(SETTINGS_RESPONSE_PREFIX):
			_handle_settings_response(msg.substr(SETTINGS_RESPONSE_PREFIX.length()))


func _handle_settings_response(json_text: String) -> void:
	var parsed: Variant = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		_settings_status_label.text = "Invalid server response."
		return

	var success := bool(parsed.get("success", false))
	var message := str(parsed.get("message", ""))

	_settings_status_label.text = message

	if success:
		await get_tree().create_timer(1.0).timeout
		_close_settings_overlay()


func _on_ws_connection_closed() -> void:
	print("Lost Connection...")


func _on_save_button_pressed() -> void:
	var packet := packets.Packet.new()
	var save_skin := packet.new_request_update_user_skin()
	save_skin.set_skin_id(g_skin_id)
	WS.send(packet)

	GameManager.set_state(GameManager.State.LOBBY)


func _on_change_nickname_pressed() -> void:
	_settings_action = "nickname"
	_settings_title_label.text = "Change Nickname"
	_settings_input.text = ""
	_settings_input.placeholder_text = "Enter new nickname"
	_settings_input.secret = false
	_settings_status_label.text = ""
	_settings_panel.visible = true
	_settings_input.grab_focus()


func _on_change_password_pressed() -> void:
	_settings_action = "password"
	_settings_title_label.text = "Change Password"
	_settings_input.text = ""
	_settings_input.placeholder_text = "Enter new password"
	_settings_input.secret = true
	_settings_status_label.text = ""
	_settings_panel.visible = true
	_settings_input.grab_focus()


func _on_overlay_send_pressed() -> void:
	var value := _settings_input.text

	if WS.get_socket().get_ready_state() != WebSocketPeer.STATE_OPEN:
		_settings_status_label.text = "Not connected to server."
		return

	if _settings_action == "nickname":
		var payload := {
			"nickname": value
		}

		var packet := packets.Packet.new()
		var chat := packet.new_chat()
		chat.set_msg(SETTINGS_CHANGE_NICKNAME_PREFIX + JSON.stringify(payload))
		WS.send(packet)

		_settings_status_label.text = "Changing nickname..."
		return

	if _settings_action == "password":
		var payload := {
			"password": value
		}

		var packet := packets.Packet.new()
		var chat := packet.new_chat()
		chat.set_msg(SETTINGS_CHANGE_PASSWORD_PREFIX + JSON.stringify(payload))
		WS.send(packet)

		_settings_status_label.text = "Changing password..."
		return


func _close_settings_overlay() -> void:
	_settings_panel.visible = false
	_settings_status_label.text = ""
	_settings_input.text = ""
	_settings_action = ""


func _on_left_button_pressed() -> void:
	g_skin_id = g_skin_id - 1
	if g_skin_id < 0:
		g_skin_id = 1
	elif g_skin_id > 1:
		g_skin_id = 0

	if g_skin_id == 0:
		_oldman.visible = false
		_catman.visible = true
	elif g_skin_id == 1:
		_catman.visible = false
		_oldman.visible = true


func _on_right_button_pressed() -> void:
	g_skin_id = g_skin_id + 1
	if g_skin_id < 0:
		g_skin_id = 1
	elif g_skin_id > 1:
		g_skin_id = 0

	if g_skin_id == 0:
		_oldman.visible = false
		_catman.visible = true
	elif g_skin_id == 1:
		_catman.visible = false
		_oldman.visible = true
