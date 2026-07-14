class_name TutorialOverlay
extends Control

signal step_shown(step_id: StringName)
signal step_dismissed(step_id: StringName)
signal tutorial_disabled

@onready var eyebrow_label: Label = %EyebrowLabel
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel

var _enabled: bool = false
var _current_step: StringName = &""
var _shown_steps: Dictionary = {}

func _ready() -> void:
	%DismissButton.pressed.connect(_dismiss_current)
	%SkipButton.pressed.connect(_dismiss_current)
	%DisableButton.pressed.connect(_disable_tutorial)
	visible = false

func configure(enabled: bool, reset_steps: bool = false) -> void:
	_enabled = enabled
	if reset_steps:
		_shown_steps.clear()
	if not enabled:
		visible = false

func show_step(step_id: StringName, title: String, body: String) -> bool:
	if not _enabled or _shown_steps.has(step_id) or visible:
		return false
	_current_step = step_id
	_shown_steps[step_id] = true
	eyebrow_label.text = "FIRST RUN · %s" % String(step_id).to_upper()
	title_label.text = title
	body_label.text = body
	visible = true
	step_shown.emit(step_id)
	return true

func is_step_shown(step_id: StringName) -> bool:
	return _shown_steps.has(step_id)

func current_step() -> StringName:
	return _current_step

func _dismiss_current() -> void:
	var dismissed: StringName = _current_step
	visible = false
	_current_step = &""
	step_dismissed.emit(dismissed)

func _disable_tutorial() -> void:
	_enabled = false
	visible = false
	_current_step = &""
	tutorial_disabled.emit()
