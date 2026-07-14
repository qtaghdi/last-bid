class_name GameFlowController
extends Node

var events: EventBus
var run_state: RunState = RunState.new()
var actors: Array[ActorState] = []
var rng: CentralRng
var auction: AuctionSystem
var effects: CardEffectSystem
var post_auction: PostAuctionSystem
var npc_ai: SimpleNpcAi
var information_service: InformationService
var dialogue_service: NpcDialogueService
var negotiation: NegotiationSystem
var promise_manager: PromiseManager
var knowledge_states: Dictionary = {}
var knowledge_by_lot: Dictionary = {}

func _ready() -> void:
	_initialize_services()

func start_new_run(seed_value: int = GameConstants.DEFAULT_SEED) -> void:
	_initialize_services()
	if promise_manager != null:
		promise_manager.shutdown()
	run_state = RunState.new()
	run_state.reset(seed_value)
	rng = CentralRng.new(seed_value)
	dialogue_service = NpcDialogueService.new(seed_value)
	npc_ai = SimpleNpcAi.new()
	npc_ai.setup(events, dialogue_service)
	information_service = InformationService.new()
	information_service.setup(rng, events)
	auction = AuctionSystem.new()
	auction.setup(run_state, events, rng, npc_ai)
	effects = CardEffectSystem.new()
	effects.setup(run_state, events, rng)
	promise_manager = PromiseManager.new()
	promise_manager.setup(
		run_state,
		events,
		seed_value,
		dialogue_service,
		information_service,
		effects
	)
	negotiation = NegotiationSystem.new()
	negotiation.setup(
		run_state,
		events,
		seed_value,
		dialogue_service,
		information_service,
		effects,
		promise_manager
	)
	post_auction = PostAuctionSystem.new()
	post_auction.setup(
		run_state,
		events,
		rng,
		effects,
		npc_ai,
		information_service,
		promise_manager
	)
	actors = [
		ActorState.create(GameConstants.PLAYER_ID, "플레이어", GameConstants.ActorType.PLAYER),
		ActorState.create(&"npc_1", "마라", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_COLLECTOR, GameConstants.CHARACTER_MARA),
		ActorState.create(&"npc_2", "세라", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_CREDITOR, GameConstants.CHARACTER_SERA),
		ActorState.create(&"npc_3", "볼트", GameConstants.ActorType.NPC, GameConstants.ARCHETYPE_GAMBLER, GameConstants.CHARACTER_VOLT),
	]
	negotiation.initialize_characters(actors)
	promise_manager.initialize(actors)
	knowledge_states = {}
	knowledge_by_lot = {}
	_transition_to(GameConstants.Phase.RUN_SETUP, true)
	run_state.deck = _build_deck()
	if run_state.deck.size() < GameConstants.TOTAL_ROUNDS:
		_finish_run(false, "카드 덱 생성 실패")
		return
	events.log_debug("새 게임 시작 — Seed: %d" % seed_value)
	_begin_round(1)

func request_advance() -> void:
	if run_state.finished:
		return
	match run_state.current_phase:
		GameConstants.Phase.PRE_INFO:
			_start_negotiation()
		GameConstants.Phase.NEGOTIATION:
			if negotiation == null or not negotiation.can_advance():
				events.log_debug("모든 협상 제안을 먼저 처리해야 합니다.")
				events.state_updated.emit()
				return
			_start_auction()
		GameConstants.Phase.POST_AUCTION:
			if post_auction != null and not post_auction.can_advance():
				events.log_debug("낙찰 후 처리를 완료해야 심판으로 진행할 수 있습니다.")
				events.state_updated.emit()
				return
			_transition_to(GameConstants.Phase.JUDGMENT)
			effects.process_trigger(GameConstants.EffectTrigger.JUDGMENT, actors)
			_evaluate_terminal_state()
		GameConstants.Phase.JUDGMENT:
			_transition_to(GameConstants.Phase.ROUND_END)
			effects.process_trigger(GameConstants.EffectTrigger.ROUND_END, actors)
			_expire_round_rules()
			events.round_finished.emit(run_state.current_round)
			events.log_debug("라운드 %d 종료" % run_state.current_round)
			if not _evaluate_terminal_state() and run_state.current_round >= GameConstants.TOTAL_ROUNDS:
				_finish_run(true, "10라운드 생존")
		GameConstants.Phase.ROUND_END:
			_begin_round(run_state.current_round + 1)
		_:
			events.log_debug("현재 단계에서는 다음 단계로 진행할 수 없습니다.")
	events.state_updated.emit()

