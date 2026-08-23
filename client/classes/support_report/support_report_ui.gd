extends CanvasLayer
class_name SupportReportUI

const packets := preload("res://packets.gd")

const REPORT_PREFIX := "SUPPORT_REPORT:"
const RESPONSE_PREFIX := "SUPPORT_REPORT_RESPONSE:"

const ADMIN_GET_PREFIX := "ADMIN_REPORTS_GET:"
const ADMIN_RESPONSE_PREFIX := "ADMIN_REPORTS_RESPONSE:"
const ADMIN_RESOLVE_PREFIX := "ADMIN_REPORT_RESOLVE:"
const ADMIN_RESOLVE_RESPONSE_PREFIX := "ADMIN_REPORT_RESOLVE_RESPONSE:"

const BUG_REPORT_CATEGORIES: Array[String] = [
	"Report Bug",
	"Connection Problem",
	"Other"
]

const PLAYER_REPORT_CATEGORIES: Array[String] = [
	"Cheating",
	"Toxic Behavior",
	"AFK / Griefing",
	"Other"
]

var _screen_name: String = "unknown"
var _categories: Array[String] = []
var _selected_category: String = ""

var _active_report_type: String = "bug"
var _active_screen_name: String = "unknown"
var _active_reported_player_id: int = 0
var _active_reported_player_name: String = ""
var _active_game_id: int = 0

var _report_button: Button
var _menu_panel: PanelContainer
var _form_panel: PanelContainer
var _admin_panel: PanelContainer

var _menu_title_label: Label
var _form_title_label: Label
var _category_list: VBoxContainer
var _description_box: TextEdit
var _status_label: Label
var _category_label: Label

var _admin_status_label: Label
var _admin_reports_root: VBoxContainer


func setup(screen_name: String, categories: Array[String]) -> void:
	_screen_name = screen_name
	_categories = categories

	if _categories.is_empty():
		_categories = BUG_REPORT_CATEGORIES.duplicate()


func _ready() -> void:
	_build_ui()

	if not WS.packet_received.is_connected(_on_ws_packet_received):
		WS.packet_received.connect(_on_ws_packet_received)


# Public function used by the match-result screen.
func open_player_report(reported_player_id: int, reported_player_name: String, game_id: int) -> void:
	if reported_player_id <= 0:
		return

	_open_category_menu(
		"player",
		"match_result",
		PLAYER_REPORT_CATEGORIES,
		reported_player_id,
		reported_player_name,
		game_id,
		"Report player: " + reported_player_name
	)


func _build_ui() -> void:
	_report_button = Button.new()
	_report_button.text = "🚨"
	_report_button.tooltip_text = "Report a problem"
	_report_button.custom_minimum_size = Vector2(48, 48)

	_report_button.anchor_left = 1.0
	_report_button.anchor_right = 1.0
	_report_button.anchor_top = 0.0
	_report_button.anchor_bottom = 0.0

	_report_button.offset_left = -64
	_report_button.offset_right = -16
	_report_button.offset_top = 16
	_report_button.offset_bottom = 64

	_report_button.pressed.connect(_on_report_button_pressed)
	add_child(_report_button)

	_build_menu_panel()
	_build_form_panel()
	_build_admin_panel()


func _build_menu_panel() -> void:
	_menu_panel = PanelContainer.new()
	_menu_panel.visible = false

	_menu_panel.anchor_left = 1.0
	_menu_panel.anchor_right = 1.0
	_menu_panel.anchor_top = 0.0
	_menu_panel.anchor_bottom = 0.0

	_menu_panel.offset_left = -280
	_menu_panel.offset_right = -16
	_menu_panel.offset_top = 72
	_menu_panel.offset_bottom = 320

	add_child(_menu_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(264, 0)
	_menu_panel.add_child(root)

	_menu_title_label = Label.new()
	_menu_title_label.text = "What do you want to report?"
	_menu_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_menu_title_label)

	_category_list = VBoxContainer.new()
	root.add_child(_category_list)

	var close_button := Button.new()
	close_button.text = "Cancel"
	close_button.pressed.connect(_close_all)
	root.add_child(close_button)


