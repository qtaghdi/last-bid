extends SceneTree

var _failures: int = 0
var _assertions: int = 0

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	print("LAST BID headless tests")
	_test_public_clue_data()
	_test_card_information_visibility()
	_test_knowledge_distribution_and_determinism()
	_test_information_token_investigation()
	_test_npc_evaluates_only_known_clues()
	_test_archetype_preferences()
	_test_gambler_bluff_is_limited_and_deterministic()
	_test_same_seed_replays()
	_test_auction_guards()
	_test_auction_settlement_and_discard()
	_test_delayed_effect_rounds()
	_test_broken_chalice_guard()
	_test_golden_gallows_targets_richest()
	_test_blood_loan_repayment()
	_test_price_surge_restores()
	_test_tied_targets_all_resolve()
	_test_post_auction_requires_resolution()
	_test_post_auction_ui_actions()
	_test_seal_probabilities_and_opening()
	_test_seal_accident_determinism()
	_test_sealed_inventory_limit()
	_test_sale_and_transfer_guards()
	_test_burn_and_delayed_transfer_policies()
	_test_npc_post_auction_determinism()
	_test_negotiation_phase_and_generation()
	_test_negotiation_determinism_and_rng_isolation()
	_test_offer_responses_and_relationships()
	_test_offer_type_effects()
	_test_character_emotion_tells_and_visibility()
	_test_emergency_abilities()
	_test_dialogue_data_and_rng_isolation()
	_test_promise_creation_and_six_types()
	_test_promise_fulfillment_and_violation()
	_test_promise_rewards_reputation_and_memory()
	_test_npc_betrayal_determinism_and_personality()
	_test_promise_death_cancellation_and_ui()
	_test_visual_design_system_and_components()
	_test_main_menu_settings_and_onboarding()
	_test_violation_warning_and_visual_feedback()
	await _test_visual_layout_resolutions_and_scales()
	_test_player_death_is_defeat()
	_test_round_ten_survival_is_victory()
	_test_twenty_simulations_finish()
	_test_twenty_promise_simulations_finish()
	if _failures == 0:
		print("PASS: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("FAIL: %d failures / %d assertions" % [_failures, _assertions])
		quit(1)

func _test_public_clue_data() -> void:
	var digit_pattern: RegEx = RegEx.new()
	digit_pattern.compile("[0-9]")
	for card: CardDefinition in CardCatalog.load_all():
		var structured_clues: PackedStringArray = [
			card.public_name,
			card.risk_range,
			card.value_range,
			card.trigger_timing,
			card.target_type,
		]
		var joined_clues: String = " ".join(structured_clues)
		_assert_true(not card.actual_name.is_empty(), "%s 실제 이름이 존재함" % card.id)
		_assert_true(not card.public_name.is_empty(), "%s 공개 출품명이 존재함" % card.id)
		_assert_true(card.public_name != card.actual_name, "%s 공개 출품명과 정확한 이름이 다름" % card.id)
		_assert_true(not structured_clues.has(""), "%s 구조화 단서 항목이 모두 존재함" % card.id)
		_assert_true(not joined_clues.contains(String(card.id)), "%s 공개 단서에 내부 ID가 없음" % card.id)
		_assert_true(not joined_clues.contains(card.actual_name), "%s 공개 단서에 정확한 이름이 없음" % card.id)
		_assert_true(joined_clues != card.description, "%s 공개 단서와 전체 효과 설명이 분리됨" % card.id)
		_assert_true(digit_pattern.search(joined_clues) == null, "%s 공개 단서에 정확한 수치가 없음" % card.id)
		_assert_equal(card.public_clues.size(), 5, "%s 기본 공개 단서 5개" % card.id)
		_assert_equal(card.hidden_clues.size(), 3, "%s 조사 단서 3개" % card.id)
		_assert_true(not card.tags.is_empty(), "%s NPC 평가 태그 존재" % card.id)

func _test_card_information_visibility() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var top_hud: TopHud = ui.get_node("%TopHud") as TopHud
	var participant_panel: ParticipantPanel = ui.get_node("%ParticipantPanel") as ParticipantPanel
	var card_panel: CardInfoPanel = ui.get_node("%CardInfoPanel") as CardInfoPanel
	var reaction_panel: ReactionPanel = ui.get_node("%ReactionPanel") as ReactionPanel
	var auction_panel: AuctionPanel = ui.get_node("%AuctionPanel") as AuctionPanel
	var negotiation_panel: NegotiationPanel = ui.get_node("%NegotiationPanel") as NegotiationPanel
	var post_panel: PostAuctionPanel = ui.get_node("%PostAuctionPanel") as PostAuctionPanel
	var judgment_panel: JudgmentPanel = ui.get_node("%JudgmentPanel") as JudgmentPanel
	var result_panel: RunResultPanel = ui.get_node("%RunResultPanel") as RunResultPanel
	var debug_panel: DebugDrawer = ui.get_node("%DebugPanel") as DebugDrawer
	var action_bar: PanelContainer = ui.get_node("%ActionBar") as PanelContainer
	var bid_button: Button = ui.get_node("%BidButton") as Button
	var pass_button: Button = ui.get_node("%PassButton") as Button
	var investigate_button: Button = ui.get_node("%InvestigateButton") as Button
	var advance_button: Button = ui.get_node("%AdvanceButton") as Button
	var card: CardDefinition = controller.run_state.current_card
	var player_knowledge: KnowledgeState = controller.player_knowledge()
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)

	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.PRE_INFO, "UI가 PRE_INFO에서 시작")
	_assert_equal(top_hud.displayed_phase(), "사전 정보", "상단 HUD가 사용자용 단계명을 표시")
	_assert_true(not top_hud.displayed_phase().contains("PRE_INFO"), "상단 HUD에서 내부 enum 이름 숨김")
	_assert_true(top_hud.displayed_info().contains("2"), "PRE_INFO 정보 토큰 표시")
	_assert_equal(card_panel.displayed_name(), card.public_name, "PRE_INFO에서 공개 출품명만 표시")
	_assert_true(card_panel.displayed_name() != card.actual_name, "PRE_INFO에서 정확한 이름 숨김")
	_assert_true(not card_panel.displayed_name().contains(String(card.id)), "PRE_INFO에서 내부 ID 숨김")
	_assert_equal(player_knowledge.known_clue_ids.size(), 2, "플레이어 기본 공개 단서 2개")
	_assert_true(not card_panel.displayed_clues().contains(card.description), "PRE_INFO에서 전체 효과 숨김")
	_assert_true(participant_panel.visible, "PRE_INFO 참가자 패널 표시")
	_assert_true(reaction_panel.visible, "PRE_INFO NPC 반응 패널 표시")
	_assert_true(card_panel.visible, "PRE_INFO 카드 단서 패널 표시")
	_assert_true(not auction_panel.visible, "PRE_INFO 경매 정보 패널 숨김")
	_assert_true(not post_panel.visible and not judgment_panel.visible and not result_panel.visible, "PRE_INFO에서 다른 단계 패널 숨김")
	_assert_true(not bid_button.visible and not pass_button.visible, "PRE_INFO에서 입찰 액션 숨김")
	_assert_true(investigate_button.visible and advance_button.visible, "PRE_INFO 조사와 경매 시작 액션 표시")
	_assert_true(not investigate_button.disabled, "PRE_INFO 추가 조사 버튼 활성화")
	_assert_true(not debug_panel.visible, "일반 모드에서 디버그 로그 숨김")
	var owned_card: CardDefinition = CardCatalog.by_id(&"broken_chalice")
	controller.effects.acquire_card(owned_card, player, controller.actors)
	_assert_true(participant_panel.combined_text().contains(owned_card.public_name), "PRE_INFO 보유 카드도 공개 출품명으로 표시")
	_assert_true(not participant_panel.combined_text().contains(owned_card.actual_name), "PRE_INFO 보유 카드의 정확한 이름 숨김")
	_assert_true(not participant_panel.combined_text().contains(String(owned_card.id)), "PRE_INFO 보유 카드의 내부 ID 숨김")
	_assert_true(participant_panel.combined_text().contains("“"), "PRE_INFO에서 NPC 대사 표시")

	var clue_count_before: int = player_knowledge.known_clue_ids.size()
	_assert_true(controller.request_investigate(), "PRE_INFO 조사 액션 성공")
	_assert_equal(player_knowledge.known_clue_ids.size(), clue_count_before + 1, "조사 후 새 단서가 지식에 추가")
	_assert_true(card_panel.displayed_clues().contains("◆ 새 조사 단서"), "조사 결과를 카드 패널에서 직접 강조")
	_assert_true(top_hud.displayed_info().contains("1"), "조사 직후 HUD 토큰 갱신")
	var remaining_tokens: int = controller.run_state.player_info_tokens
	controller.run_state.player_info_tokens = 0
	ui.refresh_ui()
	_assert_true(investigate_button.disabled, "정보 토큰 0이면 조사 버튼 비활성")
	controller.run_state.player_info_tokens = remaining_tokens
	ui.refresh_ui()

	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.NEGOTIATION, "PRE_INFO 후 NEGOTIATION 진입")
	_assert_equal(top_hud.displayed_phase(), "협상", "NEGOTIATION 사용자용 단계명 표시")
	_assert_true(negotiation_panel.visible, "NEGOTIATION 전용 패널 표시")
	_assert_true(not card_panel.visible and not auction_panel.visible and not reaction_panel.visible, "NEGOTIATION에서 이전 단계 패널 숨김")
	_assert_true(not bid_button.visible and not pass_button.visible and not investigate_button.visible, "NEGOTIATION에서 경매 액션 숨김")
	var negotiation_minimum: Vector2 = (ui.get_node("PageMargin/Page") as Control).get_combined_minimum_size()
	_assert_true(
		negotiation_minimum.x <= 1244.0 and negotiation_minimum.y <= 688.0,
		"NEGOTIATION 최소 레이아웃이 1280x720 콘텐츠 영역에 수용 (%s)" % negotiation_minimum
	)
	while controller.current_negotiation_offer() != null:
		_assert_true(controller.request_reject_offer(), "협상 제안 순차 거절 처리")
	ui.refresh_ui()
	_assert_true(advance_button.visible and not advance_button.disabled, "모든 협상 처리 후 경매 시작 활성")
	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.AUCTION, "경매 시작 후 AUCTION 진입")
	_assert_equal(top_hud.displayed_phase(), "경매", "AUCTION 사용자용 단계명 표시")
	_assert_equal(card_panel.displayed_name(), card.public_name, "AUCTION에서 공개 출품명 유지")
	_assert_true(not card_panel.displayed_clues().contains(card.description), "AUCTION에서 전체 효과 숨김")
	_assert_true(card_panel.visible and auction_panel.visible and reaction_panel.visible, "AUCTION 핵심 패널 표시")
	_assert_true(not post_panel.visible and not judgment_panel.visible and not result_panel.visible, "AUCTION에서 다른 단계 패널 숨김")
	_assert_true(not investigate_button.visible and not advance_button.visible, "AUCTION에서 조사와 진행 버튼 숨김")
	_assert_true(bid_button.visible and pass_button.visible, "AUCTION에서 입찰과 패스 버튼 표시")
	var price_label: Label = auction_panel.get_node("%PriceLabel") as Label
	_assert_true(price_label.text.contains("입찰 없음"), "무입찰 현재가를 입찰 없음으로 표시")
	_assert_true(not price_label.text.contains("0 G"), "무입찰 현재가에 0 G를 표시하지 않음")
	_assert_equal(bid_button.text, "첫 입찰 %d G" % card.starting_bid, "AUCTION 첫 입찰 버튼 문구")

	controller.auction._turn_index = 1
	ui.refresh_ui()
	_assert_true(bid_button.disabled, "플레이어 차례가 아니면 입찰 버튼 비활성")
	controller.auction._turn_index = 0
	player.has_passed = true
	ui.refresh_ui()
	_assert_true(bid_button.disabled, "패스한 플레이어의 입찰 버튼 비활성")
	player.has_passed = false
	var player_gold: int = player.gold
	player.gold = 0
	ui.refresh_ui()
	_assert_true(bid_button.disabled, "골드 부족 시 입찰 버튼 비활성")
	player.gold = player_gold
	controller.run_state.highest_bidder_id = GameConstants.PLAYER_ID
	controller.run_state.current_bid = card.starting_bid
	ui.refresh_ui()
	_assert_true(participant_panel.combined_text().contains("최고 입찰자"), "최고 입찰자 상태를 참가자 패널에 반영")
	controller.run_state.highest_bidder_id = &""
	controller.run_state.current_bid = 0
	ui.refresh_ui()

	ui.set_debug_mode(true)
	_assert_true(ui.is_debug_mode(), "DEBUG 모드 활성화")
	_assert_true(card_panel.displayed_name().contains(card.actual_name), "DEBUG에서 정확한 이름 표시")
	_assert_true(card_panel.displayed_name().contains(String(card.id)), "DEBUG에서 내부 ID 표시")
	_assert_true(card_panel.displayed_clues().contains(card.description), "DEBUG에서 전체 카드 설명 표시")
	_assert_true(card_panel.displayed_clues().contains(card.effects[0].description), "DEBUG에서 개별 효과 설명 표시")
	_assert_true(debug_panel.inspector_text().contains("KNOWLEDGE"), "DEBUG에서 참가자별 지식 표시")
	_assert_true(debug_panel.visible, "DEBUG에서 로그 패널 표시")

	ui.set_debug_mode(false)
	controller.request_player_pass()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.POST_AUCTION, "경매 종료 후 POST_AUCTION 진입")
	_assert_equal(top_hud.displayed_phase(), "낙찰 후 처리", "POST_AUCTION 사용자용 단계명 표시")
	_assert_true(post_panel.visible, "POST_AUCTION 전용 패널 표시")
	_assert_true(not card_panel.visible and not auction_panel.visible and not reaction_panel.visible, "POST_AUCTION에서 이전 단계 패널 숨김")
	_assert_true(not judgment_panel.visible and not result_panel.visible, "POST_AUCTION에서 이후 단계 패널 숨김")
	_assert_true(advance_button.visible and not bid_button.visible and not pass_button.visible, "POST_AUCTION에서 심판 진행만 활성")
	var post_text: String = (post_panel.get_node("%ResultLabel") as Label).text
	var post_instance: CardInstance = controller.current_post_instance()
	if post_instance != null and post_instance.reveal_level == GameConstants.RevealLevel.FULLY_REVEALED:
		_assert_true(post_text.contains(card.actual_name), "완전 개봉된 낙찰 결과에 실제 이름 표시")
	else:
		_assert_true(post_text.contains(card.public_name), "봉인된 낙찰 결과에 공개 출품명 표시")
		_assert_true(not post_text.contains(card.actual_name), "봉인된 POST_AUCTION에서 실제 이름 숨김")
	_assert_true(not debug_panel.visible, "DEBUG 해제 시 로그 패널 숨김")

	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.JUDGMENT, "POST_AUCTION 이후 JUDGMENT 진입")
	controller.events.damage_applied.emit(GameConstants.PLAYER_ID, 1, &"ui_test")
	ui.refresh_ui()
	_assert_equal(top_hud.displayed_phase(), "심판", "JUDGMENT 사용자용 단계명 표시")
	_assert_true(judgment_panel.visible and not post_panel.visible, "JUDGMENT 전용 결과 패널 표시")
	_assert_true(judgment_panel.summary_text().contains("-1 HP"), "심판 결과를 로그 없이 결과 패널에 표시")

	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.ROUND_END, "JUDGMENT 이후 ROUND_END 진입")
	_assert_equal(top_hud.displayed_phase(), "라운드 종료", "ROUND_END 사용자용 단계명 표시")
	_assert_true(judgment_panel.visible, "ROUND_END에서 라운드 요약 패널 유지")

	var replay_seed: int = controller.run_state.rng_seed
	ui.call("_start_new_run", replay_seed)
	player = controller.actor_by_id(GameConstants.PLAYER_ID)
	controller.effects.apply_damage(player, player.hp, &"ui_test")
	controller.call("_evaluate_terminal_state")
	ui.refresh_ui()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.RUN_RESULT, "플레이어 사망 시 RUN_RESULT 진입")
	_assert_true(result_panel.visible, "RUN_RESULT 결과 패널 표시")
	_assert_true(not participant_panel.visible and not reaction_panel.visible and not action_bar.visible, "RUN_RESULT에서 플레이 액션 패널 숨김")
	ui.restart_same_seed()
	_assert_equal(controller.run_state.rng_seed, replay_seed, "같은 시드로 다시 시작 시 시드 유지")
	_assert_equal(controller.run_state.current_round, 1, "같은 시드 재시작 시 1라운드로 초기화")
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.PRE_INFO, "같은 시드 재시작 시 PRE_INFO로 복귀")
	_assert_true(card_panel.visible and reaction_panel.visible and participant_panel.visible, "재시작 후 PRE_INFO 패널 복구")

	var page: Control = ui.get_node("PageMargin/Page") as Control
	var minimum: Vector2 = page.get_combined_minimum_size()
	_assert_true(minimum.x <= 1244.0 and minimum.y <= 688.0, "1280x720 가용 영역 안에 최소 레이아웃 수용")
	root.size = Vector2i(1280, 720)
	_assert_true(ui.size.x >= 1280.0 and ui.size.y >= 720.0, "1280x720 루트 레이아웃 확장")
	var page_margin: MarginContainer = ui.get_node("PageMargin") as MarginContainer
	_assert_true(
		ui.anchor_right == 1.0
		and ui.anchor_bottom == 1.0
		and page_margin.anchor_right == 1.0
		and page_margin.anchor_bottom == 1.0,
		"전체 화면 Anchor 구성"
	)
	var large_viewport: SubViewport = SubViewport.new()
	large_viewport.size = Vector2i(1920, 1080)
	root.add_child(large_viewport)
	var large_ui: Control = packed_scene.instantiate() as Control
	large_viewport.add_child(large_ui)
	_assert_equal(large_ui.size, Vector2(1920, 1080), "1920x1080 SubViewport에서 루트 UI 확장")
	large_viewport.free()
	ui.free()

