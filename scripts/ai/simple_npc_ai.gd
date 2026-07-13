class_name SimpleNpcAi
extends RefCounted

var maximum_bids: Dictionary = {}
var evaluations: Dictionary = {}
var recent_dialogues: Dictionary = {}
var bluff_intents: Dictionary = {}
var bluff_remaining: Dictionary = {}
var last_bluff_actions: Dictionary = {}

var _events: EventBus
var _dialogue_service: NpcDialogueService
var _starting_bid: int = 0
var _minimum_increment: int = GameConstants.DEFAULT_MIN_INCREMENT
var _bluff_ceilings: Dictionary = {}

func setup(events: EventBus, dialogue_service: NpcDialogueService) -> void:
	_events = events
	_dialogue_service = dialogue_service

func prepare_lot(
	actors: Array[ActorState],
	knowledge_states: Dictionary,
	inventory_tags_by_actor: Dictionary,
	starting_bid: int,
	minimum_increment: int,
	current_round: int,
	rng: CentralRng
) -> void:
	maximum_bids.clear()
	evaluations.clear()
	recent_dialogues.clear()
	bluff_intents.clear()
	bluff_remaining.clear()
	last_bluff_actions.clear()
	_bluff_ceilings.clear()
	_starting_bid = starting_bid
	_minimum_increment = minimum_increment
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC or not actor.alive:
			continue
		var knowledge: KnowledgeState = knowledge_states.get(actor.actor_id) as KnowledgeState
		var inventory_tags: PackedStringArray = inventory_tags_by_actor.get(
			actor.actor_id,
			PackedStringArray()
		)
		var evaluation: Dictionary = evaluate_knowledge(
			actor,
			knowledge,
			inventory_tags,
			actors,
			current_round
		)
		evaluations[actor.actor_id] = evaluation
		maximum_bids[actor.actor_id] = _calculate_maximum_bid(
			actor,
			evaluation,
			starting_bid,
			minimum_increment,
			rng
		)
		_prepare_bluff(actor, evaluation, rng)
		var dialogue_category: StringName = _pre_info_category(evaluation)
		_speak(actor, dialogue_category, rng)
		_events.npc_evaluation_ready.emit(actor.actor_id, evaluation.duplicate(true))

func evaluate_knowledge(
	actor: ActorState,
	knowledge: KnowledgeState,
	inventory_tags: PackedStringArray,
	actors: Array[ActorState],
	current_round: int
) -> Dictionary:
	var known_tags: PackedStringArray = knowledge.known_tags() if knowledge != null else PackedStringArray()
	var estimated_reward: int = knowledge.estimated_reward() if knowledge != null else 240
	var raw_risk: int = knowledge.estimated_risk_cost() if knowledge != null else 140
	var risk_multiplier: float = _risk_multiplier(actor.archetype)
	var estimated_risk_cost: int = roundi(float(raw_risk) * risk_multiplier)
	if actor.archetype == GameConstants.ARCHETYPE_CREDITOR and (
		knowledge == null or not knowledge.knows_type(&"risk")
	):
		estimated_risk_cost += 70
	var archetype_tag_bonus: int = _archetype_tag_bonus(actor.archetype, known_tags)
	var inventory_synergy: int = _inventory_synergy(actor.archetype, known_tags, inventory_tags)
	var current_state_modifier: int = _current_state_modifier(actor, known_tags, actors)
	var strategic_modifier: int = _strategic_modifier(actor.archetype, known_tags, current_round)
	var final_value: int = maxi(
		0,
		estimated_reward
		- estimated_risk_cost
		+ archetype_tag_bonus
		+ inventory_synergy
		+ current_state_modifier
		+ strategic_modifier
	)
	return {
		"estimated_reward": estimated_reward,
		"estimated_risk_cost": estimated_risk_cost,
		"archetype_tag_bonus": archetype_tag_bonus,
		"inventory_synergy": inventory_synergy,
		"current_state_modifier": current_state_modifier,
		"strategic_modifier": strategic_modifier,
		"final_value": final_value,
		"known_tags": known_tags,
		"used_clue_ids": knowledge.known_clue_ids.duplicate() if knowledge != null else [],
	}

