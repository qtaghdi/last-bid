class_name CardEffectSystem
extends RefCounted

var _run_state: RunState
var _events: EventBus
var _rng: CentralRng
var _definitions: Dictionary = {}
var _instance_serial: int = 0

func setup(run_state: RunState, events: EventBus, rng: CentralRng) -> void:
	_run_state = run_state
	_events = events
	_rng = rng
	_definitions.clear()
	for definition: CardDefinition in CardCatalog.load_all():
		_definitions[definition.id] = definition
	_instance_serial = 0

func acquire_card(
	definition: CardDefinition,
	owner: ActorState,
	actors: Array[ActorState]
) -> CardInstance:
	_instance_serial += 1
	var instance: CardInstance = CardInstance.create(
		definition,
		owner.actor_id,
		_run_state.current_round,
		_instance_serial
	)
	owner.inventory.append(instance)
	_events.card_acquired.emit(owner.actor_id, definition.id)
	_events.log_debug("%s이(가) %s 카드를 획득했습니다." % [owner.display_name, definition.actual_name])
	var snapshot: Dictionary = _make_snapshot(actors)
	for index: int in range(definition.effects.size()):
		var effect: CardEffectDefinition = definition.effects[index]
		if effect.trigger == GameConstants.EffectTrigger.ON_ACQUIRE:
			_process_effect(instance, definition, index, effect, owner, actors, snapshot)
	_events.state_updated.emit()
	return instance

func process_trigger(trigger: int, actors: Array[ActorState]) -> void:
	var snapshot: Dictionary = _make_snapshot(actors)
	for inventory_owner: ActorState in actors:
		for instance: CardInstance in inventory_owner.inventory:
			_process_instance_trigger(instance, inventory_owner, trigger, actors, snapshot, false)
	for instance: CardInstance in _run_state.detached_instances:
		if instance.pending_effects.is_empty():
			continue
		var effect_owner: ActorState = _actor_by_id(instance.effect_owner_id, actors)
		if effect_owner != null:
			_process_instance_trigger(instance, effect_owner, trigger, actors, snapshot, true)
	for index: int in range(_run_state.detached_instances.size() - 1, -1, -1):
		if _run_state.detached_instances[index].pending_effects.is_empty():
			_run_state.detached_instances.remove_at(index)
	_events.state_updated.emit()

func open_card(instance: CardInstance, opener: ActorState, actors: Array[ActorState]) -> void:
	if instance == null or opener == null or instance.destroyed:
		return
	var definition: CardDefinition = _definition_for(instance.definition_id)
	if definition == null:
		return
	instance.sealed = false
	instance.reveal_level = GameConstants.RevealLevel.FULLY_REVEALED
	if definition.transfer_policy == GameConstants.TransferPolicy.STAY_WITH_ORIGINAL_OWNER:
		instance.effect_owner_id = opener.actor_id
	else:
		instance.effect_owner_id = instance.owner_id
	for index: int in range(definition.effects.size()):
		var effect: CardEffectDefinition = definition.effects[index]
		if effect.effect_type == GameConstants.EffectType.DELAY_EFFECT and effect.requires_open:
			instance.delay_counters[index] = effect.delay_rounds
			instance.pending_effects[index] = true
			instance.remaining_turns = maxi(instance.remaining_turns, effect.delay_rounds)
	var snapshot: Dictionary = _make_snapshot(actors)
	_process_instance_trigger(
		instance,
		opener,
		GameConstants.EffectTrigger.ON_OPEN,
		actors,
		snapshot,
		false
	)
	_events.state_updated.emit()

func process_auxiliary_effect(
	instance: CardInstance,
	definition: CardDefinition,
	effect: CardEffectDefinition,
	source_actor: ActorState,
	actors: Array[ActorState]
) -> void:
	if instance == null or definition == null or effect == null or source_actor == null:
		return
	_process_effect(instance, definition, -1, effect, source_actor, actors, _make_snapshot(actors))
	_events.state_updated.emit()