func _test_knowledge_distribution_and_determinism() -> void:
	var first: GameFlowController = _new_controller(5150)
	var second: GameFlowController = _new_controller(5150)
	var player_ids: Array[StringName] = first.player_knowledge().known_clue_ids
	_assert_equal(player_ids, second.player_knowledge().known_clue_ids, "같은 시드에서 플레이어 단서 배분 동일")
	_assert_equal(player_ids.size(), 2, "플레이어에게 기본 단서 2개 배분")
	var differs_from_player: bool = false
	for actor: ActorState in first.actors:
		var first_state: KnowledgeState = first.knowledge_for(actor.actor_id)
		var second_state: KnowledgeState = second.knowledge_for(actor.actor_id)
		_assert_equal(first_state.known_clue_ids, second_state.known_clue_ids, "%s 단서 배분 재현" % actor.display_name)
		if actor.actor_type == GameConstants.ActorType.NPC:
			_assert_true(first_state.known_clue_ids.size() >= 1 and first_state.known_clue_ids.size() <= 2, "%s NPC 단서 1~2개" % actor.display_name)
			_assert_equal(first.npc_dialogue_for(actor.actor_id), second.npc_dialogue_for(actor.actor_id), "%s 대사 재현" % actor.display_name)
			_assert_equal(first.npc_ai.has_bluff_intent(actor.actor_id), second.npc_ai.has_bluff_intent(actor.actor_id), "%s 허세 의도 재현" % actor.display_name)
			if first_state.known_clue_ids != player_ids:
				differs_from_player = true
	_assert_true(differs_from_player, "플레이어와 NPC의 KnowledgeState가 다를 수 있음")
	first.free()
	second.free()

func _test_information_token_investigation() -> void:
	var controller: GameFlowController = _new_controller(6160)
	var knowledge: KnowledgeState = controller.player_knowledge()
	var initial_ids: Array[StringName] = knowledge.known_clue_ids.duplicate()
	_assert_equal(controller.run_state.player_info_tokens, 2, "런 시작 정보 토큰 2개")
	_assert_true(controller.request_investigate(), "첫 추가 조사 성공")
	_assert_equal(controller.run_state.player_info_tokens, 1, "조사 후 토큰 정확히 1개 감소")
	_assert_equal(knowledge.known_clue_ids.size(), initial_ids.size() + 1, "조사 단서 정확히 1개 추가")
	_assert_equal(knowledge.reveal_level, GameConstants.RevealLevel.INVESTIGATED, "조사 후 INVESTIGATED")
	_assert_true(controller.request_investigate(), "두 번째 추가 조사 성공")
	_assert_equal(controller.run_state.player_info_tokens, 0, "두 번 조사 후 토큰 0개")
	var unique_ids: Dictionary = {}
	for clue_id: StringName in knowledge.known_clue_ids:
		unique_ids[clue_id] = true
	_assert_equal(unique_ids.size(), knowledge.known_clue_ids.size(), "이미 아는 단서 중복 공개 없음")
	var count_before_failed_attempt: int = knowledge.known_clue_ids.size()
	_assert_true(not controller.request_investigate(), "토큰 0이면 조사 불가")
	_assert_equal(knowledge.known_clue_ids.size(), count_before_failed_attempt, "실패한 조사에서 단서 변화 없음")
	knowledge.reveal_fully()
	_assert_equal(knowledge.reveal_level, GameConstants.RevealLevel.FULLY_REVEALED, "명시적 FULLY_REVEALED 전환 지원")
	controller.free()

func _test_npc_evaluates_only_known_clues() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ai/simple_npc_ai.gd")
	_assert_true(not source.contains("CardDefinition"), "NPC AI API가 CardDefinition을 받지 않음")
	_assert_true(not source.contains(".effects"), "NPC AI가 실제 effects에 접근하지 않음")
	var ui_source: String = FileAccess.get_file_as_string("res://scripts/ui/main_ui.gd")
	_assert_true(not ui_source.contains(".effects"), "일반 UI 스크립트가 effects를 직접 읽지 않음")
	var ai: SimpleNpcAi = SimpleNpcAi.new()
	var actor: ActorState = ActorState.create(&"npc_test", "채권자", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_CREDITOR)
	var state: KnowledgeState = _knowledge_with_clue(PackedStringArray(["economy", "contract"]), 430, 120)
	var actors: Array[ActorState] = [actor]
	var before: Dictionary = ai.evaluate_knowledge(actor, state, PackedStringArray(), actors, 1)
	var after: Dictionary = ai.evaluate_knowledge(actor, state, PackedStringArray(), actors, 1)
	_assert_equal(before, after, "알지 못하는 단서는 평가에 영향 없음")
	_assert_equal(before["used_clue_ids"], state.known_clue_ids, "평가에 사용한 단서가 KnowledgeState와 일치")

func _test_archetype_preferences() -> void:
	var ai: SimpleNpcAi = SimpleNpcAi.new()
	var collector: ActorState = ActorState.create(&"collector", "수집가", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_COLLECTOR)
	var creditor: ActorState = ActorState.create(&"creditor", "채권자", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_CREDITOR)
	var gambler: ActorState = ActorState.create(&"gambler", "도박사", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_GAMBLER)
	var actors: Array[ActorState] = [collector, creditor, gambler]
	var neutral: KnowledgeState = _knowledge_with_clue(PackedStringArray(["neutral"]), 450, 150)
	var collector_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["rare", "cursed", "ownership"]), 450, 150)
	var creditor_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["economy", "contract", "loan"]), 450, 150)
	var gambler_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["high_risk", "high_reward", "gamble"]), 450, 150)
	_assert_true(
		int(ai.evaluate_knowledge(collector, collector_knowledge, PackedStringArray(), actors, 1)["final_value"])
		> int(ai.evaluate_knowledge(collector, neutral, PackedStringArray(), actors, 1)["final_value"]),
		"수집가가 희귀·저주·소유 태그를 높게 평가"
	)
	_assert_true(
		int(ai.evaluate_knowledge(creditor, creditor_knowledge, PackedStringArray(), actors, 1)["final_value"])
		> int(ai.evaluate_knowledge(creditor, neutral, PackedStringArray(), actors, 1)["final_value"]),
		"채권자가 경제·계약·대출 태그를 높게 평가"
	)
	_assert_true(
		int(ai.evaluate_knowledge(gambler, gambler_knowledge, PackedStringArray(), actors, 1)["final_value"])
		> int(ai.evaluate_knowledge(gambler, neutral, PackedStringArray(), actors, 1)["final_value"]),
		"도박사가 고위험·고수익 태그를 높게 평가"
	)
	var mixed_knowledge: KnowledgeState = _knowledge_with_clue(
		PackedStringArray(["ownership", "economy", "high_risk", "high_reward"]),
		470,
		180
	)
	var collector_value: int = int(ai.evaluate_knowledge(collector, mixed_knowledge, PackedStringArray(), actors, 1)["final_value"])
	var creditor_value: int = int(ai.evaluate_knowledge(creditor, mixed_knowledge, PackedStringArray(), actors, 1)["final_value"])
	var gambler_value: int = int(ai.evaluate_knowledge(gambler, mixed_knowledge, PackedStringArray(), actors, 1)["final_value"])
	_assert_true(
		collector_value != creditor_value or creditor_value != gambler_value,
		"같은 지식의 같은 카드도 아키타입별 주관적 가치가 다름"
	)

func _test_gambler_bluff_is_limited_and_deterministic() -> void:
	var selected_seed: int = -1
	var first_result: Dictionary = {}
	for seed_value: int in range(1, 80):
		var attempt: Dictionary = _prepare_low_value_gambler(seed_value)
		if bool(attempt["intent"]):
			selected_seed = seed_value
			first_result = attempt
			break
	_assert_true(selected_seed > 0, "도박사가 허세 의도를 가질 수 있음")
	if selected_seed > 0:
		var repeated: Dictionary = _prepare_low_value_gambler(selected_seed)
		_assert_equal(first_result["intent"], repeated["intent"], "같은 시드에서 허세 의도 동일")
		_assert_equal(first_result["remaining"], repeated["remaining"], "같은 시드에서 허세 횟수 동일")
		_assert_true(int(first_result["remaining"]) >= 1 and int(first_result["remaining"]) <= 2, "허세 입찰 최대 1~2회")
		_assert_true(bool(first_result["decision"].get("bluff", false)), "경쟁 관심이 있을 때 실제 허세 입찰 가능")

func _test_same_seed_replays() -> void:
	var rng_a: CentralRng = CentralRng.new(77123)
	var rng_b: CentralRng = CentralRng.new(77123)
	var sequence_a: Array[int] = []
	var sequence_b: Array[int] = []
	for index: int in range(12):
		sequence_a.append(rng_a.randi_range(0, 100000))
		sequence_b.append(rng_b.randi_range(0, 100000))
	_assert_equal(sequence_a, sequence_b, "같은 시드의 중앙 RNG 수열이 동일함")
	var catalog_a: Array[CardDefinition] = CardCatalog.load_all()
	var catalog_b: Array[CardDefinition] = CardCatalog.load_all()
	var catalog_ids_a: Array[StringName] = []
	var catalog_ids_b: Array[StringName] = []
	for card: CardDefinition in catalog_a:
		catalog_ids_a.append(card.id)
	for card: CardDefinition in catalog_b:
		catalog_ids_b.append(card.id)
	_assert_equal(catalog_ids_a, catalog_ids_b, "카드 카탈로그 순서가 동일함")
	var direct_deck_a: Array[StringName] = _make_test_deck_ids(77123)
	var direct_deck_b: Array[StringName] = _make_test_deck_ids(77123)
	_assert_equal(direct_deck_a, direct_deck_b, "중앙 RNG로 직접 만든 덱이 동일함")
	var controller_a: GameFlowController = _new_controller(77123)
	var controller_b: GameFlowController = _new_controller(77123)
	_assert_equal(controller_a.rng.rng_seed, controller_b.rng.rng_seed, "컨트롤러 RNG 시드가 동일함")
	_assert_equal(controller_a.rng.randi_range(0, 100000), controller_b.rng.randi_range(0, 100000), "덱 생성 후 RNG 상태가 동일함")
	_assert_equal(controller_a.deck_order(), controller_b.deck_order(), "게임 시작 직후 같은 시드 덱이 동일함")
	controller_a.free()
	controller_b.free()
	var first: Dictionary = _simulate_run(77123, true)
	var second: Dictionary = _simulate_run(77123, true)
	_assert_equal(first["deck"], second["deck"], "같은 시드의 카드 순서가 동일함")
	_assert_equal(first["trace"], second["trace"], "같은 시드의 NPC 입찰 및 패스 행동이 동일함")
	_assert_equal(first["result"], second["result"], "같은 시드의 최종 결과가 동일함")

func _test_auction_guards() -> void:
	var run_state: RunState = RunState.new()
	run_state.reset(11)
	run_state.current_card = CardCatalog.by_id(&"broken_chalice")
	run_state.current_min_increment = GameConstants.DEFAULT_MIN_INCREMENT
	var events: EventBus = EventBus.new()
	root.add_child(events)
	var rng: CentralRng = CentralRng.new(11)
	var ai: SimpleNpcAi = SimpleNpcAi.new()
	var auction: AuctionSystem = AuctionSystem.new()
	auction.setup(run_state, events, rng, ai)
	var player: ActorState = ActorState.create(GameConstants.PLAYER_ID, "플레이어", GameConstants.ActorType.PLAYER)
	player.gold = run_state.current_card.starting_bid - 1
	var npc: ActorState = ActorState.create(&"npc_test", "NPC", GameConstants.ActorType.NPC)
	var dead_npc: ActorState = ActorState.create(&"npc_dead", "사망 NPC", GameConstants.ActorType.NPC)
	dead_npc.hp = 0
	dead_npc.alive = false
	var actors: Array[ActorState] = [player, npc, dead_npc]
	auction.start_auction(actors)
	_assert_true(not auction.can_actor_bid(player.actor_id), "보유 골드보다 높은 입찰 불가")
	_assert_true(not auction.place_next_bid(player.actor_id), "골드 부족 입찰 요청이 거부됨")
	_assert_true(not auction.can_actor_bid(dead_npc.actor_id), "사망한 참가자는 입찰 불가")
	_assert_true(auction.pass_current(player.actor_id), "플레이어 패스 가능")
	_assert_true(player.has_passed, "패스 상태 기록")
	_assert_true(not auction.place_next_bid(player.actor_id), "패스한 참가자는 재참여 불가")
	events.free()

func _test_auction_settlement_and_discard() -> void:
	var run_state: RunState = RunState.new()
	run_state.reset(12)
	run_state.current_card = CardCatalog.by_id(&"cursed_vault")
	var events: EventBus = EventBus.new()
	root.add_child(events)
	var auction: AuctionSystem = AuctionSystem.new()
	auction.setup(run_state, events, CentralRng.new(12), SimpleNpcAi.new())
	var player: ActorState = ActorState.create(GameConstants.PLAYER_ID, "플레이어", GameConstants.ActorType.PLAYER)
	var npc: ActorState = ActorState.create(&"npc_test", "NPC", GameConstants.ActorType.NPC)
	var actors: Array[ActorState] = [player, npc]
	auction.start_auction(actors)
	_assert_true(auction.place_next_bid(player.actor_id), "시작가 입찰 성공")
	_assert_true(auction.pass_current(npc.actor_id), "상대 패스 후 경매 종료")
	var won: Dictionary = auction.settle()
	_assert_equal(won["winner_id"], player.actor_id, "마지막 입찰자가 낙찰")
	_assert_equal(player.gold, GameConstants.STARTING_GOLD - run_state.current_card.starting_bid, "낙찰가만큼 골드 차감")

	var discard_run: RunState = RunState.new()
	discard_run.reset(13)
	discard_run.current_card = CardCatalog.by_id(&"price_surge")
	var discard_auction: AuctionSystem = AuctionSystem.new()
	discard_auction.setup(discard_run, events, CentralRng.new(13), SimpleNpcAi.new())
	var discard_player: ActorState = ActorState.create(GameConstants.PLAYER_ID, "플레이어", GameConstants.ActorType.PLAYER)
	var discard_npc: ActorState = ActorState.create(&"npc_test", "NPC", GameConstants.ActorType.NPC)
	discard_auction.start_auction([discard_player, discard_npc])
	discard_auction.pass_current(discard_player.actor_id)
	discard_auction.pass_current(discard_npc.actor_id)
	var discarded: Dictionary = discard_auction.settle()
	_assert_true((discarded["winner_id"] as StringName).is_empty(), "전원 무입찰 시 카드 폐기")
	events.free()

func _test_delayed_effect_rounds() -> void:
	var context: Dictionary = _effect_context(99)
	var effects: CardEffectSystem = context["effects"]
	var actors: Array[ActorState] = context["actors"]
	var player: ActorState = actors[0]
	effects.acquire_card(CardCatalog.by_id(&"cursed_vault"), player, actors)
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	_assert_equal(player.hp, 3, "저주 1라운드 후 미발동")
	_assert_equal(player.gold, 920, "금고 수익 1회 적용")
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	_assert_equal(player.hp, 3, "저주 2라운드 후 미발동")
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	_assert_equal(player.hp, 1, "저주가 정확히 3번째 ROUND_END에 발동")
	_assert_equal(player.gold, 1160, "금고 반복 수익 3회 적용")
	(context["events"] as EventBus).free()

func _test_broken_chalice_guard() -> void:
	var context: Dictionary = _effect_context(100)
	var effects: CardEffectSystem = context["effects"]
	var actors: Array[ActorState] = context["actors"]
	var player: ActorState = actors[0]
	var chalice: CardInstance = effects.acquire_card(CardCatalog.by_id(&"broken_chalice"), player, actors)
	effects.open_card(chalice, player, actors)
	_assert_equal(effects.apply_damage(player, 3, &"test"), 0, "깨진 성배가 치명 피해를 무효화")
	_assert_equal(player.hp, 3, "치명 피해 무효 후 체력 유지")
	_assert_true(chalice.consumed, "깨진 성배가 발동 후 소모됨")
	_assert_equal(effects.apply_damage(player, 3, &"test"), 3, "성배 소모 후 다음 치명 피해 적용")
	_assert_true(not player.alive, "두 번째 치명 피해로 사망")
	(context["events"] as EventBus).free()

func _test_golden_gallows_targets_richest() -> void:
	var context: Dictionary = _effect_context(102)
	var effects: CardEffectSystem = context["effects"]
	var actors: Array[ActorState] = context["actors"]
	actors[0].gold = 1000
	actors[1].gold = 1000
	actors[2].gold = 400
	actors[3].gold = 300
	var gallows: CardInstance = effects.acquire_card(CardCatalog.by_id(&"golden_gallows"), actors[3], actors)
	effects.process_trigger(GameConstants.EffectTrigger.JUDGMENT, actors)
	_assert_equal(actors[0].hp, 1, "황금 교수대가 부유함 동률 플레이어에게 피해")
	_assert_equal(actors[1].hp, 1, "황금 교수대가 부유함 동률 NPC에게 피해")
	_assert_equal(actors[2].hp, 3, "황금 교수대 비대상 체력 유지")
	_assert_equal(actors[3].hp, 3, "황금 교수대 소유자라도 비대상이면 체력 유지")
	_assert_true(gallows.consumed, "황금 교수대가 발동 후 소모됨")
	(context["events"] as EventBus).free()