func request_player_bid() -> bool:
	if run_state.current_phase != GameConstants.Phase.AUCTION:
		return false
	var placed: bool = auction.place_next_bid(GameConstants.PLAYER_ID)
	if placed:
		_drive_npc_turns()
	return placed

func request_player_pass() -> bool:
	if run_state.current_phase != GameConstants.Phase.AUCTION:
		return false
	var passed: bool = auction.pass_current(GameConstants.PLAYER_ID)
	if passed:
		_drive_npc_turns()
	return passed

func request_investigate() -> bool:
	if not can_investigate():
		events.log_debug("조사 불가: 토큰, Phase 또는 남은 단서를 확인하세요.")
		return false
	var state: KnowledgeState = player_knowledge()
	var clue: CardClueDefinition = information_service.investigate(state, run_state.current_card)
	if clue == null:
		events.log_debug("추가 조사로 확인할 수 있는 단서가 없습니다.")
		return false
	run_state.player_info_tokens -= 1
	events.information_tokens_changed.emit(run_state.player_info_tokens)
	events.log_debug("추가 조사 성공: %s" % clue.display_text)
	events.state_updated.emit()
	return true

func can_investigate() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.PRE_INFO
		and run_state.player_info_tokens > 0
		and information_service != null
		and information_service.can_investigate(player_knowledge(), run_state.current_card)
	)

func can_player_bid() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.AUCTION
		and auction != null
		and auction.can_actor_bid(GameConstants.PLAYER_ID)
	)

func can_player_pass() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.AUCTION
		and auction != null
		and auction.current_actor_id() == GameConstants.PLAYER_ID
	)

func current_negotiation_offer() -> NegotiationOffer:
	return negotiation.current_offer() if negotiation != null else null

func can_advance_negotiation() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.NEGOTIATION
		and negotiation != null
		and negotiation.can_advance()
	)

func request_accept_offer() -> bool:
	if run_state.current_phase != GameConstants.Phase.NEGOTIATION or negotiation == null:
		return false
	var accepted: bool = negotiation.accept_current_offer()
	events.state_updated.emit()
	return accepted

func request_reject_offer() -> bool:
	if run_state.current_phase != GameConstants.Phase.NEGOTIATION or negotiation == null:
		return false
	var rejected: bool = negotiation.reject_current_offer()
	events.state_updated.emit()
	return rejected

func request_counter_offer(amount: int) -> bool:
	if run_state.current_phase != GameConstants.Phase.NEGOTIATION or negotiation == null:
		return false
	var resolved: bool = negotiation.counter_current_offer(amount)
	events.state_updated.emit()
	return resolved

func npc_run_state_for(actor_id: StringName) -> NpcRunState:
	return negotiation.state_for(actor_id) if negotiation != null else null

func npc_profile_for(actor_id: StringName) -> NpcCharacterProfile:
	return negotiation.profile_for(actor_id) if negotiation != null else null

func reputation_for(actor_id: StringName) -> int:
	return promise_manager.reputation_for(actor_id) if promise_manager != null else 0

func recent_memory_for(actor_id: StringName) -> String:
	return promise_manager.recent_memory_summary(actor_id) if promise_manager != null else "기억 없음"

func active_promise_count_for(actor_id: StringName) -> int:
	return promise_manager.active_count_for(actor_id) if promise_manager != null else 0

func recent_betrayal_by(actor_id: StringName) -> bool:
	return promise_manager.recent_betrayal_by(actor_id) if promise_manager != null else false

func active_promise_summary() -> String:
	return promise_manager.active_summary_text() if promise_manager != null else "활성 약속 없음"

func promise_violation_warning(
	action: StringName,
	target_instance_id: StringName = &"",
	target_actor_id: StringName = &""
) -> String:
	if promise_manager == null:
		return ""
	return promise_manager.player_violation_warning(
		action,
		target_instance_id,
		target_actor_id
	)

