class_name PromiseManager
extends RefCounted

var promise_seed: int = 0
var last_result_message: String = ""

var _run_state: RunState
var _events: EventBus
var _rng: CentralRng
var _dialogue: NpcDialogueService
var _information: InformationService
var _effects: CardEffectSystem
var _actors: Array[ActorState] = []
var _knowledge_by_lot: Dictionary = {}
var _promise_serial: int = 0
var _memory_serial: int = 0
var _offer_priority_cache: Dictionary = {}

func setup(
	run_state: RunState,
	events: EventBus,
	seed_value: int,
	dialogue: NpcDialogueService,
	information: InformationService,
	effects: CardEffectSystem
) -> void:
	_run_state = run_state
	_events = events
	promise_seed = seed_value ^ GameConstants.PROMISE_SEED_SALT
	_rng = CentralRng.new(promise_seed)
	_dialogue = dialogue
	_information = information
	_effects = effects
	_promise_serial = 0
	_memory_serial = 0
	_offer_priority_cache.clear()
	_connect_events()

func initialize(actors: Array[ActorState]) -> void:
	_actors = actors
	_run_state.active_promises.clear()
	_run_state.resolved_promises.clear()
	_run_state.reputation_map.clear()
	_run_state.npc_memories.clear()
	_run_state.betrayal_history.clear()
	_run_state.promise_result_messages.clear()
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		_run_state.reputation_map[actor.actor_id] = 0
		_run_state.npc_memories[actor.actor_id] = []

func shutdown() -> void:
	if _events == null:
		return
	_disconnect_if_connected(_events.bid_placed, _on_bid_placed)
	_disconnect_if_connected(_events.actor_passed, _on_actor_passed)
	_disconnect_if_connected(_events.seal_opened, _on_seal_opened)
	_disconnect_if_connected(_events.card_opened, _on_card_opened)
	_disconnect_if_connected(_events.card_transferred, _on_card_transferred)
	_disconnect_if_connected(_events.card_burned, _on_card_burned)
	_disconnect_if_connected(_events.clue_shared, _on_clue_shared)
	_disconnect_if_connected(_events.phase_changed, _on_phase_changed)
	_disconnect_if_connected(_events.round_finished, _on_round_finished)
	_disconnect_if_connected(_events.actor_died, _on_actor_died)
	_disconnect_if_connected(_events.run_finished, _on_run_finished)

func update_context(actors: Array[ActorState], knowledge_by_lot: Dictionary) -> void:
	_actors = actors
	_knowledge_by_lot = knowledge_by_lot

func create_from_offer(offer: NegotiationOffer) -> PromiseState:
	if offer == null or not offer.creates_promise or offer.promise_type.is_empty():
		return null
	var issuer: ActorState = _actor_by_id(offer.issuer_id)
	var receiver: ActorState = _actor_by_id(offer.receiver_id)
	if issuer == null or receiver == null or not issuer.alive or not receiver.alive:
		return null
	if offer.promise_type in [
		GameConstants.PROMISE_KEEP_CARD_SEALED,
		GameConstants.PROMISE_HOLD_CARD,
		GameConstants.PROMISE_TRANSFER_CARD,
	]:
		var offered_instance: CardInstance = _instance_by_id(offer.promise_target_card_instance_id)
		if offered_instance == null:
			return null
		if offer.promise_type == GameConstants.PROMISE_KEEP_CARD_SEALED and not offered_instance.sealed:
			return null
	if (
		offer.promise_type == GameConstants.PROMISE_TRANSFER_CARD
		and _actor_by_id(offer.promise_target_actor_id) == null
	):
		return null
	if offer.offered_gold > 0 and issuer.gold < offer.offered_gold:
		return null
	_promise_serial += 1
	var promise: PromiseState = PromiseState.new()
	promise.promise_id = StringName(
		"promise_%02d_%03d" % [_run_state.current_round, _promise_serial]
	)
	promise.issuer_id = offer.issuer_id
	promise.receiver_id = offer.receiver_id
	promise.promise_type = offer.promise_type
	promise.obligor_ids = offer.promise_obligor_ids.duplicate()
	promise.target_actor_id = offer.promise_target_actor_id
	promise.target_card_instance_id = offer.promise_target_card_instance_id
	promise.target_lot_id = offer.promise_target_lot_id
	promise.target_display_name = offer.target_display_name
	promise.created_round = _run_state.current_round
	promise.target_round = offer.promise_target_round
	promise.expires_round = offer.promise_target_round
	promise.immediate_reward_gold = offer.offered_gold
	promise.reward_gold = offer.promise_reward_gold
	promise.reward_clue_id = offer.promise_reward_clue_id
	promise.penalty_hp = offer.promise_penalty_hp
	promise.penalty_gold = offer.promise_penalty_gold
	promise.reputation_reward = offer.promise_reputation_reward
	promise.reputation_penalty = offer.promise_reputation_penalty
	promise.card_policy = offer.promise_card_policy
	promise.conditions = [
		{"key": &"passed_ids", "value": {}},
		{"key": &"betrayal_decisions", "value": {}},
	]
	var target_instance: CardInstance = _instance_by_id(promise.target_card_instance_id)
	if target_instance != null:
		promise.set_condition(&"opened_seals_at_creation", target_instance.opened_seals)
		promise.set_condition(&"owner_at_creation", target_instance.owner_id)
	if not _pay_immediate_reward(promise):
		return null
	_run_state.active_promises.append(promise)
	last_result_message = "새 약속이 생성되었습니다: %s" % promise_type_name(promise.promise_type)
	_events.promise_created.emit(promise.promise_id, promise.promise_type)
	_events.promise_accepted.emit(promise.promise_id)
	_events.active_promises_changed.emit()
	_events.log_debug(
		"약속 생성: %s type=%s target_round=%d"
		% [promise.promise_id, promise.promise_type, promise.target_round]
	)
	_events.state_updated.emit()
	return promise