func decide_action(
	actor: ActorState,
	required_bid: int,
	has_competing_interest: bool,
	rng: CentralRng
) -> Dictionary:
	last_bluff_actions[actor.actor_id] = false
	if not actor.alive or actor.has_passed or required_bid > actor.gold:
		_speak(actor, &"pass", rng)
		return {"bid": false, "bluff": false}
	var max_bid: int = maximum_bid_for(actor.actor_id)
	var normal_bid: bool = required_bid <= max_bid and rng.randf() <= _bid_probability(actor.archetype)
	if normal_bid:
		var evaluation: Dictionary = evaluations.get(actor.actor_id, {})
		var category: StringName = &"strong_preference" if int(evaluation.get("final_value", 0)) >= 550 else &"interest"
		_speak(actor, category, rng)
		return {"bid": true, "bluff": false}
	var can_bluff: bool = (
		actor.archetype == GameConstants.ARCHETYPE_GAMBLER
		and bool(bluff_intents.get(actor.actor_id, false))
		and int(bluff_remaining.get(actor.actor_id, 0)) > 0
		and has_competing_interest
		and required_bid <= int(_bluff_ceilings.get(actor.actor_id, 0))
	)
	if can_bluff:
		bluff_remaining[actor.actor_id] = int(bluff_remaining[actor.actor_id]) - 1
		last_bluff_actions[actor.actor_id] = true
		_speak(actor, &"bluff", rng)
		return {"bid": true, "bluff": true}
	var pass_category: StringName = &"price_pressure" if required_bid > max_bid else &"pass"
	_speak(actor, pass_category, rng)
	return {"bid": false, "bluff": false}

func maximum_bid_for(actor_id: StringName) -> int:
	return int(maximum_bids.get(actor_id, 0))

func evaluation_for(actor_id: StringName) -> Dictionary:
	return evaluations.get(actor_id, {}).duplicate(true)

func dialogue_for(actor_id: StringName) -> String:
	return str(recent_dialogues.get(actor_id, ""))

func is_bluffing(actor_id: StringName) -> bool:
	return bool(last_bluff_actions.get(actor_id, false))

func has_bluff_intent(actor_id: StringName) -> bool:
	return bool(bluff_intents.get(actor_id, false))

func evaluate_purchase(
	actor: ActorState,
	knowledge: KnowledgeState,
	inventory_tags: PackedStringArray,
	actors: Array[ActorState],
	current_round: int,
	offered_price: int
) -> Dictionary:
	var evaluation: Dictionary = evaluate_knowledge(
		actor,
		knowledge,
		inventory_tags,
		actors,
		current_round
	)
	var urgency_modifier: int = 0
	if current_round >= GameConstants.TOTAL_ROUNDS - 2:
		urgency_modifier -= 60
	if actor.archetype == GameConstants.ARCHETYPE_GAMBLER and actor.gold >= 500:
		urgency_modifier += 45
	var purchase_value: int = (
		int(evaluation.get("estimated_reward", 0))
		- int(evaluation.get("estimated_risk_cost", 0))
		+ int(evaluation.get("archetype_tag_bonus", 0))
		+ int(evaluation.get("inventory_synergy", 0))
		- offered_price
		+ urgency_modifier
	)
	evaluation["offered_price"] = offered_price
	evaluation["urgency_modifier"] = urgency_modifier
	evaluation["purchase_value"] = purchase_value
	return evaluation

