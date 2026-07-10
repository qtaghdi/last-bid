extends Control

@onready var controller: GameFlowController = $GameFlowController
@onready var round_label: Label = %RoundLabel
@onready var phase_label: Label = %PhaseLabel
@onready var actors_label: RichTextLabel = %ActorsLabel
@onready var card_name_label: Label = %CardNameLabel
@onready var card_description_label: Label = %CardDescriptionLabel
@onready var bid_info_label: Label = %BidInfoLabel
@onready var turn_label: Label = %TurnLabel
@onready var bid_button: Button = %BidButton
@onready var pass_button: Button = %PassButton
@onready var advance_button: Button = %AdvanceButton
@onready var seed_input: LineEdit = %SeedInput
@onready var new_run_button: Button = %NewRunButton
@onready var debug_toggle: CheckButton = %DebugToggle
@onready var debug_panel: PanelContainer = %DebugPanel
@onready var debug_log: RichTextLabel = %DebugLog
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

var _debug_lines: PackedStringArray = []
var _debug_mode: bool = false

func _ready() -> void:
	seed_input.text = str(GameConstants.DEFAULT_SEED)
	bid_button.pressed.connect(_on_bid_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	debug_toggle.toggled.connect(_on_debug_toggled)
	seed_input.text_submitted.connect(_on_seed_submitted)
	controller.events.state_updated.connect(_refresh)
	controller.events.debug_logged.connect(_append_debug_log)
	controller.events.run_finished.connect(_on_run_finished)
	controller.start_new_run(_seed_value())
	set_debug_mode(false)
	_refresh()

func _on_bid_pressed() -> void:
	controller.request_player_bid()
	_refresh()

func _on_pass_pressed() -> void:
	controller.request_player_pass()
	_refresh()

func _on_advance_pressed() -> void:
	controller.request_advance()
	_refresh()

func _on_new_run_pressed() -> void:
	_debug_lines.clear()
	debug_log.text = ""
	controller.start_new_run(_seed_value())
	_refresh()

func _on_seed_submitted(_new_text: String) -> void:
	_on_new_run_pressed()

func _on_debug_toggled(enabled: bool) -> void:
	set_debug_mode(enabled)

func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled
	if not is_node_ready():
		return
	if debug_toggle.button_pressed != enabled:
		debug_toggle.set_pressed_no_signal(enabled)
	debug_panel.visible = enabled
	_refresh()

func is_debug_mode() -> bool:
	return _debug_mode

func _on_run_finished(victory: bool, reason: String) -> void:
	result_panel.visible = true
	result_label.text = "%s\n%s" % ["승리" if victory else "패배", reason]
	result_label.modulate = Color("d8b56c") if victory else Color("c9675b")

func _refresh() -> void:
	if controller == null or controller.run_state == null:
		return
	var run: RunState = controller.run_state
	round_label.text = "ROUND  %02d / %02d" % [run.current_round, GameConstants.TOTAL_ROUNDS]
	phase_label.text = GameConstants.phase_name(run.current_phase)
	if run.current_card != null:
		_update_card_information(run.current_card, run.current_phase)
		var highest_name: String = "없음"
		if not run.highest_bidder_id.is_empty():
			var highest: ActorState = controller.actor_by_id(run.highest_bidder_id)
			if highest != null:
				highest_name = highest.display_name
		var current_bid_text: String = "입찰 없음"
		if not run.highest_bidder_id.is_empty():
			current_bid_text = "%d G" % run.current_bid
		bid_info_label.text = (
			"시작가  %d G\n현재가  %s\n최고 입찰자  %s\n최소 인상  %d G"
			% [run.current_card.starting_bid, current_bid_text, highest_name, run.current_min_increment]
		)
	else:
		card_name_label.text = "카드 준비 중"
		card_description_label.text = ""
		bid_info_label.text = ""
	_update_actor_panel()
	_update_turn_and_buttons()
	result_panel.visible = run.current_phase == GameConstants.Phase.RUN_RESULT
	if result_panel.visible:
		result_label.text = "%s\n%s" % ["승리" if run.victory else "패배", run.result_reason]
		result_label.modulate = Color("d8b56c") if run.victory else Color("c9675b")

func _update_actor_panel() -> void:
	var blocks: PackedStringArray = []
	for actor: ActorState in controller.actors:
		var status: String = "생존" if actor.alive else "사망"
		var pass_status: String = " · PASS" if actor.has_passed and actor.alive else ""
		var actor_color: String = "d8b56c" if actor.actor_type == GameConstants.ActorType.PLAYER else "c7c0ad"
		if not actor.alive:
			actor_color = "6f6962"
		blocks.append(
			"[color=#%s][font_size=19][b]%s[/b][/font_size][/color]  %s%s\n"
			% [actor_color, actor.display_name, status, pass_status]
			+ "HP  %d / %d    GOLD  %d\n" % [actor.hp, actor.max_hp, actor.gold]
			+ "CARD  %s" % actor.owned_card_names(
				_debug_mode or not _is_concealed_phase(controller.run_state.current_phase),
				_debug_mode
			)
		)
	actors_label.text = "\n\n".join(blocks)

func _update_card_information(card: CardDefinition, phase: int) -> void:
	if _debug_mode:
		card_name_label.text = "%s  [ID: %s]" % [card.display_name, card.id]
		card_description_label.text = _full_debug_description(card)
		return
	if _is_concealed_phase(phase):
		card_name_label.text = card.public_label
	else:
		card_name_label.text = card.display_name
	card_description_label.text = _public_clue_description(card)

func _public_clue_description(card: CardDefinition) -> String:
	return (
		"역할군: %s\n위험도: %s\n예상 가치: %s\n발동 시점: %s\n대상: %s"
		% [
			card.public_role_group,
			card.public_risk_range,
			card.public_value_range,
			card.public_trigger_timing,
			card.public_target_type,
		]
	)

func _full_debug_description(card: CardDefinition) -> String:
	var lines: PackedStringArray = [card.description, "", "전체 효과"]
	for effect: CardEffectDefinition in card.effects:
		lines.append("• %s" % effect.description)
	return "\n".join(lines)

func _is_concealed_phase(phase: int) -> bool:
	return phase == GameConstants.Phase.PRE_INFO or phase == GameConstants.Phase.AUCTION

func _update_turn_and_buttons() -> void:
	var phase: int = controller.run_state.current_phase
	var turn_actor_id: StringName = controller.current_turn_actor_id()
	if phase == GameConstants.Phase.AUCTION:
		var turn_actor: ActorState = controller.actor_by_id(turn_actor_id)
		turn_label.text = "현재 차례: %s" % (turn_actor.display_name if turn_actor != null else "정산 중")
	else:
		turn_label.text = _phase_guidance(phase)
	var required_bid: int = controller.current_required_bid()
	var has_no_bid: bool = controller.run_state.highest_bidder_id.is_empty()
	if (
		has_no_bid
		and controller.run_state.current_card != null
		and (phase == GameConstants.Phase.PRE_INFO or phase == GameConstants.Phase.AUCTION)
	):
		bid_button.text = "첫 입찰 %d G" % controller.run_state.current_card.starting_bid
	else:
		bid_button.text = "입찰 %d G" % required_bid if required_bid > 0 else "입찰"
	bid_button.disabled = not controller.can_player_bid()
	pass_button.disabled = not controller.can_player_pass()
	advance_button.disabled = phase == GameConstants.Phase.AUCTION or phase == GameConstants.Phase.RUN_RESULT
	advance_button.text = _advance_button_text(phase)

func _phase_guidance(phase: int) -> String:
	match phase:
		GameConstants.Phase.PRE_INFO:
			return "출품 정보를 확인하고 경매를 시작하세요."
		GameConstants.Phase.POST_AUCTION:
			return "낙찰 정산 완료. 심판 단계로 진행하세요."
		GameConstants.Phase.JUDGMENT:
			return "심판 효과 처리 완료. 라운드를 마감하세요."
		GameConstants.Phase.ROUND_END:
			return "라운드 종료. 다음 출품으로 진행하세요."
		GameConstants.Phase.RUN_RESULT:
			return "게임이 종료되었습니다."
		_:
			return "게임 준비 중"

func _advance_button_text(phase: int) -> String:
	match phase:
		GameConstants.Phase.PRE_INFO:
			return "경매 시작"
		GameConstants.Phase.POST_AUCTION:
			return "심판 진행"
		GameConstants.Phase.JUDGMENT:
			return "라운드 종료"
		GameConstants.Phase.ROUND_END:
			return "다음 라운드"
		_:
			return "다음 단계"

func _append_debug_log(message: String) -> void:
	_debug_lines.append("[%02d] %s" % [_debug_lines.size() + 1, message])
	while _debug_lines.size() > 160:
		_debug_lines.remove_at(0)
	debug_log.text = "\n".join(_debug_lines)
	debug_log.scroll_to_line(maxi(0, _debug_lines.size() - 1))

func _seed_value() -> int:
	if seed_input.text.strip_edges().is_valid_int():
		return int(seed_input.text.strip_edges())
	seed_input.text = str(GameConstants.DEFAULT_SEED)
	return GameConstants.DEFAULT_SEED
