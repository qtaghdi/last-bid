extends Control

@onready var controller: GameFlowController = $GameFlowController
@onready var top_hud: TopHud = %TopHud
@onready var active_promise_panel: ActivePromisePanel = %ActivePromisePanel
@onready var participant_panel: ParticipantPanel = %ParticipantPanel
@onready var card_info_panel: CardInfoPanel = %CardInfoPanel
@onready var reaction_panel: ReactionPanel = %ReactionPanel
@onready var auction_panel: AuctionPanel = %AuctionPanel
@onready var negotiation_panel: NegotiationPanel = %NegotiationPanel
@onready var post_auction_panel: PostAuctionPanel = %PostAuctionPanel
@onready var judgment_panel: JudgmentPanel = %JudgmentPanel
@onready var result_panel: RunResultPanel = %RunResultPanel
@onready var debug_drawer: DebugDrawer = %DebugPanel
@onready var page_margin: MarginContainer = $PageMargin
@onready var main_menu: MainMenu = %MainMenu
@onready var settings_modal: SettingsModal = %SettingsModal
@onready var tutorial_overlay: TutorialOverlay = %TutorialOverlay
@onready var toast_layer: ToastLayer = %ToastLayer
@onready var confirmation_modal: ConfirmationModal = %ConfirmationModal
@onready var damage_flash: ColorRect = %DamageFlash
@onready var transition_overlay: ColorRect = %TransitionOverlay
@onready var context_phase_label: Label = %ContextPhaseLabel
@onready var context_guide_label: Label = %ContextGuideLabel
@onready var context_guide_panel: PanelContainer = %ContextGuide
@onready var action_bar: PanelContainer = %ActionBar
@onready var action_hint: Label = %ActionHint
@onready var bid_button: Button = %BidButton
@onready var pass_button: Button = %PassButton
@onready var investigate_button: Button = %InvestigateButton
@onready var advance_button: Button = %AdvanceButton

var _debug_lines: PackedStringArray = []
var _resolution_lines: PackedStringArray = []
var _debug_mode: bool = false
var _preferences: UiPreferences = UiPreferences.new()
var _presentation_stats: Dictionary = {"opened": 0, "sold": 0, "burned": 0}
var _pending_sale: Dictionary = {}
var _session_run_count: int = 0
var _transition_tween: Tween
var _feedback_tween: Tween