func process_round_start(round_number: int) -> void:
	for promise: PromiseState in _active_snapshot():
		if promise.target_round != round_number:
			continue
		if promise.promise_type == GameConstants.PROMISE_SHARE_INFORMATION:
			_process_due_information_promise(promise)
		elif promise.promise_type == GameConstants.PROMISE_TRANSFER_CARD:
			_process_due_npc_transfer(promise)

func actionable_player_promise() -> PromiseState:
	for promise: PromiseState in _run_state.active_promises:
		if can_player_fulfill(promise.promise_id):
			return promise
	return null

func can_player_fulfill(promise_id: StringName) -> bool:
	var promise: PromiseState = _active_by_id(promise_id)
	if promise == null or not promise.has_obligor(GameConstants.PLAYER_ID):
		return false
	if promise.promise_type == GameConstants.PROMISE_TRANSFER_CARD:
		var player: ActorState = _actor_by_id(GameConstants.PLAYER_ID)
		var target: ActorState = _actor_by_id(promise.target_actor_id)
		var instance: CardInstance = player.instance_by_id(promise.target_card_instance_id) if player != null else null
		return (
			player != null
			and target != null
			and target.alive
			and instance != null
			and instance.transferable_snapshot
			and (not instance.sealed or target.has_inventory_space_for_sealed())
		)
	if promise.promise_type == GameConstants.PROMISE_SHARE_INFORMATION:
		var lot_knowledge: Dictionary = _knowledge_by_lot.get(promise.target_lot_id, {}) as Dictionary
		var source: KnowledgeState = lot_knowledge.get(GameConstants.PLAYER_ID) as KnowledgeState
		var receiver: KnowledgeState = lot_knowledge.get(promise.receiver_id) as KnowledgeState
		return not _first_shareable_clue(source, receiver).is_empty()
	return false

func fulfill_player_promise(promise_id: StringName) -> bool:
	if not can_player_fulfill(promise_id):
		return false
	var promise: PromiseState = _active_by_id(promise_id)
	if promise.promise_type == GameConstants.PROMISE_TRANSFER_CARD:
		var player: ActorState = _actor_by_id(GameConstants.PLAYER_ID)
		var target: ActorState = _actor_by_id(promise.target_actor_id)
		var instance: CardInstance = player.instance_by_id(promise.target_card_instance_id)
		return _effects.transfer_instance(instance, player, target, _actors)
	if promise.promise_type == GameConstants.PROMISE_SHARE_INFORMATION:
		var lot_knowledge: Dictionary = _knowledge_by_lot.get(promise.target_lot_id, {}) as Dictionary
		var source: KnowledgeState = lot_knowledge.get(GameConstants.PLAYER_ID) as KnowledgeState
		var receiver: KnowledgeState = lot_knowledge.get(promise.receiver_id) as KnowledgeState
		var clue_id: StringName = _first_shareable_clue(source, receiver)
		return _information.share_known_clue(source, receiver, clue_id)
	return false

func npc_should_pass(actor_id: StringName, round_number: int) -> bool:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.target_round == round_number
			and promise.has_obligor(actor_id)
			and promise.promise_type in [
				GameConstants.PROMISE_SKIP_AUCTION,
				GameConstants.PROMISE_MUTUAL_PASS,
			]
		):
			return not decide_npc_betrayal(promise, actor_id)
	return false

func npc_should_preserve_card(actor_id: StringName, instance_id: StringName) -> bool:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.has_obligor(actor_id)
			and promise.target_card_instance_id == instance_id
			and promise.promise_type in [
				GameConstants.PROMISE_KEEP_CARD_SEALED,
				GameConstants.PROMISE_HOLD_CARD,
			]
		):
			return not decide_npc_betrayal(promise, actor_id)
	return false

func decide_npc_betrayal(
	promise: PromiseState,
	actor_id: StringName,
	immediate_gain_override: int = -1
) -> bool:
	if promise == null or not promise.is_active() or not promise.has_obligor(actor_id):
		return false
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null or actor.actor_type != GameConstants.ActorType.NPC:
		return false
	var decisions: Dictionary = promise.condition_value(&"betrayal_decisions", {}) as Dictionary
	if decisions.has(actor_id):
		return bool(decisions[actor_id])
	var breakdown: Dictionary = betrayal_score(promise, actor_id, immediate_gain_override)
	var jitter: int = _rng.randi_range(-20, 20)
	var total: int = int(breakdown.get("total", 0)) + jitter
	var betrayed: bool = total >= 40
	decisions[actor_id] = betrayed
	promise.set_condition(&"betrayal_decisions", decisions)
	promise.set_condition(&"betrayal_score_%s" % actor_id, total)
	_events.log_debug(
		"배신 판정: %s promise=%s score=%d jitter=%d result=%s"
		% [actor.display_name, promise.promise_id, int(breakdown.get("total", 0)), jitter, betrayed]
	)
	return betrayed

