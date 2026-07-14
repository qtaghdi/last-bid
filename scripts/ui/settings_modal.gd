class_name SettingsModal
extends Control

signal applied
signal closed
signal tutorial_replay_requested

@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var ui_scale_option: OptionButton = %UiScaleOption
@onready var text_scale_option: OptionButton = %TextScaleOption
@onready var reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var tutorial_toggle: CheckButton = %TutorialToggle
@onready var debug_toggle: CheckButton = %DebugToggle

var _preferences: UiPreferences

func _ready() -> void:
	$Overlay.color = UiPalette.OVERLAY
	%ApplyButton.pressed.connect(_apply)
	%CloseButton.pressed.connect(_close)
	%TutorialReplayButton.pressed.connect(func() -> void: tutorial_replay_requested.emit())
	_populate_options()
	visible = false

func open(preferences: UiPreferences) -> void:
	_preferences = preferences
	window_mode_option.select(1 if preferences.fullscreen else 0)
	_select_metadata(resolution_option, preferences.resolution)
	_select_metadata(ui_scale_option, preferences.ui_scale)
	_select_metadata(text_scale_option, preferences.text_scale)
	reduce_motion_toggle.button_pressed = preferences.reduce_motion
	tutorial_toggle.button_pressed = preferences.tutorial_enabled
	debug_toggle.button_pressed = preferences.debug_panel_enabled
	visible = true

func displayed_values() -> Dictionary:
	return {
		"fullscreen": window_mode_option.selected == 1,
		"resolution": resolution_option.get_item_metadata(resolution_option.selected),
		"ui_scale": ui_scale_option.get_item_metadata(ui_scale_option.selected),
		"text_scale": text_scale_option.get_item_metadata(text_scale_option.selected),
		"reduce_motion": reduce_motion_toggle.button_pressed,
		"tutorial": tutorial_toggle.button_pressed,
		"debug": debug_toggle.button_pressed,
	}

func _populate_options() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("창 모드")
	window_mode_option.add_item("전체 화면")
	resolution_option.clear()
	for resolution: Vector2i in UiPreferences.SUPPORTED_RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
		resolution_option.set_item_metadata(resolution_option.item_count - 1, resolution)
	ui_scale_option.clear()
	for scale: float in UiPreferences.SUPPORTED_SCALES:
		ui_scale_option.add_item("%d%%" % roundi(scale * 100.0))
		ui_scale_option.set_item_metadata(ui_scale_option.item_count - 1, scale)
	text_scale_option.clear()
	for scale: float in UiPreferences.SUPPORTED_TEXT_SCALES:
		text_scale_option.add_item("%d%%" % roundi(scale * 100.0))
		text_scale_option.set_item_metadata(text_scale_option.item_count - 1, scale)

func _select_metadata(option: OptionButton, value: Variant) -> void:
	for index: int in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			return

func _apply() -> void:
	if _preferences == null:
		return
	_preferences.fullscreen = window_mode_option.selected == 1
	_preferences.resolution = resolution_option.get_item_metadata(resolution_option.selected)
	_preferences.ui_scale = float(ui_scale_option.get_item_metadata(ui_scale_option.selected))
	_preferences.text_scale = float(text_scale_option.get_item_metadata(text_scale_option.selected))
	_preferences.reduce_motion = reduce_motion_toggle.button_pressed
	_preferences.tutorial_enabled = tutorial_toggle.button_pressed
	_preferences.debug_panel_enabled = debug_toggle.button_pressed
	_preferences.save_preferences()
	applied.emit()
	_close()

func _close() -> void:
	visible = false
	closed.emit()