func transfer_instance(
	instance: CardInstance,
	from_actor: ActorState,
	to_actor: ActorState,
	actors: Array[ActorState]
) -> bool:
	if (
		instance == null
		or from_actor == null
		or to_actor == null
		or not from_actor.alive
		or not to_actor.alive
		or not instance.is_available()
		or instance.owner_id != from_actor.actor_id
	):
		return false
	var definition: CardDefinition = _definition_for(instance.definition_id)
	if definition == null or not definition.transferable:
		return false
	if from_actor.remove_instance(instance.instance_id) == null:
		return false
	to_actor.inventory.append(instance)
	var previous_owner: StringName = from_actor.actor_id
	instance.record_transfer(previous_owner, to_actor.actor_id, _run_state.current_round)
	match definition.transfer_policy:
		GameConstants.TransferPolicy.FOLLOW_CURRENT_OWNER:
			instance.effect_owner_id = to_actor.actor_id
		GameConstants.TransferPolicy.CANCEL_ON_TRANSFER:
			for index: int in range(definition.effects.size()):
				if definition.effects[index].effect_type == GameConstants.EffectType.DELAY_EFFECT:
					instance.resolved_effects[index] = true
			instance.delay_counters.clear()
			instance.pending_effects.clear()
			instance.remaining_turns = 0
		GameConstants.TransferPolicy.TRIGGER_ON_TRANSFER:
			instance.effect_owner_id = to_actor.actor_id
			_process_instance_trigger(
				instance,
				to_actor,
				GameConstants.EffectTrigger.ON_TRANSFER,
				actors,
				_make_snapshot(actors),
				false
			)
		GameConstants.TransferPolicy.STAY_WITH_ORIGINAL_OWNER:
			pass
	_events.card_transferred.emit(instance.instance_id, previous_owner, to_actor.actor_id)
	_events.card_owner_changed.emit(instance.instance_id, to_actor.actor_id)
	_events.log_debug(
		"카드 이전: %s → %s (%s)"
		% [from_actor.display_name, to_actor.display_name, definition.actual_name]
	)
	_events.state_updated.emit()
	return true

func burn_instance(instance: CardInstance, owner: ActorState, actors: Array[ActorState]) -> bool:
	if instance == null or owner == null or instance.owner_id != owner.actor_id:
		return false
	var definition: CardDefinition = _definition_for(instance.definition_id)
	if definition == null or not definition.burnable or owner.gold < definition.burn_cost:
		return false
	owner.gold -= definition.burn_cost
	_events.gold_changed.emit(owner.actor_id, -definition.burn_cost, owner.gold, &"")
	for burn_effect: CardEffectDefinition in definition.burn_effects:
		process_auxiliary_effect(instance, definition, burn_effect, owner, actors)
	owner.remove_instance(instance.instance_id)
	var former_owner: StringName = owner.actor_id
	instance.owner_id = &""
	instance.destroyed = true
	instance.consumed = true
	if (
		definition.transfer_policy == GameConstants.TransferPolicy.STAY_WITH_ORIGINAL_OWNER
		and not instance.pending_effects.is_empty()
	):
		_run_state.detached_instances.append(instance)
	else:
		instance.delay_counters.clear()
		instance.pending_effects.clear()
		instance.remaining_turns = 0
	_events.card_burned.emit(instance.instance_id, former_owner)
	_events.log_debug("%s 소각: %s (-%d골드)" % [owner.display_name, definition.actual_name, definition.burn_cost])
	_events.state_updated.emit()
	return true

func apply_damage(
	target: ActorState,
	amount: int,
	source_card_id: StringName = &""
) -> int:
	if target == null or not target.alive or amount <= 0:
		return 0
	if amount >= target.hp and _consume_lethal_guard(target):
		_events.log_debug("%s의 치명 피해가 무효화되었습니다." % target.display_name)
		_events.state_updated.emit()
		return 0
	var actual_damage: int = mini(amount, target.hp)
	target.hp -= actual_damage
	_events.damage_applied.emit(target.actor_id, actual_damage, source_card_id)
	_events.log_debug("%s 체력 -%d (%d/%d)" % [target.display_name, actual_damage, target.hp, target.max_hp])
	if target.hp <= 0:
		target.hp = 0
		target.alive = false
		target.has_passed = true
		_events.actor_died.emit(target.actor_id)
		_events.log_debug("%s 사망" % target.display_name)
	_events.state_updated.emit()
	return actual_damage

