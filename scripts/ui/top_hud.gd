class_name TopHud
extends PanelContainer

signal debug_toggled(enabled: bool)
signal new_run_requested(seed_value: int)

@onready var round_label: Label = %RoundLabel
@onready var phase_label: Label = %PhaseLabel
@onready var seed_input: LineEdit = %SeedInput
@onready var info_label: Label = %InfoLabel
@onready var debug_toggle: CheckButton = %DebugToggle
@onready var new_run_button: Button = %NewRunButton

func _ready() -> void:
	debug_toggle.toggled.connect(func(enabled: bool) -> void: debug_toggled.emit(enabled))
	new_run_button.pressed.connect(func() -> void: new_run_requested.emit(seed_value()))
	seed_input.text_submitted.connect(func(_text: String) -> void: new_run_requested.emit(seed_value()))

func render(run_state: RunState, debug_enabled: bool) -> void:
	round_label.text = "ROUND %d / %d" % [run_state.current_round, GameConstants.TOTAL_ROUNDS]
	phase_label.text = UiPalette.phase_label(run_state.current_phase)
	info_label.text = "INFO %d" % run_state.player_info_tokens
	if seed_input.text != str(run_state.rng_seed) and not seed_input.has_focus():
		seed_input.text = str(run_state.rng_seed)
	if debug_toggle.button_pressed != debug_enabled:
		debug_toggle.set_pressed_no_signal(debug_enabled)

func set_seed(seed_value: int) -> void:
	seed_input.text = str(seed_value)

func seed_value() -> int:
	if seed_input.text.strip_edges().is_valid_int():
		return int(seed_input.text.strip_edges())
	return GameConstants.DEFAULT_SEED

func displayed_phase() -> String:
	return phase_label.text

func displayed_info() -> String:
	return info_label.text