func _test_blood_loan_repayment() -> void:
	var context: Dictionary = _effect_context(103)
	var effects: CardEffectSystem = context["effects"]
	var actors: Array[ActorState] = context["actors"]
	var player: ActorState = actors[0]
	var loan: CardInstance = effects.acquire_card(CardCatalog.by_id(&"blood_loan"), player, actors)
	_assert_equal(player.gold, 800, "피의 대출 낙찰만으로 골드가 증가하지 않음")
	effects.open_card(loan, player, actors)
	_assert_equal(player.gold, 1300, "피의 대출 개봉 시 +500골드")
	player.gold = 100
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	_assert_equal(player.gold, 100, "피의 대출 첫 ROUND_END에는 상환하지 않음")
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	_assert_equal(player.gold, 0, "피의 대출 두 번째 ROUND_END에 보유 골드 차감")
	_assert_equal(player.hp, 0, "부족한 600골드가 체력 3 피해로 변환")
	_assert_true(not player.alive, "피의 대출 상환 피해로 사망 가능")
	(context["events"] as EventBus).free()

func _test_price_surge_restores() -> void:
	var controller: GameFlowController = _new_controller(123)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	var surge: CardInstance = controller.effects.acquire_card(
		CardCatalog.by_id(&"price_surge"),
		player,
		controller.actors
	)
	_assert_true(controller.run_state.active_global_effects.is_empty(), "가격 폭주는 낙찰만으로 발동하지 않음")
	controller.effects.open_card(surge, player, controller.actors)
	var affected_round: int = controller.run_state.current_round + 1
	_assert_equal(
		int(controller.run_state.active_global_effects[&"min_increment_value"]),
		GameConstants.PRICE_SURGE_INCREMENT,
		"가격 폭주가 다음 라운드 인상액을 설정"
	)
	controller._begin_round(affected_round)
	_assert_equal(
		controller.run_state.current_min_increment,
		GameConstants.PRICE_SURGE_INCREMENT,
		"가격 폭주가 지정된 다음 라운드에 실제 적용"
	)
	controller._expire_round_rules()
	_assert_equal(
		controller.run_state.current_min_increment,
		GameConstants.DEFAULT_MIN_INCREMENT,
		"가격 폭주 라운드 종료 후 50골드 복구"
	)
	_assert_true(
		not controller.run_state.active_global_effects.has(&"min_increment_round"),
		"가격 폭주 글로벌 상태 제거"
	)
	controller.free()

func _test_tied_targets_all_resolve() -> void:
	var context: Dictionary = _effect_context(101)
	var effects: CardEffectSystem = context["effects"]
	var actors: Array[ActorState] = context["actors"]
	effects.acquire_card(CardCatalog.by_id(&"black_ledger"), actors[0], actors)
	effects.process_trigger(GameConstants.EffectTrigger.JUDGMENT, actors)
	for actor: ActorState in actors:
		_assert_equal(actor.gold, 880, "부유함 동률 대상 %s에게 +80" % actor.actor_id)
		_assert_equal(actor.hp, 2, "가난함 동률 대상 %s에게 피해" % actor.actor_id)
	(context["events"] as EventBus).free()

func _test_post_auction_requires_resolution() -> void:
	var controller: GameFlowController = _new_controller(9001)
	var instance: CardInstance = _prepare_post_card(controller, &"blood_loan", GameConstants.PLAYER_ID)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.POST_AUCTION, "플레이어 낙찰 후 POST_AUCTION 진입")
	_assert_true(instance.sealed, "낙찰 카드는 기본 봉인 상태")
	_assert_true(not instance.post_auction_resolved, "낙찰 직후 처리는 미완료")
	_assert_true(instance.reveal_level != GameConstants.RevealLevel.FULLY_REVEALED, "낙찰만으로 완전 공개되지 않음")
	_assert_equal(player.gold, GameConstants.STARTING_GOLD, "낙찰 등록만으로 ON_OPEN 효과가 실행되지 않음")
	_assert_true(not controller.can_advance_post_auction(), "처리 완료 전 심판 진행 불가")
	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.POST_AUCTION, "미처리 상태에서 단계 이동 거부")
	_assert_true(controller.request_keep_post_card(), "현재 봉인 상태로 보관 가능")
	_assert_true(instance.post_auction_resolved, "보관 후 처리 완료")
	_assert_true(not controller.request_keep_post_card(), "같은 카드 POST_AUCTION 처리는 한 번만 가능")
	_assert_true(controller.can_advance_post_auction(), "처리 완료 후 심판 진행 가능")
	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.JUDGMENT, "완료 후 JUDGMENT 진입")
	controller.free()

func _test_post_auction_ui_actions() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var post_panel: PostAuctionPanel = ui.get_node("%PostAuctionPanel") as PostAuctionPanel
	var advance_button: Button = ui.get_node("%AdvanceButton") as Button
	var open_button: Button = post_panel.get_node("%OpenButton") as Button
	var keep_button: Button = post_panel.get_node("%KeepButton") as Button
	var instance: CardInstance = _prepare_post_card(controller, &"broken_chalice", GameConstants.PLAYER_ID)
	ui.refresh_ui()
	_assert_true(post_panel.visible, "플레이어 낙찰 시 POST_AUCTION 패널 표시")
	_assert_true(open_button.visible and keep_button.visible, "플레이어 낙찰 후 개봉·보관 액션 표시")
	_assert_true(open_button.text.contains("사고"), "개봉 전에 다음 봉인 사고 확률 표시")
	_assert_true(advance_button.disabled, "낙찰 후 처리 전 계속 버튼 비활성")
	_assert_true(post_panel.displayed_text().contains(controller.run_state.current_card.public_name), "봉인 상태에서 public_name 표시")
	_assert_true(not post_panel.displayed_text().contains(controller.run_state.current_card.actual_name), "봉인 상태에서 actual_name 숨김")
	controller.request_open_next_seal()
	ui.refresh_ui()
	_assert_equal(instance.opened_seals, 1, "UI 액션 후 봉인 1개 개봉")
	_assert_true(post_panel.displayed_text().contains("봉인 1"), "개봉 결과를 POST_AUCTION UI에 직접 표시")
	while controller.can_open_next_seal():
		controller.request_open_next_seal()
	ui.refresh_ui()
	_assert_true(post_panel.displayed_text().contains(controller.run_state.current_card.actual_name), "완전 공개 후 actual_name 표시")
	_assert_true(post_panel.displayed_text().contains(controller.run_state.current_card.description), "완전 공개 후 정확한 효과 표시")
	_assert_true(controller.request_keep_post_card(), "완전 개봉 카드 보관")
	ui.refresh_ui()
	_assert_true(not advance_button.disabled, "POST_AUCTION 처리 후 계속 버튼 활성")
	ui.free()

func _test_seal_probabilities_and_opening() -> void:
	var expected: Dictionary = {
		&"low": [0, 5, 10],
		&"medium": [0, 10, 20],
		&"high": [5, 20, 35],
	}
	for risk: StringName in expected:
		for seal_index: int in range(GameConstants.MAX_SEALS):
			_assert_equal(
				PostAuctionSystem.accident_percent(risk, seal_index + 1),
				expected[risk][seal_index],
				"%s 위험도 봉인 %d 사고 확률" % [risk, seal_index + 1]
			)
	var controller: GameFlowController = _new_controller(9002)
	var instance: CardInstance = _prepare_post_card(controller, &"broken_chalice", GameConstants.PLAYER_ID)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	for seal_number: int in range(1, GameConstants.MAX_SEALS + 1):
		_assert_true(controller.request_open_next_seal(), "봉인 %d 순차 개봉" % seal_number)
		_assert_equal(instance.opened_seals, seal_number, "열린 봉인 수 %d 기록" % seal_number)
	_assert_true(not instance.sealed, "세 번째 봉인 후 sealed 해제")
	_assert_equal(instance.reveal_level, GameConstants.RevealLevel.FULLY_REVEALED, "세 번째 봉인 후 완전 공개")
	_assert_equal(controller.player_knowledge().reveal_level, GameConstants.RevealLevel.FULLY_REVEALED, "플레이어 지식도 완전 공개")
	_assert_true(not controller.can_open_next_seal(), "세 번째 봉인 이후 추가 개봉 불가")
	_assert_equal(controller.effects.apply_damage(player, player.hp, &"seal_test"), 0, "개봉된 깨진 성배가 치명 피해 방어")
	_assert_true(instance.consumed, "개봉 효과 사용 후 성배 소비")
	controller.free()

func _test_seal_accident_determinism() -> void:
	var selected_seed: int = -1
	var first_trace: Dictionary = {}
	for seed_value: int in range(1, 80):
		var candidate: Dictionary = _seal_trace(seed_value)
		if bool(candidate["had_accident"]):
			selected_seed = seed_value
			first_trace = candidate
			break
	_assert_true(selected_seed >= 0, "고위험 봉인 사고가 발생하는 테스트 Seed 발견")
	if selected_seed >= 0:
		var second_trace: Dictionary = _seal_trace(selected_seed)
		_assert_equal(first_trace["trace"], second_trace["trace"], "같은 Seed의 봉인 사고 순서 재현")
		_assert_equal(first_trace["hp"], second_trace["hp"], "같은 Seed의 사고 피해 재현")
	var lethal_seed: int = -1
	for seed_value: int in range(1, 80):
		var lethal_controller: GameFlowController = _new_controller(seed_value)
		_prepare_post_card(lethal_controller, &"golden_gallows", GameConstants.PLAYER_ID)
		lethal_controller.actor_by_id(GameConstants.PLAYER_ID).hp = 1
		while lethal_controller.can_open_next_seal() and not lethal_controller.run_state.finished:
			lethal_controller.request_open_next_seal()
		if lethal_controller.run_state.finished:
			lethal_seed = seed_value
			_assert_true(not lethal_controller.run_state.victory, "봉인 사고 사망은 즉시 패배")
			_assert_equal(lethal_controller.run_state.result_reason, "플레이어 사망", "사고 사망 패배 사유 기록")
			lethal_controller.free()
			break
		lethal_controller.free()
	_assert_true(lethal_seed >= 0, "봉인 사고 사망 검증 Seed 발견")

func _test_sealed_inventory_limit() -> void:
	var controller: GameFlowController = _new_controller(9003)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	controller.effects.acquire_card(CardCatalog.by_id(&"cursed_vault"), player, controller.actors)
	controller.effects.acquire_card(CardCatalog.by_id(&"black_ledger"), player, controller.actors)
	controller.effects.acquire_card(CardCatalog.by_id(&"golden_gallows"), player, controller.actors)
	var current: CardInstance = _prepare_post_card(controller, &"broken_chalice", GameConstants.PLAYER_ID)
	_assert_equal(player.sealed_card_count(), 4, "새 낙찰 직후 봉인 카드가 임시로 한도 초과 가능")
	_assert_true(not controller.can_keep_post_card(), "봉인 카드 3장 보유 시 추가 보관 불가")
	_assert_true(not controller.request_keep_post_card(), "한도 초과 보관 요청 거부")
	while controller.can_open_next_seal():
		controller.request_open_next_seal()
	_assert_true(not current.sealed, "현재 카드를 완전 개봉해 봉인 한도에서 제외")
	_assert_equal(player.sealed_card_count(), 3, "완전 개봉 후 봉인 카드 수 복구")
	_assert_true(controller.request_keep_post_card(), "공간 확보 후 보관 가능")
	controller.free()

func _test_sale_and_transfer_guards() -> void:
	var controller: GameFlowController = _new_controller(9004)
	var instance: CardInstance = _prepare_post_card(controller, &"cursed_vault", GameConstants.PLAYER_ID)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	var buyer: ActorState = controller.actor_by_id(&"npc_1")
	buyer.alive = false
	_assert_true(not controller.request_sell_post_card(buyer.actor_id, 50, &""), "사망 NPC 판매 거부")
	_assert_true(not instance.sale_attempted, "유효하지 않은 대상은 판매 기회 미소모")
	buyer.alive = true
	buyer.gold = 0
	_assert_true(not controller.request_sell_post_card(buyer.actor_id, 50, &""), "골드 부족 NPC 판매 거부")
	buyer.gold = GameConstants.STARTING_GOLD
	var remaining_before: int = instance.remaining_turns
	var player_gold_before: int = player.gold
	var buyer_gold_before: int = buyer.gold
	var clue_id: StringName = controller.player_knowledge().known_clue_ids[0]
	_assert_true(controller.request_sell_post_card(buyer.actor_id, 50, clue_id), "유효한 NPC 판매 제안 수락")
	_assert_equal(instance.owner_id, buyer.actor_id, "판매 성공 시 owner_id 변경")
	_assert_equal(instance.remaining_turns, remaining_before, "판매 후 remaining_turns 유지")
	_assert_equal(instance.transfer_history.size(), 1, "판매 이전 이력 기록")
	_assert_equal(player.gold, player_gold_before + 50, "판매자가 제안 가격 수령")
	_assert_equal(buyer.gold, buyer_gold_before - 50, "구매자가 제안 가격 지불")
	_assert_true(controller.knowledge_for(buyer.actor_id).knows(clue_id), "판매 시 선택한 단서가 구매자 지식에 추가")
	_assert_true(player.instance_by_id(instance.instance_id) == null, "기존 인벤토리에서 이전 카드 제거")
	_assert_true(buyer.instance_by_id(instance.instance_id) == instance, "새 인벤토리에 같은 instance_id 추가")
	_assert_true(not controller.request_sell_post_card(buyer.actor_id, 50, clue_id), "한 POST_AUCTION에서 판매 제안 반복 불가")
	controller.free()

	var rejected: GameFlowController = _new_controller(9005)
	var rejected_instance: CardInstance = _prepare_post_card(rejected, &"black_ledger", GameConstants.PLAYER_ID)
	var rejected_buyer: ActorState = rejected.actor_by_id(&"npc_2")
	_assert_true(not rejected.request_sell_post_card(rejected_buyer.actor_id, 800, &""), "평가 기준 미달 판매 제안 거절")
	_assert_true(rejected_instance.sale_attempted, "거절된 제안도 1회 제한 소모")
	_assert_equal(rejected_instance.owner_id, GameConstants.PLAYER_ID, "판매 거절 시 소유권 유지")
	_assert_true(not rejected.can_sell_post_card(), "판매 거절 후 재제안 불가")
	rejected.free()

	var nontransferable: GameFlowController = _new_controller(9006)
	_prepare_post_card(nontransferable, &"price_surge", GameConstants.PLAYER_ID)
	_assert_true(not nontransferable.can_sell_post_card(), "transferable=false 카드는 판매 불가")
	nontransferable.free()