func _ready() -> void:
	$Backdrop.modulate = UiPalette.with_alpha(UiPalette.MUTED, 0.09)
	$Shade.color = UiPalette.with_alpha(UiPalette.BACKGROUND, 0.90)
	damage_flash.color = UiPalette.DANGER
	transition_overlay.color = UiPalette.BACKGROUND_SECONDARY
	bid_button.pressed.connect(_on_bid_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	top_hud.debug_toggled.connect(set_debug_mode)
	top_hud.settings_requested.connect(_open_settings)
	debug_drawer.close_requested.connect(func() -> void: set_debug_mode(false))
	result_panel.same_seed_requested.connect(_restart_same_seed)
	result_panel.new_seed_requested.connect(_restart_new_seed)
	result_panel.main_menu_requested.connect(_show_main_menu)
	post_auction_panel.open_requested.connect(_on_post_open_requested)
	post_auction_panel.keep_requested.connect(_on_post_keep_requested)
	post_auction_panel.burn_requested.connect(_on_post_burn_requested)
	post_auction_panel.sale_requested.connect(_on_post_sale_requested)
	negotiation_panel.accept_requested.connect(_on_offer_accept_requested)
	negotiation_panel.reject_requested.connect(_on_offer_reject_requested)
	negotiation_panel.counter_requested.connect(_on_offer_counter_requested)
	active_promise_panel.fulfill_requested.connect(_on_promise_fulfill_requested)
	main_menu.new_game_requested.connect(_enter_game)
	main_menu.same_seed_requested.connect(_enter_game)
	main_menu.settings_requested.connect(_open_settings)
	main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	settings_modal.applied.connect(_apply_preferences)
	settings_modal.tutorial_replay_requested.connect(_replay_tutorial)
	confirmation_modal.confirmed.connect(_on_confirmation_confirmed)
	confirmation_modal.cancelled.connect(func(_action_id: StringName) -> void: _pending_sale.clear())
	tutorial_overlay.tutorial_disabled.connect(_on_tutorial_disabled)
	_preferences.load_preferences()
	_apply_preferences()
	_configure_tooltips()
	_connect_events()
	top_hud.set_seed(GameConstants.DEFAULT_SEED)
	_start_new_run(GameConstants.DEFAULT_SEED)
	_show_main_menu()

func _connect_events() -> void:
	controller.events.state_updated.connect(_refresh)
	controller.events.phase_changed.connect(_on_phase_changed)
	controller.events.debug_logged.connect(_append_debug_log)
	controller.events.round_started.connect(_on_round_started)
	controller.events.card_effect_triggered.connect(_on_card_effect_triggered)
	controller.events.card_consumed.connect(_on_card_consumed)
	controller.events.damage_applied.connect(_on_damage_applied)
	controller.events.gold_changed.connect(_on_gold_changed)
	controller.events.actor_died.connect(_on_actor_died)
	controller.events.seal_accident_triggered.connect(_on_seal_accident_triggered)
	controller.events.seal_opened.connect(_on_seal_opened_visual)
	controller.events.card_opened.connect(_on_post_card_opened)
	controller.events.card_transferred.connect(_on_card_transferred)
	controller.events.card_burned.connect(_on_card_burned)
	controller.events.sale_accepted.connect(_on_sale_accepted)
	controller.events.promise_created.connect(_on_promise_created)
	controller.events.promise_fulfilled.connect(_on_promise_fulfilled)
	controller.events.promise_broken.connect(_on_promise_broken)
	controller.events.promise_cancelled.connect(_on_promise_cancelled)
	controller.events.betrayal_committed.connect(_on_betrayal_committed)

func _start_new_run(seed_value: int) -> void:
	_debug_lines.clear()
	_resolution_lines.clear()
	_presentation_stats = {"opened": 0, "sold": 0, "burned": 0}
	top_hud.set_seed(seed_value)
	main_menu.set_last_seed(seed_value)
	controller.start_new_run(seed_value)
	_refresh()

func _restart_same_seed() -> void:
	_enter_game(controller.run_state.rng_seed)

func _restart_new_seed() -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	_enter_game(seed_value)

func _enter_game(seed_value: int) -> void:
	var show_tutorial: bool = _preferences.tutorial_should_run() and _session_run_count == 0
	_session_run_count += 1
	main_menu.visible = false
	page_margin.visible = true
	tutorial_overlay.configure(show_tutorial, true)
	_start_new_run(seed_value)
	if show_tutorial:
		_show_tutorial_for_phase(GameConstants.Phase.PRE_INFO)

func _show_main_menu() -> void:
	main_menu.set_last_seed(controller.run_state.rng_seed if controller.run_state != null else GameConstants.DEFAULT_SEED)
	main_menu.visible = true
	page_margin.visible = false
	tutorial_overlay.configure(false)
	set_debug_mode(false)

func _open_settings() -> void:
	settings_modal.open(_preferences)

func _apply_preferences() -> void:
	_preferences.apply(self)
	top_hud.set_debug_available(_preferences.debug_panel_enabled)
	auction_panel.set_reduce_motion(_preferences.reduce_motion)
	if not _preferences.debug_panel_enabled:
		set_debug_mode(false)

func _replay_tutorial() -> void:
	_preferences.reset_tutorial()
	tutorial_overlay.configure(true, true)
	if controller.run_state != null:
		_show_tutorial_for_phase(controller.run_state.current_phase)

func _on_tutorial_disabled() -> void:
	_preferences.tutorial_enabled = false
	_preferences.complete_tutorial()

func _on_bid_pressed() -> void:
	var warning: String = controller.promise_violation_warning(&"bid")
	if _request_violation_confirmation(&"bid", warning):
		return
	_perform_bid()

func _on_pass_pressed() -> void:
	controller.request_player_pass()
	_refresh()

func _on_investigate_pressed() -> void:
	controller.request_investigate()
	_refresh()

func _on_advance_pressed() -> void:
	controller.request_advance()
	_refresh()

func _on_post_open_requested() -> void:
	var instance: CardInstance = controller.current_post_instance()
	var instance_id: StringName = instance.instance_id if instance != null else &""
	var warning: String = controller.promise_violation_warning(&"open_seal", instance_id)
	if _request_violation_confirmation(&"open_seal", warning):
		return
	_perform_open_seal()

func _on_post_keep_requested() -> void:
	controller.request_keep_post_card()
	_refresh()

func _on_post_burn_requested() -> void:
	var instance: CardInstance = controller.current_post_instance()
	var instance_id: StringName = instance.instance_id if instance != null else &""
	var warning: String = controller.promise_violation_warning(&"burn_card", instance_id)
	if _request_violation_confirmation(&"burn_card", warning):
		return
	_perform_burn()

func _on_post_sale_requested(buyer_id: StringName, price: int, clue_id: StringName) -> void:
	var instance: CardInstance = controller.current_post_instance()
	var instance_id: StringName = instance.instance_id if instance != null else &""
	var warning: String = controller.promise_violation_warning(&"sell_card", instance_id, buyer_id)
	_pending_sale = {"buyer_id": buyer_id, "price": price, "clue_id": clue_id}
	if _request_violation_confirmation(&"sell_card", warning):
		return
	_perform_sale()

func _request_violation_confirmation(action_id: StringName, warning: String) -> bool:
	if warning.is_empty():
		return false
	confirmation_modal.request_confirmation(action_id, "약속 위반 가능성", warning)
	return true

func _on_confirmation_confirmed(action_id: StringName) -> void:
	match action_id:
		&"bid":
			_perform_bid()
		&"open_seal":
			_perform_open_seal()
		&"burn_card":
			_perform_burn()
		&"sell_card":
			_perform_sale()

func _perform_bid() -> void:
	controller.request_player_bid()
	_refresh()

func _perform_open_seal() -> void:
	controller.request_open_next_seal()
	_refresh()

func _perform_burn() -> void:
	controller.request_burn_post_card()
	_refresh()

func _perform_sale() -> void:
	if _pending_sale.is_empty():
		return
	controller.request_sell_post_card(
		_pending_sale.get("buyer_id", &""),
		int(_pending_sale.get("price", 0)),
		_pending_sale.get("clue_id", &"")
	)
	_pending_sale.clear()
	_refresh()

func _on_offer_accept_requested() -> void:
	controller.request_accept_offer()
	_refresh()

func _on_offer_reject_requested() -> void:
	controller.request_reject_offer()
	_refresh()

func _on_offer_counter_requested(amount: int) -> void:
	controller.request_counter_offer(amount)
	_refresh()

func _on_promise_fulfill_requested(promise_id: StringName) -> void:
	controller.request_fulfill_promise(promise_id)
	_refresh()

func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled and _preferences.debug_panel_enabled
	if not is_node_ready():
		return
	debug_drawer.visible = _debug_mode
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
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	var alive_count: int = 0
	for actor: ActorState in controller.actors:
		if actor.alive:
			alive_count += 1
	var rule_changed: bool = run.current_min_increment != GameConstants.DEFAULT_MIN_INCREMENT
	var rule_summary: String = (
		"최소 인상 %d G" % run.current_min_increment
		if rule_changed
		else "기본 경매"
	)
	var rule_tooltip: String = (
		"현재 라운드에 공개 적용 중인 최소 인상액은 %d G입니다." % run.current_min_increment
		if rule_changed
		else "공개된 전역 규칙 변경이 없습니다. 기본 최소 인상액은 %d G입니다."
		% GameConstants.DEFAULT_MIN_INCREMENT
	)
	top_hud.render(
		run,
		player.hp if player != null else -1,
		player.max_hp if player != null else 0,
		player.gold if player != null else 0,
		player.alive if player != null else false,
		alive_count,
		controller.actors.size(),
		rule_summary,
		rule_tooltip,
		rule_changed,
		_debug_mode,
		controller.active_promise_summary()
	)
	active_promise_panel.render(controller)
	participant_panel.render(controller, _debug_mode)
	card_info_panel.render(
		run.current_card,
		controller.player_knowledge(),
		_debug_mode,
		controller.debug_effect_report()
	)
	reaction_panel.render(controller)
	auction_panel.render(controller)
	negotiation_panel.render(controller)
	post_auction_panel.render(controller)
	judgment_panel.render(run.current_phase, _resolution_lines, controller.actors)
	result_panel.render(controller, _debug_mode, _presentation_stats)
	_update_phase_visibility(run.current_phase)
	_update_action_bar(run.current_phase)
	_update_context_guide(run.current_phase)
	debug_drawer.visible = _debug_mode
	if _debug_mode:
		debug_drawer.render(controller.debug_information_report(), _debug_lines)

func _update_phase_visibility(phase: int) -> void:
	var is_pre_info: bool = phase == GameConstants.Phase.PRE_INFO
	var is_auction: bool = phase == GameConstants.Phase.AUCTION
	var is_negotiation: bool = phase == GameConstants.Phase.NEGOTIATION
	var is_post: bool = phase == GameConstants.Phase.POST_AUCTION
	var is_resolution: bool = phase == GameConstants.Phase.JUDGMENT or phase == GameConstants.Phase.ROUND_END
	var is_result: bool = phase == GameConstants.Phase.RUN_RESULT
	card_info_panel.visible = is_pre_info or is_auction
	negotiation_panel.visible = is_negotiation
	auction_panel.visible = is_auction
	post_auction_panel.visible = is_post
	judgment_panel.visible = is_resolution
	result_panel.visible = is_result
	var has_active_promises: bool = not controller.run_state.active_promises.is_empty()
	reaction_panel.visible = (is_pre_info or is_auction) and not has_active_promises
	participant_panel.visible = not is_result
	action_bar.visible = not is_result
	top_hud.visible = not is_result
	active_promise_panel.visible = not is_result and has_active_promises
	context_guide_panel.visible = not is_auction and not (is_pre_info and has_active_promises)
	context_phase_label.text = UiPalette.phase_label(phase)

func _update_action_bar(phase: int) -> void:
	var run: RunState = controller.run_state
	var is_pre_info: bool = phase == GameConstants.Phase.PRE_INFO
	var is_auction: bool = phase == GameConstants.Phase.AUCTION
	var is_negotiation: bool = phase == GameConstants.Phase.NEGOTIATION
	investigate_button.visible = is_pre_info
	advance_button.visible = is_pre_info or is_negotiation or phase in [
		GameConstants.Phase.POST_AUCTION,
		GameConstants.Phase.JUDGMENT,
		GameConstants.Phase.ROUND_END,
	]
	bid_button.visible = is_auction
	pass_button.visible = is_auction
	investigate_button.disabled = not controller.can_investigate()
	bid_button.disabled = not controller.can_player_bid()
	pass_button.disabled = not controller.can_player_pass()
	advance_button.disabled = false
	if is_pre_info:
		investigate_button.text = "추가 조사 · INFO %d" % run.player_info_tokens
		advance_button.text = "협상으로"
		action_hint.text = "공개 단서와 NPC 반응을 확인한 뒤 조사 여부를 결정하세요."
	elif is_negotiation:
		advance_button.text = "경매 시작"
		advance_button.disabled = not controller.can_advance_negotiation()
		action_hint.text = (
			"모든 제안을 처리했습니다. 경매를 시작하세요."
			if controller.can_advance_negotiation()
			else "현재 제안에 수락, 거절 또는 한 번의 가격 재제안으로 답하세요."
		)
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
		advance_button.disabled = not controller.can_advance_post_auction()
		action_hint.text = (
			"낙찰 후 처리가 완료되었습니다. 심판으로 진행하세요."
			if controller.can_advance_post_auction()
			else controller.post_action_block_reason()
		)
	elif phase == GameConstants.Phase.JUDGMENT:
		advance_button.text = "라운드 정산"
		action_hint.text = "심판 결과를 확인한 뒤 라운드 종료 효과를 처리하세요."
	elif phase == GameConstants.Phase.ROUND_END:
		advance_button.text = "다음 라운드"
		action_hint.text = "이번 라운드 요약을 확인하고 다음 라운드로 진행하세요."

func _update_context_guide(phase: int) -> void:
	match phase:
		GameConstants.Phase.PRE_INFO:
			context_guide_label.text = "핵심 단서와 NPC 반응을 비교한 뒤 정보 토큰 사용 여부를 결정하세요."
		GameConstants.Phase.NEGOTIATION:
			context_guide_label.text = "보상, 요구 행동, 기한과 위반 조건을 분리해서 확인하세요. Tell은 확정 정보가 아닙니다."
		GameConstants.Phase.AUCTION:
			context_guide_label.text = "현재 차례와 다음 입찰가를 확인하세요. 한 번 패스하면 재참여할 수 없습니다."
		GameConstants.Phase.POST_AUCTION:
			context_guide_label.text = "다음 봉인의 사고 확률과 활성 약속을 확인한 뒤 처리 방법을 선택하세요."
		GameConstants.Phase.JUDGMENT, GameConstants.Phase.ROUND_END:
			context_guide_label.text = "카드 효과, 약속 결과, 사망 순서로 정산 내용을 확인하세요."
		GameConstants.Phase.RUN_RESULT:
			context_guide_label.text = "이번 런의 카드, 약속, 평판과 Seed 기록을 확인하세요."
		_:
			context_guide_label.text = "경매 준비 중입니다."

func _configure_tooltips() -> void:
	investigate_button.tooltip_text = TooltipTerms.text("정보 토큰")
	bid_button.tooltip_text = "현재 차례에 다음 입찰가를 제시합니다. 약속 위반 위험이 있으면 먼저 경고합니다."
	pass_button.tooltip_text = "이번 경매에서 물러납니다. 패스한 뒤에는 다시 참여할 수 없습니다."
	advance_button.tooltip_text = "현재 단계의 필수 처리가 끝났을 때 다음 단계로 이동합니다."
	judgment_panel.tooltip_text = TooltipTerms.text("심판")
	post_auction_panel.tooltip_text = "%s\n%s" % [
		TooltipTerms.text("봉인"),
		TooltipTerms.text("사고 확률"),
	]
	negotiation_panel.tooltip_text = "%s\n%s" % [
		TooltipTerms.text("Tell"),
		TooltipTerms.text("Reputation"),
	]

func _on_phase_changed(phase: int) -> void:
	_play_phase_transition()
	_show_tutorial_for_phase(phase)
	if phase == GameConstants.Phase.RUN_RESULT and _preferences.tutorial_should_run():
		_preferences.complete_tutorial()

func _show_tutorial_for_phase(phase: int) -> void:
	match phase:
		GameConstants.Phase.PRE_INFO:
			tutorial_overlay.show_step(
				&"pre_info",
				"단서로 정체를 추론하세요",
				"카드의 실제 이름과 정확한 효과는 아직 숨겨져 있습니다. 위험도와 가치 범위, NPC 반응을 함께 보세요."
			)
		GameConstants.Phase.NEGOTIATION:
			tutorial_overlay.show_step(
				&"negotiation",
				"말보다 조건을 먼저 확인하세요",
				"NPC의 대사와 Tell은 항상 진실이 아닙니다. 보상, 요구 행동, 기한과 위반 조건을 나눠서 판단하세요."
			)
		GameConstants.Phase.AUCTION:
			tutorial_overlay.show_step(
				&"auction",
				"패스는 되돌릴 수 없습니다",
				"현재 차례와 다음 입찰가를 확인하세요. 패스한 참가자는 이번 경매에 다시 들어올 수 없습니다."
			)
		GameConstants.Phase.POST_AUCTION:
			tutorial_overlay.show_step(
				&"post_auction",
				"낙찰 뒤에도 선택이 남습니다",
				"봉인을 열어 정보를 얻거나, 보관·판매·소각할 수 있습니다. 봉인마다 다음 사고 확률을 확인하세요."
			)

func _on_promise_created(_promise_id: StringName, promise_type: StringName) -> void:
	toast_layer.show_message(
		"새 약속 · %s" % PromiseManager.promise_type_name(promise_type),
		&"info",
		_preferences.reduce_motion
	)
	tutorial_overlay.show_step(
		&"promise",
		"약속은 어길 수 있지만 기억됩니다",
		"활성 약속의 기한과 위반 조건을 확인하세요. 위험 행동은 경고하지만 선택을 강제로 막지는 않습니다."
	)

func _play_phase_transition() -> void:
	if _preferences.reduce_motion or not is_inside_tree():
		transition_overlay.modulate.a = 0.0
		return
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	transition_overlay.modulate.a = 0.18
	_transition_tween = create_tween()
	_transition_tween.tween_property(
		transition_overlay,
		"modulate:a",
		0.0,
		UiPalette.MOTION_NORMAL
	)

func _play_damage_feedback() -> void:
	if _preferences.reduce_motion or not is_inside_tree():
		damage_flash.modulate.a = 0.0
		return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	damage_flash.modulate.a = 0.22
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(
		damage_flash,
		"modulate:a",
		0.0,
		UiPalette.MOTION_NORMAL
	)

func _play_panel_emphasis(panel: Control, accent: Color = UiPalette.GOLD_BRIGHT) -> void:
	if _preferences.reduce_motion or not panel.is_inside_tree():
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.985, 0.985)
	panel.modulate = accent
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, UiPalette.MOTION_NORMAL)
	tween.parallel().tween_property(panel, "modulate", Color.WHITE, UiPalette.MOTION_SLOW)

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
	var visible_card_name: String = definition.actual_name if definition != null else String(card_id)
	var post_instance: CardInstance = controller.current_post_instance()
	if (
		controller.run_state.current_phase == GameConstants.Phase.POST_AUCTION
		and post_instance != null
		and post_instance.definition_id == card_id
		and post_instance.reveal_level != GameConstants.RevealLevel.FULLY_REVEALED
		and definition != null
	):
		visible_card_name = definition.public_name
	var target_names: PackedStringArray = []
	for target_id: StringName in target_ids:
		var target: ActorState = controller.actor_by_id(target_id)
		target_names.append(target.display_name if target != null else String(target_id))
	_resolution_lines.append(
		"[color=#%s][b]%s 발동[/b][/color] → %s"
		% [
			UiPalette.bbcode(UiPalette.GOLD_BRIGHT),
			visible_card_name,
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
	_play_damage_feedback()
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

func _on_seal_accident_triggered(
	_instance_id: StringName,
	seal_number: int,
	result_text: String
) -> void:
	_resolution_lines.append(
		"[color=#%s][b]봉인 %d 사고[/b][/color] · %s"
		% [UiPalette.bbcode(UiPalette.DANGER), seal_number, result_text]
	)
	toast_layer.show_message(
		"봉인 %d 사고 · %s" % [seal_number, result_text],
		&"danger",
		_preferences.reduce_motion
	)
	_play_damage_feedback()

func _on_seal_opened_visual(
	_instance_id: StringName,
	seal_number: int,
	_reveal_text: String
) -> void:
	toast_layer.show_message(
		"봉인 %d 개방" % seal_number,
		&"info",
		_preferences.reduce_motion
	)
	_play_panel_emphasis(post_auction_panel)

func _on_post_card_opened(_instance_id: StringName, owner_id: StringName) -> void:
	_presentation_stats["opened"] = int(_presentation_stats.get("opened", 0)) + 1
	var owner: ActorState = controller.actor_by_id(owner_id)
	var definition: CardDefinition = controller.run_state.current_card
	_resolution_lines.append(
		"[color=#%s][b]%s 완전 개봉[/b][/color] · %s"
		% [
			UiPalette.bbcode(UiPalette.GOLD_BRIGHT),
			definition.actual_name if definition != null else "카드",
			owner.display_name if owner != null else owner_id,
		]
	)
	toast_layer.show_message(
		"카드 완전 공개 · %s" % (definition.actual_name if definition != null else "카드"),
		&"success",
		_preferences.reduce_motion
	)
	_play_panel_emphasis(post_auction_panel, UiPalette.GOLD_BRIGHT)

func _on_card_transferred(
	_instance_id: StringName,
	from_id: StringName,
	to_id: StringName
) -> void:
	var from_actor: ActorState = controller.actor_by_id(from_id)
	var to_actor: ActorState = controller.actor_by_id(to_id)
	_resolution_lines.append(
		"소유권 이전 · %s → %s"
		% [
			from_actor.display_name if from_actor != null else from_id,
			to_actor.display_name if to_actor != null else to_id,
		]
	)

func _on_card_burned(_instance_id: StringName, former_owner_id: StringName) -> void:
	_presentation_stats["burned"] = int(_presentation_stats.get("burned", 0)) + 1
	var owner: ActorState = controller.actor_by_id(former_owner_id)
	_resolution_lines.append(
		"카드 소각 · %s" % [owner.display_name if owner != null else former_owner_id]
	)
	toast_layer.show_message("카드를 소각했습니다.", &"danger", _preferences.reduce_motion)

func _on_sale_accepted(
	_instance_id: StringName,
	buyer_id: StringName,
	price: int
) -> void:
	_presentation_stats["sold"] = int(_presentation_stats.get("sold", 0)) + 1
	var buyer: ActorState = controller.actor_by_id(buyer_id)
	toast_layer.show_message(
		"판매 성사 · %s · %d G" % [buyer.display_name if buyer != null else "NPC", price],
		&"success",
		_preferences.reduce_motion
	)

func _on_promise_fulfilled(
	_promise_id: StringName,
	_fulfilled_by: StringName,
	reason: String
) -> void:
	_resolution_lines.append(
		"[color=#%s][b]약속 이행[/b][/color] · %s"
		% [UiPalette.bbcode(UiPalette.GOLD_BRIGHT), reason]
	)
	toast_layer.show_message("약속 이행 · %s" % reason, &"success", _preferences.reduce_motion)

func _on_promise_broken(
	_promise_id: StringName,
	_broken_by: StringName,
	reason: String
) -> void:
	_resolution_lines.append(
		"[color=#%s][b]약속 위반[/b][/color] · %s"
		% [UiPalette.bbcode(UiPalette.DANGER), reason]
	)
	toast_layer.show_message("약속 위반 · %s" % reason, &"danger", _preferences.reduce_motion)

func _on_promise_cancelled(_promise_id: StringName, reason: String) -> void:
	_resolution_lines.append("약속 취소 · %s" % reason)
	toast_layer.show_message("약속 취소 · %s" % reason, &"info", _preferences.reduce_motion)

func _on_betrayal_committed(
	actor_id: StringName,
	_promise_id: StringName,
	reason: String
) -> void:
	var actor: ActorState = controller.actor_by_id(actor_id)
	_resolution_lines.append(
		"[color=#%s][b]%s의 배신[/b][/color] · %s"
		% [
			UiPalette.bbcode(UiPalette.DANGER),
			actor.display_name if actor != null else "NPC",
			reason,
		]
	)
	toast_layer.show_message(
		"%s의 배신" % (actor.display_name if actor != null else "NPC"),
		&"danger",
		_preferences.reduce_motion
	)

func _is_resolution_phase() -> bool:
	return controller.run_state.current_phase in [
		GameConstants.Phase.JUDGMENT,
		GameConstants.Phase.ROUND_END,
	]