func betrayal_score(
	promise: PromiseState,
	actor_id: StringName,
	immediate_gain_override: int = -1
) -> Dictionary:
	var actor: ActorState = _actor_by_id(actor_id)
	var state: NpcRunState = _npc_state(actor_id)
	if actor == null or state == null:
		return {"total": -999}
	var immediate_gain: int = immediate_gain_override
	if immediate_gain < 0:
		match promise.promise_type:
			GameConstants.PROMISE_MUTUAL_PASS:
				immediate_gain = 90
			GameConstants.PROMISE_SKIP_AUCTION:
				immediate_gain = 75
			GameConstants.PROMISE_SHARE_INFORMATION:
				immediate_gain = 65
			GameConstants.PROMISE_TRANSFER_CARD:
				immediate_gain = 100
			_:
				immediate_gain = 50
	var goal_bonus: int = _secret_goal_betrayal_bonus(state.secret_goal_id, promise.promise_type)
	var survival_pressure: int = 0
	if actor.hp <= 1:
		survival_pressure = 140 if actor.character_id == GameConstants.CHARACTER_MARA else 90
	elif actor.gold < 150:
		survival_pressure = 35
	var revenge_modifier: int = _memory_count(actor_id, GameConstants.MEMORY_PLAYER_BETRAYED_NPC) * 35
	var personality_loyalty: int = 70
	match actor.character_id:
		GameConstants.CHARACTER_MARA:
			personality_loyalty = 115
		GameConstants.CHARACTER_VOLT:
			personality_loyalty = 35
		GameConstants.CHARACTER_SERA:
			personality_loyalty = 70
	var reputation_modifier: int = reputation_for(actor_id) * 30
	var relationship_modifier: int = state.relationship_score * 20
	var total: int = (
		immediate_gain
		+ goal_bonus
		+ survival_pressure
		+ revenge_modifier
		- personality_loyalty
		- reputation_modifier
		- relationship_modifier
	)
	return {
		"immediate_gain": immediate_gain,
		"secret_goal_bonus": goal_bonus,
		"survival_pressure": survival_pressure,
		"revenge_modifier": revenge_modifier,
		"personality_loyalty": personality_loyalty,
		"reputation_modifier": reputation_modifier,
		"relationship_modifier": relationship_modifier,
		"total": total,
	}

func reputation_for(actor_id: StringName) -> int:
	return int(_run_state.reputation_map.get(actor_id, 0))

func offer_priority_variation(actor_id: StringName, round_number: int) -> int:
	var key: StringName = StringName("%d:%s" % [round_number, actor_id])
	if not _offer_priority_cache.has(key):
		_offer_priority_cache[key] = _rng.randi_range(-10, 10)
	return int(_offer_priority_cache[key])

func change_reputation(actor_id: StringName, delta: int, reason: String = "") -> int:
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null or actor.actor_type != GameConstants.ActorType.NPC or delta == 0:
		return reputation_for(actor_id)
	var previous: int = reputation_for(actor_id)
	var next_value: int = clampi(
		previous + delta,
		GameConstants.REPUTATION_MIN,
		GameConstants.REPUTATION_MAX
	)
	_run_state.reputation_map[actor_id] = next_value
	var actual_delta: int = next_value - previous
	if actual_delta != 0:
		_events.reputation_changed.emit(actor_id, next_value, actual_delta)
		_events.log_debug(
			"평판 변화: %s %+d → %d%s"
			% [actor.display_name, actual_delta, next_value, " · %s" % reason if not reason.is_empty() else ""]
		)
	return next_value

func add_memory(
	actor_id: StringName,
	event_type: StringName,
	source_actor_id: StringName,
	target_actor_id: StringName,
	card_instance_id: StringName,
	severity: int,
	summary: String
) -> NpcMemoryEntry:
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null or actor.actor_type != GameConstants.ActorType.NPC:
		return null
	_memory_serial += 1
	var entry: NpcMemoryEntry = NpcMemoryEntry.create(
		StringName("memory_%s_%03d" % [actor_id, _memory_serial]),
		actor_id,
		event_type,
		source_actor_id,
		target_actor_id,
		card_instance_id,
		_run_state.current_round,
		clampi(severity, 1, 3),
		summary
	)
	var memories: Array = _run_state.npc_memories.get(actor_id, []) as Array
	memories.append(entry)
	while memories.size() > GameConstants.MAX_NPC_MEMORIES:
		var remove_index: int = 0
		for index: int in range(1, memories.size()):
			var candidate: NpcMemoryEntry = memories[index] as NpcMemoryEntry
			var current: NpcMemoryEntry = memories[remove_index] as NpcMemoryEntry
			if candidate.severity < current.severity:
				remove_index = index
			elif candidate.severity == current.severity and candidate.round_number < current.round_number:
				remove_index = index
		memories.remove_at(remove_index)
	_run_state.npc_memories[actor_id] = memories
	_events.npc_memory_added.emit(actor_id, event_type)
	_events.state_updated.emit()
	return entry

func memories_for(actor_id: StringName) -> Array[NpcMemoryEntry]:
	var result: Array[NpcMemoryEntry] = []
	for value: Variant in _run_state.npc_memories.get(actor_id, []):
		var entry: NpcMemoryEntry = value as NpcMemoryEntry
		if entry != null:
			result.append(entry)
	return result

func recent_memory_summary(actor_id: StringName) -> String:
	var memories: Array[NpcMemoryEntry] = memories_for(actor_id)
	return memories[-1].summary_text if not memories.is_empty() else "기억 없음"

func memory_offer_modifier(actor_id: StringName) -> int:
	var modifier: int = 0
	for memory: NpcMemoryEntry in memories_for(actor_id):
		match memory.event_type:
			GameConstants.MEMORY_PROMISE_FULFILLED, GameConstants.MEMORY_GOOD_TRADE:
				modifier += 10 * memory.severity
			GameConstants.MEMORY_PLAYER_BETRAYED_NPC, GameConstants.MEMORY_BAD_TRADE:
				modifier -= 15 * memory.severity
			GameConstants.MEMORY_REFUSED_OFFER:
				modifier -= 4
	return clampi(modifier, -60, 60)