func choose_post_auction_action(
	actor: ActorState,
	knowledge: KnowledgeState,
	has_sealed_space: bool,
	current_round: int
) -> Dictionary:
	var known_tags: PackedStringArray = knowledge.known_tags() if knowledge != null else PackedStringArray()
	var evaluation: Dictionary = evaluations.get(actor.actor_id, {})
	var estimated_reward: int = int(
		evaluation.get("estimated_reward", knowledge.estimated_reward() if knowledge != null else 240)
	)
	var estimated_risk: int = int(
		evaluation.get("estimated_risk_cost", knowledge.estimated_risk_cost() if knowledge != null else 180)
	)
	var action: int = GameConstants.PostAuctionAction.KEEP
	var seals_to_open: int = 0
	match actor.archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			var collector_interest: bool = _contains_any(
				known_tags,
				PackedStringArray(["rare", "cursed", "ownership", "collection", "unique"])
			)
			if has_sealed_space and (collector_interest or estimated_reward >= estimated_risk):
				action = GameConstants.PostAuctionAction.KEEP
			else:
				action = GameConstants.PostAuctionAction.OPEN
				seals_to_open = 2
		GameConstants.ARCHETYPE_CREDITOR:
			var economic_interest: bool = _contains_any(
				known_tags,
				PackedStringArray(["economy", "contract", "loan", "income", "debt"])
			)
			if estimated_risk > estimated_reward + 100:
				action = GameConstants.PostAuctionAction.BURN
			elif economic_interest:
				action = GameConstants.PostAuctionAction.OPEN
				seals_to_open = 1
			else:
				action = GameConstants.PostAuctionAction.KEEP
		GameConstants.ARCHETYPE_GAMBLER:
			if _contains_any(known_tags, PackedStringArray(["high_risk", "high_reward", "gamble"])):
				action = GameConstants.PostAuctionAction.OPEN
				seals_to_open = GameConstants.MAX_SEALS
			else:
				action = GameConstants.PostAuctionAction.KEEP
	if not has_sealed_space and action == GameConstants.PostAuctionAction.KEEP:
		action = GameConstants.PostAuctionAction.BURN
	if current_round >= GameConstants.TOTAL_ROUNDS and action == GameConstants.PostAuctionAction.KEEP:
		action = GameConstants.PostAuctionAction.OPEN
		seals_to_open = GameConstants.MAX_SEALS
	return {
		"action": action,
		"seals_to_open": seals_to_open,
		"used_clue_ids": knowledge.known_clue_ids.duplicate() if knowledge != null else [],
	}

func _calculate_maximum_bid(
	actor: ActorState,
	evaluation: Dictionary,
	starting_bid: int,
	minimum_increment: int,
	rng: CentralRng
) -> int:
	var reserve: int = 150
	var aggression_percent: int = 105
	match actor.archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			reserve = 150
			aggression_percent = 112
		GameConstants.ARCHETYPE_CREDITOR:
			reserve = 250
			aggression_percent = 92
		GameConstants.ARCHETYPE_GAMBLER:
			reserve = 100
			aggression_percent = 128
	var affordable: int = maxi(0, actor.gold - reserve)
	if affordable < starting_bid:
		affordable = actor.gold
	var subjective_cap: int = int(evaluation.get("final_value", 0)) * aggression_percent / 100
	if actor.hp <= 1:
		subjective_cap = subjective_cap * (90 if actor.archetype == GameConstants.ARCHETYPE_GAMBLER else 70) / 100
	var variation: int = rng.randi_range(-minimum_increment, minimum_increment * 2)
	return clampi(subjective_cap + variation, 0, affordable)

func _prepare_bluff(actor: ActorState, evaluation: Dictionary, rng: CentralRng) -> void:
	var intent: bool = false
	var remaining: int = 0
	if (
		actor.archetype == GameConstants.ARCHETYPE_GAMBLER
		and actor.gold >= _starting_bid + _minimum_increment * 2
		and int(evaluation.get("final_value", 0)) < _starting_bid + 220
	):
		intent = rng.randf() <= 0.5
		if intent:
			remaining = rng.randi_range(1, 2)
	bluff_intents[actor.actor_id] = intent
	bluff_remaining[actor.actor_id] = remaining
	_bluff_ceilings[actor.actor_id] = mini(
		actor.gold - 100,
		_starting_bid + _minimum_increment * 2
	)

