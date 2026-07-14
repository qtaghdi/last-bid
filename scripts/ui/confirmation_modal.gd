class_name ConfirmationModal
extends Control

signal confirmed(action_id: StringName)
signal cancelled(action_id: StringName)

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel

var _action_id: StringName = &""

func _ready() -> void:
	$Overlay.color = UiPalette.OVERLAY
	%ConfirmButton.pressed.connect(_confirm)
	%CancelButton.pressed.connect(_cancel)
	visible = false

func request_confirmation(action_id: StringName, title: String, message: String) -> void:
	_action_id = action_id
	title_label.text = title
	message_label.text = message
	visible = true

func pending_action() -> StringName:
	return _action_id

func _confirm() -> void:
	var action: StringName = _action_id
	visible = false
	_action_id = &""
	confirmed.emit(action)

func _cancel() -> void:
	var action: StringName = _action_id
	visible = false
	_action_id = &""
	cancelled.emit(action)