func _build_form_panel() -> void:
	_form_panel = PanelContainer.new()
	_form_panel.visible = false

	_form_panel.anchor_left = 0.5
	_form_panel.anchor_right = 0.5
	_form_panel.anchor_top = 0.5
	_form_panel.anchor_bottom = 0.5

	_form_panel.offset_left = -220
	_form_panel.offset_right = 220
	_form_panel.offset_top = -160
	_form_panel.offset_bottom = 160

	add_child(_form_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(440, 320)
	root.add_theme_constant_override("separation", 8)
	_form_panel.add_child(root)

	_form_title_label = Label.new()
	_form_title_label.text = "Report a problem"
	_form_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_form_title_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_form_title_label)

	_category_label = Label.new()
	_category_label.text = "Category:"
	root.add_child(_category_label)

	_description_box = TextEdit.new()
	_description_box.placeholder_text = "Describe the problem here..."
	_description_box.custom_minimum_size = Vector2(420, 150)
	root.add_child(_description_box)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)

	var send_button := Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(_on_send_pressed)
	buttons.add_child(send_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	buttons.add_child(back_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_close_all)
	buttons.add_child(cancel_button)


func _build_admin_panel() -> void:
	_admin_panel = PanelContainer.new()
	_admin_panel.visible = false

	_admin_panel.anchor_left = 0.5
	_admin_panel.anchor_right = 0.5
	_admin_panel.anchor_top = 0.5
	_admin_panel.anchor_bottom = 0.5

	_admin_panel.offset_left = -420
	_admin_panel.offset_right = 420
	_admin_panel.offset_top = -300
	_admin_panel.offset_bottom = 300

	add_child(_admin_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(840, 600)
	_admin_panel.add_child(root)

	var title := Label.new()
	title.text = "Admin Reports"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	_admin_status_label = Label.new()
	_admin_status_label.text = ""
	root.add_child(_admin_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 480)
	root.add_child(scroll)

	_admin_reports_root = VBoxContainer.new()
	scroll.add_child(_admin_reports_root)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_request_admin_reports)
	buttons.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_all)
	buttons.add_child(close_button)


func _on_report_button_pressed() -> void:
	_close_all()

	if _is_socket_open():
		_request_admin_reports()
	else:
		_open_bug_report_menu()


func _open_bug_report_menu() -> void:
	_open_category_menu(
		"bug",
		_screen_name,
		_categories,
		0,
		"",
		0,
		"What do you want to report?"
	)


func _open_category_menu(
	report_type: String,
	screen_name: String,
	categories: Array[String],
	reported_player_id: int,
	reported_player_name: String,
	game_id: int,
	title_text: String
) -> void:
	_close_all()

	_active_report_type = report_type
	_active_screen_name = screen_name
	_active_reported_player_id = reported_player_id
	_active_reported_player_name = reported_player_name
	_active_game_id = game_id
	_selected_category = ""

	if _menu_title_label != null:
		_menu_title_label.text = title_text

	for child in _category_list.get_children():
		child.queue_free()

	for category in categories:
		var local_category := category
		var category_button := Button.new()
		category_button.text = local_category
		category_button.pressed.connect(func(): _on_category_selected(local_category))
		_category_list.add_child(category_button)

	_menu_panel.visible = true


func _request_admin_reports() -> void:
	var packet := packets.Packet.new()
	var chat := packet.new_chat()
	chat.set_msg(ADMIN_GET_PREFIX)
	WS.send(packet)


func _on_category_selected(category: String) -> void:
	_selected_category = category

	_menu_panel.visible = false
	_form_panel.visible = true

	if _description_box != null:
		_description_box.text = ""

	if _status_label != null:
		_status_label.text = ""

	if _category_label != null:
		_category_label.text = "Category: " + _selected_category

	if _form_title_label != null:
		if _active_report_type == "player":
			_form_title_label.text = "Report Player: " + _active_reported_player_name
		else:
			_form_title_label.text = "Report a problem"


func _on_back_pressed() -> void:
	_form_panel.visible = false
	_menu_panel.visible = true

	if _status_label != null:
		_status_label.text = ""


func _close_all() -> void:
	if _menu_panel != null:
		_menu_panel.visible = false

	if _form_panel != null:
		_form_panel.visible = false

	if _admin_panel != null:
		_admin_panel.visible = false

	if _status_label != null:
		_status_label.text = ""


func _on_send_pressed() -> void:
	var description := _description_box.text.strip_edges()

	if description.length() < 5:
		_status_label.text = "Please describe the problem first."
		return

	if description.length() > 500:
		_status_label.text = "Report is too long. Max 500 characters."
		return

	if not _is_socket_open():
		_status_label.text = "Cannot send report. Not connected to server."
		return

	if _active_report_type == "player" and _active_reported_player_id <= 0:
		_status_label.text = "Invalid player report target."
		return

	var payload := {
		"report_type": _active_report_type,
		"screen": _active_screen_name,
		"category": _selected_category,
		"description": description,
		"reported_player_id": _active_reported_player_id,
		"game_id": _active_game_id
	}

	var packet := packets.Packet.new()
	var chat := packet.new_chat()
	chat.set_msg(REPORT_PREFIX + JSON.stringify(payload))
	WS.send(packet)

	_status_label.text = "Sending report..."


