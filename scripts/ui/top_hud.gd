class_name TopHud
extends PanelContainer

signal debug_toggled(enabled: bool)
signal settings_requested

const COMPACT_WIDTH: float = 1120.0
const WIDE_HEIGHT: float = 104.0
const COMPACT_HEIGHT: float = 68.0

@onready var column: VBoxContainer = $Column
@onready var phase_eyebrow: Label = %PhaseEyebrow
@onready var phase_label: Label = %PhaseLabel
@onready var round_label: Label = %RoundLabel
@onready var round_progress: ProgressBar = %RoundProgress
@onready var hp_block: PanelContainer = %HpBlock
@onready var hp_label: Label = %HpLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var gold_value_label: Label = %GoldValueLabel
@onready var gold_eyebrow: Label = $Column/PrimaryRow/GoldBlock/GoldColumn/GoldEyebrow
@onready var info_block: PanelContainer = %InfoBlock
@onready var info_label: Label = %InfoLabel
@onready var rule_badge: PanelContainer = %RuleBadge
@onready var rule_label: Label = %RuleLabel
@onready var promise_label: Label = %PromiseLabel
@onready var survivor_label: Label = %SurvivorLabel
@onready var seed_label: Label = %SeedLabel
@onready var debug_toggle: CheckButton = %DebugToggle

var _seed_value: int = GameConstants.DEFAULT_SEED
var _debug_enabled: bool = false
var _compact_mode: bool = false
var _promise_count: int = 0
var _promise_full_text: String = "약속 없음"
var _alive_count: int = 0
var _actor_count: int = 0

func _ready() -> void:
	debug_toggle.toggled.connect(func(enabled: bool) -> void: debug_toggled.emit(enabled))
	%SettingsButton.pressed.connect(func() -> void: settings_requested.emit())
	resized.connect(_update_compact_mode)
	info_label.tooltip_text = TooltipTerms.text("정보 토큰")
	promise_label.tooltip_text = TooltipTerms.text("약속")
	seed_label.tooltip_text = "Seed가 같으면 게임플레이 난수 결과를 재현할 수 있습니다."
	call_deferred("_update_compact_mode")

func render(
	run_state: RunState,
	player_hp: int,
	player_max_hp: int,
	player_gold: int,
	player_alive: bool,
	alive_count: int,
	actor_count: int,
	public_rule_summary: String,
	public_rule_tooltip: String,
	rule_emphasized: bool,
	debug_enabled: bool,
	promise_summary: String = ""
) -> void:
	phase_label.text = UiPalette.phase_label(run_state.current_phase)
	phase_label.tooltip_text = "현재 단계 · %s" % phase_label.text
	round_label.text = "%d / %d" % [run_state.current_round, GameConstants.TOTAL_ROUNDS]
	round_progress.max_value = GameConstants.TOTAL_ROUNDS
	round_progress.value = run_state.current_round
	_render_hp(player_hp, player_max_hp, player_alive)
	_render_gold(player_gold, player_max_hp > 0)
	_render_info_tokens(run_state.player_info_tokens)
	_render_rule(public_rule_summary, public_rule_tooltip, rule_emphasized)
	_promise_count = run_state.active_promises.size()
	_promise_full_text = (
		"약속 없음"
		if _promise_count == 0
		else "약속 %d · %s" % [_promise_count, _imminent_promise(run_state, promise_summary)]
	)
	promise_label.tooltip_text = (
		promise_summary
		if not promise_summary.is_empty() and promise_summary != "활성 약속 없음"
		else _promise_full_text
	)
	_alive_count = alive_count
	_actor_count = actor_count
	_debug_enabled = debug_enabled
	set_seed(run_state.rng_seed)
	if debug_toggle.button_pressed != debug_enabled:
		debug_toggle.set_pressed_no_signal(debug_enabled)
	_update_compact_mode()

func set_seed(seed_value: int) -> void:
	_seed_value = seed_value
	seed_label.text = "SEED %d" % seed_value
	seed_label.tooltip_text = (
		"재현 Seed · %d\n같은 Seed는 게임플레이 난수 결과를 재현합니다." % seed_value
	)

func seed_value() -> int:
	return _seed_value

func displayed_phase() -> String:
	return phase_label.text

func displayed_info() -> String:
	return info_label.text

func displayed_promise() -> String:
	return promise_label.text

func displayed_hp() -> String:
	return hp_label.text

func displayed_gold() -> String:
	return gold_value_label.text

func displayed_rule() -> String:
	return rule_label.text

func displayed_survivors() -> String:
	return survivor_label.text

func is_compact_mode() -> bool:
	return _compact_mode

func apply_responsive_width(available_width: float) -> void:
	_set_compact_mode(available_width > 0.0 and available_width < COMPACT_WIDTH)

func set_debug_available(available: bool) -> void:
	debug_toggle.visible = available
	if not available:
		debug_toggle.set_pressed_no_signal(false)