func _process_effect(
	instance: CardInstance,
	definition: CardDefinition,
	effect_index: int,
	effect: CardEffectDefinition,
	owner: ActorState,
	actors: Array[ActorState],
	snapshot: Dictionary
) -> void:
	if bool(instance.resolved_effects.get(effect_index, false)):
		return
	var effective_type: int = effect.effect_type
	if effect.effect_type == GameConstants.EffectType.DELAY_EFFECT:
		var remaining: int = int(instance.delay_counters.get(effect_index, effect.delay_rounds)) - 1
		instance.delay_counters[effect_index] = remaining
		instance.remaining_turns = _largest_remaining_delay(instance)
		if remaining > 0:
			_events.log_debug("%s 지연 효과: %d라운드 남음" % [definition.actual_name, remaining])
			return
		instance.resolved_effects[effect_index] = true
		instance.pending_effects.erase(effect_index)
		effective_type = effect.nested_effect_type

	var targets: Array[ActorState] = _select_targets(effect.target_selector, owner, actors, snapshot)
	var target_ids: Array[StringName] = []
	for target: ActorState in targets:
		target_ids.append(target.actor_id)
	_events.card_effect_triggered.emit(definition.id, effect.effect_type, target_ids)

	match effective_type:
		GameConstants.EffectType.MODIFY_HP:
			for target: ActorState in targets:
				if effect.amount < 0:
					apply_damage(target, absi(effect.amount), definition.id)
				elif effect.amount > 0 and target.alive:
					var previous_hp: int = target.hp
					target.hp = mini(target.max_hp, target.hp + effect.amount)
					_events.log_debug("%s 체력 +%d" % [target.display_name, target.hp - previous_hp])
		GameConstants.EffectType.MODIFY_GOLD:
			for target: ActorState in targets:
				_apply_gold_effect(target, effect, definition.id)
		GameConstants.EffectType.SET_GLOBAL_RULE:
			_apply_global_rule(effect)
		GameConstants.EffectType.CONSUME_CARD:
			instance.consumed = true
			_events.card_consumed.emit(definition.id, owner.actor_id)
		_:
			_events.log_debug("지원되지 않는 효과 실행 요청: %d" % effective_type)

	_events.log_debug("카드 효과: %s — %s" % [definition.actual_name, effect.description])
	if effect.consume_after_trigger:
		instance.consumed = true
		_events.card_consumed.emit(definition.id, owner.actor_id)
		_events.log_debug("%s 카드가 소모되었습니다." % definition.actual_name)

func _apply_gold_effect(
	target: ActorState,
	effect: CardEffectDefinition,
	source_card_id: StringName
) -> void:
	if not target.alive or effect.amount == 0:
		return
	var previous_gold: int = target.gold
	target.gold = maxi(0, target.gold + effect.amount)
	var delta: int = target.gold - previous_gold
	_events.gold_changed.emit(target.actor_id, delta, target.gold, source_card_id)
	_events.log_debug("%s 골드 %+d (%d)" % [target.display_name, delta, target.gold])
	if effect.amount < 0 and effect.overflow_hp_per_gold > 0:
		var shortage: int = maxi(0, absi(effect.amount) - previous_gold)
		if shortage > 0:
			var overflow_damage: int = ceili(float(shortage) / float(effect.overflow_hp_per_gold))
			apply_damage(target, overflow_damage, source_card_id)

func _apply_global_rule(effect: CardEffectDefinition) -> void:
	if effect.global_rule == &"next_round_min_increment":
		_run_state.active_global_effects[&"min_increment_round"] = _run_state.current_round + 1
		_run_state.active_global_effects[&"min_increment_value"] = effect.amount
		_events.log_debug("다음 라운드 최소 인상액이 %d골드로 변경됩니다." % effect.amount)
	else:
		_events.log_debug("알 수 없는 글로벌 규칙: %s" % effect.global_rule)

func _consume_lethal_guard(target: ActorState) -> bool:
	for instance: CardInstance in target.inventory:
		if instance.consumed:
			continue
		var definition: CardDefinition = _definition_for(instance.definition_id)
		if definition == null:
			continue
		if instance.sealed and not definition.effects_while_sealed:
			continue
		for effect: CardEffectDefinition in definition.effects:
			if (
				effect.trigger == GameConstants.EffectTrigger.ON_LETHAL_DAMAGE
				and effect.effect_type == GameConstants.EffectType.CONSUME_CARD
			):
				instance.consumed = true
				_events.card_consumed.emit(definition.id, target.actor_id)
				var targets: Array[StringName] = [target.actor_id]
				_events.card_effect_triggered.emit(definition.id, effect.effect_type, targets)
				_events.log_debug("%s 발동 후 소모" % definition.actual_name)
				return true
	return false