func _test_burn_and_delayed_transfer_policies() -> void:
	var insufficient: GameFlowController = _new_controller(9006)
	_prepare_post_card(insufficient, &"cursed_vault", GameConstants.PLAYER_ID)
	insufficient.actor_by_id(GameConstants.PLAYER_ID).gold = 0
	_assert_true(not insufficient.can_burn_post_card(), "골드 부족 시 소각 불가")
	_assert_true(not insufficient.request_burn_post_card(), "골드 부족 소각 요청 거부")
	insufficient.free()

	var burn_controller: GameFlowController = _new_controller(9007)
	var vault: CardInstance = _prepare_post_card(burn_controller, &"cursed_vault", GameConstants.PLAYER_ID)
	var burn_player: ActorState = burn_controller.actor_by_id(GameConstants.PLAYER_ID)
	var gold_before: int = burn_player.gold
	_assert_true(burn_controller.request_burn_post_card(), "저주받은 금고 소각 성공")
	_assert_equal(burn_player.gold, gold_before - 150, "소각 비용 차감")
	_assert_equal(burn_player.hp, 2, "금고 burn_effect 체력 피해")
	_assert_true(vault.destroyed and vault.consumed, "소각 카드를 destroyed/consumed 처리")
	_assert_true(burn_player.instance_by_id(vault.instance_id) == null, "소각 카드 인벤토리 제거")
	burn_controller.free()

	var follow_context: Dictionary = _effect_context(9011)
	var follow_effects: CardEffectSystem = follow_context["effects"]
	var follow_actors: Array[ActorState] = follow_context["actors"]
	var first_owner: ActorState = follow_actors[0]
	var next_owner: ActorState = follow_actors[1]
	var follow_vault: CardInstance = follow_effects.acquire_card(
		CardCatalog.by_id(&"cursed_vault"),
		first_owner,
		follow_actors
	)
	follow_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, follow_actors)
	var follow_remaining: int = follow_vault.remaining_turns
	_assert_true(follow_effects.transfer_instance(follow_vault, first_owner, next_owner, follow_actors), "FOLLOW_CURRENT_OWNER 카드 이전 성공")
	_assert_equal(follow_vault.effect_owner_id, next_owner.actor_id, "FOLLOW_CURRENT_OWNER 대상이 새 소유자로 변경")
	_assert_equal(follow_vault.remaining_turns, follow_remaining, "FOLLOW_CURRENT_OWNER 이전 후 카운트 유지")
	_assert_true(first_owner.instance_by_id(follow_vault.instance_id) == null, "FOLLOW 이전 후 기존 인벤토리 참조 제거")
	_assert_true(next_owner.instance_by_id(follow_vault.instance_id) == follow_vault, "FOLLOW 이전 후 새 인벤토리에 단일 참조")
	follow_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, follow_actors)
	follow_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, follow_actors)
	_assert_equal(first_owner.hp, 3, "FOLLOW 이전 후 기존 소유자는 지연 피해 제외")
	_assert_equal(next_owner.hp, 1, "FOLLOW 이전 후 새 소유자가 지연 피해 대상")
	var dead_target: ActorState = follow_actors[2]
	dead_target.alive = false
	var second_card: CardInstance = follow_effects.acquire_card(
		CardCatalog.by_id(&"black_ledger"),
		first_owner,
		follow_actors
	)
	_assert_true(not follow_effects.transfer_instance(second_card, first_owner, dead_target, follow_actors), "사망 actor에게 카드 이전 불가")
	(follow_context["events"] as EventBus).free()

	var cancel_definition: CardDefinition = CardCatalog.by_id(&"blood_loan")
	var original_policy: int = cancel_definition.transfer_policy
	cancel_definition.transfer_policy = GameConstants.TransferPolicy.CANCEL_ON_TRANSFER
	var cancel_context: Dictionary = _effect_context(9012)
	var cancel_effects: CardEffectSystem = cancel_context["effects"]
	var cancel_actors: Array[ActorState] = cancel_context["actors"]
	var cancel_owner: ActorState = cancel_actors[0]
	var cancel_buyer: ActorState = cancel_actors[1]
	var cancel_loan: CardInstance = cancel_effects.acquire_card(cancel_definition, cancel_owner, cancel_actors)
	cancel_effects.open_card(cancel_loan, cancel_owner, cancel_actors)
	_assert_true(cancel_effects.transfer_instance(cancel_loan, cancel_owner, cancel_buyer, cancel_actors), "CANCEL_ON_TRANSFER 카드 이전 성공")
	_assert_equal(cancel_loan.remaining_turns, 0, "CANCEL_ON_TRANSFER 지연 카운트 제거")
	cancel_owner.gold = 100
	cancel_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, cancel_actors)
	cancel_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, cancel_actors)
	_assert_equal(cancel_owner.gold, 100, "CANCEL_ON_TRANSFER 이후 예약 효과 미발동")
	cancel_definition.transfer_policy = original_policy
	(cancel_context["events"] as EventBus).free()

	var trigger_definition: CardDefinition = CardCatalog.by_id(&"broken_chalice")
	var trigger_policy: int = trigger_definition.transfer_policy
	var transfer_effect: CardEffectDefinition = CardEffectDefinition.new()
	transfer_effect.trigger = GameConstants.EffectTrigger.ON_TRANSFER
	transfer_effect.effect_type = GameConstants.EffectType.MODIFY_GOLD
	transfer_effect.target_selector = GameConstants.EffectType.SELECT_OWNER
	transfer_effect.amount = 50
	transfer_effect.description = "이전받은 소유자 골드 +50"
	trigger_definition.transfer_policy = GameConstants.TransferPolicy.TRIGGER_ON_TRANSFER
	trigger_definition.effects.append(transfer_effect)
	var trigger_context: Dictionary = _effect_context(9013)
	var trigger_effects: CardEffectSystem = trigger_context["effects"]
	var trigger_actors: Array[ActorState] = trigger_context["actors"]
	var trigger_owner: ActorState = trigger_actors[0]
	var trigger_buyer: ActorState = trigger_actors[1]
	var trigger_card: CardInstance = trigger_effects.acquire_card(trigger_definition, trigger_owner, trigger_actors)
	_assert_true(trigger_effects.transfer_instance(trigger_card, trigger_owner, trigger_buyer, trigger_actors), "TRIGGER_ON_TRANSFER 카드 이전 성공")
	_assert_equal(trigger_buyer.gold, GameConstants.STARTING_GOLD + 50, "TRIGGER_ON_TRANSFER 효과가 새 소유자에게 발동")
	trigger_definition.effects.erase(transfer_effect)
	trigger_definition.transfer_policy = trigger_policy
	(trigger_context["events"] as EventBus).free()

	var context: Dictionary = _effect_context(9008)
	var effects: CardEffectSystem = context["effects"]
	var actors: Array[ActorState] = context["actors"]
	var debtor: ActorState = actors[0]
	var buyer: ActorState = actors[1]
	var loan: CardInstance = effects.acquire_card(CardCatalog.by_id(&"blood_loan"), debtor, actors)
	effects.open_card(loan, debtor, actors)
	var remaining_before: int = loan.remaining_turns
	_assert_true(effects.transfer_instance(loan, debtor, buyer, actors), "피의 대출 이전 성공")
	_assert_equal(loan.remaining_turns, remaining_before, "이전 후 지연 카운트 유지")
	_assert_equal(loan.effect_owner_id, debtor.actor_id, "STAY_WITH_ORIGINAL_OWNER 채무자 고정")
	debtor.gold = 100
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
	_assert_equal(debtor.gold, 0, "이전 후 원래 개봉자가 상환")
	_assert_equal(buyer.gold, GameConstants.STARTING_GOLD, "새 소유자는 고정 채무에서 제외")
	_assert_equal(loan.transfer_history.size(), 1, "직접 이전도 transfer_history 기록")
	(context["events"] as EventBus).free()

	var detached_context: Dictionary = _effect_context(9009)
	var detached_effects: CardEffectSystem = detached_context["effects"]
	var detached_actors: Array[ActorState] = detached_context["actors"]
	var detached_debtor: ActorState = detached_actors[0]
	var detached_loan: CardInstance = detached_effects.acquire_card(
		CardCatalog.by_id(&"blood_loan"),
		detached_debtor,
		detached_actors
	)
	detached_effects.open_card(detached_loan, detached_debtor, detached_actors)
	_assert_true(detached_effects.burn_instance(detached_loan, detached_debtor, detached_actors), "개봉된 피의 대출 소각 성공")
	_assert_equal((detached_context["run_state"] as RunState).detached_instances.size(), 1, "소각 후 고정 채무를 detached 상태로 유지")
	detached_debtor.gold = 100
	detached_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, detached_actors)
	detached_effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, detached_actors)
	_assert_equal(detached_debtor.gold, 0, "소각해도 원래 개봉자의 상환 의무 유지")
	(detached_context["events"] as EventBus).free()

func _test_npc_post_auction_determinism() -> void:
	var first: Dictionary = _npc_post_trace(9010, &"golden_gallows", &"npc_3")
	var second: Dictionary = _npc_post_trace(9010, &"golden_gallows", &"npc_3")
	_assert_equal(first, second, "같은 Seed에서 NPC 낙찰 후 처리 재현")
	_assert_true(bool(first["resolved"]), "NPC가 POST_AUCTION 처리를 자동 완료")

	var ai: SimpleNpcAi = SimpleNpcAi.new()
	var collector: ActorState = ActorState.create(&"collector", "수집가", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_COLLECTOR)
	var creditor: ActorState = ActorState.create(&"creditor", "채권자", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_CREDITOR)
	var gambler: ActorState = ActorState.create(&"gambler", "도박사", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_GAMBLER)
	var collector_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["rare", "ownership"]), 450, 180)
	var creditor_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["debt", "high_risk"]), 100, 600)
	var gambler_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["high_risk", "gamble"]), 450, 350)
	_assert_equal(int(ai.choose_post_auction_action(collector, collector_knowledge, true, 3)["action"]), GameConstants.PostAuctionAction.KEEP, "수집가는 희귀·소유 카드 보관 선호")
	_assert_equal(int(ai.choose_post_auction_action(creditor, creditor_knowledge, true, 3)["action"]), GameConstants.PostAuctionAction.BURN, "채권자는 고위험 손실 카드 소각 선호")
	var gambler_choice: Dictionary = ai.choose_post_auction_action(gambler, gambler_knowledge, true, 3)
	_assert_equal(int(gambler_choice["action"]), GameConstants.PostAuctionAction.OPEN, "도박사는 고위험 카드 개봉 선호")
	_assert_equal(int(gambler_choice["seals_to_open"]), GameConstants.MAX_SEALS, "도박사는 세 번째 봉인까지 감수")

func _test_negotiation_phase_and_generation() -> void:
	var controller: GameFlowController = _new_controller(12001)
	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.NEGOTIATION, "PRE_INFO 다음 단계는 NEGOTIATION")
	_assert_true(controller.run_state.negotiation_offers.size() <= GameConstants.MAX_NEGOTIATION_OFFERS, "라운드당 협상 제안 최대 2개")
	var issuers: Dictionary = {}
	for offer: NegotiationOffer in controller.run_state.negotiation_offers:
		var issuer: ActorState = controller.actor_by_id(offer.issuer_id)
		_assert_true(issuer != null and issuer.alive, "살아 있는 NPC만 협상 제안")
		_assert_true(not issuers.has(offer.issuer_id), "동일 NPC 중복 제안 없음")
		issuers[offer.issuer_id] = true
		_assert_equal(offer.expires_round, controller.run_state.current_round, "제안은 현재 라운드에 만료")
	if controller.current_negotiation_offer() != null:
		controller.request_advance()
		_assert_equal(controller.run_state.current_phase, GameConstants.Phase.NEGOTIATION, "미처리 제안 중 경매 진입 차단")
	while controller.current_negotiation_offer() != null:
		_assert_true(controller.request_reject_offer(), "협상 제안 순차 처리")
	_assert_true(controller.can_advance_negotiation(), "모든 제안 처리 후 경매 진행 가능")
	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.AUCTION, "협상 종료 후 AUCTION 진입")
	controller.free()

	var no_offer: GameFlowController = _new_controller(12002)
	for actor: ActorState in no_offer.actors:
		if actor.actor_type == GameConstants.ActorType.NPC:
			actor.alive = false
	no_offer.run_state.current_phase = GameConstants.Phase.NEGOTIATION
	no_offer.negotiation.begin_round(no_offer.actors, no_offer.knowledge_states)
	_assert_equal(no_offer.run_state.negotiation_offers.size(), 0, "사망 NPC는 제안하지 않음")
	_assert_true(no_offer.negotiation.can_advance(), "제안 0개면 협상 정상 완료")
	no_offer.free()

func _test_negotiation_determinism_and_rng_isolation() -> void:
	var first_trace: Dictionary = _negotiation_trace(12010)
	var second_trace: Dictionary = _negotiation_trace(12010)
	_assert_equal(first_trace, second_trace, "같은 Seed에서 목표·제안·가격·Tell·감정 재현")

	var with_negotiation: GameFlowController = _new_controller(12011)
	var without_negotiation: GameFlowController = _new_controller(12011)
	with_negotiation.request_advance()
	_assert_equal(
		with_negotiation.rng.randi_range(1, 100000),
		without_negotiation.rng.randi_range(1, 100000),
		"협상 RNG가 gameplay RNG 순서를 오염시키지 않음"
	)
	with_negotiation.free()
	without_negotiation.free()

	var catalog: NpcContentCatalog = NpcContentCatalog.new()
	var profile_count: int = 0
	var goal_controller: GameFlowController = _new_controller(12012)
	for actor: ActorState in goal_controller.actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		profile_count += 1
		var profile: NpcCharacterProfile = catalog.profile(actor.character_id)
		var state: NpcRunState = goal_controller.npc_run_state_for(actor.actor_id)
		_assert_true(profile != null, "%s 프로필 데이터 로드" % actor.display_name)
		_assert_true(profile.secret_goal_pool.has(String(state.secret_goal_id)), "%s 목표가 캐릭터별 풀에서 선택" % actor.display_name)
	_assert_equal(profile_count, 3, "마라·볼트·세라 프로필 3개")
	goal_controller.npc_run_state_for(&"npc_3").secret_goal_id = &"volt_bid_total"
	var goal_offer: NegotiationOffer = goal_controller.negotiation.build_offer(&"npc_3")
	_assert_equal(goal_offer.offer_type, GameConstants.OfferType.SKIP_AUCTION, "볼트의 누적 입찰 목표가 경쟁 제거 제안에 반영")
	goal_controller.free()