func _render_hp(hp: int, max_hp: int, alive: bool) -> void:
	var accent: Color = UiPalette.SUCCESS
	if max_hp <= 0:
		hp_label.text = "HP —"
		hp_bar.max_value = 1
		hp_bar.value = 0
		accent = UiPalette.MUTED
	elif not alive or hp <= 0:
		hp_label.text = "† 사망"
		hp_bar.max_value = max_hp
		hp_bar.value = 0
		accent = UiPalette.DANGER
	elif hp <= 1:
		hp_label.text = "! 위험 · HP %d / %d" % [hp, max_hp]
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		accent = UiPalette.DANGER
	else:
		hp_label.text = "HP %d / %d" % [hp, max_hp]
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	hp_label.tooltip_text = "플레이어 체력 · %s" % hp_label.text
	hp_label.add_theme_color_override("font_color", accent)
	_apply_panel_accent(hp_block, accent)

func _render_gold(gold: int, player_available: bool) -> void:
	gold_value_label.text = str(gold) if player_available else "—"
	gold_value_label.tooltip_text = (
		"플레이어 골드 · %d G" % gold
		if player_available
		else "플레이어 상태를 확인할 수 없습니다."
	)

func _render_info_tokens(token_count: int) -> void:
	if token_count <= 0:
		info_label.text = "× 정보 없음"
		info_label.add_theme_color_override("font_color", UiPalette.MUTED)
		_apply_panel_accent(info_block, UiPalette.DISABLED)
	else:
		info_label.text = "◆ 정보 %d" % token_count
		info_label.add_theme_color_override("font_color", UiPalette.GOLD_BRIGHT)
		_apply_panel_accent(info_block, UiPalette.GOLD_MUTED)
	info_label.tooltip_text = "%s\n현재 수량 · %d" % [TooltipTerms.text("정보 토큰"), token_count]

func _render_rule(summary: String, tooltip: String, emphasized: bool) -> void:
	var visible_summary: String = summary if not summary.is_empty() else "기본 경매"
	rule_label.text = "규칙 · %s" % visible_summary
	rule_label.tooltip_text = tooltip if not tooltip.is_empty() else visible_summary
	var accent: Color = UiPalette.GOLD_BRIGHT if emphasized else UiPalette.BORDER_DEFAULT
	rule_label.add_theme_color_override(
		"font_color",
		UiPalette.GOLD_BRIGHT if emphasized else UiPalette.MUTED
	)
	_apply_panel_accent(rule_badge, accent)

func _update_compact_mode() -> void:
	apply_responsive_width(size.x)

func _set_compact_mode(compact: bool) -> void:
	_compact_mode = compact
	phase_eyebrow.visible = not _compact_mode
	gold_eyebrow.visible = not _compact_mode
	promise_label.text = (
		("약속 없음" if _promise_count == 0 else "약속 %d" % _promise_count)
		if _compact_mode
		else _promise_full_text
	)
	survivor_label.text = (
		"생존 %d" % _alive_count
		if _compact_mode
		else "생존 %d / %d" % [_alive_count, _actor_count]
	)
	seed_label.visible = _debug_enabled or not _compact_mode
	_apply_density(_compact_mode)

func _apply_density(compact: bool) -> void:
	custom_minimum_size.y = COMPACT_HEIGHT if compact else WIDE_HEIGHT
	column.add_theme_constant_override("separation", 2 if compact else 5)
	var primary_height: float = 32.0 if compact else 44.0
	for control: Control in [
		$Column/PrimaryRow/PhaseBadge,
		$Column/PrimaryRow/RoundBlock,
		hp_block,
		$Column/PrimaryRow/GoldBlock,
		info_block,
	]:
		control.custom_minimum_size.y = primary_height
	var tool_height: float = 32.0 if compact else 38.0
	%SettingsButton.custom_minimum_size.y = tool_height
	debug_toggle.custom_minimum_size.y = tool_height
	var secondary_height: float = 20.0 if compact else 26.0
	rule_badge.custom_minimum_size.y = secondary_height
	%PromiseBadge.custom_minimum_size.y = secondary_height
	var base_style: StyleBox = get_theme_stylebox("panel", "PanelContainer")
	if base_style is StyleBoxFlat:
		var density_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
		density_style.content_margin_left = 10.0 if compact else 14.0
		density_style.content_margin_right = 10.0 if compact else 14.0
		density_style.content_margin_top = 2.0 if compact else 12.0
		density_style.content_margin_bottom = 2.0 if compact else 12.0
		add_theme_stylebox_override("panel", density_style)

func _apply_panel_accent(panel: PanelContainer, accent: Color) -> void:
	var inherited_style: StyleBox = panel.get_theme_stylebox("panel")
	if inherited_style is StyleBoxFlat:
		var style: StyleBoxFlat = inherited_style.duplicate() as StyleBoxFlat
		style.border_color = accent
		panel.add_theme_stylebox_override("panel", style)
	else:
		panel.add_theme_stylebox_override("panel", UiPalette.badge_style(accent, UiPalette.PANEL))

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
