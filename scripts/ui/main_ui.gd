extends Control

@onready var controller: GameFlowController = $GameFlowController
@onready var top_hud: TopHud = %TopHud
@onready var participant_panel: ParticipantPanel = %ParticipantPanel
@onready var card_info_panel: CardInfoPanel = %CardInfoPanel
@onready var reaction_panel: ReactionPanel = %ReactionPanel
@onready var auction_panel: AuctionPanel = %AuctionPanel
@onready var post_auction_panel: PostAuctionPanel = %PostAuctionPanel
@onready var judgment_panel: JudgmentPanel = %JudgmentPanel
@onready var result_panel: RunResultPanel = %RunResultPanel
@onready var debug_drawer: DebugDrawer = %DebugPanel
@onready var action_bar: PanelContainer = %ActionBar
@onready var action_hint: Label = %ActionHint
@onready var bid_button: Button = %BidButton
@onready var pass_button: Button = %PassButton
@onready var investigate_button: Button = %InvestigateButton
@onready var advance_button: Button = %AdvanceButton

var _debug_lines: PackedStringArray = []
var _resolution_lines: PackedStringArray = []
var _debug_mode: bool = false

func _ready() -> void:
	$Backdrop.modulate = UiPalette.with_alpha(UiPalette.MUTED, 0.09)
	$Shade.color = UiPalette.with_alpha(UiPalette.BACKGROUND, 0.90)
	bid_button.pressed.connect(_on_bid_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	top_hud.debug_toggled.connect(set_debug_mode)
	top_hud.new_run_requested.connect(_start_new_run)
	debug_drawer.close_requested.connect(func() -> void: set_debug_mode(false))
	result_panel.same_seed_requested.connect(_restart_same_seed)
	result_panel.new_seed_requested.connect(_restart_new_seed)
	_connect_events()
	top_hud.set_seed(GameConstants.DEFAULT_SEED)
	_start_new_run(GameConstants.DEFAULT_SEED)

func _connect_events() -> void:
	controller.events.state_updated.connect(_refresh)
	controller.events.debug_logged.connect(_append_debug_log)
	controller.events.round_started.connect(_on_round_started)
	controller.events.card_effect_triggered.connect(_on_card_effect_triggered)
	controller.events.card_consumed.connect(_on_card_consumed)
	controller.events.damage_applied.connect(_on_damage_applied)
	controller.events.gold_changed.connect(_on_gold_changed)
	controller.events.actor_died.connect(_on_actor_died)

func _start_new_run(seed_value: int) -> void:
	_debug_lines.clear()
	_resolution_lines.clear()
	top_hud.set_seed(seed_value)
	controller.start_new_run(seed_value)
	_refresh()

func _restart_same_seed() -> void:
	_start_new_run(controller.run_state.rng_seed)

func _restart_new_seed() -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	_start_new_run(seed_value)

func _on_bid_pressed() -> void:
	controller.request_player_bid()
	_refresh()

func _on_pass_pressed() -> void:
	controller.request_player_pass()
	_refresh()

func _on_investigate_pressed() -> void:
	controller.request_investigate()
	_refresh()

func _on_advance_pressed() -> void:
	controller.request_advance()
	_refresh()

func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled
	if not is_node_ready():
		return
	debug_drawer.visible = enabled
	_refresh()

func is_debug_mode() -> bool:
	return _debug_mode

func restart_same_seed() -> void:
	_restart_same_seed()

func refresh_ui() -> void:
	_refresh()

func _refresh() -> void:
	if controller == null or controller.run_state == null:
		return
	var run: RunState = controller.run_state
	top_hud.render(run, _debug_mode)
	participant_panel.render(controller, _debug_mode)
	card_info_panel.render(
		run.current_card,
		controller.player_knowledge(),
		_debug_mode,
		controller.debug_effect_report()
	)
	reaction_panel.render(controller)
	auction_panel.render(controller)
	post_auction_panel.render(controller)
	judgment_panel.render(run.current_phase, _resolution_lines, controller.actors)
	result_panel.render(controller, _debug_mode)
	_update_phase_visibility(run.current_phase)
	_update_action_bar(run.current_phase)
	debug_drawer.visible = _debug_mode
	if _debug_mode:
		debug_drawer.render(controller.debug_information_report(), _debug_lines)

func _update_phase_visibility(phase: int) -> void:
	var is_pre_info: bool = phase == GameConstants.Phase.PRE_INFO
	var is_auction: bool = phase == GameConstants.Phase.AUCTION
	var is_post: bool = phase == GameConstants.Phase.POST_AUCTION
	var is_resolution: bool = phase == GameConstants.Phase.JUDGMENT or phase == GameConstants.Phase.ROUND_END
	var is_result: bool = phase == GameConstants.Phase.RUN_RESULT
	card_info_panel.visible = is_pre_info or is_auction
	auction_panel.visible = is_auction
	post_auction_panel.visible = is_post
	judgment_panel.visible = is_resolution
	result_panel.visible = is_result
	reaction_panel.visible = is_pre_info or is_auction
	participant_panel.visible = not is_result
	action_bar.visible = not is_result

func _update_action_bar(phase: int) -> void:
	var run: RunState = controller.run_state
	var is_pre_info: bool = phase == GameConstants.Phase.PRE_INFO
	var is_auction: bool = phase == GameConstants.Phase.AUCTION
	investigate_button.visible = is_pre_info
	advance_button.visible = is_pre_info or phase in [
		GameConstants.Phase.POST_AUCTION,
		GameConstants.Phase.JUDGMENT,
		GameConstants.Phase.ROUND_END,
	]
	bid_button.visible = is_auction
	pass_button.visible = is_auction
	investigate_button.disabled = not controller.can_investigate()
	bid_button.disabled = not controller.can_player_bid()
	pass_button.disabled = not controller.can_player_pass()
	if is_pre_info:
		investigate_button.text = "추가 조사 · INFO %d" % run.player_info_tokens
		advance_button.text = "경매 시작"
		action_hint.text = "공개 단서와 NPC 반응을 확인한 뒤 조사 여부를 결정하세요."
	elif is_auction:
		var required_bid: int = controller.current_required_bid()
		bid_button.text = (
			"첫 입찰 %d G" % required_bid
			if run.highest_bidder_id.is_empty()
			else "%d G로 입찰" % required_bid
		)
		action_hint.text = auction_panel.action_guidance(controller)
	elif phase == GameConstants.Phase.POST_AUCTION:
		advance_button.text = "심판으로"
		action_hint.text = "낙찰 결과를 확인하고 심판 단계로 진행하세요."
	elif phase == GameConstants.Phase.JUDGMENT:
		advance_button.text = "라운드 정산"
		action_hint.text = "심판 결과를 확인한 뒤 라운드 종료 효과를 처리하세요."
	elif phase == GameConstants.Phase.ROUND_END:
		advance_button.text = "다음 라운드"
		action_hint.text = "이번 라운드 요약을 확인하고 다음 라운드로 진행하세요."

func _append_debug_log(message: String) -> void:
	_debug_lines.append("[%03d] %s" % [_debug_lines.size() + 1, message])
	while _debug_lines.size() > 200:
		_debug_lines.remove_at(0)
	if _debug_mode:
		debug_drawer.render(controller.debug_information_report(), _debug_lines)

func _on_round_started(_round_number: int, _card_id: StringName) -> void:
	_resolution_lines.clear()

func _on_card_effect_triggered(
	card_id: StringName,
	_effect_type: int,
	target_ids: Array[StringName]
) -> void:
	var definition: CardDefinition = CardCatalog.by_id(card_id)
	var target_names: PackedStringArray = []
	for target_id: StringName in target_ids:
		var target: ActorState = controller.actor_by_id(target_id)
		target_names.append(target.display_name if target != null else String(target_id))
	_resolution_lines.append(
		"[color=#%s][b]%s 발동[/b][/color] → %s"
		% [
			UiPalette.bbcode(UiPalette.GOLD_BRIGHT),
			definition.actual_name if definition != null else card_id,
			", ".join(target_names),
		]
	)

func _on_card_consumed(card_id: StringName, owner_id: StringName) -> void:
	var definition: CardDefinition = CardCatalog.by_id(card_id)
	var owner: ActorState = controller.actor_by_id(owner_id)
	_resolution_lines.append(
		"%s 소모 · %s"
		% [definition.actual_name if definition != null else card_id, owner.display_name if owner != null else owner_id]
	)

func _on_damage_applied(actor_id: StringName, amount: int, source_card_id: StringName) -> void:
	if not _is_resolution_phase() and source_card_id.is_empty():
		return
	var actor: ActorState = controller.actor_by_id(actor_id)
	_resolution_lines.append(
		"[color=#%s]%s  -%d HP[/color]"
		% [UiPalette.bbcode(UiPalette.DANGER), actor.display_name if actor != null else actor_id, amount]
	)

func _on_gold_changed(
	actor_id: StringName,
	delta: int,
	_new_total: int,
	source_card_id: StringName
) -> void:
	if not _is_resolution_phase() and source_card_id.is_empty():
		return
	var actor: ActorState = controller.actor_by_id(actor_id)
	_resolution_lines.append(
		"%s  %s%d G"
		% [actor.display_name if actor != null else actor_id, "+" if delta >= 0 else "", delta]
	)

func _on_actor_died(actor_id: StringName) -> void:
	var actor: ActorState = controller.actor_by_id(actor_id)
	_resolution_lines.append(
		"[color=#%s][b]%s 사망[/b][/color]"
		% [UiPalette.bbcode(UiPalette.DANGER), actor.display_name if actor != null else actor_id]
	)

func _is_resolution_phase() -> bool:
	return controller.run_state.current_phase in [
		GameConstants.Phase.JUDGMENT,
		GameConstants.Phase.ROUND_END,
	]