func _test_offer_responses_and_relationships() -> void:
	var accepted: GameFlowController = _new_controller(12020)
	var skip_offer: NegotiationOffer = _install_offer(accepted, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	var issuer: ActorState = accepted.actor_by_id(&"npc_3")
	var player: ActorState = accepted.actor_by_id(GameConstants.PLAYER_ID)
	var issuer_gold: int = issuer.gold
	var player_gold: int = player.gold
	_assert_true(accepted.request_accept_offer(), "입찰 포기 제안 수락")
	_assert_equal(player.gold, player_gold + skip_offer.offered_gold, "수락 시 플레이어 보상 지급")
	_assert_equal(issuer.gold, issuer_gold - skip_offer.offered_gold, "수락 시 NPC 골드 차감")
	_assert_equal(accepted.run_state.active_promises.size(), 1, "입찰 포기 수락 시 활성 약속 생성")
	var accepted_promise: PromiseState = accepted.run_state.active_promises[0]
	_assert_equal(accepted_promise.promise_type, GameConstants.PROMISE_SKIP_AUCTION, "입찰 포기 조건이 PromiseState에 저장")
	_assert_true(not accepted.run_state.player_forced_pass, "약속 수락 후 플레이어가 이행 또는 위반을 직접 선택")
	_assert_equal(accepted.npc_run_state_for(&"npc_3").relationship_score, 1, "제안 수락 시 관계 증가")
	_assert_true(not accepted.request_accept_offer(), "해결된 제안 중복 처리 방지")
	accepted.request_advance()
	_assert_true(accepted.request_player_pass(), "경매에서 패스해 약속 이행")
	_assert_equal(accepted_promise.status, GameConstants.PROMISE_FULFILLED, "입찰 포기 약속 이행 상태 기록")
	accepted.free()

	var rejected: GameFlowController = _new_controller(12021)
	var rejected_offer: NegotiationOffer = _install_offer(rejected, &"npc_1", GameConstants.OfferType.KEEP_SEALED)
	var rejected_player_gold: int = rejected.actor_by_id(GameConstants.PLAYER_ID).gold
	_assert_true(rejected.request_reject_offer(), "협상 제안 거절")
	_assert_true(rejected_offer.rejected and rejected_offer.resolved, "거절 제안 해결 상태 기록")
	_assert_equal(rejected.actor_by_id(GameConstants.PLAYER_ID).gold, rejected_player_gold, "거절 시 보상과 상태 변화 없음")
	_assert_equal(rejected.npc_run_state_for(&"npc_1").relationship_score, -1, "제안 거절 시 관계 감소")
	rejected.free()

	var countered: GameFlowController = _new_controller(12022)
	var counter_offer: NegotiationOffer = _install_offer(countered, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	var counter_amount: int = counter_offer.offered_gold + GameConstants.COUNTER_INCREMENT
	counter_offer.acceptance_threshold = counter_amount
	_assert_true(countered.request_counter_offer(counter_amount), "한 번의 가격 재제안 처리")
	_assert_equal(counter_offer.counter_count, 1, "가격 재제안 횟수 1회 기록")
	_assert_true(counter_offer.accepted, "수락 기준 이내 재제안 수락")
	_assert_true(not countered.request_counter_offer(counter_amount + 50), "해결 후 추가 재제안 불가")
	countered.free()

	var invalid_counter: GameFlowController = _new_controller(12023)
	var invalid_offer: NegotiationOffer = _install_offer(invalid_counter, &"npc_1", GameConstants.OfferType.KEEP_SEALED)
	var invalid_issuer: ActorState = invalid_counter.actor_by_id(&"npc_1")
	_assert_true(not invalid_counter.request_counter_offer(invalid_issuer.gold + 50), "NPC 보유 골드 초과 재제안 불가")
	_assert_equal(invalid_offer.counter_count, 0, "유효하지 않은 재제안은 횟수 미소비")
	invalid_offer.acceptance_threshold = invalid_offer.offered_gold
	_assert_true(invalid_counter.request_counter_offer(invalid_offer.offered_gold + 50), "기준 초과 재제안도 한 번 처리")
	_assert_true(invalid_offer.rejected, "수락 기준 초과 재제안 거절")
	invalid_counter.free()

	var bounded: NpcRunState = NpcRunState.create(GameConstants.CHARACTER_MARA, &"goal")
	_assert_equal(bounded.change_relationship(10), GameConstants.RELATIONSHIP_MAX, "관계 점수 상한 +2")
	_assert_equal(bounded.change_relationship(-10), GameConstants.RELATIONSHIP_MIN, "관계 점수 하한 -2")
	var restarted: GameFlowController = _new_controller(12024)
	_assert_equal(restarted.npc_run_state_for(&"npc_1").relationship_score, 0, "새 런에서 관계 점수 초기화")
	restarted.free()

func _test_offer_type_effects() -> void:
	var buying: GameFlowController = _new_controller(12030)
	var buying_player: ActorState = buying.actor_by_id(GameConstants.PLAYER_ID)
	var buying_npc: ActorState = buying.actor_by_id(&"npc_3")
	var owned: CardInstance = buying.effects.acquire_card(CardCatalog.by_id(&"broken_chalice"), buying_player, buying.actors)
	var buy_offer: NegotiationOffer = _install_offer(buying, &"npc_3", GameConstants.OfferType.BUY_CARD)
	_assert_equal(buy_offer.offer_type, GameConstants.OfferType.BUY_CARD, "카드 구매 제안 생성")
	_assert_true(buying.request_accept_offer(), "카드 구매 제안 수락")
	_assert_equal(owned.owner_id, buying_npc.actor_id, "카드 구매 수락 시 소유권 이전")
	_assert_true(buying_player.instance_by_id(owned.instance_id) == null, "구매 후 플레이어 인벤토리에서 제거")
	buying.free()

	var sealed: GameFlowController = _new_controller(12031)
	sealed.effects.acquire_card(
		CardCatalog.by_id(&"broken_chalice"),
		sealed.actor_by_id(GameConstants.PLAYER_ID),
		sealed.actors
	)
	var sealed_offer: NegotiationOffer = _install_offer(sealed, &"npc_1", GameConstants.OfferType.KEEP_SEALED)
	_assert_true(sealed.request_accept_offer(), "개봉 금지 제안 수락")
	_assert_true(sealed.run_state.temporary_negotiation_warning.contains("활성 약속"), "개봉 금지 활성 약속 안내 유지")
	_assert_equal(sealed_offer.requested_action, GameConstants.RequestedAction.DO_NOT_OPEN, "개봉 금지 요청 행동 매핑")
	_assert_equal(sealed.run_state.active_promises[0].promise_type, GameConstants.PROMISE_KEEP_CARD_SEALED, "개봉 금지 약속 타입 연결")
	sealed.free()

	var shared: GameFlowController = _new_controller(12032)
	var source: KnowledgeState = _knowledge_with_clue(PackedStringArray(["information"]), 300, 100)
	source.actor_id = &"npc_2"
	source.card_instance_id = shared.run_state.current_lot_id
	var target: KnowledgeState = KnowledgeState.create(GameConstants.PLAYER_ID, shared.run_state.current_lot_id)
	shared.knowledge_states[&"npc_2"] = source
	shared.knowledge_states[GameConstants.PLAYER_ID] = target
	var share_offer: NegotiationOffer = _install_offer(shared, &"npc_2", GameConstants.OfferType.SHARE_INFORMATION)
	_assert_equal(share_offer.offer_type, GameConstants.OfferType.SHARE_INFORMATION, "정보 교환 제안 생성")
	_assert_true(shared.request_accept_offer(), "정보 교환 제안 수락")
	_assert_true(not target.knows(&"test_clue"), "정보 제공 약속은 수락 즉시 단서를 공개하지 않음")
	_assert_equal(shared.run_state.active_promises[0].promise_type, GameConstants.PROMISE_SHARE_INFORMATION, "정보 제공 약속 생성")
	_assert_true(shared.information_service.share_known_clue(source, target, &"test_clue"), "NPC가 약속한 단서 제공")
	_assert_true(target.knows(&"test_clue"), "정보 제공 후 플레이어 지식 갱신")
	_assert_equal(shared.run_state.resolved_promises[0].status, GameConstants.PROMISE_FULFILLED, "단서 제공으로 약속 이행")
	shared.free()

	var held: GameFlowController = _new_controller(12033)
	held.effects.acquire_card(
		CardCatalog.by_id(&"broken_chalice"),
		held.actor_by_id(GameConstants.PLAYER_ID),
		held.actors
	)
	var hold_offer: NegotiationOffer = _install_offer(held, &"npc_1", GameConstants.OfferType.HOLD_CARD)
	_assert_true(held.request_accept_offer(), "카드 보관 요청 수락")
	_assert_true(held.run_state.temporary_negotiation_warning.contains("활성 약속"), "카드 보관 활성 약속 표시")
	_assert_equal(hold_offer.requested_action, GameConstants.RequestedAction.KEEP_CARD, "보관 요청 행동 매핑")
	_assert_equal(held.run_state.active_promises[0].promise_type, GameConstants.PROMISE_HOLD_CARD, "카드 보관 약속 타입 연결")
	held.free()

func _test_character_emotion_tells_and_visibility() -> void:
	var emotional: GameFlowController = _new_controller(12040)
	emotional.actor_by_id(&"npc_1").hp = 1
	emotional.request_advance()
	_assert_equal(emotional.npc_run_state_for(&"npc_1").emotion, GameConstants.Emotion.AFRAID, "HP 1 마라는 AFRAID")
	_assert_true(
		emotional.npc_run_state_for(&"npc_3").emotion in [GameConstants.Emotion.INTERESTED, GameConstants.Emotion.SMUG, GameConstants.Emotion.NERVOUS],
		"볼트 감정이 평가 상태에 따라 갱신"
	)
	emotional.free()

	var catalog: NpcContentCatalog = NpcContentCatalog.new()
	var tell_ids: Dictionary = {}
	for character_id: StringName in [GameConstants.CHARACTER_MARA, GameConstants.CHARACTER_VOLT, GameConstants.CHARACTER_SERA]:
		var profile: NpcCharacterProfile = catalog.profile(character_id)
		var tells: Array[Dictionary] = catalog.tells_for(profile, &"")
		_assert_true(not tells.is_empty(), "%s 행동 신호 풀 존재" % character_id)
		for tell: Dictionary in tells:
			_assert_true(float(tell.get("reliability", 1.0)) < 1.0, "%s Tell reliability가 100%% 미만" % tell.get("id", ""))
			tell_ids[StringName(str(tell.get("id", "")))] = character_id
	_assert_equal(tell_ids.size(), 9, "캐릭터별 행동 신호 풀 분리")

	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var ui_controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var participants: ParticipantPanel = ui.get_node("%ParticipantPanel") as ParticipantPanel
	var negotiation_panel: NegotiationPanel = ui.get_node("%NegotiationPanel") as NegotiationPanel
	var normal_text: String = participants.combined_text()
	_assert_true(normal_text.contains("마라") and normal_text.contains("볼트") and normal_text.contains("세라"), "일반 UI에 캐릭터 이름 표시")
	_assert_true(normal_text.contains("감정") and normal_text.contains("관계") and normal_text.contains("비장"), "참가자 패널에 감정·관계·비장의 수단 표시")
	for actor: ActorState in ui_controller.actors:
		if actor.actor_type == GameConstants.ActorType.NPC:
			var goal: Dictionary = ui_controller.negotiation.goal_for(actor.actor_id)
			_assert_true(not normal_text.contains(str(goal.get("description", ""))), "일반 UI에서 숨겨진 목표 비공개")
	ui_controller.request_advance()
	ui.refresh_ui()
	_assert_true(negotiation_panel.visible, "NEGOTIATION UI 표시")
	_assert_true(not negotiation_panel.displayed_text().contains(ui_controller.run_state.current_card.description), "협상 UI에서 실제 효과 설명 숨김")
	_assert_true(ui_controller.debug_information_report().contains("goal="), "DEBUG에서 숨겨진 목표 표시")
	_assert_true(ui_controller.debug_information_report().contains("NEGOTIATION RNG SEED"), "DEBUG에서 협상 RNG 표시")
	ui.free()

func _test_emergency_abilities() -> void:
	var mara_controller: GameFlowController = _new_controller(12050)
	var mara: ActorState = mara_controller.actor_by_id(&"npc_1")
	var mara_card: CardInstance = mara_controller.effects.acquire_card(CardCatalog.by_id(&"broken_chalice"), mara, mara_controller.actors)
	var mara_gold: int = mara.gold
	_assert_true(mara_controller.negotiation.try_use_emergency(mara.actor_id, true), "마라 긴급 소각 사용")
	_assert_true(mara_card.destroyed and mara.instance_by_id(mara_card.instance_id) == null, "긴급 소각으로 봉인 카드 제거")
	_assert_equal(mara.gold, mara_gold, "긴급 소각 비용 면제")
	_assert_true(not mara_controller.negotiation.try_use_emergency(mara.actor_id, true), "마라 비장의 수단 재사용 불가")
	mara_controller.free()

	var volt_controller: GameFlowController = _new_controller(12051)
	var volt: ActorState = volt_controller.actor_by_id(&"npc_3")
	volt.hp = 2
	volt.gold = 100
	_assert_true(volt_controller.negotiation.try_use_emergency(volt.actor_id, true), "볼트 생명 담보 사용")
	_assert_equal(volt.hp, 1, "생명 담보 체력 1 지불")
	_assert_equal(volt.gold, 500, "생명 담보 400 G 획득")
	_assert_true(not volt_controller.negotiation.try_use_emergency(volt.actor_id, true), "볼트 비장의 수단 재사용 불가")
	volt_controller.free()

	var sera_controller: GameFlowController = _new_controller(12052)
	var player_knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["information"]), 300, 100)
	player_knowledge.actor_id = GameConstants.PLAYER_ID
	player_knowledge.card_instance_id = sera_controller.run_state.current_lot_id
	var sera_knowledge: KnowledgeState = KnowledgeState.create(&"npc_2", sera_controller.run_state.current_lot_id)
	sera_controller.knowledge_states[GameConstants.PLAYER_ID] = player_knowledge
	sera_controller.knowledge_states[&"npc_2"] = sera_knowledge
	sera_controller.negotiation.begin_round(sera_controller.actors, sera_controller.knowledge_states)
	_assert_true(sera_controller.negotiation.try_use_emergency(&"npc_2", true), "세라 정보 절취 사용")
	_assert_true(sera_knowledge.knows(&"test_clue"), "정보 절취로 플레이어 단서 획득")
	_assert_true(not sera_controller.negotiation.try_use_emergency(&"npc_2", true), "세라 비장의 수단 재사용 불가")
	sera_controller.free()

func _test_dialogue_data_and_rng_isolation() -> void:
	var first: NpcDialogueService = NpcDialogueService.new(12060)
	var second: NpcDialogueService = NpcDialogueService.new(12060)
	for character_id: StringName in [GameConstants.CHARACTER_MARA, GameConstants.CHARACTER_VOLT, GameConstants.CHARACTER_SERA]:
		_assert_true(first.line_count(character_id) >= 20, "%s 대사 데이터 20줄 이상" % character_id)
		_assert_true(first.categories(character_id).has("negotiation_start"), "%s 협상 대사 카테고리 분리" % character_id)
		for category: String in [
			"promise_propose",
			"promise_accepted",
			"promise_rejected",
			"promise_fulfilled",
			"promise_broken_by_player",
			"promise_broken_by_self",
			"betrayal_warning",
			"betrayal_reaction",
			"trust_high",
			"trust_low",
			"memory_reference",
		]:
			_assert_true(first.categories(character_id).has(category), "%s %s 대사 카테고리 존재" % [character_id, category])
	var first_lines: PackedStringArray = []
	var second_lines: PackedStringArray = []
	for _index: int in range(6):
		first_lines.append(first.select_line(GameConstants.CHARACTER_SERA, &"negotiation_start"))
		second_lines.append(second.select_line(GameConstants.CHARACTER_SERA, &"negotiation_start"))
	_assert_equal(first_lines, second_lines, "같은 Seed에서 협상 대사 재현")
	_assert_true(
		first.select_line(GameConstants.CHARACTER_MARA, &"greeting")
		!= first.select_line(GameConstants.CHARACTER_VOLT, &"greeting"),
		"캐릭터별 대사 풀 구분"
	)
	var dialogue_source: String = FileAccess.get_file_as_string("res://scripts/ai/npc_dialogue_service.gd")
	_assert_true(dialogue_source.contains("npc_dialogue.json"), "협상 대사를 외부 데이터에서 로드")
	_assert_true(not dialogue_source.contains("그 봉인은 열지 마요"), "협상 대사를 코드에 하드코딩하지 않음")
	var gameplay_first: CentralRng = CentralRng.new(12061)
	var gameplay_second: CentralRng = CentralRng.new(12061)
	var dialogue: NpcDialogueService = NpcDialogueService.new(12061)
	for _index: int in range(10):
		dialogue.select_line(GameConstants.CHARACTER_VOLT, &"interest")
	_assert_equal(gameplay_first.randi_range(1, 100000), gameplay_second.randi_range(1, 100000), "dialogue RNG가 gameplay RNG에 영향 없음")