func active_for(actor_id: StringName) -> Array[PromiseState]:
	var result: Array[PromiseState] = []
	for promise: PromiseState in _run_state.active_promises:
		if promise.involves(actor_id):
			result.append(promise)
	return result

func active_count_for(actor_id: StringName) -> int:
	return active_for(actor_id).size()

func recent_betrayal_by(actor_id: StringName) -> bool:
	for index: int in range(_run_state.betrayal_history.size() - 1, -1, -1):
		var betrayal: Dictionary = _run_state.betrayal_history[index]
		if int(betrayal.get("round", -99)) < _run_state.current_round - 1:
			break
		if betrayal.get("actor_id", &"") == actor_id:
			return true
	return false

func active_summary_text() -> String:
	if _run_state.active_promises.is_empty():
		return "활성 약속 없음"
	var lines: PackedStringArray = []
	for promise: PromiseState in _run_state.active_promises:
		lines.append(promise_summary(promise))
	return "\n".join(lines)

func promise_summary(promise: PromiseState) -> String:
	if promise == null:
		return "약속 없음"
	var counterpart: ActorState = _actor_by_id(_npc_counterpart_id(promise))
	var name: String = counterpart.display_name if counterpart != null else "상대"
	var remaining: int = maxi(0, promise.target_round - _run_state.current_round)
	var deadline: String = "현재 경매 종료" if remaining == 0 else "%d라운드 남음" % remaining
	return "%s · %s · %s · %s" % [
		name,
		promise_type_name(promise.promise_type),
		promise.target_display_name if not promise.target_display_name.is_empty() else "현재 경매",
		deadline,
	]

func violation_text(promise_type: StringName) -> String:
	match promise_type:
		GameConstants.PROMISE_SKIP_AUCTION:
			return "대상 경매에서 입찰하면 위반"
		GameConstants.PROMISE_KEEP_CARD_SEALED:
			return "기한 전에 봉인을 열면 위반"
		GameConstants.PROMISE_HOLD_CARD:
			return "판매·이전·소각하면 위반"
		GameConstants.PROMISE_TRANSFER_CARD:
			return "기한 내 지정 상대에게 넘기지 않으면 위반"
		GameConstants.PROMISE_SHARE_INFORMATION:
			return "기한 내 단서를 제공하지 않으면 위반"
		GameConstants.PROMISE_MUTUAL_PASS:
			return "둘 중 한 명이라도 입찰하면 해당 참가자 위반"
		_:
			return "조건을 지키지 않으면 위반"

func result_counts() -> Dictionary:
	var fulfilled: int = 0
	var broken: int = 0
	var cancelled: int = 0
	for promise: PromiseState in _run_state.resolved_promises:
		match promise.status:
			GameConstants.PROMISE_FULFILLED:
				fulfilled += 1
			GameConstants.PROMISE_BROKEN:
				broken += 1
			GameConstants.PROMISE_CANCELLED, GameConstants.PROMISE_EXPIRED:
				cancelled += 1
	return {"fulfilled": fulfilled, "broken": broken, "cancelled": cancelled}

func debug_report() -> String:
	var lines: PackedStringArray = [
		"PROMISE RNG SEED: %d" % promise_seed,
		"ACTIVE PROMISES: %d · RESOLVED: %d" % [
			_run_state.active_promises.size(),
			_run_state.resolved_promises.size(),
		],
	]
	for promise: PromiseState in _run_state.active_promises + _run_state.resolved_promises:
		lines.append(
			"%s type=%s status=%s issuer=%s receiver=%s obligors=%s actor=%s card=%s lot=%s round=%d/%d reward=%d penalty_hp=%d penalty_gold=%d rep=%+d/-%d reason=%s"
			% [
				promise.promise_id,
				promise.promise_type,
				promise.status,
				promise.issuer_id,
				promise.receiver_id,
				promise.obligor_ids,
				promise.target_actor_id,
				promise.target_card_instance_id,
				promise.target_lot_id,
				promise.created_round,
				promise.target_round,
				promise.reward_gold,
				promise.penalty_hp,
				promise.penalty_gold,
				promise.reputation_reward,
				promise.reputation_penalty,
				promise.resolution_reason,
			]
		)
	for actor: ActorState in _actors:
		if actor.actor_type == GameConstants.ActorType.NPC:
			lines.append(
				"%s reputation=%+d memories=%d recent_betrayal=%s"
				% [
					actor.actor_id,
					reputation_for(actor.actor_id),
					memories_for(actor.actor_id).size(),
					recent_betrayal_by(actor.actor_id),
				]
			)
	return "\n".join(lines)

static func promise_type_name(promise_type: StringName) -> String:
	match promise_type:
		GameConstants.PROMISE_SKIP_AUCTION:
			return "경매 불참 약속"
		GameConstants.PROMISE_KEEP_CARD_SEALED:
			return "봉인 유지 약속"
		GameConstants.PROMISE_HOLD_CARD:
			return "카드 보관 약속"
		GameConstants.PROMISE_TRANSFER_CARD:
			return "카드 이전 약속"
		GameConstants.PROMISE_SHARE_INFORMATION:
			return "정보 제공 약속"
		GameConstants.PROMISE_MUTUAL_PASS:
			return "상호 패스 약속"
		_:
			return "알 수 없는 약속"

