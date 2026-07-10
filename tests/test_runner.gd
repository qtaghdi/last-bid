extends SceneTree

var _failures: int = 0
var _assertions: int = 0

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	print("LAST BID headless tests")
	_test_public_clue_data()
	_test_card_information_visibility()
	_test_same_seed_replays()
	_test_auction_guards()
	_test_auction_settlement_and_discard()
	_test_delayed_effect_rounds()
	_test_broken_chalice_guard()
	_test_golden_gallows_targets_richest()
	_test_blood_loan_repayment()
	_test_price_surge_restores()
	_test_tied_targets_all_resolve()
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
			card.public_label,
			card.public_role_group,
			card.public_risk_range,
			card.public_value_range,
			card.public_trigger_timing,
			card.public_target_type,
		]
		var joined_clues: String = " ".join(structured_clues)
		_assert_true(not card.public_label.is_empty(), "%s 공개 출품명이 존재함" % card.id)
		_assert_true(card.public_label != card.display_name, "%s 공개 출품명과 정확한 이름이 다름" % card.id)
		_assert_true(not structured_clues.has(""), "%s 구조화 단서 항목이 모두 존재함" % card.id)
		_assert_true(not joined_clues.contains(String(card.id)), "%s 공개 단서에 내부 ID가 없음" % card.id)
		_assert_true(not joined_clues.contains(card.display_name), "%s 공개 단서에 정확한 이름이 없음" % card.id)
		_assert_true(joined_clues != card.description, "%s 공개 단서와 전체 효과 설명이 분리됨" % card.id)
		_assert_true(digit_pattern.search(joined_clues) == null, "%s 공개 단서에 정확한 수치가 없음" % card.id)

func _test_card_information_visibility() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var ui: Control = packed_scene.instantiate() as Control
	root.add_child(ui)
	var controller: GameFlowController = ui.get_node("GameFlowController") as GameFlowController
	var name_label: Label = ui.get_node("%CardNameLabel") as Label
	var description_label: Label = ui.get_node("%CardDescriptionLabel") as Label
	var bid_info_label: Label = ui.get_node("%BidInfoLabel") as Label
	var bid_button: Button = ui.get_node("%BidButton") as Button
	var actors_label: RichTextLabel = ui.get_node("%ActorsLabel") as RichTextLabel
	var debug_panel: PanelContainer = ui.get_node("%DebugPanel") as PanelContainer
	var card: CardDefinition = controller.run_state.current_card

	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.PRE_INFO, "UI가 PRE_INFO에서 시작")
	_assert_equal(name_label.text, card.public_label, "PRE_INFO에서 공개 출품명만 표시")
	_assert_true(name_label.text != card.display_name, "PRE_INFO에서 정확한 이름 숨김")
	_assert_true(not name_label.text.contains(String(card.id)), "PRE_INFO에서 내부 ID 숨김")
	_assert_equal(description_label.text, _expected_structured_clues(card), "PRE_INFO에서 구조화 단서만 표시")
	_assert_true(not description_label.text.contains(card.description), "PRE_INFO에서 전체 효과 숨김")
	_assert_true(bid_info_label.text.contains("현재가  입찰 없음"), "무입찰 현재가를 입찰 없음으로 표시")
	_assert_true(not bid_info_label.text.contains("현재가  0 G"), "무입찰 현재가에 0 G를 표시하지 않음")
	_assert_equal(bid_button.text, "첫 입찰 %d G" % card.starting_bid, "PRE_INFO 첫 입찰 버튼 문구")
	_assert_true(not debug_panel.visible, "일반 모드에서 디버그 로그 숨김")
	var owned_card: CardDefinition = CardCatalog.by_id(&"broken_chalice")
	controller.effects.acquire_card(owned_card, controller.actor_by_id(GameConstants.PLAYER_ID), controller.actors)
	_assert_true(actors_label.text.contains(owned_card.public_label), "PRE_INFO 보유 카드도 공개 출품명으로 표시")
	_assert_true(not actors_label.text.contains(owned_card.display_name), "PRE_INFO 보유 카드의 정확한 이름 숨김")
	_assert_true(not actors_label.text.contains(String(owned_card.id)), "PRE_INFO 보유 카드의 내부 ID 숨김")

	controller.request_advance()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.AUCTION, "경매 시작 후 AUCTION 진입")
	_assert_equal(name_label.text, card.public_label, "AUCTION에서 공개 출품명 유지")
	_assert_equal(description_label.text, _expected_structured_clues(card), "AUCTION에서 구조화 단서 유지")
	_assert_true(not description_label.text.contains(card.description), "AUCTION에서 전체 효과 숨김")
	_assert_equal(bid_button.text, "첫 입찰 %d G" % card.starting_bid, "AUCTION 첫 입찰 버튼 문구")

	ui.call("set_debug_mode", true)
	_assert_true(bool(ui.call("is_debug_mode")), "DEBUG 모드 활성화")
	_assert_true(name_label.text.contains(card.display_name), "DEBUG에서 정확한 이름 표시")
	_assert_true(name_label.text.contains(String(card.id)), "DEBUG에서 내부 ID 표시")
	_assert_true(description_label.text.contains(card.description), "DEBUG에서 전체 카드 설명 표시")
	_assert_true(description_label.text.contains(card.effects[0].description), "DEBUG에서 개별 효과 설명 표시")
	_assert_true(debug_panel.visible, "DEBUG에서 로그 패널 표시")

	ui.call("set_debug_mode", false)
	controller.request_player_pass()
	_assert_equal(controller.run_state.current_phase, GameConstants.Phase.POST_AUCTION, "경매 종료 후 POST_AUCTION 진입")
	_assert_equal(name_label.text, card.display_name, "낙찰 이후 정확한 이름 공개")
	_assert_true(not description_label.text.contains(card.description), "일반 모드에서는 낙찰 후에도 전체 효과 숨김")
	_assert_equal(description_label.text, _expected_structured_clues(card), "낙찰 이후에도 구조화 단서만 설명")
	_assert_true(not debug_panel.visible, "DEBUG 해제 시 로그 패널 숨김")
	ui.free()

func _expected_structured_clues(card: CardDefinition) -> String:
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
	effects.acquire_card(CardCatalog.by_id(&"blood_loan"), player, actors)
	_assert_equal(player.gold, 1300, "피의 대출 낙찰 즉시 +500골드")
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
	controller.effects.acquire_card(CardCatalog.by_id(&"price_surge"), player, controller.actors)
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
			GameConstants.Phase.POST_AUCTION, GameConstants.Phase.JUDGMENT, GameConstants.Phase.ROUND_END:
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