func request_fulfill_promise(promise_id: StringName) -> bool:
	if promise_manager == null:
		return false
	var fulfilled: bool = promise_manager.fulfill_player_promise(promise_id)
	events.state_updated.emit()
	return fulfilled

func negotiation_offer_summary(offer: NegotiationOffer) -> String:
	if offer == null:
		return "현재 제안이 없습니다."
	var lines: PackedStringArray = [
		"%s · %s" % [NegotiationSystem.offer_type_name(offer.offer_type), offer.target_display_name],
	]
	if offer.offered_gold > 0:
		lines.append("제공: %d G" % offer.offered_gold)
	if not offer.offered_clue_id.is_empty():
		lines.append("제공: 현재 물품의 단서 1개")
	if offer.creates_promise:
		lines.append("약속: %s" % PromiseManager.promise_type_name(offer.promise_type))
		lines.append(
			"기한: %s"
			% (
				"현재 경매 종료"
				if offer.promise_target_round == run_state.current_round
				else "%d라운드 종료" % offer.promise_target_round
			)
		)
		lines.append(
			"즉시 보상: %s"
			% ("%d G" % offer.offered_gold if offer.offered_gold > 0 else "없음")
		)
		var fulfillment_rewards: PackedStringArray = []
		if offer.promise_reward_gold > 0:
			fulfillment_rewards.append("%d G" % offer.promise_reward_gold)
		if offer.promise_reputation_reward > 0:
			fulfillment_rewards.append("평판 +%d" % offer.promise_reputation_reward)
		if not offer.promise_reward_clue_id.is_empty():
			fulfillment_rewards.append("단서 1개")
		lines.append(
			"이행 보상: %s"
			% (", ".join(fulfillment_rewards) if not fulfillment_rewards.is_empty() else "없음")
		)
		var penalties: PackedStringArray = ["평판 -%d" % offer.promise_reputation_penalty]
		if offer.promise_penalty_gold > 0:
			penalties.append("%d G 손실" % offer.promise_penalty_gold)
		if offer.promise_penalty_hp > 0:
			penalties.append("HP -%d" % offer.promise_penalty_hp)
		lines.append("위반 시: %s" % ", ".join(penalties))
		lines.append("위반 조건: %s" % promise_manager.violation_text(offer.promise_type))
		return "\n".join(lines)
	match offer.requested_action:
		GameConstants.RequestedAction.SELL_CARD:
			lines.append("요청: 카드 소유권 이전")
		GameConstants.RequestedAction.DO_NOT_OPEN:
			lines.append("요청: 이번 라운드 봉인 유지")
		GameConstants.RequestedAction.PASS_CURRENT_AUCTION:
			lines.append("요청: 이번 경매 패스")
		GameConstants.RequestedAction.KEEP_CARD:
			lines.append("요청: 카드 보관")
	return "\n".join(lines)

func current_post_instance() -> CardInstance:
	return post_auction.active_instance if post_auction != null else null

func can_advance_post_auction() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.POST_AUCTION
		and post_auction != null
		and post_auction.can_advance()
	)

func can_open_next_seal() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.POST_AUCTION
		and post_auction != null
		and post_auction.can_open(GameConstants.PLAYER_ID)
	)

func request_open_next_seal() -> bool:
	if not can_open_next_seal():
		return false
	var opened: bool = post_auction.open_next_seal(
		GameConstants.PLAYER_ID,
		actors,
		knowledge_states
	)
	_evaluate_terminal_state()
	events.state_updated.emit()
	return opened

func can_keep_post_card() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.POST_AUCTION
		and post_auction != null
		and post_auction.can_keep(GameConstants.PLAYER_ID, actors)
	)

func request_keep_post_card() -> bool:
	if run_state.current_phase != GameConstants.Phase.POST_AUCTION or post_auction == null:
		return false
	var kept: bool = post_auction.keep(GameConstants.PLAYER_ID, actors)
	events.state_updated.emit()
	return kept

func can_burn_post_card() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.POST_AUCTION
		and post_auction != null
		and post_auction.can_burn(GameConstants.PLAYER_ID, actors)
	)

func request_burn_post_card() -> bool:
	if not can_burn_post_card():
		return false
	var burned: bool = post_auction.burn(GameConstants.PLAYER_ID, actors)
	_evaluate_terminal_state()
	events.state_updated.emit()
	return burned