func _on_ws_packet_received(packet: packets.Packet) -> void:
	if not packet.has_chat():
		return

	var msg := packet.get_chat().get_msg()

	if msg.begins_with(RESPONSE_PREFIX):
		_handle_report_response(msg.substr(RESPONSE_PREFIX.length()))
		return

	if msg.begins_with(ADMIN_RESPONSE_PREFIX):
		_handle_admin_reports_response(msg.substr(ADMIN_RESPONSE_PREFIX.length()))
		return

	if msg.begins_with(ADMIN_RESOLVE_RESPONSE_PREFIX):
		_handle_admin_resolve_response(msg.substr(ADMIN_RESOLVE_RESPONSE_PREFIX.length()))
		return


func _handle_report_response(json_text: String) -> void:
	var parsed: Variant = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		if _status_label != null:
			_status_label.text = "Server sent an invalid report response."
		return

	var success := bool(parsed.get("success", false))
	var message := str(parsed.get("message", ""))

	if _status_label != null:
		_status_label.text = message

	if success:
		if _description_box != null:
			_description_box.text = ""

		await get_tree().create_timer(1.0).timeout
		_close_all()


func _handle_admin_reports_response(json_text: String) -> void:
	var parsed: Variant = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		_open_bug_report_menu()
		return

	var is_admin := bool(parsed.get("admin", false))
	var success := bool(parsed.get("success", false))

	if not is_admin:
		_open_bug_report_menu()
		return

	_close_all()
	_admin_panel.visible = true

	if not success:
		_admin_status_label.text = str(parsed.get("message", "Failed to load reports."))
		return

	var reports: Array = parsed.get("reports", [])
	_render_admin_reports(reports)


func _handle_admin_resolve_response(json_text: String) -> void:
	var parsed: Variant = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	if _admin_status_label != null:
		_admin_status_label.text = str(parsed.get("message", ""))


func _render_admin_reports(reports: Array) -> void:
	for child in _admin_reports_root.get_children():
		child.queue_free()

	var bug_reports: Array = []
	var player_reports: Array = []

	for report in reports:
		if typeof(report) != TYPE_DICTIONARY:
			continue

		var report_type := str(report.get("report_type", "bug"))
		if report_type == "player":
			player_reports.append(report)
		else:
			bug_reports.append(report)

	_admin_status_label.text = "Open reports are shown first."

	_add_reports_section("Bug / Support Reports", bug_reports)
	_add_reports_section("Player Reports", player_reports)


func _add_reports_section(title_text: String, reports: Array) -> void:
	var title := Label.new()
	title.text = "\n" + title_text
	title.add_theme_font_size_override("font_size", 18)
	_admin_reports_root.add_child(title)

	if reports.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No reports."
		_admin_reports_root.add_child(empty_label)
		return

	for report in reports:
		_add_report_row(report)


func _add_report_row(report: Dictionary) -> void:
	var panel := PanelContainer.new()
	_admin_reports_root.add_child(panel)

	var root := VBoxContainer.new()
	panel.add_child(root)

	var report_id := int(report.get("report_id", 0))
	var resolved := bool(report.get("resolved", false))

	var header := Label.new()
	header.text = "ID #" + str(report_id) \
		+ " | Type: " + str(report.get("report_type", "")) \
		+ " | Screen: " + str(report.get("screen", "")) \
		+ " | Category: " + str(report.get("category", "")) \
		+ " | Resolved: " + str(resolved)
	root.add_child(header)

	var meta := Label.new()
	meta.text = "Reporter User ID: " + str(report.get("reporter_user_id", 0)) \
		+ " | Reported User ID: " + str(report.get("reported_user_id", 0)) \
		+ " | Game ID: " + str(report.get("game_id", 0)) \
		+ " | Created: " + str(report.get("created_at", ""))
	root.add_child(meta)

	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = "Description: " + str(report.get("description", ""))
	root.add_child(description)

	if not resolved:
		var resolve_button := Button.new()
		resolve_button.text = "Mark as Resolved"
		resolve_button.pressed.connect(func(): _on_resolve_report_pressed(report_id))
		root.add_child(resolve_button)


func _on_resolve_report_pressed(report_id: int) -> void:
	if report_id <= 0:
		return

	if not _is_socket_open():
		_admin_status_label.text = "Cannot resolve report. Not connected to server."
		return

	var packet := packets.Packet.new()
	var chat := packet.new_chat()
	chat.set_msg(ADMIN_RESOLVE_PREFIX + str(report_id))
	WS.send(packet)

	_admin_status_label.text = "Resolving report..."


func _is_socket_open() -> bool:
	return WS.get_socket().get_ready_state() == WebSocketPeer.STATE_OPEN