func _connect_events() -> void:
	_events.bid_placed.connect(_on_bid_placed)
	_events.actor_passed.connect(_on_actor_passed)
	_events.seal_opened.connect(_on_seal_opened)
	_events.card_opened.connect(_on_card_opened)
	_events.card_transferred.connect(_on_card_transferred)
	_events.card_burned.connect(_on_card_burned)
	_events.clue_shared.connect(_on_clue_shared)
	_events.phase_changed.connect(_on_phase_changed)
	_events.round_finished.connect(_on_round_finished)
	_events.actor_died.connect(_on_actor_died)
	_events.run_finished.connect(_on_run_finished)

func _disconnect_if_connected(signal_value: Signal, callable: Callable) -> void:
	if signal_value.is_connected(callable):
		signal_value.disconnect(callable)

func _on_bid_placed(actor_id: StringName, _amount: int) -> void:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.target_round == _run_state.current_round
			and promise.has_obligor(actor_id)
			and promise.promise_type in [
				GameConstants.PROMISE_SKIP_AUCTION,
				GameConstants.PROMISE_MUTUAL_PASS,
			]
		):
			_break_promise(promise, actor_id, "%s이(가) 약속한 경매에서 입찰했습니다." % _actor_name(actor_id))

func _on_actor_passed(actor_id: StringName) -> void:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.target_round != _run_state.current_round
			or not promise.has_obligor(actor_id)
			or promise.promise_type not in [
				GameConstants.PROMISE_SKIP_AUCTION,
				GameConstants.PROMISE_MUTUAL_PASS,
			]
		):
			continue
		var passed_ids: Dictionary = promise.condition_value(&"passed_ids", {}) as Dictionary
		passed_ids[actor_id] = true
		promise.set_condition(&"passed_ids", passed_ids)
		if _all_obligors_recorded(promise, passed_ids):
			_fulfill_promise(promise, GameConstants.PLAYER_ID if promise.has_obligor(GameConstants.PLAYER_ID) else actor_id, "약속한 참가자가 모두 경매에서 패스했습니다.")

func _on_seal_opened(instance_id: StringName, _seal_number: int, _reveal_text: String) -> void:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.promise_type == GameConstants.PROMISE_KEEP_CARD_SEALED
			and promise.target_card_instance_id == instance_id
		):
			var owner: ActorState = _owner_of_instance(instance_id)
			var breaker_id: StringName = owner.actor_id if owner != null else promise.obligor_ids[0]
			_break_promise(promise, breaker_id, "%s이(가) 약속한 카드의 봉인을 열었습니다." % _actor_name(breaker_id))

func _on_card_opened(_instance_id: StringName, _owner_id: StringName) -> void:
	pass

func _on_card_transferred(instance_id: StringName, from_id: StringName, to_id: StringName) -> void:
	for promise: PromiseState in _active_snapshot():
		if promise.target_card_instance_id != instance_id:
			continue
		match promise.promise_type:
			GameConstants.PROMISE_TRANSFER_CARD:
				if from_id in promise.obligor_ids and to_id == promise.target_actor_id:
					_fulfill_promise(promise, from_id, "%s에게 약속한 카드를 전달했습니다." % _actor_name(to_id))
				elif from_id in promise.obligor_ids:
					_break_promise(promise, from_id, "약속한 카드를 다른 참가자에게 이전했습니다.")
			GameConstants.PROMISE_HOLD_CARD:
				if from_id in promise.obligor_ids:
					_break_promise(promise, from_id, "보관하기로 한 카드를 이전했습니다.")

func _on_card_burned(instance_id: StringName, former_owner_id: StringName) -> void:
	for promise: PromiseState in _active_snapshot():
		if promise.target_card_instance_id != instance_id:
			continue
		if promise.card_policy == GameConstants.PROMISE_FULFILL_ON_UNAVOIDABLE:
			_fulfill_promise(promise, former_owner_id, "불가피한 카드 소멸로 약속을 이행한 것으로 처리했습니다.")
		elif promise.card_policy == GameConstants.PROMISE_CANCEL_IF_TARGET_DIES:
			_cancel_promise(promise, "약속 대상이 사라져 취소되었습니다.")
		else:
			_break_promise(promise, former_owner_id, "약속 대상 카드를 자발적으로 소각했습니다.")

func _on_clue_shared(
	source_actor_id: StringName,
	target_actor_id: StringName,
	lot_id: StringName,
	clue_id: StringName
) -> void:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.promise_type == GameConstants.PROMISE_SHARE_INFORMATION
			and promise.has_obligor(source_actor_id)
			and promise.receiver_id == target_actor_id
			and (promise.target_lot_id.is_empty() or promise.target_lot_id == lot_id)
			and (promise.reward_clue_id.is_empty() or promise.reward_clue_id == clue_id)
		):
			_fulfill_promise(promise, source_actor_id, "%s이(가) 약속한 단서를 제공했습니다." % _actor_name(source_actor_id))

func _on_phase_changed(phase: int) -> void:
	if phase == GameConstants.Phase.POST_AUCTION:
		_resolve_pass_promises()