func _test_promise_creation_and_six_types() -> void:
	var controller: GameFlowController = _new_controller(13001)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	var owned: CardInstance = controller.effects.acquire_card(
		CardCatalog.by_id(&"broken_chalice"),
		player,
		controller.actors
	)
	for npc_id: StringName in [&"npc_1", &"npc_2", &"npc_3"]:
		controller.actor_by_id(npc_id).gold = 5000
	_prepare_share_knowledge(controller, &"npc_2", GameConstants.PLAYER_ID)
	var specs: Array[Dictionary] = [
		{"issuer": &"npc_3", "offer": GameConstants.OfferType.SKIP_AUCTION, "promise": GameConstants.PROMISE_SKIP_AUCTION},
		{"issuer": &"npc_1", "offer": GameConstants.OfferType.KEEP_SEALED, "promise": GameConstants.PROMISE_KEEP_CARD_SEALED},
		{"issuer": &"npc_1", "offer": GameConstants.OfferType.HOLD_CARD, "promise": GameConstants.PROMISE_HOLD_CARD},
		{"issuer": &"npc_3", "offer": GameConstants.OfferType.TRANSFER_CARD, "promise": GameConstants.PROMISE_TRANSFER_CARD},
		{"issuer": &"npc_2", "offer": GameConstants.OfferType.SHARE_INFORMATION, "promise": GameConstants.PROMISE_SHARE_INFORMATION},
		{"issuer": &"npc_3", "offer": GameConstants.OfferType.MUTUAL_PASS, "promise": GameConstants.PROMISE_MUTUAL_PASS},
	]
	var promise_ids: Dictionary = {}
	for spec: Dictionary in specs:
		var offer: NegotiationOffer = _install_offer(
			controller,
			spec["issuer"],
			int(spec["offer"])
		)
		_assert_true(offer.creates_promise, "%s 제안이 약속 생성으로 표시" % spec["promise"])
		_assert_equal(offer.promise_type, spec["promise"], "%s 약속 타입 매핑" % spec["promise"])
		_assert_true(controller.request_accept_offer(), "%s 약속 제안 수락" % spec["promise"])
		var promise: PromiseState = controller.run_state.active_promises[-1]
		_assert_true(not promise_ids.has(promise.promise_id), "promise_id 런 내 고유")
		promise_ids[promise.promise_id] = true
		_assert_equal(promise.target_round, offer.promise_target_round, "약속 기한 정확")
		if promise.promise_type in [
			GameConstants.PROMISE_KEEP_CARD_SEALED,
			GameConstants.PROMISE_HOLD_CARD,
			GameConstants.PROMISE_TRANSFER_CARD,
		]:
			_assert_equal(promise.target_card_instance_id, owned.instance_id, "카드 약속이 definition이 아닌 instance_id 추적")
	_assert_equal(promise_ids.size(), 6, "지원 약속 6종 모두 생성")
	controller.free()

	var rejected: GameFlowController = _new_controller(13002)
	var rejected_offer: NegotiationOffer = _install_offer(rejected, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	_assert_true(rejected_offer.creates_promise, "거절 대상 약속 제안 생성")
	_assert_true(rejected.request_reject_offer(), "약속 제안 거절")
	_assert_equal(rejected.run_state.active_promises.size(), 0, "거절한 제안은 PromiseState를 생성하지 않음")
	rejected.free()

func _test_promise_fulfillment_and_violation() -> void:
	var skip_fulfilled: GameFlowController = _new_controller(13101)
	var skip_offer: NegotiationOffer = _install_offer(skip_fulfilled, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	_assert_true(skip_fulfilled.request_accept_offer(), "SKIP_AUCTION 약속 수락")
	var skip_promise: PromiseState = skip_fulfilled.run_state.active_promises[0]
	skip_fulfilled.events.actor_passed.emit(GameConstants.PLAYER_ID)
	_assert_equal(skip_promise.status, GameConstants.PROMISE_FULFILLED, "패스로 SKIP_AUCTION 이행")
	_assert_equal(skip_promise.fulfilled_by, GameConstants.PLAYER_ID, "SKIP_AUCTION 이행 actor 기록")
	_assert_true(skip_offer.promise_target_round == skip_promise.target_round, "SKIP_AUCTION 기한 유지")
	skip_fulfilled.free()

	var skip_broken: GameFlowController = _new_controller(13102)
	_install_offer(skip_broken, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	skip_broken.request_accept_offer()
	var broken_skip: PromiseState = skip_broken.run_state.active_promises[0]
	skip_broken.events.bid_placed.emit(GameConstants.PLAYER_ID, 200)
	_assert_equal(broken_skip.status, GameConstants.PROMISE_BROKEN, "입찰로 SKIP_AUCTION 위반")
	_assert_equal(broken_skip.broken_by, GameConstants.PLAYER_ID, "입찰 위반 actor 기록")
	skip_broken.free()

	var sealed_fulfilled: GameFlowController = _new_controller(13103)
	var sealed_instance: CardInstance = _add_player_promise_card(sealed_fulfilled)
	_install_offer(sealed_fulfilled, &"npc_1", GameConstants.OfferType.KEEP_SEALED)
	sealed_fulfilled.request_accept_offer()
	var sealed_promise: PromiseState = sealed_fulfilled.run_state.active_promises[0]
	sealed_fulfilled.run_state.current_round = sealed_promise.target_round
	sealed_fulfilled.events.round_finished.emit(sealed_promise.target_round)
	_assert_equal(sealed_promise.status, GameConstants.PROMISE_FULFILLED, "기한까지 유지해 KEEP_CARD_SEALED 이행")
	_assert_equal(sealed_promise.target_card_instance_id, sealed_instance.instance_id, "봉인 약속 대상 instance 유지")
	sealed_fulfilled.free()

	var sealed_broken: GameFlowController = _new_controller(13104)
	var opened_instance: CardInstance = _add_player_promise_card(sealed_broken)
	_install_offer(sealed_broken, &"npc_1", GameConstants.OfferType.KEEP_SEALED)
	sealed_broken.request_accept_offer()
	var opened_promise: PromiseState = sealed_broken.run_state.active_promises[0]
	sealed_broken.events.seal_opened.emit(opened_instance.instance_id, 1, "테스트 공개")
	_assert_equal(opened_promise.status, GameConstants.PROMISE_BROKEN, "봉인 해제로 KEEP_CARD_SEALED 위반")
	sealed_broken.free()

	var hold_fulfilled: GameFlowController = _new_controller(13105)
	_add_player_promise_card(hold_fulfilled)
	_install_offer(hold_fulfilled, &"npc_1", GameConstants.OfferType.HOLD_CARD)
	hold_fulfilled.request_accept_offer()
	var hold_promise: PromiseState = hold_fulfilled.run_state.active_promises[0]
	hold_fulfilled.run_state.current_round = hold_promise.target_round
	hold_fulfilled.events.round_finished.emit(hold_promise.target_round)
	_assert_equal(hold_promise.status, GameConstants.PROMISE_FULFILLED, "소유권 유지로 HOLD_CARD 이행")
	hold_fulfilled.free()

	var hold_broken: GameFlowController = _new_controller(13106)
	var held_instance: CardInstance = _add_player_promise_card(hold_broken)
	var hold_player: ActorState = hold_broken.actor_by_id(GameConstants.PLAYER_ID)
	var hold_target: ActorState = hold_broken.actor_by_id(&"npc_1")
	_install_offer(hold_broken, &"npc_1", GameConstants.OfferType.HOLD_CARD)
	hold_broken.request_accept_offer()
	var moved_hold_promise: PromiseState = hold_broken.run_state.active_promises[0]
	hold_broken.effects.transfer_instance(held_instance, hold_player, hold_target, hold_broken.actors)
	_assert_equal(moved_hold_promise.status, GameConstants.PROMISE_BROKEN, "판매 또는 이전으로 HOLD_CARD 위반")
	hold_broken.free()

	var burned_hold: GameFlowController = _new_controller(13113)
	var burned_instance: CardInstance = _add_player_promise_card(burned_hold)
	var burner: ActorState = burned_hold.actor_by_id(GameConstants.PLAYER_ID)
	_install_offer(burned_hold, &"npc_1", GameConstants.OfferType.HOLD_CARD)
	burned_hold.request_accept_offer()
	var burned_promise: PromiseState = burned_hold.run_state.active_promises[0]
	_assert_true(burned_hold.effects.burn_instance(burned_instance, burner, burned_hold.actors), "약속 대상 카드 자발적 소각")
	_assert_equal(burned_promise.status, GameConstants.PROMISE_BROKEN, "자발적 소각은 카드 약속 위반")
	burned_hold.free()

	var transfer_fulfilled: GameFlowController = _new_controller(13107)
	var transfer_instance: CardInstance = _add_player_promise_card(transfer_fulfilled)
	var transfer_offer: NegotiationOffer = _install_offer(transfer_fulfilled, &"npc_3", GameConstants.OfferType.TRANSFER_CARD)
	transfer_fulfilled.request_accept_offer()
	var transfer_promise: PromiseState = transfer_fulfilled.run_state.active_promises[0]
	_assert_true(transfer_fulfilled.request_fulfill_promise(transfer_promise.promise_id), "활성 약속 패널 액션으로 카드 이전")
	_assert_equal(transfer_promise.status, GameConstants.PROMISE_FULFILLED, "지정 NPC 이전으로 TRANSFER_CARD 이행")
	_assert_equal(transfer_instance.owner_id, transfer_offer.promise_target_actor_id, "TRANSFER_CARD 대상 actor 정확")
	transfer_fulfilled.free()

	var transfer_broken: GameFlowController = _new_controller(13108)
	_add_player_promise_card(transfer_broken)
	_install_offer(transfer_broken, &"npc_3", GameConstants.OfferType.TRANSFER_CARD)
	transfer_broken.request_accept_offer()
	var expired_transfer: PromiseState = transfer_broken.run_state.active_promises[0]
	transfer_broken.run_state.current_round = expired_transfer.target_round
	transfer_broken.events.round_finished.emit(expired_transfer.target_round)
	_assert_equal(expired_transfer.status, GameConstants.PROMISE_BROKEN, "기한 초과로 TRANSFER_CARD 위반")
	transfer_broken.free()

	var share_fulfilled: GameFlowController = _new_controller(13109)
	var share_context: Dictionary = _prepare_share_knowledge(share_fulfilled, &"npc_2", GameConstants.PLAYER_ID)
	_install_offer(share_fulfilled, &"npc_2", GameConstants.OfferType.SHARE_INFORMATION)
	share_fulfilled.request_accept_offer()
	var share_promise: PromiseState = share_fulfilled.run_state.active_promises[0]
	share_fulfilled.information_service.share_known_clue(share_context["source"], share_context["target"], &"test_clue")
	_assert_equal(share_promise.status, GameConstants.PROMISE_FULFILLED, "실제 단서 전달로 SHARE_INFORMATION 이행")
	share_fulfilled.free()

	var share_broken: GameFlowController = _new_controller(13110)
	_prepare_share_knowledge(share_broken, &"npc_2", GameConstants.PLAYER_ID)
	_install_offer(share_broken, &"npc_2", GameConstants.OfferType.SHARE_INFORMATION)
	share_broken.request_accept_offer()
	var expired_share: PromiseState = share_broken.run_state.active_promises[0]
	share_broken.run_state.current_round = expired_share.target_round
	share_broken.events.round_finished.emit(expired_share.target_round)
	_assert_equal(expired_share.status, GameConstants.PROMISE_BROKEN, "미제공 기한 초과로 SHARE_INFORMATION 위반")
	share_broken.free()

	var mutual_fulfilled: GameFlowController = _new_controller(13111)
	_install_offer(mutual_fulfilled, &"npc_1", GameConstants.OfferType.MUTUAL_PASS)
	mutual_fulfilled.request_accept_offer()
	var mutual_promise: PromiseState = mutual_fulfilled.run_state.active_promises[0]
	mutual_fulfilled.events.actor_passed.emit(GameConstants.PLAYER_ID)
	mutual_fulfilled.events.actor_passed.emit(&"npc_1")
	_assert_equal(mutual_promise.status, GameConstants.PROMISE_FULFILLED, "양쪽 패스로 MUTUAL_PASS 이행")
	mutual_fulfilled.free()

	var mutual_broken: GameFlowController = _new_controller(13112)
	_install_offer(mutual_broken, &"npc_1", GameConstants.OfferType.MUTUAL_PASS)
	mutual_broken.request_accept_offer()
	var broken_mutual: PromiseState = mutual_broken.run_state.active_promises[0]
	mutual_broken.events.bid_placed.emit(GameConstants.PLAYER_ID, 200)
	_assert_equal(broken_mutual.status, GameConstants.PROMISE_BROKEN, "한쪽 입찰로 MUTUAL_PASS 위반")
	mutual_broken.free()

func _test_promise_rewards_reputation_and_memory() -> void:
	var fulfilled: GameFlowController = _new_controller(13201)
	var offer: NegotiationOffer = _install_offer(fulfilled, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	var player: ActorState = fulfilled.actor_by_id(GameConstants.PLAYER_ID)
	var initial_gold: int = player.gold
	_assert_true(fulfilled.request_accept_offer(), "보상 테스트 약속 수락")
	var promise: PromiseState = fulfilled.run_state.active_promises[0]
	_assert_equal(player.gold, initial_gold + offer.offered_gold, "즉시 보상 한 번 지급")
	fulfilled.events.actor_passed.emit(GameConstants.PLAYER_ID)
	var fulfilled_gold: int = player.gold
	_assert_equal(fulfilled_gold, initial_gold + offer.offered_gold + offer.promise_reward_gold, "이행 보상 한 번 지급")
	fulfilled.events.actor_passed.emit(GameConstants.PLAYER_ID)
	_assert_equal(player.gold, fulfilled_gold, "이행 보상 중복 지급 없음")
	_assert_true(promise.immediate_reward_paid and promise.reward_paid, "보상 지급 플래그 기록")
	_assert_equal(fulfilled.reputation_for(&"npc_3"), 1, "약속 이행 시 Reputation +1")
	_assert_equal(fulfilled.promise_manager.memories_for(&"npc_3")[-1].event_type, GameConstants.MEMORY_PROMISE_FULFILLED, "이행 기억 추가")
	fulfilled.free()

	var broken: GameFlowController = _new_controller(13202)
	var broken_offer: NegotiationOffer = _install_offer(broken, &"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	broken_offer.promise_penalty_hp = 1
	var broken_player: ActorState = broken.actor_by_id(GameConstants.PLAYER_ID)
	var before_penalty_hp: int = broken_player.hp
	broken.request_accept_offer()
	var before_penalty: int = broken_player.gold
	var broken_promise: PromiseState = broken.run_state.active_promises[0]
	broken.events.bid_placed.emit(GameConstants.PLAYER_ID, 200)
	_assert_equal(broken_player.gold, before_penalty - broken_offer.promise_penalty_gold, "위반 골드 패널티 한 번 적용")
	_assert_equal(broken_player.hp, before_penalty_hp - 1, "위반 HP 패널티 적용")
	broken.events.bid_placed.emit(GameConstants.PLAYER_ID, 250)
	_assert_equal(broken_player.gold, before_penalty - broken_offer.promise_penalty_gold, "위반 패널티 중복 적용 없음")
	_assert_true(broken_promise.penalty_applied, "위반 패널티 적용 플래그 기록")
	_assert_equal(broken.reputation_for(&"npc_3"), -2, "약속 위반 시 Reputation -2")
	_assert_equal(broken.promise_manager.memories_for(&"npc_3")[-1].event_type, GameConstants.MEMORY_PLAYER_BETRAYED_NPC, "플레이어 배신 기억 추가")
	broken.free()

	var bounded: GameFlowController = _new_controller(13203)
	_assert_equal(bounded.promise_manager.change_reputation(&"npc_1", 99), GameConstants.REPUTATION_MAX, "Reputation 상한 +3")
	_assert_equal(bounded.promise_manager.change_reputation(&"npc_1", -99), GameConstants.REPUTATION_MIN, "Reputation 하한 -3")
	bounded.start_new_run(13203)
	_assert_equal(bounded.reputation_for(&"npc_1"), 0, "새 런에서 Reputation 초기화")
	for index: int in range(7):
		bounded.promise_manager.add_memory(
			&"npc_1",
			GameConstants.MEMORY_REFUSED_OFFER if index > 0 else GameConstants.MEMORY_PLAYER_BETRAYED_NPC,
			GameConstants.PLAYER_ID,
			&"npc_1",
			&"",
			1 if index > 0 else 3,
			"기억 %d" % index
		)
	var memories: Array[NpcMemoryEntry] = bounded.promise_manager.memories_for(&"npc_1")
	_assert_equal(memories.size(), GameConstants.MAX_NPC_MEMORIES, "NPC당 최근 기억 최대 5개")
	var kept_severe: bool = false
	for memory: NpcMemoryEntry in memories:
		kept_severe = kept_severe or memory.event_type == GameConstants.MEMORY_PLAYER_BETRAYED_NPC
	_assert_true(kept_severe, "중요도가 높은 오래된 기억 우선 보존")
	bounded.free()

	var high_trust: GameFlowController = _new_controller(13204)
	var low_trust: GameFlowController = _new_controller(13204)
	high_trust.promise_manager.change_reputation(&"npc_3", 3)
	low_trust.promise_manager.change_reputation(&"npc_3", -3)
	var high_offer: NegotiationOffer = high_trust.negotiation.build_offer(&"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	var low_offer: NegotiationOffer = low_trust.negotiation.build_offer(&"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	_assert_true(high_offer.offered_gold > low_offer.offered_gold, "높은 Reputation이 협상 가격 우대에 반영")
	_assert_true(high_offer.acceptance_threshold > low_offer.acceptance_threshold, "높은 Reputation이 재제안 수락 범위에 반영")
	high_trust.free()
	low_trust.free()

	var remembered: GameFlowController = _new_controller(13205)
	var neutral: GameFlowController = _new_controller(13205)
	for index: int in range(2):
		remembered.promise_manager.add_memory(
			&"npc_3",
			GameConstants.MEMORY_PROMISE_FULFILLED,
			GameConstants.PLAYER_ID,
			&"npc_3",
			&"",
			2,
			"약속 이행 기억 %d" % index
		)
	var remembered_score: int = int(remembered.negotiation._offer_score(remembered.actor_by_id(&"npc_3"))["score"])
	var neutral_score: int = int(neutral.negotiation._offer_score(neutral.actor_by_id(&"npc_3"))["score"])
	_assert_true(remembered_score > neutral_score, "긍정 기억이 이후 제안 생성 점수에 반영")
	var remembered_offer: NegotiationOffer = remembered.negotiation.build_offer(&"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	var neutral_offer: NegotiationOffer = neutral.negotiation.build_offer(&"npc_3", GameConstants.OfferType.SKIP_AUCTION)
	_assert_true(remembered_offer.acceptance_threshold > neutral_offer.acceptance_threshold, "기억이 counter offer 허용 범위에 반영")
	remembered.free()
	neutral.free()

func _test_npc_betrayal_determinism_and_personality() -> void:
	var mara_controller: GameFlowController = _new_controller(13301)
	_install_offer(mara_controller, &"npc_1", GameConstants.OfferType.MUTUAL_PASS)
	mara_controller.request_accept_offer()
	var mara_promise: PromiseState = mara_controller.run_state.active_promises[0]
	_assert_true(not mara_controller.promise_manager.decide_npc_betrayal(mara_promise, &"npc_1", 80), "마라는 기본 배신 성향이 낮음")
	mara_controller.actor_by_id(&"npc_1").hp = 1
	var pressured_offer: NegotiationOffer = _install_offer(mara_controller, &"npc_1", GameConstants.OfferType.MUTUAL_PASS)
	mara_controller.request_accept_offer()
	var pressured_promise: PromiseState = mara_controller.run_state.active_promises[-1]
	_assert_true(mara_controller.promise_manager.decide_npc_betrayal(pressured_promise, &"npc_1", 80), "HP 1 생존 압박에서 마라 배신 가능")
	_assert_true(pressured_offer.creates_promise, "생존 압박 약속도 정상 생성")
	mara_controller.free()

	var volt_controller: GameFlowController = _new_controller(13302)
	volt_controller.npc_run_state_for(&"npc_3").secret_goal_id = &"volt_win_auctions"
	_install_offer(volt_controller, &"npc_3", GameConstants.OfferType.MUTUAL_PASS)
	volt_controller.request_accept_offer()
	var volt_promise: PromiseState = volt_controller.run_state.active_promises[0]
	_assert_true(volt_controller.promise_manager.decide_npc_betrayal(volt_promise, &"npc_3", 80), "볼트는 즉시 이익과 목표가 크면 배신 가능")
	volt_controller.events.bid_placed.emit(&"npc_3", 200)
	_assert_equal(volt_promise.status, GameConstants.PROMISE_BROKEN, "NPC 입찰로 약속 위반 판정")
	_assert_equal(volt_controller.run_state.betrayal_history.size(), 1, "NPC 배신 이력 기록")
	_assert_equal(volt_controller.npc_run_state_for(&"npc_3").emotion, GameConstants.Emotion.SMUG, "볼트 배신 후 SMUG 감정")
	volt_controller.free()

	var sera_controller: GameFlowController = _new_controller(13303)
	_prepare_share_knowledge(sera_controller, &"npc_2", GameConstants.PLAYER_ID)
	sera_controller.npc_run_state_for(&"npc_2").secret_goal_id = &"sera_gain_clues"
	_install_offer(sera_controller, &"npc_2", GameConstants.OfferType.SHARE_INFORMATION)
	sera_controller.request_accept_offer()
	var sera_promise: PromiseState = sera_controller.run_state.active_promises[0]
	_assert_true(sera_controller.promise_manager.decide_npc_betrayal(sera_promise, &"npc_2", 120), "세라는 정보 우위 이익이 크면 배신 가능")
	sera_controller.free()

	var high_rep: GameFlowController = _new_controller(13304)
	var low_rep: GameFlowController = _new_controller(13304)
	for item: Dictionary in [
		{"controller": high_rep, "reputation": 3},
		{"controller": low_rep, "reputation": -3},
	]:
		var candidate: GameFlowController = item["controller"] as GameFlowController
		candidate.npc_run_state_for(&"npc_3").secret_goal_id = &"volt_bid_total"
		candidate.promise_manager.change_reputation(&"npc_3", int(item["reputation"]))
		_install_offer(candidate, &"npc_3", GameConstants.OfferType.MUTUAL_PASS)
		candidate.request_accept_offer()
	_assert_true(not high_rep.promise_manager.decide_npc_betrayal(high_rep.run_state.active_promises[0], &"npc_3", 40), "높은 Reputation이 배신 가능성 감소")
	_assert_true(low_rep.promise_manager.decide_npc_betrayal(low_rep.run_state.active_promises[0], &"npc_3", 40), "낮은 Reputation이 배신 가능성 증가")
	high_rep.free()
	low_rep.free()

	_assert_equal(_promise_betrayal_trace(13305), _promise_betrayal_trace(13305), "같은 Seed에서 배신 여부·점수·대상 재현")
	var rng_first: GameFlowController = _new_controller(13306)
	var rng_second: GameFlowController = _new_controller(13306)
	_install_offer(rng_first, &"npc_3", GameConstants.OfferType.MUTUAL_PASS)
	rng_first.request_accept_offer()
	rng_first.promise_manager.decide_npc_betrayal(rng_first.run_state.active_promises[0], &"npc_3")
	_assert_equal(rng_first.rng.randi_range(1, 100000), rng_second.rng.randi_range(1, 100000), "promise RNG가 gameplay RNG 순서를 오염시키지 않음")
	rng_first.free()
	rng_second.free()

func _test_promise_death_cancellation_and_ui() -> void:
	var death: GameFlowController = _new_controller(13401)
	_install_offer(death, &"npc_1", GameConstants.OfferType.SKIP_AUCTION)
	death.request_accept_offer()
	var death_promise: PromiseState = death.run_state.active_promises[0]
	death.effects.apply_damage(death.actor_by_id(&"npc_1"), 3, &"test")
	_assert_equal(death_promise.status, GameConstants.PROMISE_CANCELLED, "약속 당사자 사망 시 취소")
	_assert_equal(death.reputation_for(&"npc_1"), 0, "불가피한 사망 취소 시 Reputation 변화 없음")
	_assert_true(not death_promise.penalty_applied, "사망한 actor에게 패널티 지급 없음")
	death.free()

	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var negotiation_panel: NegotiationPanel = ui.get_node("%NegotiationPanel") as NegotiationPanel
	var active_panel: ActivePromisePanel = ui.get_node("%ActivePromisePanel") as ActivePromisePanel
	var participants: ParticipantPanel = ui.get_node("%ParticipantPanel") as ParticipantPanel
	var judgment: JudgmentPanel = ui.get_node("%JudgmentPanel") as JudgmentPanel
	var instance: CardInstance = _add_player_promise_card(controller)
	var offer: NegotiationOffer = _install_offer(controller, &"npc_1", GameConstants.OfferType.KEEP_SEALED)
	ui.refresh_ui()
	var offer_text: String = negotiation_panel.displayed_text()
	_assert_true(offer_text.contains("약속") and offer_text.contains("기한"), "협상 UI에 약속 유형과 기한 표시")
	_assert_true(offer_text.contains("즉시 보상") and offer_text.contains("이행 보상") and offer_text.contains("위반 시"), "협상 UI에 보상과 위반 패널티 표시")
	_assert_true(not offer_text.contains(String(instance.instance_id)), "일반 협상 UI에서 내부 card instance_id 숨김")
	controller.request_accept_offer()
	ui.refresh_ui()
	_assert_true(active_panel.visible, "수락한 약속을 공통 활성 약속 패널에 표시")
	_assert_true(active_panel.displayed_text().contains("봉인 유지 약속"), "활성 약속 내용 표시")
	_assert_true(active_panel.displayed_text().contains("1라운드 남음"), "활성 약속 남은 기한 표시")
	_assert_true(active_panel.displayed_text().contains("봉인을 열면 위반"), "활성 약속 위반 조건 표시")
	_assert_true(not active_panel.displayed_text().contains(String(instance.instance_id)), "활성 약속 UI에서 내부 ID 숨김")
	_assert_true(participants.combined_text().contains("평판") and participants.combined_text().contains("기억") and participants.combined_text().contains("활성 약속"), "참가자 패널에 평판·기억·활성 약속 수 표시")
	_assert_true(not participants.combined_text().contains("severity"), "일반 UI에 memory severity 미노출")
	_assert_true(controller.debug_information_report().contains(String(offer.promise_type)), "DEBUG에서 전체 PromiseState 타입 표시")
	_assert_true(controller.debug_information_report().contains(String(controller.run_state.active_promises[0].promise_id)), "DEBUG에서 promise_id 표시")
	_assert_true(controller.debug_information_report().contains("PROMISE RNG SEED"), "DEBUG에서 promise RNG 상태 표시")
	var page: Control = ui.get_node("PageMargin/Page") as Control
	var active_minimum: Vector2 = page.get_combined_minimum_size()
	_assert_true(active_minimum.x <= 1244.0 and active_minimum.y <= 688.0, "활성 약속 포함 1280x720 최소 레이아웃 수용 (%s)" % active_minimum)
	controller.events.seal_opened.emit(instance.instance_id, 1, "테스트 공개")
	controller.run_state.current_phase = GameConstants.Phase.JUDGMENT
	ui.refresh_ui()
	_assert_true(judgment.summary_text().contains("약속 위반"), "약속 결과를 JUDGMENT 결과 카드에 표시")
	_assert_true(not active_panel.visible, "해결된 약속은 활성 패널에서 제거")
	ui.call("_start_new_run", 13402)
	var transfer_instance: CardInstance = _add_player_promise_card(controller)
	_install_offer(controller, &"npc_3", GameConstants.OfferType.TRANSFER_CARD)
	controller.request_accept_offer()
	ui.refresh_ui()
	var fulfill_button: Button = active_panel.get_node("%FulfillButton") as Button
	_assert_true(fulfill_button.visible and fulfill_button.text.contains("카드"), "카드 이전 약속에 직접 이행 버튼 표시")
	fulfill_button.pressed.emit()
	_assert_equal(transfer_instance.owner_id, &"npc_3", "활성 약속 UI 버튼으로 지정 NPC에게 카드 이전")
	_assert_equal(controller.run_state.active_promises.size(), 0, "UI 이행 후 활성 약속 제거")
	ui.free()

func _test_visual_design_system_and_components() -> void:
	var theme: Theme = load("res://themes/last_bid_theme.tres") as Theme
	_assert_true(theme != null, "Milestone 6 공통 Theme 로드")
	for variation: StringName in [
		&"ElevatedPanel",
		&"CardPanel",
		&"CharacterPanel",
		&"Modal",
		&"Toast",
		&"StatusBadge",
	]:
		_assert_true(theme.has_stylebox(&"panel", variation), "%s 패널 스타일 정의" % variation)
	for variation: StringName in [
		&"PrimaryButton",
		&"SecondaryButton",
		&"DangerButton",
		&"IconButton",
		&"Tab",
	]:
		_assert_true(theme.has_stylebox(&"normal", variation), "%s 버튼 스타일 정의" % variation)
		_assert_true(theme.has_stylebox(&"focus", variation), "%s 키보드 포커스 스타일 정의" % variation)
	_assert_true(
		theme.has_stylebox(&"fill", &"AuctionProgressIndicator"),
		"ProgressIndicator 역할의 경매 진행 스타일 정의"
	)
	_assert_true(theme.has_stylebox(&"separator", &"Divider"), "Divider 스타일 정의")
	_assert_true(
		UiPalette.BACKGROUND_PRIMARY != UiPalette.PANEL_PRIMARY
		and UiPalette.GOLD_PRIMARY != UiPalette.TEXT_SECONDARY
		and UiPalette.DANGER_PRIMARY != UiPalette.SUCCESS_PRIMARY,
		"배경·패널·강조·위험·성공 토큰이 의미별로 분리"
	)
	_assert_true(
		UiPalette.SPACE_1 < UiPalette.SPACE_3
		and UiPalette.SPACE_3 < UiPalette.SPACE_6
		and UiPalette.FONT_CAPTION < UiPalette.FONT_DISPLAY,
		"간격과 타이포그래피 스케일 정의"
	)
	_assert_true(TooltipTerms.has_all_required(), "필수 14개 게임 용어 Tooltip 정의")
	for term: String in TooltipTerms.REQUIRED_TERMS:
		_assert_true(TooltipTerms.text(term).length() >= 15, "%s Tooltip이 행동 판단 정보를 제공" % term)

	var component_scenes: PackedStringArray = [
		"res://scenes/ui/participant_card.tscn",
		"res://scenes/ui/seal_indicator.tscn",
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/settings_modal.tscn",
		"res://scenes/ui/tutorial_overlay.tscn",
		"res://scenes/ui/toast_layer.tscn",
		"res://scenes/ui/confirmation_modal.tscn",
	]
	for scene_path: String in component_scenes:
		_assert_true(load(scene_path) is PackedScene, "%s 공통 UI 컴포넌트 로드" % scene_path)

	var seal_scene: PackedScene = load("res://scenes/ui/seal_indicator.tscn") as PackedScene
	var seals: SealIndicator = seal_scene.instantiate() as SealIndicator
	root.add_child(seals)
	seals.render(0, false)
	_assert_true(
		seals.displayed_state().contains("1:잠김") and seals.displayed_state().contains("3:잠김"),
		"미개봉 카드가 세 개의 독립 봉인 상태 표시"
	)
	seals.render(1, false)
	_assert_true(
		seals.displayed_state().contains("1:열림") and seals.displayed_state().contains("2:잠김"),
		"부분 개봉 상태가 열린 봉인과 잠긴 봉인을 구분"
	)
	seals.render(3, true)
	_assert_true(not seals.displayed_state().contains("잠김"), "완전 공개 상태에서 세 봉인 모두 열림")
	seals.free()

func _test_main_menu_settings_and_onboarding() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var main_menu: MainMenu = ui.get_node("%MainMenu") as MainMenu
	var page_margin: MarginContainer = ui.get_node("PageMargin") as MarginContainer
	var settings: SettingsModal = ui.get_node("%SettingsModal") as SettingsModal
	var tutorial: TutorialOverlay = ui.get_node("%TutorialOverlay") as TutorialOverlay
	var participant_panel: ParticipantPanel = ui.get_node("%ParticipantPanel") as ParticipantPanel
	var participant_list: VBoxContainer = participant_panel.get_node("%ParticipantList") as VBoxContainer
	_assert_true(main_menu.visible and not page_margin.visible, "실행 시 게임 셸보다 메인 메뉴를 먼저 표시")
	main_menu.set_last_seed(24680)
	_assert_equal(main_menu.seed_value(), 24680, "메인 메뉴가 최근 Seed를 재사용")
	(main_menu.get_node("%SeedInput") as LineEdit).text = "not-a-seed"
	_assert_equal(main_menu.seed_value(), GameConstants.DEFAULT_SEED, "잘못된 Seed 입력은 기본 Seed로 안전하게 대체")
	(main_menu.get_node("%SettingsButton") as Button).pressed.emit()
	_assert_true(settings.visible, "메인 메뉴에서 설정 모달 열기")
	_assert_equal((settings.get_node("%ResolutionOption") as OptionButton).item_count, 4, "지원 해상도 4종 제공")
	_assert_equal((settings.get_node("%UiScaleOption") as OptionButton).item_count, 3, "UI 배율 80·100·120 제공")
	_assert_equal((settings.get_node("%TextScaleOption") as OptionButton).item_count, 3, "텍스트 크기 3단계 제공")
	var settings_values: Dictionary = settings.displayed_values()
	_assert_true(
		settings_values.has("fullscreen")
		and settings_values.has("reduce_motion")
		and settings_values.has("tutorial")
		and settings_values.has("debug"),
		"설정에 화면·모션·튜토리얼·디버그 접근성 항목 제공"
	)
	(settings.get_node("%CloseButton") as Button).pressed.emit()
	(main_menu.get_node("%SeedInput") as LineEdit).text = "24680"
	(main_menu.get_node("%NewGameButton") as Button).pressed.emit()
	_assert_true(not main_menu.visible and page_margin.visible, "새 게임 선택 시 플레이 셸 진입")
	_assert_true(tutorial.visible and tutorial.current_step() == &"pre_info", "첫 플레이 PRE_INFO Coach Mark 표시")
	_assert_equal(participant_list.get_child_count(), 4, "플레이어 1명과 NPC 3명을 독립 참가자 카드로 표시")
	for child: Node in participant_list.get_children():
		var participant_card: ParticipantCard = child as ParticipantCard
		_assert_true(participant_card != null, "참가자 목록이 재사용 ParticipantCard로 구성")
		_assert_true(
			participant_card.get_node("%PortraitTexture") is TextureRect
			and participant_card.get_node("%Silhouette") is SilhouettePortrait,
			"참가자 카드에 교체 가능한 초상화 슬롯과 실루엣 제공"
		)
		_assert_true(not (participant_card.get_node("%DetailsPanel") as PanelContainer).visible, "세부 관계 정보는 기본 접힘")
	(participant_list.get_child(0).get_node("%DetailsButton") as Button).pressed.emit()
	_assert_true(
		(participant_list.get_child(0).get_node("%DetailsPanel") as PanelContainer).visible,
		"참가자 세부 정보가 필요할 때 펼쳐짐"
	)
	(tutorial.get_node("%DismissButton") as Button).pressed.emit()
	_assert_true(not tutorial.visible and tutorial.is_step_shown(&"pre_info"), "Coach Mark를 개별 단계 단위로 닫기")
	ui.free()

	var tutorial_scene: PackedScene = load("res://scenes/ui/tutorial_overlay.tscn") as PackedScene
	var standalone_tutorial: TutorialOverlay = tutorial_scene.instantiate() as TutorialOverlay
	root.add_child(standalone_tutorial)
	standalone_tutorial.configure(true, true)
	_assert_true(
		standalone_tutorial.show_step(&"auction", "경매", "다음 입찰가와 현재 차례를 확인하세요."),
		"튜토리얼 단계를 명시적으로 재생"
	)
	_assert_true(
		not standalone_tutorial.show_step(&"post_auction", "낙찰 후", "봉인을 확인하세요."),
		"여러 Coach Mark를 동시에 띄우지 않음"
	)
	(standalone_tutorial.get_node("%DisableButton") as Button).pressed.emit()
	_assert_true(
		not standalone_tutorial.visible
		and not standalone_tutorial.show_step(&"post_auction", "낙찰 후", "봉인을 확인하세요."),
		"다시 보지 않기 선택 시 이후 Coach Mark 비활성"
	)
	standalone_tutorial.configure(true, true)
	_assert_true(
		standalone_tutorial.show_step(&"post_auction", "낙찰 후", "봉인을 확인하세요."),
		"설정의 튜토리얼 다시 보기용 단계 초기화 지원"
	)
	standalone_tutorial.free()

func _test_violation_warning_and_visual_feedback() -> void:
	var controller: GameFlowController = _new_controller(13601)
	_install_offer(controller, &"npc_1", GameConstants.OfferType.SKIP_AUCTION)
	_assert_true(controller.request_accept_offer(), "경고 테스트용 경매 패스 약속 수락")
	var promise: PromiseState = controller.run_state.active_promises[0]
	var warning: String = controller.promise_violation_warning(&"bid")
	_assert_true(
		warning.contains("마라") and warning.contains("위반"),
		"위험 행동 전에 상대와 위반 약속을 설명하는 경고 생성"
	)
	_assert_equal(promise.status, GameConstants.PROMISE_ACTIVE, "경고 조회만으로 약속 상태를 변경하지 않음")
	controller.free()

	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var ui_controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var confirmation: ConfirmationModal = ui.get_node("%ConfirmationModal") as ConfirmationModal
	_install_offer(ui_controller, &"npc_1", GameConstants.OfferType.SKIP_AUCTION)
	ui_controller.request_accept_offer()
	ui_controller.run_state.current_phase = GameConstants.Phase.AUCTION
	ui_controller.auction.start_auction(ui_controller.actors)
	ui.refresh_ui()
	var bid_before: int = ui_controller.run_state.current_bid
	ui.call("_on_bid_pressed")
	_assert_true(
		confirmation.visible and confirmation.pending_action() == &"bid",
		"약속 위반 가능 입찰은 확인 모달로 한 번 경고"
	)
	_assert_equal(ui_controller.run_state.current_bid, bid_before, "확인 전에는 위험 행동을 실행하지 않음")
	(confirmation.get_node("%ConfirmButton") as Button).pressed.emit()
	_assert_true(ui_controller.run_state.current_bid > bid_before, "경고 후 강행을 선택하면 입찰 실행")
	_assert_equal(
		ui_controller.run_state.resolved_promises[0].status,
		GameConstants.PROMISE_BROKEN,
		"강행한 입찰의 기존 약속 위반 규칙 유지"
	)

	var toast: ToastLayer = ui.get_node("%ToastLayer") as ToastLayer
	toast.show_message("카드 완전 공개", &"success", true)
	_assert_equal(toast.last_message, "카드 완전 공개", "Toast가 최근 핵심 피드백 저장")
	_assert_true((toast.get_node("%ToastPanel") as PanelContainer).visible, "Reduce Motion에서도 즉시 읽을 수 있는 Toast 표시")
	var preferences: UiPreferences = UiPreferences.new()
	preferences.reduce_motion = true
	preferences.ui_scale = 1.2
	preferences.text_scale = 1.1
	preferences.apply(ui)
	_assert_true(
		absf(ui.get_window().content_scale_factor - 1.2) < 0.001,
		"UI 배율 120%를 실제 Window 콘텐츠 배율에 적용"
	)
	_assert_equal(ui.theme.default_font_size, roundi(UiPalette.FONT_BODY * 1.1), "텍스트 크기 설정을 Theme에 적용")
	ui.get_window().content_scale_factor = 1.0
	ui.free()

func _test_visual_layout_resolutions_and_scales() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	for resolution: Vector2i in UiPreferences.SUPPORTED_RESOLUTIONS:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = resolution
		root.add_child(viewport)
		var ui: Control = packed_scene.instantiate() as Control
		viewport.add_child(ui)
		await process_frame
		_assert_equal(ui.size, Vector2(resolution), "%dx%d에서 루트 UI 확장" % [resolution.x, resolution.y])
		viewport.free()
		await process_frame

	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var page_margin: MarginContainer = ui.get_node("PageMargin") as MarginContainer
	var page: Control = ui.get_node("PageMargin/Page") as Control
	page_margin.visible = true
	(ui.get_node("%MainMenu") as MainMenu).visible = false
	await process_frame
	var phases: PackedInt32Array = [
		GameConstants.Phase.PRE_INFO,
		GameConstants.Phase.NEGOTIATION,
		GameConstants.Phase.AUCTION,
		GameConstants.Phase.POST_AUCTION,
		GameConstants.Phase.JUDGMENT,
		GameConstants.Phase.ROUND_END,
		GameConstants.Phase.RUN_RESULT,
	]
	for phase: int in phases:
		controller.run_state.current_phase = phase
		ui.refresh_ui()
		await process_frame
		var phase_minimum: Vector2 = page.get_combined_minimum_size()
		for scale: float in UiPreferences.SUPPORTED_SCALES:
			var logical_size: Vector2 = Vector2(1280, 720) / scale
			var available: Vector2 = logical_size - Vector2(28, 24)
			_assert_true(
				phase_minimum.x <= available.x + 1.0 and phase_minimum.y <= available.y + 1.0,
				"%s 화면이 1280x720 · UI %d%%에서 수용 (%s)"
				% [UiPalette.phase_label(phase), roundi(scale * 100.0), phase_minimum]
			)

	controller.run_state.current_phase = GameConstants.Phase.PRE_INFO
	controller.run_state.active_promises.clear()
	for index: int in range(3):
		var promise: PromiseState = PromiseState.new()
		promise.promise_id = StringName("layout_promise_%d" % index)
		promise.issuer_id = StringName("npc_%d" % (index + 1))
		promise.receiver_id = GameConstants.PLAYER_ID
		promise.promise_type = [
			GameConstants.PROMISE_SKIP_AUCTION,
			GameConstants.PROMISE_MUTUAL_PASS,
			GameConstants.PROMISE_KEEP_CARD_SEALED,
		][index]
		promise.obligor_ids = [GameConstants.PLAYER_ID]
		promise.target_display_name = "테스트 약속 %d" % (index + 1)
		promise.target_round = controller.run_state.current_round + index
		controller.run_state.active_promises.append(promise)
	ui.refresh_ui()
	await process_frame
	var active_panel: ActivePromisePanel = ui.get_node("%ActivePromisePanel") as ActivePromisePanel
	var promise_minimum: Vector2 = page.get_combined_minimum_size()
	var strict_available: Vector2 = Vector2(1280, 720) / 1.2 - Vector2(28, 24)
	_assert_true(active_panel.visible and active_panel.displayed_text().contains("테스트 약속 3"), "활성 약속 3개를 스크롤 가능한 공통 영역에 표시")
	_assert_true(
		promise_minimum.x <= strict_available.x + 1.0 and promise_minimum.y <= strict_available.y + 1.0,
		"활성 약속 3개도 1280x720 · UI 120%%에서 수용 (%s)" % promise_minimum
	)
	_assert_true(not (ui.get_node("%ReactionPanel") as ReactionPanel).visible, "정보 밀집 시 보조 NPC 반응을 접어 핵심 약속 우선")
	ui.free()

func _test_player_death_is_defeat() -> void:
	var controller: GameFlowController = _new_controller(303)
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	controller.effects.apply_damage(player, 3, &"test")
	controller._evaluate_terminal_state()
	_assert_true(controller.run_state.finished, "플레이어 사망 시 즉시 종료")
	_assert_true(not controller.run_state.victory, "플레이어 사망은 패배")
	_assert_equal(controller.run_state.result_reason, "플레이어 사망", "패배 사유 기록")
	controller.free()

func _test_round_ten_survival_is_victory() -> void:
	var controller: GameFlowController = _new_controller(404)
	for actor: ActorState in controller.actors:
		actor.inventory.clear()
	controller.run_state.current_round = GameConstants.TOTAL_ROUNDS
	controller.run_state.current_phase = GameConstants.Phase.JUDGMENT
	controller.request_advance()
	_assert_true(controller.run_state.finished, "10라운드 종료 시 게임 종료")
	_assert_true(controller.run_state.victory, "플레이어 생존 시 승리")
	_assert_equal(controller.run_state.result_reason, "10라운드 생존", "승리 사유 기록")
	controller.free()

func _test_twenty_simulations_finish() -> void:
	for simulation_index: int in range(20):
		var result: Dictionary = _simulate_run(8000 + simulation_index, false)
		_assert_true(bool(result["finished"]), "시뮬레이션 %d 종료" % (simulation_index + 1))
		_assert_true(int(result["steps"]) < 500, "시뮬레이션 %d 무한 루프 없음" % (simulation_index + 1))

func _test_twenty_promise_simulations_finish() -> void:
	for simulation_index: int in range(20):
		var result: Dictionary = _simulate_run_with_promises(9000 + simulation_index)
		_assert_true(bool(result["finished"]), "약속 활성 시뮬레이션 %d 종료" % (simulation_index + 1))
		_assert_true(int(result["steps"]) < 600, "약속 활성 시뮬레이션 %d 무한 루프 없음" % (simulation_index + 1))
		_assert_true(int(result["promise_decisions"]) > 0, "약속 활성 시뮬레이션 %d에서 약속 응답 처리" % (simulation_index + 1))

func _simulate_run(seed_value: int, capture_trace: bool) -> Dictionary:
	var controller: GameFlowController = _new_controller(seed_value)
	var trace: Array[String] = []
	if capture_trace:
		controller.events.bid_placed.connect(
			func(actor_id: StringName, amount: int) -> void:
				trace.append("B:%s:%d" % [actor_id, amount])
		)
		controller.events.actor_passed.connect(
			func(actor_id: StringName) -> void:
				trace.append("P:%s" % actor_id)
		)
	var deck: Array[StringName] = controller.deck_order()
	var steps: int = 0
	while not controller.run_state.finished and steps < 500:
		steps += 1
		match controller.run_state.current_phase:
			GameConstants.Phase.PRE_INFO:
				controller.request_advance()
			GameConstants.Phase.NEGOTIATION:
				if controller.current_negotiation_offer() != null:
					controller.request_reject_offer()
				elif controller.can_advance_negotiation():
					controller.request_advance()
			GameConstants.Phase.AUCTION:
				var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
				var required: int = controller.current_required_bid()
				if controller.can_player_bid() and required <= mini(player.gold, 500):
					controller.request_player_bid()
				elif controller.can_player_pass():
					controller.request_player_pass()
				else:
					break
			GameConstants.Phase.POST_AUCTION:
				if not controller.can_advance_post_auction():
					if not controller.request_keep_post_card():
						while controller.can_open_next_seal() and not controller.run_state.finished:
							controller.request_open_next_seal()
						if not controller.run_state.finished:
							controller.request_keep_post_card()
				if not controller.run_state.finished:
					controller.request_advance()
			GameConstants.Phase.JUDGMENT, GameConstants.Phase.ROUND_END:
				controller.request_advance()
			_:
				break
	var result: Dictionary = {
		"deck": deck,
		"trace": trace,
		"result": "%s:%s:%d" % [controller.run_state.victory, controller.run_state.result_reason, controller.run_state.current_round],
		"finished": controller.run_state.finished,
		"steps": steps,
	}
	controller.free()
	return result

func _simulate_run_with_promises(seed_value: int) -> Dictionary:
	var controller: GameFlowController = _new_controller(seed_value)
	var steps: int = 0
	var promise_decisions: int = 0
	while not controller.run_state.finished and steps < 600:
		steps += 1
		match controller.run_state.current_phase:
			GameConstants.Phase.PRE_INFO:
				var actionable: PromiseState = controller.promise_manager.actionable_player_promise()
				while actionable != null:
					if not controller.request_fulfill_promise(actionable.promise_id):
						break
					actionable = controller.promise_manager.actionable_player_promise()
				controller.request_advance()
			GameConstants.Phase.NEGOTIATION:
				var offer: NegotiationOffer = controller.current_negotiation_offer()
				if offer != null:
					if offer.creates_promise:
						if controller.request_accept_offer():
							promise_decisions += 1
						else:
							controller.request_reject_offer()
					else:
						controller.request_reject_offer()
				elif controller.can_advance_negotiation():
					controller.request_advance()
			GameConstants.Phase.AUCTION:
				var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
				var required: int = controller.current_required_bid()
				var promised_pass: bool = false
				for promise: PromiseState in controller.run_state.active_promises:
					if (
						promise.target_round == controller.run_state.current_round
						and promise.has_obligor(GameConstants.PLAYER_ID)
						and promise.promise_type in [
							GameConstants.PROMISE_SKIP_AUCTION,
							GameConstants.PROMISE_MUTUAL_PASS,
						]
					):
						promised_pass = true
						break
				if promised_pass and controller.can_player_pass():
					controller.request_player_pass()
				elif controller.can_player_bid() and required <= mini(player.gold, 500):
					controller.request_player_bid()
				elif controller.can_player_pass():
					controller.request_player_pass()
				else:
					break
			GameConstants.Phase.POST_AUCTION:
				if not controller.can_advance_post_auction():
					if not controller.request_keep_post_card():
						while controller.can_open_next_seal() and not controller.run_state.finished:
							controller.request_open_next_seal()
						if not controller.run_state.finished:
							controller.request_keep_post_card()
				if not controller.run_state.finished:
					controller.request_advance()
			GameConstants.Phase.JUDGMENT, GameConstants.Phase.ROUND_END:
				controller.request_advance()
			_:
				break
	var result: Dictionary = {
		"finished": controller.run_state.finished,
		"steps": steps,
		"promise_decisions": promise_decisions,
		"resolved_promises": controller.run_state.resolved_promises.size(),
	}
	controller.free()
	return result

func _add_player_promise_card(controller: GameFlowController) -> CardInstance:
	return controller.effects.acquire_card(
		CardCatalog.by_id(&"broken_chalice"),
		controller.actor_by_id(GameConstants.PLAYER_ID),
		controller.actors
	)

func _prepare_share_knowledge(
	controller: GameFlowController,
	source_id: StringName,
	target_id: StringName
) -> Dictionary:
	var source: KnowledgeState = _knowledge_with_clue(PackedStringArray(["information"]), 300, 100)
	source.actor_id = source_id
	source.card_instance_id = controller.run_state.current_lot_id
	var target: KnowledgeState = KnowledgeState.create(target_id, controller.run_state.current_lot_id)
	controller.knowledge_states[source_id] = source
	controller.knowledge_states[target_id] = target
	controller.knowledge_by_lot[controller.run_state.current_lot_id] = controller.knowledge_states
	controller.promise_manager.update_context(controller.actors, controller.knowledge_by_lot)
	return {"source": source, "target": target}

func _promise_betrayal_trace(seed_value: int) -> Dictionary:
	var controller: GameFlowController = _new_controller(seed_value)
	controller.npc_run_state_for(&"npc_3").secret_goal_id = &"volt_win_auctions"
	_install_offer(controller, &"npc_3", GameConstants.OfferType.MUTUAL_PASS)
	controller.request_accept_offer()
	var promise: PromiseState = controller.run_state.active_promises[0]
	var betrayed: bool = controller.promise_manager.decide_npc_betrayal(promise, &"npc_3")
	var result: Dictionary = {
		"promise_type": promise.promise_type,
		"actor": &"npc_3",
		"betrayed": betrayed,
		"score": int(promise.condition_value(StringName("betrayal_score_npc_3"), 0)),
		"promise_seed": controller.promise_manager.promise_seed,
	}
	controller.free()
	return result

func _prepare_post_card(
	controller: GameFlowController,
	card_id: StringName,
	owner_id: StringName
) -> CardInstance:
	var definition: CardDefinition = CardCatalog.by_id(card_id)
	var owner: ActorState = controller.actor_by_id(owner_id)
	controller.run_state.current_card = definition
	controller.run_state.current_lot_id = StringName("test_post_%s_%d" % [card_id, controller.run_state.current_round])
	controller.run_state.current_bid = definition.starting_bid
	controller.run_state.highest_bidder_id = owner_id
	controller.knowledge_states = controller.information_service.distribute(
		definition,
		controller.run_state.current_lot_id,
		controller.actors
	)
	controller.knowledge_by_lot[controller.run_state.current_lot_id] = controller.knowledge_states
	var instance: CardInstance = controller.effects.acquire_card(definition, owner, controller.actors)
	controller.run_state.current_phase = GameConstants.Phase.POST_AUCTION
	controller.post_auction.begin(instance, controller.actors, controller.knowledge_states)
	return instance

func _seal_trace(seed_value: int) -> Dictionary:
	var controller: GameFlowController = _new_controller(seed_value)
	var instance: CardInstance = _prepare_post_card(controller, &"golden_gallows", GameConstants.PLAYER_ID)
	var trace: Array[String] = []
	var had_accident: bool = false
	while controller.can_open_next_seal() and not controller.run_state.finished:
		controller.request_open_next_seal()
		var accident: bool = not controller.post_auction.last_accident_message.is_empty()
		had_accident = had_accident or accident
		trace.append("%d:%s:%d" % [instance.opened_seals, accident, controller.actor_by_id(GameConstants.PLAYER_ID).hp])
	var result: Dictionary = {
		"trace": trace,
		"had_accident": had_accident,
		"hp": controller.actor_by_id(GameConstants.PLAYER_ID).hp,
	}
	controller.free()
	return result

func _npc_post_trace(
	seed_value: int,
	card_id: StringName,
	npc_id: StringName
) -> Dictionary:
	var controller: GameFlowController = _new_controller(seed_value)
	var instance: CardInstance = _prepare_post_card(controller, card_id, npc_id)
	var result: Dictionary = {
		"decision": controller.post_auction.last_npc_decision.duplicate(true),
		"opened_seals": instance.opened_seals,
		"sealed": instance.sealed,
		"destroyed": instance.destroyed,
		"resolved": instance.post_auction_resolved,
		"owner": instance.owner_id,
		"message": controller.post_auction.last_result_message,
	}
	controller.free()
	return result

func _negotiation_trace(seed_value: int) -> Dictionary:
	var controller: GameFlowController = _new_controller(seed_value)
	controller.request_advance()
	var offers: Array[String] = []
	for offer: NegotiationOffer in controller.run_state.negotiation_offers:
		offers.append(
			"%s:%d:%d:%s:%s:%d"
			% [
				offer.issuer_id,
				offer.offer_type,
				offer.offered_gold,
				offer.offered_clue_id,
				offer.tell_text,
				offer.acceptance_threshold,
			]
		)
	var npc_states: Array[String] = []
	for actor: ActorState in controller.actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		var state: NpcRunState = controller.npc_run_state_for(actor.actor_id)
		npc_states.append(
			"%s:%s:%d:%s"
			% [actor.actor_id, state.secret_goal_id, state.emotion, state.recent_tell_id]
		)
	var result: Dictionary = {
		"offers": offers,
		"states": npc_states,
		"negotiation_seed": controller.negotiation.negotiation_seed,
		"dialogue_seed": controller.dialogue_service.dialogue_seed,
	}
	controller.free()
	return result

func _install_offer(
	controller: GameFlowController,
	issuer_id: StringName,
	offer_type: int
) -> NegotiationOffer:
	controller.run_state.current_phase = GameConstants.Phase.NEGOTIATION
	controller.negotiation.begin_round(controller.actors, controller.knowledge_states)
	controller.run_state.negotiation_offers.clear()
	controller.run_state.current_offer_index = 0
	controller.run_state.negotiation_complete = false
	controller.run_state.player_forced_pass = false
	controller.run_state.temporary_negotiation_warning = ""
	var offer: NegotiationOffer = controller.negotiation.build_offer(issuer_id, offer_type)
	controller.run_state.negotiation_offers.append(offer)
	return offer

func _new_controller(seed_value: int) -> GameFlowController:
	var controller: GameFlowController = GameFlowController.new()
	root.add_child(controller)
	controller.start_new_run(seed_value)
	return controller

func _effect_context(seed_value: int) -> Dictionary:
	var run_state: RunState = RunState.new()
	run_state.reset(seed_value)
	run_state.current_round = 1
	var events: EventBus = EventBus.new()
	root.add_child(events)
	var rng: CentralRng = CentralRng.new(seed_value)
	var effects: CardEffectSystem = CardEffectSystem.new()
	effects.setup(run_state, events, rng)
	var actors: Array[ActorState] = [
		ActorState.create(GameConstants.PLAYER_ID, "플레이어", GameConstants.ActorType.PLAYER),
		ActorState.create(&"npc_a", "NPC A", GameConstants.ActorType.NPC),
		ActorState.create(&"npc_b", "NPC B", GameConstants.ActorType.NPC),
		ActorState.create(&"npc_c", "NPC C", GameConstants.ActorType.NPC),
	]
	return {
		"run_state": run_state,
		"events": events,
		"rng": rng,
		"effects": effects,
		"actors": actors,
	}

func _make_test_deck_ids(seed_value: int) -> Array[StringName]:
	var local_rng: CentralRng = CentralRng.new(seed_value)
	var definitions: Array[CardDefinition] = CardCatalog.load_all()
	var deck: Array[CardDefinition] = []
	deck.append_array(definitions)
	while deck.size() < GameConstants.TOTAL_ROUNDS:
		deck.append(definitions[local_rng.choose_index(definitions.size())])
	local_rng.shuffle(deck)
	var ids: Array[StringName] = []
	for card: CardDefinition in deck:
		ids.append(card.id)
	return ids

func _knowledge_with_clue(
	tags: PackedStringArray,
	estimated_reward: int,
	estimated_risk: int
) -> KnowledgeState:
	var state: KnowledgeState = KnowledgeState.create(&"test_actor", &"test_lot")
	var clue: CardClueDefinition = CardClueDefinition.new()
	clue.clue_id = &"test_clue"
	clue.clue_type = &"trait"
	clue.display_text = "테스트 단서"
	clue.related_tags = tags
	clue.estimated_reward = estimated_reward
	clue.estimated_risk_cost = estimated_risk
	state.learn_clue(clue, 1.0, false)
	return state

func _prepare_low_value_gambler(seed_value: int) -> Dictionary:
	var events: EventBus = EventBus.new()
	root.add_child(events)
	var ai: SimpleNpcAi = SimpleNpcAi.new()
	ai.setup(events, NpcDialogueService.new())
	var gambler: ActorState = ActorState.create(
		&"npc_gambler",
		"도박사",
		GameConstants.ActorType.NPC,
		GameConstants.ARCHETYPE_GAMBLER
	)
	var knowledge: KnowledgeState = _knowledge_with_clue(PackedStringArray(["neutral"]), 80, 220)
	knowledge.actor_id = gambler.actor_id
	var rng: CentralRng = CentralRng.new(seed_value)
	ai.prepare_lot(
		[gambler],
		{gambler.actor_id: knowledge},
		{gambler.actor_id: PackedStringArray()},
		100,
		50,
		1,
		rng
	)
	var remaining_before: int = int(ai.bluff_remaining.get(gambler.actor_id, 0))
	var decision: Dictionary = ai.decide_action(gambler, 150, true, rng)
	var result: Dictionary = {
		"intent": ai.has_bluff_intent(gambler.actor_id),
		"remaining": remaining_before,
		"decision": decision,
	}
	events.free()
	return result

func _assert_true(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	printerr("  ✗ %s" % message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual == expected:
		return
	_failures += 1
	printerr("  ✗ %s — expected=%s actual=%s" % [message, expected, actual])