func can_sell_post_card() -> bool:
	return (
		run_state.current_phase == GameConstants.Phase.POST_AUCTION
		and post_auction != null
		and post_auction.can_sell(GameConstants.PLAYER_ID, actors)
	)

func request_sell_post_card(
	buyer_id: StringName,
	price: int,
	disclosed_clue_id: StringName
) -> bool:
	if run_state.current_phase != GameConstants.Phase.POST_AUCTION or post_auction == null:
		return false
	var accepted: bool = post_auction.propose_sale(
		GameConstants.PLAYER_ID,
		buyer_id,
		price,
		disclosed_clue_id,
		actors,
		knowledge_states
	)
	events.state_updated.emit()
	return accepted

func post_action_block_reason() -> String:
	if post_auction == null:
		return "낙찰 후 처리 시스템이 준비되지 않았습니다."
	return post_auction.action_block_reason(GameConstants.PLAYER_ID, actors)

func sale_targets() -> Array[ActorState]:
	return post_auction.available_sale_targets(actors) if post_auction != null else []

func current_required_bid() -> int:
	if auction == null or run_state.current_phase != GameConstants.Phase.AUCTION:
		return 0
	return auction.next_required_bid()

func current_turn_actor_id() -> StringName:
	if auction == null or run_state.current_phase != GameConstants.Phase.AUCTION:
		return &""
	return auction.current_actor_id()

func actor_by_id(actor_id: StringName) -> ActorState:
	for actor: ActorState in actors:
		if actor.actor_id == actor_id:
			return actor
	return null

func knowledge_for(actor_id: StringName) -> KnowledgeState:
	return knowledge_states.get(actor_id) as KnowledgeState

func player_knowledge() -> KnowledgeState:
	return knowledge_for(GameConstants.PLAYER_ID)

func npc_dialogue_for(actor_id: StringName) -> String:
	return npc_ai.dialogue_for(actor_id) if npc_ai != null else ""

func npc_evaluation_for(actor_id: StringName) -> Dictionary:
	return npc_ai.evaluation_for(actor_id) if npc_ai != null else {}

func debug_information_report() -> String:
	if run_state.current_card == null:
		return "현재 카드 없음"
	var lines: PackedStringArray = [
		"ACTUAL: %s [%s]" % [run_state.current_card.actual_name, run_state.current_card.id],
		"%s" % run_state.current_card.description,
		"RNG SEED: %d" % run_state.rng_seed,
		"LOT: %s" % run_state.current_lot_id,
		"\nALL PUBLIC CLUES",
	]
	var post_instance: CardInstance = current_post_instance()
	if post_instance != null:
		lines.append(
			"POST INSTANCE: %s owner=%s seals=%d sealed=%s reveal=%d resolved=%s"
			% [
				post_instance.instance_id,
				post_instance.owner_id,
				post_instance.opened_seals,
				post_instance.sealed,
				post_instance.reveal_level,
				post_instance.post_auction_resolved,
			]
		)
	for clue: CardClueDefinition in run_state.current_card.public_clues:
		lines.append("- %s: %s" % [clue.clue_id, clue.display_text])
	lines.append("ALL HIDDEN CLUES")
	for clue: CardClueDefinition in run_state.current_card.hidden_clues:
		lines.append("- %s: %s" % [clue.clue_id, clue.display_text])
	for actor: ActorState in actors:
		var state: KnowledgeState = knowledge_for(actor.actor_id)
		lines.append("\n%s KNOWLEDGE" % actor.display_name)
		lines.append(state.debug_summary() if state != null else "없음")
		if actor.actor_type == GameConstants.ActorType.NPC:
			var evaluation: Dictionary = npc_evaluation_for(actor.actor_id)
			lines.append(
				"평가 R=%d Risk=-%d Tag=%+d Inv=%+d State=%+d Strat=%+d Final=%d"
				% [
					evaluation.get("estimated_reward", 0),
					evaluation.get("estimated_risk_cost", 0),
					evaluation.get("archetype_tag_bonus", 0),
					evaluation.get("inventory_synergy", 0),
					evaluation.get("current_state_modifier", 0),
					evaluation.get("strategic_modifier", 0),
					evaluation.get("final_value", 0),
				]
			)
			lines.append(
				"최대 입찰=%d 허세 의도=%s 최근 허세=%s"
				% [
					npc_ai.maximum_bid_for(actor.actor_id),
					npc_ai.has_bluff_intent(actor.actor_id),
					npc_ai.is_bluffing(actor.actor_id),
				]
			)
	if negotiation != null:
		lines.append("\n" + negotiation.debug_report())
	if promise_manager != null:
		lines.append("\n" + promise_manager.debug_report())
	return "\n".join(lines)