func _on_round_finished(round_number: int) -> void:
	for promise: PromiseState in _active_snapshot():
		if promise.target_round > round_number:
			continue
		match promise.promise_type:
			GameConstants.PROMISE_KEEP_CARD_SEALED:
				var instance: CardInstance = _instance_by_id(promise.target_card_instance_id)
				if instance != null:
					_fulfill_promise(promise, promise.obligor_ids[0], "기한까지 카드 봉인을 유지했습니다.")
				else:
					_cancel_promise(promise, "대상 카드를 찾을 수 없어 약속을 취소했습니다.")
			GameConstants.PROMISE_HOLD_CARD:
				var holder: ActorState = _owner_of_instance(promise.target_card_instance_id)
				if holder != null and promise.has_obligor(holder.actor_id):
					_fulfill_promise(promise, holder.actor_id, "기한까지 카드 소유권을 유지했습니다.")
				else:
					_break_promise(promise, promise.obligor_ids[0], "기한에 약속한 카드 소유권을 유지하지 못했습니다.")
			GameConstants.PROMISE_TRANSFER_CARD:
				_break_promise(promise, promise.obligor_ids[0], "기한 내 약속한 카드 이전을 완료하지 못했습니다.")
			GameConstants.PROMISE_SHARE_INFORMATION:
				_break_promise(promise, promise.obligor_ids[0], "기한 내 약속한 단서를 제공하지 못했습니다.")
			GameConstants.PROMISE_SKIP_AUCTION, GameConstants.PROMISE_MUTUAL_PASS:
				_resolve_single_pass_promise(promise)

func _on_actor_died(actor_id: StringName) -> void:
	for promise: PromiseState in _active_snapshot():
		if promise.involves(actor_id) or promise.target_actor_id == actor_id:
			_cancel_promise(promise, "%s의 사망으로 약속을 취소했습니다." % _actor_name(actor_id))

func _on_run_finished(_victory: bool, _reason: String) -> void:
	for promise: PromiseState in _active_snapshot():
		_cancel_promise(promise, "런 종료로 활성 약속을 취소했습니다.")

func _resolve_pass_promises() -> void:
	for promise: PromiseState in _active_snapshot():
		if (
			promise.target_round == _run_state.current_round
			and promise.promise_type in [
				GameConstants.PROMISE_SKIP_AUCTION,
				GameConstants.PROMISE_MUTUAL_PASS,
			]
		):
			_resolve_single_pass_promise(promise)

func _resolve_single_pass_promise(promise: PromiseState) -> void:
	var passed_ids: Dictionary = promise.condition_value(&"passed_ids", {}) as Dictionary
	if _all_obligors_recorded(promise, passed_ids):
		_fulfill_promise(promise, GameConstants.PLAYER_ID if promise.has_obligor(GameConstants.PLAYER_ID) else promise.obligor_ids[0], "약속한 참가자가 모두 경매에서 패스했습니다.")
	else:
		for obligor_id: StringName in promise.obligor_ids:
			if not bool(passed_ids.get(obligor_id, false)):
				_break_promise(promise, obligor_id, "%s이(가) 기한 내 패스하지 않았습니다." % _actor_name(obligor_id))
				return

func _process_due_information_promise(promise: PromiseState) -> void:
	var npc_obligor: ActorState = _first_npc_obligor(promise)
	if npc_obligor == null:
		return
	if decide_npc_betrayal(promise, npc_obligor.actor_id):
		_break_promise(promise, npc_obligor.actor_id, "%s이(가) 정보 제공 약속을 저버렸습니다." % npc_obligor.display_name)
		return
	var lot_knowledge: Dictionary = _knowledge_by_lot.get(promise.target_lot_id, {}) as Dictionary
	var source: KnowledgeState = lot_knowledge.get(npc_obligor.actor_id) as KnowledgeState
	var target: KnowledgeState = lot_knowledge.get(promise.receiver_id) as KnowledgeState
	var clue_id: StringName = promise.reward_clue_id
	if clue_id.is_empty():
		clue_id = _first_shareable_clue(source, target)
	if not clue_id.is_empty() and _information.share_known_clue(source, target, clue_id):
		return
	_cancel_promise(promise, "전달 가능한 새 단서가 없어 약속을 취소했습니다.")

func _process_due_npc_transfer(promise: PromiseState) -> void:
	var npc_obligor: ActorState = _first_npc_obligor(promise)
	if npc_obligor == null:
		return
	var target: ActorState = _actor_by_id(promise.target_actor_id)
	var instance: CardInstance = npc_obligor.instance_by_id(promise.target_card_instance_id)
	if target == null or instance == null:
		return
	if decide_npc_betrayal(promise, npc_obligor.actor_id):
		_break_promise(promise, npc_obligor.actor_id, "%s이(가) 카드 이전 약속을 저버렸습니다." % npc_obligor.display_name)
		return
	_effects.transfer_instance(instance, npc_obligor, target, _actors)

func _fulfill_promise(promise: PromiseState, fulfilled_by: StringName, reason: String) -> void:
	if promise == null or not promise.is_active():
		return
	promise.status = GameConstants.PROMISE_FULFILLED
	promise.fulfilled_round = _run_state.current_round
	promise.fulfilled_by = fulfilled_by
	promise.resolution_reason = reason
	_move_to_resolved(promise)
	_apply_fulfillment_reward(promise)
	var counterpart_id: StringName = _npc_counterpart_id(promise)
	if fulfilled_by == GameConstants.PLAYER_ID and not counterpart_id.is_empty():
		change_reputation(counterpart_id, promise.reputation_reward, "약속 이행")
		_change_relationship(counterpart_id, 1)
		_set_emotion_after_fulfillment(counterpart_id)
		add_memory(
			counterpart_id,
			GameConstants.MEMORY_PROMISE_FULFILLED,
			fulfilled_by,
			counterpart_id,
			promise.target_card_instance_id,
			2,
			"플레이어가 약속을 지켰다"
		)
	last_result_message = "약속 이행 · %s" % reason
	_record_result(last_result_message)
	_events.promise_fulfilled.emit(promise.promise_id, fulfilled_by, reason)
	_events.log_debug("약속 이행: %s · %s" % [promise.promise_id, reason])
	_events.state_updated.emit()

