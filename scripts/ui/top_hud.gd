class_name TopHud
extends PanelContainer

signal debug_toggled(enabled: bool)
signal settings_requested

@onready var round_label: Label = %RoundLabel
@onready var phase_label: Label = %PhaseLabel
@onready var info_label: Label = %InfoLabel
@onready var promise_label: Label = %PromiseLabel
@onready var seed_label: Label = %SeedLabel
@onready var round_progress: ProgressBar = %RoundProgress
@onready var debug_toggle: CheckButton = %DebugToggle

var _seed_value: int = GameConstants.DEFAULT_SEED

func _ready() -> void:
	debug_toggle.toggled.connect(func(enabled: bool) -> void: debug_toggled.emit(enabled))
	%SettingsButton.pressed.connect(func() -> void: settings_requested.emit())
	info_label.tooltip_text = TooltipTerms.text("정보 토큰")
	promise_label.tooltip_text = TooltipTerms.text("약속")
	seed_label.tooltip_text = "Seed가 같으면 게임플레이 난수 결과를 재현할 수 있습니다."

func render(run_state: RunState, debug_enabled: bool, promise_summary: String = "") -> void:
	round_label.text = "ROUND %d / %d" % [run_state.current_round, GameConstants.TOTAL_ROUNDS]
	round_progress.max_value = GameConstants.TOTAL_ROUNDS
	round_progress.value = run_state.current_round
	phase_label.text = UiPalette.phase_label(run_state.current_phase)
	info_label.text = "INFO %d" % run_state.player_info_tokens
	var promise_count: int = run_state.active_promises.size()
	promise_label.text = (
		"약속 없음"
		if promise_count == 0
		else "약속 %d · %s" % [promise_count, _imminent_promise(run_state, promise_summary)]
	)
	set_seed(run_state.rng_seed)
	if debug_toggle.button_pressed != debug_enabled:
		debug_toggle.set_pressed_no_signal(debug_enabled)

func set_seed(seed_value: int) -> void:
	_seed_value = seed_value
	seed_label.text = "SEED %d" % seed_value

func seed_value() -> int:
	return _seed_value

func displayed_phase() -> String:
	return phase_label.text

func displayed_info() -> String:
	return info_label.text

func displayed_promise() -> String:
	return promise_label.text

func set_debug_available(available: bool) -> void:
	debug_toggle.visible = available
	if not available:
		debug_toggle.set_pressed_no_signal(false)

func _imminent_promise(run_state: RunState, summary: String) -> String:
	var imminent: PromiseState
	for promise: PromiseState in run_state.active_promises:
		if imminent == null or promise.target_round < imminent.target_round:
			imminent = promise
	if imminent != null:
		var remaining: int = maxi(0, imminent.target_round - run_state.current_round)
		return "%s · %s" % [
			PromiseManager.promise_type_name(imminent.promise_type),
			"이번 경매" if remaining == 0 else "R%d" % imminent.target_round,
		]
	if summary.is_empty() or summary == "활성 약속 없음":
		return "활성"
	var first_line: String = summary.split("\n")[0]
	return first_line.left(28) + ("…" if first_line.length() > 28 else "")
