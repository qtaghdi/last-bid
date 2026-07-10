class_name DebugDrawer
extends PanelContainer

signal close_requested

@onready var inspector: RichTextLabel = %DebugInspector
@onready var log_view: RichTextLabel = %DebugLog

func _ready() -> void:
	%CloseButton.pressed.connect(func() -> void: close_requested.emit())

func render(information_report: String, log_lines: PackedStringArray) -> void:
	inspector.text = information_report
	log_view.text = "\n".join(log_lines)
	log_view.scroll_to_line(maxi(0, log_lines.size() - 1))

func inspector_text() -> String:
	return inspector.text