func _select_targets(
	selector: int,
	owner: ActorState,
	actors: Array[ActorState],
	snapshot: Dictionary
) -> Array[ActorState]:
	var targets: Array[ActorState] = []
	if selector == GameConstants.EffectType.SELECT_OWNER:
		if owner.alive:
			targets.append(owner)
		return targets
	var alive_actors: Array[ActorState] = []
	for actor: ActorState in actors:
		if actor.alive:
			alive_actors.append(actor)
	if alive_actors.is_empty():
		return targets
	if selector == GameConstants.EffectType.SELECT_RANDOM_ALIVE:
		targets.append(alive_actors[_rng.choose_index(alive_actors.size())])
		return targets
	var selected_gold: int = int(snapshot[alive_actors[0].actor_id]["gold"])
	for actor: ActorState in alive_actors:
		var actor_gold: int = int(snapshot[actor.actor_id]["gold"])
		if selector == GameConstants.EffectType.SELECT_RICHEST:
			selected_gold = maxi(selected_gold, actor_gold)
		elif selector == GameConstants.EffectType.SELECT_POOREST:
			selected_gold = mini(selected_gold, actor_gold)
	for actor: ActorState in alive_actors:
		if int(snapshot[actor.actor_id]["gold"]) == selected_gold:
			targets.append(actor)
	return targets

func _make_snapshot(actors: Array[ActorState]) -> Dictionary:
	var snapshot: Dictionary = {}
	for actor: ActorState in actors:
		snapshot[actor.actor_id] = {
			"gold": actor.gold,
			"hp": actor.hp,
			"alive": actor.alive,
		}
	return snapshot

func _largest_remaining_delay(instance: CardInstance) -> int:
	var largest: int = 0
	for value: Variant in instance.delay_counters.values():
		largest = maxi(largest, int(value))
	return largest

func _definition_for(card_id: StringName) -> CardDefinition:
	return _definitions.get(card_id) as CardDefinition

func _process_instance_trigger(
	instance: CardInstance,
	inventory_owner: ActorState,
	trigger: int,
	actors: Array[ActorState],
	snapshot: Dictionary,
	allow_destroyed_pending: bool
) -> void:
	if instance == null or instance.consumed and not allow_destroyed_pending:
		return
	var definition: CardDefinition = _definition_for(instance.definition_id)
	if definition == null:
		_events.log_debug("카드 효과 실패: 정의 없음 (%s)" % instance.definition_id)
		return
	if (
		instance.sealed
		and not definition.effects_while_sealed
		and trigger not in [GameConstants.EffectTrigger.ON_OPEN, GameConstants.EffectTrigger.ON_TRANSFER]
	):
		return
	var effect_owner: ActorState = _effect_owner_for(instance, definition, inventory_owner, actors)
	if effect_owner == null or not effect_owner.alive:
		return
	for index: int in range(definition.effects.size()):
		if instance.consumed and not allow_destroyed_pending:
			break
		var effect: CardEffectDefinition = definition.effects[index]
		if effect.trigger != trigger:
			continue
		if effect.requires_open and instance.sealed:
			continue
		if allow_destroyed_pending and not bool(instance.pending_effects.get(index, false)):
			continue
		_process_effect(instance, definition, index, effect, effect_owner, actors, snapshot)

func _effect_owner_for(
	instance: CardInstance,
	definition: CardDefinition,
	inventory_owner: ActorState,
	actors: Array[ActorState]
) -> ActorState:
	if definition.transfer_policy == GameConstants.TransferPolicy.STAY_WITH_ORIGINAL_OWNER:
		return _actor_by_id(instance.effect_owner_id, actors)
	return inventory_owner

func _actor_by_id(actor_id: StringName, actors: Array[ActorState]) -> ActorState:
	for actor: ActorState in actors:
		if actor.actor_id == actor_id:
			return actor
	return null