func debug_effect_report() -> String:
	if run_state.current_card == null:
		return "현재 카드 없음"
	var lines: PackedStringArray = [run_state.current_card.description, "", "전체 효과"]
	for effect: CardEffectDefinition in run_state.current_card.effects:
		lines.append("• %s" % effect.description)
	return "\n".join(lines)

func deck_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for definition: CardDefinition in run_state.deck:
		order.append(definition.id)
	return order

func _initialize_services() -> void:
	if events == null:
		events = EventBus.new()
		events.name = "EventBus"
		add_child(events)
		events.bid_placed.connect(_record_negotiation_bid)
		events.auction_won.connect(_record_negotiation_win)
		events.card_opened.connect(_record_negotiation_open)
		events.card_transferred.connect(_record_negotiation_trade)

func _build_deck() -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = CardCatalog.load_all()
	var built_deck: Array[CardDefinition] = []
	if definitions.is_empty():
		events.log_debug("카드 정의를 불러오지 못했습니다.")
		return built_deck
	for definition: CardDefinition in definitions:
		built_deck.append(definition)
	while built_deck.size() < GameConstants.TOTAL_ROUNDS:
		built_deck.append(definitions[rng.choose_index(definitions.size())])
	rng.shuffle(built_deck)
	return built_deck

func _begin_round(round_number: int) -> void:
	if round_number < 1 or round_number > GameConstants.TOTAL_ROUNDS:
		_finish_run(actor_by_id(GameConstants.PLAYER_ID).alive, "라운드 범위 종료")
		return
	run_state.current_round = round_number
	run_state.current_card = run_state.deck[round_number - 1]
	run_state.current_lot_id = StringName(
		"lot_%02d_%s" % [round_number, run_state.current_card.id]
	)
	run_state.current_bid = 0
	run_state.highest_bidder_id = &""
	run_state.current_min_increment = GameConstants.DEFAULT_MIN_INCREMENT
	if int(run_state.active_global_effects.get(&"min_increment_round", -1)) == round_number:
		run_state.current_min_increment = int(
			run_state.active_global_effects.get(&"min_increment_value", GameConstants.PRICE_SURGE_INCREMENT)
		)
	knowledge_states = information_service.distribute(
		run_state.current_card,
		run_state.current_lot_id,
		actors
	)
	knowledge_by_lot[run_state.current_lot_id] = knowledge_states
	if promise_manager != null:
		promise_manager.update_context(actors, knowledge_by_lot)
		promise_manager.process_round_start(round_number)
	if post_auction != null:
		post_auction.reset()
	npc_ai.prepare_lot(
		actors,
		knowledge_states,
		_inventory_tags_by_actor(),
		run_state.current_card.starting_bid,
		run_state.current_min_increment,
		round_number,
		rng
	)
	_transition_to(GameConstants.Phase.PRE_INFO)
	events.round_started.emit(round_number, run_state.current_card.id)
	events.log_debug(
		"라운드 %d 시작 — %s / 최소 인상 %d골드"
		% [round_number, run_state.current_card.actual_name, run_state.current_min_increment]
	)
	events.state_updated.emit()

func _start_auction() -> void:
	if _alive_actor_count() <= 1:
		_evaluate_terminal_state()
		return
	_transition_to(GameConstants.Phase.AUCTION)
	auction.start_auction(actors)
	if run_state.player_forced_pass and auction.current_actor_id() == GameConstants.PLAYER_ID:
		auction.pass_current(GameConstants.PLAYER_ID)
	_drive_npc_turns()

func _start_negotiation() -> void:
	if _alive_actor_count() <= 1:
		_evaluate_terminal_state()
		return
	_transition_to(GameConstants.Phase.NEGOTIATION)
	negotiation.begin_round(actors, knowledge_states)

