class_name AuctionSystem
extends RefCounted

var _actors: Array[ActorState] = []
var _run_state: RunState
var _events: EventBus
var _rng: CentralRng
var _npc_ai: SimpleNpcAi
var _turn_order: Array[StringName] = []
var _turn_index: int = 0
var _action_count: int = 0
var _complete: bool = false
var _settled: bool = false

func setup(
	run_state: RunState,
	events: EventBus,
	rng: CentralRng,
	npc_ai: SimpleNpcAi
) -> void:
	_run_state = run_state
	_events = events
	_rng = rng
	_npc_ai = npc_ai

func start_auction(actors: Array[ActorState]) -> void:
	_actors = actors
	_turn_order = []
	_turn_index = 0
	_action_count = 0
	_complete = false
	_settled = false
	_run_state.current_bid = 0
	_run_state.highest_bidder_id = &""
	for actor: ActorState in _actors:
		actor.reset_for_auction()
		if actor.alive:
			_turn_order.append(actor.actor_id)
	_npc_ai.prepare_auction(
		_actors,
		_run_state.current_card,
		_run_state.current_min_increment,
		_rng
	)
	if _turn_order.is_empty():
		_complete = true
		_events.log_debug("경매 참가자가 없어 카드를 폐기합니다.")
	else:
		_seek_actionable_actor()
	_events.state_updated.emit()

func is_complete() -> bool:
	return _complete

func current_actor_id() -> StringName:
	if _complete or _turn_order.is_empty():
		return &""
	return _turn_order[_turn_index]

func next_required_bid() -> int:
	if _run_state.highest_bidder_id.is_empty():
		return _run_state.current_card.starting_bid
	return _run_state.current_bid + _run_state.current_min_increment

func can_actor_bid(actor_id: StringName) -> bool:
	if _complete or current_actor_id() != actor_id:
		return false
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null or not actor.alive or actor.has_passed:
		return false
	return next_required_bid() <= actor.gold

func place_next_bid(actor_id: StringName) -> bool:
	if not can_actor_bid(actor_id):
		_events.log_debug("입찰 거부: %s는 현재 %d골드 입찰이 불가능합니다." % [actor_id, next_required_bid()])
		return false
	var amount: int = next_required_bid()
	_run_state.current_bid = amount
	_run_state.highest_bidder_id = actor_id
	_action_count += 1
	_events.bid_placed.emit(actor_id, amount)
	_events.log_debug("%s 입찰: %d골드" % [_actor_by_id(actor_id).display_name, amount])
	_after_action()
	return true

func pass_current(actor_id: StringName) -> bool:
	if _complete or current_actor_id() != actor_id:
		_events.log_debug("패스 거부: %s의 차례가 아닙니다." % actor_id)
		return false
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null or not actor.alive or actor.has_passed:
		return false
	actor.has_passed = true
	_action_count += 1
	_events.actor_passed.emit(actor_id)
	_events.log_debug("%s 패스" % actor.display_name)
	_after_action()
	return true

func perform_npc_turn() -> void:
	if _complete:
		return
	var actor: ActorState = _actor_by_id(current_actor_id())
	if actor == null or actor.actor_type != GameConstants.ActorType.NPC:
		return
	var required_bid: int = next_required_bid()
	if _npc_ai.should_bid(actor, required_bid, _rng):
		place_next_bid(actor.actor_id)
	else:
		pass_current(actor.actor_id)

func settle() -> Dictionary:
	if not _complete or _settled:
		return {}
	_settled = true
	if _run_state.highest_bidder_id.is_empty():
		_events.log_debug("아무도 입찰하지 않아 %s 카드를 폐기합니다." % _run_state.current_card.display_name)
		return {"winner_id": &"", "amount": 0}
	var winner: ActorState = _actor_by_id(_run_state.highest_bidder_id)
	if winner == null or not winner.alive or winner.gold < _run_state.current_bid:
		_events.log_debug("낙찰 정산 실패: 낙찰자 상태 또는 골드가 유효하지 않습니다.")
		return {"winner_id": &"", "amount": 0, "error": true}
	var paid_amount: int = _run_state.current_bid
	winner.gold -= paid_amount
	_events.gold_changed.emit(winner.actor_id, -paid_amount, winner.gold)
	_events.auction_won.emit(winner.actor_id, _run_state.current_card.id, paid_amount)
	_events.log_debug("%s 낙찰: %s (%d골드)" % [winner.display_name, _run_state.current_card.display_name, paid_amount])
	return {"winner_id": winner.actor_id, "amount": paid_amount}

func npc_maximum_bids() -> Dictionary:
	return _npc_ai.maximum_bids.duplicate(true)

func _after_action() -> void:
	if _action_count >= GameConstants.AUCTION_ACTION_LIMIT:
		_complete = true
		_events.log_debug("안전장치 작동: 경매 행동 %d회 도달" % GameConstants.AUCTION_ACTION_LIMIT)
		_events.state_updated.emit()
		return
	if _is_auction_over():
		_complete = true
		_events.state_updated.emit()
		return
	_turn_index = (_turn_index + 1) % _turn_order.size()
	_seek_actionable_actor()
	_events.state_updated.emit()

func _seek_actionable_actor() -> void:
	if _turn_order.is_empty():
		_complete = true
		return
	for _scan: int in range(_turn_order.size()):
		var actor: ActorState = _actor_by_id(_turn_order[_turn_index])
		if (
			actor != null
			and actor.alive
			and not actor.has_passed
			and actor.actor_id != _run_state.highest_bidder_id
		):
			return
		_turn_index = (_turn_index + 1) % _turn_order.size()
	_complete = true

func _is_auction_over() -> bool:
	if _run_state.highest_bidder_id.is_empty():
		for actor: ActorState in _actors:
			if actor.alive and not actor.has_passed:
				return false
		return true
	for actor: ActorState in _actors:
		if (
			actor.alive
			and not actor.has_passed
			and actor.actor_id != _run_state.highest_bidder_id
		):
			return false
	return true

func _actor_by_id(actor_id: StringName) -> ActorState:
	for actor: ActorState in _actors:
		if actor.actor_id == actor_id:
			return actor
	return null
