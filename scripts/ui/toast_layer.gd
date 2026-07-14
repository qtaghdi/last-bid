class_name ToastLayer
extends Control

@onready var toast_panel: PanelContainer = %ToastPanel
@onready var message_label: Label = %MessageLabel

var last_message: String = ""
var _active_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false

func show_message(message: String, kind: StringName = &"info", reduce_motion: bool = false) -> void:
	last_message = message
	message_label.text = message
	message_label.modulate = _color_for(kind)
	toast_panel.visible = true
	toast_panel.modulate = Color.WHITE
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if reduce_motion:
		return
	toast_panel.modulate.a = 0.0
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.tween_property(
		toast_panel,
		"modulate:a",
		1.0,
		UiPalette.MOTION_FAST
	)
	_active_tween.tween_interval(1.65)
	_active_tween.tween_property(
		toast_panel,
		"modulate:a",
		0.0,
		UiPalette.MOTION_NORMAL
	)
	_active_tween.tween_callback(func() -> void: toast_panel.visible = false)

func _color_for(kind: StringName) -> Color:
	match kind:
		&"danger":
			return UiPalette.DANGER
		&"success":
			return UiPalette.SUCCESS
		_:
			return UiPalette.IVORY
