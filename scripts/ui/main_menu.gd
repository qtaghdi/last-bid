class_name MainMenu
extends Control

signal new_game_requested(seed_value: int)
signal same_seed_requested(seed_value: int)
signal settings_requested
signal quit_requested

@onready var seed_input: LineEdit = %SeedInput
@onready var same_seed_button: Button = %SameSeedButton

var _last_seed: int = GameConstants.DEFAULT_SEED

func _ready() -> void:
	$Shade.color = UiPalette.with_alpha(UiPalette.BACKGROUND_PRIMARY, 0.62)
	%NewGameButton.pressed.connect(func() -> void: new_game_requested.emit(seed_value()))
	same_seed_button.pressed.connect(func() -> void: same_seed_requested.emit(_last_seed))
	%SettingsButton.pressed.connect(func() -> void: settings_requested.emit())
	%QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	seed_input.text_submitted.connect(func(_text: String) -> void: new_game_requested.emit(seed_value()))
	seed_input.tooltip_text = "같은 Seed는 카드 순서와 게임플레이 판단을 동일하게 재현합니다."
	set_last_seed(GameConstants.DEFAULT_SEED)

func set_last_seed(seed_value: int) -> void:
	_last_seed = seed_value
	seed_input.text = str(seed_value)
	same_seed_button.text = "같은 Seed · %d" % seed_value

func seed_value() -> int:
	var value: String = seed_input.text.strip_edges()
	return int(value) if value.is_valid_int() else GameConstants.DEFAULT_SEED