func _break_promise(promise: PromiseState, broken_by: StringName, reason: String) -> void:
	if promise == null or not promise.is_active():
		return
	promise.status = GameConstants.PROMISE_BROKEN
	promise.broken_round = _run_state.current_round
	promise.broken_by = broken_by
	promise.resolution_reason = reason
	_move_to_resolved(promise)
	_apply_break_penalty(promise)
	var counterpart_id: StringName = _npc_counterpart_id(promise)
	var breaker: ActorState = _actor_by_id(broken_by)
	if broken_by == GameConstants.PLAYER_ID and not counterpart_id.is_empty():
		change_reputation(counterpart_id, -promise.reputation_penalty, "약속 위반")
		_change_relationship(counterpart_id, -1)
		_set_emotion_after_player_betrayal(counterpart_id)
		add_memory(
			counterpart_id,
			GameConstants.MEMORY_PLAYER_BETRAYED_NPC,
			broken_by,
			counterpart_id,
			promise.target_card_instance_id,
			3,
			"플레이어가 약속을 어겼다"
		)
		_events.betrayal_reacted.emit(counterpart_id, broken_by)
	elif breaker != null and breaker.actor_type == GameConstants.ActorType.NPC:
		_record_npc_betrayal(breaker, promise, reason)
	last_result_message = "약속 위반 · %s" % reason
	_record_result(last_result_message)
	_events.promise_broken.emit(promise.promise_id, broken_by, reason)
	_events.log_debug("약속 위반: %s by=%s · %s" % [promise.promise_id, broken_by, reason])
	_events.state_updated.emit()

func _cancel_promise(promise: PromiseState, reason: String) -> void:
	if promise == null or not promise.is_active():
		return
	promise.status = GameConstants.PROMISE_CANCELLED
	promise.resolution_reason = reason
	_move_to_resolved(promise)
	last_result_message = "약속 취소 · %s" % reason
	_record_result(last_result_message)
	_events.promise_cancelled.emit(promise.promise_id, reason)
	_events.log_debug("약속 취소: %s · %s" % [promise.promise_id, reason])
	_events.state_updated.emit()

func expire_promise(promise: PromiseState, reason: String) -> void:
	if promise == null or not promise.is_active():
		return
	promise.status = GameConstants.PROMISE_EXPIRED
	promise.resolution_reason = reason
	_move_to_resolved(promise)
	last_result_message = "약속 만료 · %s" % reason
	_record_result(last_result_message)
	_events.promise_expired.emit(promise.promise_id, reason)
	_events.state_updated.emit()

func _move_to_resolved(promise: PromiseState) -> void:
	_run_state.active_promises.erase(promise)
	_run_state.resolved_promises.append(promise)
	_events.active_promises_changed.emit()

func _pay_immediate_reward(promise: PromiseState) -> bool:
	if promise.immediate_reward_gold <= 0:
		return true
	var payer: ActorState = _actor_by_id(promise.issuer_id)
	var receiver: ActorState = _actor_by_id(promise.receiver_id)
	if payer == null or receiver == null or payer.gold < promise.immediate_reward_gold:
		return false
	payer.gold -= promise.immediate_reward_gold
	receiver.gold += promise.immediate_reward_gold
	promise.immediate_reward_paid = true
	_events.gold_changed.emit(payer.actor_id, -promise.immediate_reward_gold, payer.gold, &"")
	_events.gold_changed.emit(receiver.actor_id, promise.immediate_reward_gold, receiver.gold, &"")
	return true

func _apply_fulfillment_reward(promise: PromiseState) -> void:
	if promise.reward_paid:
		return
	promise.reward_paid = true
	if promise.reward_gold <= 0:
		return
	var recipient: ActorState = _actor_by_id(promise.fulfilled_by)
	var payer_id: StringName = _npc_counterpart_id(promise)
	var payer: ActorState = _actor_by_id(payer_id)
	if recipient == null or not recipient.alive:
		return
	var amount: int = promise.reward_gold
	if payer != null and payer != recipient:
		amount = mini(amount, payer.gold)
		payer.gold -= amount
		_events.gold_changed.emit(payer.actor_id, -amount, payer.gold, &"")
	recipient.gold += amount
	_events.gold_changed.emit(recipient.actor_id, amount, recipient.gold, &"")

func _apply_break_penalty(promise: PromiseState) -> void:
	if promise.penalty_applied:
		return
	promise.penalty_applied = true
	var breaker: ActorState = _actor_by_id(promise.broken_by)
	if breaker == null or not breaker.alive:
		return
	if promise.penalty_gold > 0:
		var loss: int = mini(promise.penalty_gold, breaker.gold)
		breaker.gold -= loss
		_events.gold_changed.emit(breaker.actor_id, -loss, breaker.gold, &"")
	if promise.penalty_hp > 0 and breaker.alive:
		_effects.apply_damage(breaker, promise.penalty_hp, &"")

func _record_npc_betrayal(actor: ActorState, promise: PromiseState, reason: String) -> void:
	_run_state.betrayal_history.append({
		"actor_id": actor.actor_id,
		"promise_id": promise.promise_id,
		"round": _run_state.current_round,
		"reason": reason,
	})
	add_memory(
		actor.actor_id,
		GameConstants.MEMORY_BETRAYED_PLAYER,
		actor.actor_id,
		GameConstants.PLAYER_ID,
		promise.target_card_instance_id,
		3,
		"자신이 플레이어와의 약속을 저버렸다"
	)
	_change_relationship(actor.actor_id, -1)
	_set_emotion_after_self_betrayal(actor.actor_id)
	_events.betrayal_committed.emit(actor.actor_id, promise.promise_id, reason)
	_events.betrayal_reacted.emit(GameConstants.PLAYER_ID, actor.actor_id)