func _pre_info_category(evaluation: Dictionary) -> StringName:
	var final_value: int = int(evaluation.get("final_value", 0))
	if final_value >= 550:
		return &"strong_preference"
	if final_value >= 300:
		return &"interest"
	return &"caution"

func _speak(actor: ActorState, category: StringName, rng: CentralRng) -> void:
	if _dialogue_service == null or _events == null:
		return
	var line: String = _dialogue_service.select_line(actor.archetype, category, rng)
	recent_dialogues[actor.actor_id] = line
	_events.npc_dialogue_spoken.emit(actor.actor_id, line, category)
	_events.log_debug("%s 대사[%s]: %s" % [actor.display_name, category, line])

func _risk_multiplier(archetype: StringName) -> float:
	match archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			return 0.82
		GameConstants.ARCHETYPE_CREDITOR:
			return 1.25
		GameConstants.ARCHETYPE_GAMBLER:
			return 0.55
		_:
			return 1.0

func _archetype_tag_bonus(archetype: StringName, known_tags: PackedStringArray) -> int:
	var preferred: PackedStringArray = InformationService.preferred_tags_for(archetype)
	var weight: int = 60
	if archetype == GameConstants.ARCHETYPE_COLLECTOR:
		weight = 70
	elif archetype == GameConstants.ARCHETYPE_GAMBLER:
		weight = 75
	var matches: int = 0
	for tag: String in known_tags:
		if preferred.has(tag):
			matches += 1
	return matches * weight

func _inventory_synergy(
	archetype: StringName,
	known_tags: PackedStringArray,
	inventory_tags: PackedStringArray
) -> int:
	var matches: int = 0
	for tag: String in known_tags:
		if inventory_tags.has(tag):
			matches += 1
	var weight: int = 40 if archetype == GameConstants.ARCHETYPE_COLLECTOR else 25
	return matches * weight

func _current_state_modifier(
	actor: ActorState,
	known_tags: PackedStringArray,
	actors: Array[ActorState]
) -> int:
	var modifier: int = 0
	if actor.archetype == GameConstants.ARCHETYPE_CREDITOR and known_tags.has("economy"):
		for participant: ActorState in actors:
			if participant.alive and participant.gold < 400:
				modifier += 25
	elif actor.archetype == GameConstants.ARCHETYPE_GAMBLER:
		if actor.hp >= 2 and actor.gold >= 500:
			modifier += 60
		if actor.hp <= 1:
			modifier -= 35
	return modifier

func _strategic_modifier(
	archetype: StringName,
	known_tags: PackedStringArray,
	current_round: int
) -> int:
	var modifier: int = (current_round - 1) * 4
	if archetype == GameConstants.ARCHETYPE_COLLECTOR and (
		known_tags.has("rare") or known_tags.has("unique") or known_tags.has("cursed")
	):
		modifier += 50
	if archetype == GameConstants.ARCHETYPE_CREDITOR and known_tags.has("disaster"):
		modifier -= 100
	if archetype == GameConstants.ARCHETYPE_GAMBLER and (
		known_tags.has("high_risk") or known_tags.has("high_reward")
	):
		modifier += 55
	return modifier

func _bid_probability(archetype: StringName) -> float:
	match archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			return 0.82
		GameConstants.ARCHETYPE_CREDITOR:
			return 0.72
		GameConstants.ARCHETYPE_GAMBLER:
			return 0.88
		_:
			return 0.75

func _contains_any(values: PackedStringArray, candidates: PackedStringArray) -> bool:
	for candidate: String in candidates:
		if values.has(candidate):
			return true
	return false
