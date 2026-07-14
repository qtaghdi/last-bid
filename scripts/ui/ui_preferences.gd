class_name UiPreferences
extends RefCounted

const CONFIG_PATH: String = "user://ui_preferences.cfg"
const SECTION: String = "interface"
const SUPPORTED_SCALES: PackedFloat32Array = [0.8, 1.0, 1.2]
const SUPPORTED_TEXT_SCALES: PackedFloat32Array = [0.9, 1.0, 1.1]
const SUPPORTED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var fullscreen: bool = false
var resolution: Vector2i = Vector2i(1280, 720)
var ui_scale: float = 1.0
var text_scale: float = 1.0
var reduce_motion: bool = false
var tutorial_enabled: bool = true
var tutorial_completed: bool = false
var debug_panel_enabled: bool = true

func load_preferences() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	fullscreen = bool(config.get_value(SECTION, "fullscreen", fullscreen))
	resolution = config.get_value(SECTION, "resolution", resolution) as Vector2i
	ui_scale = _nearest_scale(
		float(config.get_value(SECTION, "ui_scale", ui_scale)),
		SUPPORTED_SCALES
	)
	text_scale = _nearest_scale(
		float(config.get_value(SECTION, "text_scale", text_scale)),
		SUPPORTED_TEXT_SCALES
	)
	reduce_motion = bool(config.get_value(SECTION, "reduce_motion", reduce_motion))
	tutorial_enabled = bool(config.get_value(SECTION, "tutorial_enabled", tutorial_enabled))
	tutorial_completed = bool(config.get_value(SECTION, "tutorial_completed", tutorial_completed))
	debug_panel_enabled = bool(config.get_value(SECTION, "debug_panel_enabled", debug_panel_enabled))

func save_preferences() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "resolution", resolution)
	config.set_value(SECTION, "ui_scale", ui_scale)
	config.set_value(SECTION, "text_scale", text_scale)
	config.set_value(SECTION, "reduce_motion", reduce_motion)
	config.set_value(SECTION, "tutorial_enabled", tutorial_enabled)
	config.set_value(SECTION, "tutorial_completed", tutorial_completed)
	config.set_value(SECTION, "debug_panel_enabled", debug_panel_enabled)
	config.save(CONFIG_PATH)

func apply(root: Control) -> void:
	if root.theme != null:
		root.theme = root.theme.duplicate() as Theme
		root.theme.default_base_scale = ui_scale
		root.theme.default_font_size = roundi(UiPalette.FONT_BODY * text_scale)
	var window: Window = root.get_window()
	if window != null:
		window.content_scale_factor = ui_scale
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not fullscreen:
		DisplayServer.window_set_size(resolution)

func reset_tutorial() -> void:
	tutorial_enabled = true
	tutorial_completed = false
	save_preferences()

func complete_tutorial() -> void:
	tutorial_completed = true
	save_preferences()

func tutorial_should_run() -> bool:
	return tutorial_enabled and not tutorial_completed

func _nearest_scale(value: float, supported: PackedFloat32Array) -> float:
	var result: float = supported[0]
	var distance: float = absf(value - result)
	for candidate: float in supported:
		var next_distance: float = absf(value - candidate)
		if next_distance < distance:
			result = candidate
			distance = next_distance
	return result