func _record_result(message: String) -> void:
	_run_state.promise_result_messages.append(message)
	while _run_state.promise_result_messages.size() > 8:
		_run_state.promise_result_messages.remove_at(0)

func _change_relationship(actor_id: StringName, delta: int) -> void:
	var state: NpcRunState = _npc_state(actor_id)
	if state != null:
		_events.relationship_changed.emit(actor_id, state.change_relationship(delta))

func _set_emotion_after_fulfillment(actor_id: StringName) -> void:
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null:
		return
	_set_emotion(
		actor_id,
		GameConstants.Emotion.INTERESTED if actor.character_id == GameConstants.CHARACTER_VOLT else GameConstants.Emotion.CALM
	)

func _set_emotion_after_player_betrayal(actor_id: StringName) -> void:
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null:
		return
	_set_emotion(
		actor_id,
		GameConstants.Emotion.AFRAID if actor.character_id == GameConstants.CHARACTER_MARA else GameConstants.Emotion.ANGRY
	)

func _set_emotion_after_self_betrayal(actor_id: StringName) -> void:
	var actor: ActorState = _actor_by_id(actor_id)
	if actor == null:
		return
	var emotion: int = GameConstants.Emotion.SMUG
	if actor.character_id == GameConstants.CHARACTER_MARA:
		emotion = GameConstants.Emotion.NERVOUS
	elif actor.character_id == GameConstants.CHARACTER_SERA:
		emotion = GameConstants.Emotion.CALM if _rng.randf() < 0.5 else GameConstants.Emotion.SMUG
	_set_emotion(actor_id, emotion)

func _set_emotion(actor_id: StringName, emotion: int) -> void:
	var state: NpcRunState = _npc_state(actor_id)
	if state == null or state.emotion == emotion:
		return
	state.emotion = emotion
	_events.emotion_changed.emit(actor_id, emotion)

func _secret_goal_betrayal_bonus(goal_id: StringName, promise_type: StringName) -> int:
	var goal: String = String(goal_id)
	if promise_type in [GameConstants.PROMISE_SKIP_AUCTION, GameConstants.PROMISE_MUTUAL_PASS]:
		return 55 if goal.contains("bid") or goal.contains("win") else 0
	if promise_type == GameConstants.PROMISE_KEEP_CARD_SEALED:
		return 45 if goal.contains("open") else 0
	if promise_type == GameConstants.PROMISE_TRANSFER_CARD:
		return 45 if goal.contains("trade") else 0
	if promise_type == GameConstants.PROMISE_SHARE_INFORMATION:
		return 50 if goal.contains("clue") else 0
	return 0

func _memory_count(actor_id: StringName, event_type: StringName) -> int:
	var count: int = 0
	for memory: NpcMemoryEntry in memories_for(actor_id):
		if memory.event_type == event_type:
			count += memory.severity
	return count

func _all_obligors_recorded(promise: PromiseState, values: Dictionary) -> bool:
	for actor_id: StringName in promise.obligor_ids:
		if not bool(values.get(actor_id, false)):
			return false
	return not promise.obligor_ids.is_empty()

func _npc_counterpart_id(promise: PromiseState) -> StringName:
	var issuer: ActorState = _actor_by_id(promise.issuer_id)
	if issuer != null and issuer.actor_type == GameConstants.ActorType.NPC:
		return issuer.actor_id
	var receiver: ActorState = _actor_by_id(promise.receiver_id)
	return receiver.actor_id if receiver != null and receiver.actor_type == GameConstants.ActorType.NPC else &""

func _first_npc_obligor(promise: PromiseState) -> ActorState:
	for actor_id: StringName in promise.obligor_ids:
		var actor: ActorState = _actor_by_id(actor_id)
		if actor != null and actor.actor_type == GameConstants.ActorType.NPC:
			return actor
	return null

func _first_shareable_clue(source: KnowledgeState, target: KnowledgeState) -> StringName:
	if source == null or target == null:
		return &""
	for clue_id: StringName in source.known_clue_ids:
		if not target.knows(clue_id):
			return clue_id
	return &""

func _active_snapshot() -> Array[PromiseState]:
	return _run_state.active_promises.duplicate()

func _active_by_id(promise_id: StringName) -> PromiseState:
	for promise: PromiseState in _run_state.active_promises:
		if promise.promise_id == promise_id:
			return promise
	return null

func _actor_by_id(actor_id: StringName) -> ActorState:
	for actor: ActorState in _actors:
		if actor.actor_id == actor_id:
			return actor
	return null

func _actor_name(actor_id: StringName) -> String:
	var actor: ActorState = _actor_by_id(actor_id)
	return actor.display_name if actor != null else String(actor_id)

func _npc_state(actor_id: StringName) -> NpcRunState:
	return _run_state.npc_run_states.get(actor_id) as NpcRunState

func _instance_by_id(instance_id: StringName) -> CardInstance:
	if instance_id.is_empty():
		return null
	for actor: ActorState in _actors:
		var instance: CardInstance = actor.instance_by_id(instance_id)
		if instance != null:
			return instance
	for instance: CardInstance in _run_state.detached_instances:
		if instance.instance_id == instance_id:
			return instance
	return null

func _owner_of_instance(instance_id: StringName) -> ActorState:
	for actor: ActorState in _actors:
		if actor.instance_by_id(instance_id) != null:
			return actor
	return null
