class_name GameFlowController
extends Node

var events: EventBus
var run_state: RunState = RunState.new()
var actors: Array[ActorState] = []
var rng: CentralRng
var auction: AuctionSystem
var effects: CardEffectSystem
var npc_ai: SimpleNpcAi

func _ready() -> void:
	_initialize_services()

func start_new_run(seed_value: int = GameConstants.DEFAULT_SEED) -> void:
	_initialize_services()
	run_state = RunState.new()
	run_state.reset(seed_value)
	rng = CentralRng.new(seed_value)
	npc_ai = SimpleNpcAi.new()
	auction = AuctionSystem.new()
	auction.setup(run_state, events, rng, npc_ai)
	effects = CardEffectSystem.new()
	effects.setup(run_state, events, rng)
	actors = [
		ActorState.create(GameConstants.PLAYER_ID, "플레이어", GameConstants.ActorType.PLAYER),
		ActorState.create(&"npc_1", "수집가", GameConstants.ActorType.NPC),
		ActorState.create(&"npc_2", "채권자", GameConstants.ActorType.NPC),
		ActorState.create(&"npc_3", "도박사", GameConstants.ActorType.NPC),
	]
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
			_start_auction()
		GameConstants.Phase.POST_AUCTION:
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
	run_state.current_bid = 0
	run_state.highest_bidder_id = &""
	run_state.current_min_increment = GameConstants.DEFAULT_MIN_INCREMENT
	if int(run_state.active_global_effects.get(&"min_increment_round", -1)) == round_number:
		run_state.current_min_increment = int(
			run_state.active_global_effects.get(&"min_increment_value", GameConstants.PRICE_SURGE_INCREMENT)
		)
	_transition_to(GameConstants.Phase.PRE_INFO)
	events.round_started.emit(round_number, run_state.current_card.id)
	events.log_debug(
		"라운드 %d 시작 — %s / 최소 인상 %d골드"
		% [round_number, run_state.current_card.display_name, run_state.current_min_increment]
	)
	events.state_updated.emit()

func _start_auction() -> void:
	if _alive_actor_count() <= 1:
		_evaluate_terminal_state()
		return
	_transition_to(GameConstants.Phase.AUCTION)
	auction.start_auction(actors)
	_drive_npc_turns()

func _drive_npc_turns() -> void:
	var guard: int = 0
	while (
		run_state.current_phase == GameConstants.Phase.AUCTION
		and not auction.is_complete()
		and auction.current_actor_id() != GameConstants.PLAYER_ID
	):
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
	if not winner_id.is_empty():
		var winner: ActorState = actor_by_id(winner_id)
		if winner != null:
			effects.acquire_card(run_state.current_card, winner, actors)
	_transition_to(GameConstants.Phase.POST_AUCTION)
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
