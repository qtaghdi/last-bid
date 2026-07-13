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
	_test_player_death_is_defeat()
	_test_round_ten_survival_is_victory()
	_test_twenty_simulations_finish()
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
