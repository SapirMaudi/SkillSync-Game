class_name Log
extends RichTextLabel

func _message(message: String, color: Color = Color.WHITE) -> void:
	append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), message])
	
func info(message: String) -> void:
	_message(message, Color.WHITE)

func warn(message: String) -> void:
	_message(message, Color.YELLOW)
	
func error(message: String) -> void:
	_message(message, Color.ORANGE_RED)
	
func success(message: String) -> void:
	_message(message, Color.LAWN_GREEN)