func _drive_npc_turns() -> void:
	var guard: int = 0
	while (
		run_state.current_phase == GameConstants.Phase.AUCTION
		and not auction.is_complete()
		and auction.current_actor_id() != GameConstants.PLAYER_ID
	):
		var npc_actor_id: StringName = auction.current_actor_id()
		if promise_manager != null and promise_manager.npc_should_pass(npc_actor_id, run_state.current_round):
			auction.pass_current(npc_actor_id)
		else:
			auction.perform_npc_turn()
		guard += 1
		if guard >= GameConstants.AUCTION_ACTION_LIMIT:
			events.log_debug("NPC 진행 안전장치 작동")
			break
	if auction.is_complete():
		_finish_auction()

func _finish_auction() -> void:
	var result: Dictionary = auction.settle()
	var winner_id: StringName = result.get("winner_id", &"") as StringName
	var acquired_instance: CardInstance = null
	if not winner_id.is_empty():
		var winner: ActorState = actor_by_id(winner_id)
		if winner != null:
			acquired_instance = effects.acquire_card(run_state.current_card, winner, actors)
	_transition_to(GameConstants.Phase.POST_AUCTION)
	post_auction.begin(acquired_instance, actors, knowledge_states)
	_evaluate_terminal_state()
	events.state_updated.emit()

func _expire_round_rules() -> void:
	var affected_round: int = int(run_state.active_global_effects.get(&"min_increment_round", -1))
	if affected_round == run_state.current_round:
		run_state.active_global_effects.erase(&"min_increment_round")
		run_state.active_global_effects.erase(&"min_increment_value")
		run_state.current_min_increment = GameConstants.DEFAULT_MIN_INCREMENT
		events.log_debug("가격 폭주 종료 — 최소 인상액 50골드 복구")

func _evaluate_terminal_state() -> bool:
	var player: ActorState = actor_by_id(GameConstants.PLAYER_ID)
	if player == null or not player.alive:
		_finish_run(false, "플레이어 사망")
		return true
	if _alive_actor_count() == 1:
		_finish_run(true, "최후의 생존자")
		return true
	return false

func _alive_actor_count() -> int:
	var count: int = 0
	for actor: ActorState in actors:
		if actor.alive:
			count += 1
	return count

func _inventory_tags_by_actor() -> Dictionary:
	var result: Dictionary = {}
	for actor: ActorState in actors:
		var tags: PackedStringArray = []
		for instance: CardInstance in actor.inventory:
			if instance.consumed:
				continue
			var definition: CardDefinition = CardCatalog.by_id(instance.definition_id)
			if definition == null:
				continue
			for tag: String in definition.tags:
				if not tags.has(tag):
					tags.append(tag)
		result[actor.actor_id] = tags
	return result

func _finish_run(victory: bool, reason: String) -> void:
	if run_state.finished:
		return
	run_state.finished = true
	run_state.victory = victory
	run_state.result_reason = reason
	_transition_to(GameConstants.Phase.RUN_RESULT)
	events.run_finished.emit(victory, reason)
	events.log_debug("게임 종료 — %s: %s" % ["승리" if victory else "패배", reason])
	events.state_updated.emit()

func _transition_to(next_phase: int, force_emit: bool = false) -> void:
	if not force_emit and run_state.current_phase == next_phase:
		return
	run_state.current_phase = next_phase
	events.phase_changed.emit(next_phase)
	events.log_debug("Phase → %s" % GameConstants.phase_name(next_phase))

func _record_negotiation_bid(actor_id: StringName, amount: int) -> void:
	if negotiation != null:
		negotiation.record_bid(actor_id, amount)

func _record_negotiation_win(actor_id: StringName, _card_id: StringName, _amount: int) -> void:
	if negotiation != null:
		negotiation.record_auction_win(actor_id)

func _record_negotiation_open(_instance_id: StringName, owner_id: StringName) -> void:
	if negotiation != null:
		negotiation.record_card_opened(owner_id)

func _record_negotiation_trade(_instance_id: StringName, from_id: StringName, to_id: StringName) -> void:
	if negotiation != null:
		negotiation.record_trade(from_id, to_id)
