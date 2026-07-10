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
	_events.log_debug("%s이(가) %s 카드를 획득했습니다." % [owner.display_name, definition.display_name])
	var snapshot: Dictionary = _make_snapshot(actors)
	for index: int in range(definition.effects.size()):
		var effect: CardEffectDefinition = definition.effects[index]
		if effect.trigger == GameConstants.EffectTrigger.ON_ACQUIRE:
			_process_effect(instance, definition, index, effect, owner, actors, snapshot)
	_events.state_updated.emit()
	return instance

func process_trigger(trigger: int, actors: Array[ActorState]) -> void:
	var snapshot: Dictionary = _make_snapshot(actors)
	for owner: ActorState in actors:
		if not owner.alive:
			continue
		for instance: CardInstance in owner.inventory:
			if not owner.alive:
				break
			if instance.consumed:
				continue
			var definition: CardDefinition = _definition_for(instance.definition_id)
			if definition == null:
				_events.log_debug("카드 효과 실패: 정의 없음 (%s)" % instance.definition_id)
				continue
			for index: int in range(definition.effects.size()):
				if instance.consumed:
					break
				var effect: CardEffectDefinition = definition.effects[index]
				if effect.trigger == trigger:
					_process_effect(instance, definition, index, effect, owner, actors, snapshot)
	_events.state_updated.emit()

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
			_events.log_debug("%s 지연 효과: %d라운드 남음" % [definition.display_name, remaining])
			return
		instance.resolved_effects[effect_index] = true
		effective_type = effect.nested_effect_type

	var targets: Array[ActorState] = _select_targets(effect.target_selector, owner, actors, snapshot)
	var target_ids: Array[StringName] = []
	for target: ActorState in targets:
		target_ids.append(target.actor_id)

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
		_:
			_events.log_debug("지원되지 않는 효과 실행 요청: %d" % effective_type)

	_events.card_effect_triggered.emit(definition.id, effect.effect_type, target_ids)
	_events.log_debug("카드 효과: %s — %s" % [definition.display_name, effect.description])
	if effect.consume_after_trigger:
		instance.consumed = true
		_events.log_debug("%s 카드가 소모되었습니다." % definition.display_name)

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
	_events.gold_changed.emit(target.actor_id, delta, target.gold)
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
		for effect: CardEffectDefinition in definition.effects:
			if (
				effect.trigger == GameConstants.EffectTrigger.ON_LETHAL_DAMAGE
				and effect.effect_type == GameConstants.EffectType.CONSUME_CARD
			):
				instance.consumed = true
				var targets: Array[StringName] = [target.actor_id]
				_events.card_effect_triggered.emit(definition.id, effect.effect_type, targets)
				_events.log_debug("%s 발동 후 소모" % definition.display_name)
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
