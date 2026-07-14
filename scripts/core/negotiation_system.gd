class_name NegotiationSystem
extends RefCounted

var last_result_message: String = ""
var negotiation_seed: int = 0

var _run_state: RunState
var _events: EventBus
var _rng: CentralRng
var _dialogue: NpcDialogueService
var _information: InformationService
var _effects: CardEffectSystem
var _promises: PromiseManager
var _content: NpcContentCatalog
var _actors: Array[ActorState] = []
var _knowledge_states: Dictionary = {}
var _offer_serial: int = 0

func setup(
	run_state: RunState,
	events: EventBus,
	seed_value: int,
	dialogue: NpcDialogueService,
	information: InformationService,
	effects: CardEffectSystem,
	promises: PromiseManager
) -> void:
	_run_state = run_state
	_events = events
	negotiation_seed = seed_value ^ GameConstants.NEGOTIATION_SEED_SALT
	_rng = CentralRng.new(negotiation_seed)
	_dialogue = dialogue
	_information = information
	_effects = effects
	_promises = promises
	_content = NpcContentCatalog.new()
	_offer_serial = 0

func initialize_characters(actors: Array[ActorState]) -> void:
	_actors = actors
	_run_state.npc_run_states.clear()
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		var profile: NpcCharacterProfile = _content.profile(actor.character_id)
		if profile == null:
			continue
		actor.display_name = profile.display_name
		actor.archetype = profile.base_archetype
		var goal_id: StringName = &""
		if not profile.secret_goal_pool.is_empty():
			goal_id = StringName(profile.secret_goal_pool[_rng.choose_index(profile.secret_goal_pool.size())])
		_run_state.npc_run_states[actor.actor_id] = NpcRunState.create(profile.id, goal_id)
		_update_goal_progress(actor.actor_id)

func begin_round(actors: Array[ActorState], knowledge_states: Dictionary) -> void:
	_actors = actors
	_knowledge_states = knowledge_states
	_run_state.negotiation_offers.clear()
	_run_state.current_offer_index = 0
	_run_state.negotiation_complete = false
	_run_state.player_forced_pass = false
	_run_state.temporary_negotiation_warning = ""
	last_result_message = "협상 제안을 확인하세요."
	_events.negotiation_started.emit(_run_state.current_round)
	for actor: ActorState in actors:
		if actor.actor_type == GameConstants.ActorType.NPC and actor.alive:
			_refresh_emotion(actor)
			try_use_emergency(actor.actor_id, false)
	var candidates: Array[Dictionary] = []
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC or not actor.alive:
			continue
		var evaluation: Dictionary = _offer_score(actor)
		var state: NpcRunState = state_for(actor.actor_id)
		if state != null:
			state.latest_offer_score = int(evaluation.get("score", 0))
			state.latest_offer_reason = str(evaluation.get("reason", ""))
		var score: int = int(evaluation.get("score", 0))
		var reputation: int = _promises.reputation_for(actor.actor_id) if _promises != null else 0
		var chance: int = clampi(48 + score / 8 + reputation * 4, 28, 94)
		var roll: int = _rng.randi_range(1, 100)
		_events.log_debug(
			"협상 제안 판정: %s score=%d chance=%d roll=%d"
			% [actor.display_name, score, chance, roll]
		)
		if score >= GameConstants.NEGOTIATION_SCORE_THRESHOLD and roll <= chance:
			candidates.append({"actor": actor, "score": score, "reason": evaluation.get("reason", "")})
	candidates.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return int(first.get("score", 0)) > int(second.get("score", 0))
	)
	for index: int in range(mini(GameConstants.MAX_NEGOTIATION_OFFERS, candidates.size())):
		var candidate: Dictionary = candidates[index]
		var issuer: ActorState = candidate.get("actor") as ActorState
		var offer: NegotiationOffer = build_offer(issuer.actor_id, -1)
		if offer == null:
			continue
		offer.generation_score = int(candidate.get("score", 0))
		offer.generation_reason = str(candidate.get("reason", ""))
		_run_state.negotiation_offers.append(offer)
		_events.offer_created.emit(offer.offer_id, offer.issuer_id, offer.offer_type)
	if _run_state.negotiation_offers.is_empty():
		last_result_message = "이번 라운드에는 협상 제안이 없습니다."
		_finish_negotiation()
	_events.state_updated.emit()

func build_offer(issuer_id: StringName, forced_type: int = -1) -> NegotiationOffer:
	var issuer: ActorState = _actor_by_id(issuer_id)
	var profile: NpcCharacterProfile = profile_for(issuer_id)
	if issuer == null or profile == null or not issuer.alive:
		return null
	var offer_type: int = forced_type if forced_type >= 0 else _choose_offer_type(issuer)
	var player: ActorState = _actor_by_id(GameConstants.PLAYER_ID)
	var target_instance: CardInstance = _first_promisable_player_card(player, issuer, offer_type)
	var offered_clue: StringName = _shareable_clue_id(issuer_id)
	if offer_type == GameConstants.OfferType.BUY_CARD and target_instance == null:
		offer_type = GameConstants.OfferType.SKIP_AUCTION
	if offer_type == GameConstants.OfferType.SHARE_INFORMATION and offered_clue.is_empty():
		offer_type = GameConstants.OfferType.HOLD_CARD
	if (
		offer_type in [
			GameConstants.OfferType.KEEP_SEALED,
			GameConstants.OfferType.HOLD_CARD,
			GameConstants.OfferType.TRANSFER_CARD,
		]
		and target_instance == null
	):
		offer_type = GameConstants.OfferType.MUTUAL_PASS if issuer.character_id == GameConstants.CHARACTER_ROWAN else GameConstants.OfferType.SKIP_AUCTION
	_offer_serial += 1
	var offer: NegotiationOffer = NegotiationOffer.new()
	offer.offer_id = StringName("offer_%02d_%s_%02d" % [_run_state.current_round, issuer.actor_id, _offer_serial])
	offer.issuer_id = issuer.actor_id
	offer.offer_type = offer_type
	offer.target_lot_id = _run_state.current_lot_id
	offer.expires_round = _run_state.current_round
	if target_instance != null and offer_type in [
		GameConstants.OfferType.BUY_CARD,
		GameConstants.OfferType.KEEP_SEALED,
		GameConstants.OfferType.HOLD_CARD,
		GameConstants.OfferType.TRANSFER_CARD,
	]:
		offer.target_card_instance_id = target_instance.instance_id
		offer.target_display_name = target_instance.public_name_snapshot
	else:
		offer.target_display_name = "현재 경매 물품"
	offer.offered_clue_id = offered_clue if offer_type == GameConstants.OfferType.SHARE_INFORMATION else &""
	offer.requested_action = _requested_action_for(offer_type)
	offer.offered_gold = _offer_gold(issuer, profile, offer_type)
	offer.can_counter = offer.offered_gold > 0
	var state: NpcRunState = state_for(issuer.actor_id)
	var relation: int = state.relationship_score if state != null else 0
	var reputation: int = _promises.reputation_for(issuer.actor_id) if _promises != null else 0
	var memory_counter_modifier: int = _promises.memory_offer_modifier(issuer.actor_id) / 2 if _promises != null else 0
	offer.acceptance_threshold = mini(
		issuer.gold,
		maxi(
			offer.offered_gold,
			offer.offered_gold
		+ profile.counter_offer_tolerance
		+ relation * 25
		+ reputation * 25
		+ memory_counter_modifier
		+ _rng.randi_range(-25, 25)
		)
	)
	if state != null:
		state.latest_acceptance_threshold = offer.acceptance_threshold
	_configure_promise_offer(offer, issuer, forced_type < 0)
	var category: StringName = _dialogue_category_for(offer_type)
	if reputation >= 2:
		category = &"trust_high"
	elif reputation <= -2:
		category = &"trust_low"
	elif _promises != null and _promises.memories_for(issuer.actor_id).size() >= 2:
		category = &"memory_reference"
	offer.dialogue = _dialogue.select_line(profile.dialogue_resource_id, category)
	var tell: Dictionary = _select_tell(profile, _tell_trigger_for(state))
	if not tell.is_empty():
		offer.tell_text = str(tell.get("text", ""))
		if state != null:
			state.recent_tell_id = StringName(str(tell.get("id", "")))
			state.recent_tell_text = offer.tell_text
			state.tell_reliability = float(tell.get("reliability", 0.0))
		_events.tell_triggered.emit(issuer.actor_id, state.recent_tell_id, offer.tell_text)
	return offer

func current_offer() -> NegotiationOffer:
	if (
		_run_state.current_offer_index < 0
		or _run_state.current_offer_index >= _run_state.negotiation_offers.size()
	):
		return null
	return _run_state.negotiation_offers[_run_state.current_offer_index]

func can_advance() -> bool:
	return _run_state.negotiation_complete

func accept_current_offer(countered: bool = false) -> bool:
	var offer: NegotiationOffer = current_offer()
	if offer == null or not offer.is_pending():
		return false
	if not _apply_offer(offer):
		last_result_message = "제안 조건을 더 이상 이행할 수 없습니다."
		return false
	offer.accepted = true
	offer.resolved = true
	var issuer: ActorState = _actor_by_id(offer.issuer_id)
	var state: NpcRunState = state_for(offer.issuer_id)
	_change_relationship(offer.issuer_id, 1)
	_set_emotion(offer.issuer_id, GameConstants.Emotion.INTERESTED)
	if issuer != null:
		var category: StringName = (
			&"promise_accepted"
			if offer.creates_promise
			else (&"counter_accept" if countered else &"accept")
		)
		last_result_message = "%s: %s" % [issuer.display_name, _dialogue.select_line(issuer.character_id, category)]
	_events.offer_accepted.emit(offer.offer_id, offer.issuer_id)
	if state != null and offer.offer_type == GameConstants.OfferType.BUY_CARD:
		state.add_metric(&"trades")
		_update_goal_progress(offer.issuer_id)
	_advance_offer()
	return true

func reject_current_offer() -> bool:
	var offer: NegotiationOffer = current_offer()
	if offer == null or not offer.is_pending():
		return false
	offer.rejected = true
	offer.resolved = true
	var issuer: ActorState = _actor_by_id(offer.issuer_id)
	var state: NpcRunState = state_for(offer.issuer_id)
	if state != null:
		state.add_metric(&"rejections")
	if _promises != null:
		_promises.add_memory(
			offer.issuer_id,
			GameConstants.MEMORY_REFUSED_OFFER,
			GameConstants.PLAYER_ID,
			offer.issuer_id,
			offer.target_card_instance_id,
			1,
			"플레이어가 제안을 거절했다"
		)
	_change_relationship(offer.issuer_id, -1)
	_set_emotion(
		offer.issuer_id,
		GameConstants.Emotion.ANGRY if state != null and int(state.metrics.get("rejections", 0)) >= 2 else GameConstants.Emotion.NERVOUS
	)
	if issuer != null:
		last_result_message = "%s: %s" % [
			issuer.display_name,
			_dialogue.select_line(
				issuer.character_id,
				&"promise_rejected" if offer.creates_promise else &"reject"
			),
		]
	_events.offer_rejected.emit(offer.offer_id, offer.issuer_id)
	_advance_offer()
	return true

func counter_current_offer(amount: int) -> bool:
	var offer: NegotiationOffer = current_offer()
	var issuer: ActorState = _actor_by_id(offer.issuer_id) if offer != null else null
	if (
		offer == null
		or issuer == null
		or not offer.is_pending()
		or not offer.can_counter
		or offer.counter_count >= 1
		or amount <= offer.offered_gold
		or amount > issuer.gold
		or amount % GameConstants.COUNTER_INCREMENT != 0
	):
		return false
	offer.counter_count += 1
	if _promises != null and amount >= offer.offered_gold + GameConstants.COUNTER_INCREMENT * 2:
		_promises.add_memory(
			offer.issuer_id,
			GameConstants.MEMORY_COUNTERED_AGGRESSIVELY,
			GameConstants.PLAYER_ID,
			offer.issuer_id,
			offer.target_card_instance_id,
			1,
			"플레이어가 공격적으로 조건을 올렸다"
		)
	_events.offer_countered.emit(offer.offer_id, amount)
	if amount <= offer.acceptance_threshold:
		offer.offered_gold = amount
		return accept_current_offer(true)
	last_result_message = "%s: %s" % [issuer.display_name, _dialogue.select_line(issuer.character_id, &"reject")]
	return reject_current_offer()

func try_use_emergency(actor_id: StringName, force: bool = false) -> bool:
	var actor: ActorState = _actor_by_id(actor_id)
	var state: NpcRunState = state_for(actor_id)
	var profile: NpcCharacterProfile = profile_for(actor_id)
	if actor == null or state == null or profile == null or state.emergency_used or not actor.alive:
		return false
	var used: bool = false
	match profile.emergency_ability_id:
		&"emergency_burn":
			if force or actor.hp <= profile.fear_threshold:
				for instance: CardInstance in actor.inventory:
					if instance.is_available() and instance.sealed and instance.burnable_snapshot:
						used = _effects.burn_instance(instance, actor, _actors, true)
						break
		&"life_collateral":
			if actor.hp > 1 and (force or (actor.gold <= 250 and _rng.randf() <= 0.7)):
				_effects.apply_damage(actor, 1, &"")
				if actor.alive:
					actor.gold += 400
					_events.gold_changed.emit(actor.actor_id, 400, actor.gold, &"")
					used = true
		&"information_theft":
			if force or (_run_state.current_round >= 4 and _rng.randf() <= 0.45):
				var player_knowledge: KnowledgeState = _knowledge_states.get(GameConstants.PLAYER_ID) as KnowledgeState
				var npc_knowledge: KnowledgeState = _knowledge_states.get(actor.actor_id) as KnowledgeState
				var clue_id: StringName = _first_unique_clue(player_knowledge, npc_knowledge)
				used = _information.share_known_clue(player_knowledge, npc_knowledge, clue_id)
				if used:
					state.add_metric(&"clues")
	if not used:
		return false
	state.emergency_used = true
	_events.emergency_ability_used.emit(actor.actor_id, profile.emergency_ability_id)
	_events.log_debug("%s 비장의 수단 사용: %s" % [actor.display_name, profile.emergency_ability_id])
	_update_goal_progress(actor.actor_id)
	return true

func state_for(actor_id: StringName) -> NpcRunState:
	return _run_state.npc_run_states.get(actor_id) as NpcRunState

func profile_for(actor_id: StringName) -> NpcCharacterProfile:
	var actor: ActorState = _actor_by_id(actor_id)
	return _content.profile(actor.character_id) if actor != null else null

func goal_for(actor_id: StringName) -> Dictionary:
	var state: NpcRunState = state_for(actor_id)
	return _content.goal(state.secret_goal_id) if state != null else {}

func record_bid(actor_id: StringName, amount: int) -> void:
	var state: NpcRunState = state_for(actor_id)
	if state != null:
		state.add_metric(&"cumulative_bid", amount)
		_update_goal_progress(actor_id)

func record_auction_win(actor_id: StringName) -> void:
	var state: NpcRunState = state_for(actor_id)
	if state != null:
		state.add_metric(&"auctions_won")
		_set_emotion(actor_id, GameConstants.Emotion.SMUG)
		_update_goal_progress(actor_id)

func record_card_opened(actor_id: StringName) -> void:
	var state: NpcRunState = state_for(actor_id)
	if state == null:
		return
	state.add_metric(&"fully_revealed")
	var knowledge: KnowledgeState = _knowledge_states.get(actor_id) as KnowledgeState
	if knowledge != null and knowledge.estimated_risk_cost() >= 300:
		state.add_metric(&"high_risk_opened")
	_update_goal_progress(actor_id)

func record_trade(from_id: StringName, to_id: StringName) -> void:
	for actor_id: StringName in [from_id, to_id]:
		var state: NpcRunState = state_for(actor_id)
		if state != null:
			state.add_metric(&"trades")
			_update_goal_progress(actor_id)
	if _promises != null:
		var npc_id: StringName = to_id if from_id == GameConstants.PLAYER_ID else from_id
		var npc: ActorState = _actor_by_id(npc_id)
		if npc != null and npc.actor_type == GameConstants.ActorType.NPC:
			if from_id == GameConstants.PLAYER_ID or to_id == GameConstants.PLAYER_ID:
				_promises.change_reputation(npc_id, 1, "거래 이행")
			_promises.add_memory(
				npc_id,
				GameConstants.MEMORY_GOOD_TRADE,
				from_id,
				to_id,
				&"",
				1,
				"플레이어와 거래를 완료했다"
			)

func debug_report() -> String:
	var lines: PackedStringArray = [
		"NEGOTIATION RNG SEED: %d" % negotiation_seed,
		"DIALOGUE RNG SEED: %d" % _dialogue.dialogue_seed,
		"OFFERS: %d index=%d complete=%s forced_pass=%s"
		% [
			_run_state.negotiation_offers.size(),
			_run_state.current_offer_index,
			_run_state.negotiation_complete,
			_run_state.player_forced_pass,
		],
	]
	for actor: ActorState in _actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		var profile: NpcCharacterProfile = profile_for(actor.actor_id)
		var state: NpcRunState = state_for(actor.actor_id)
		var goal: Dictionary = goal_for(actor.actor_id)
		if profile == null or state == null:
			continue
		lines.append(
			"%s [%s/%s] goal=%s (%d/%d) emotion=%s relation=%+d reputation=%+d memories=%d offer=%d threshold=%d tell=%s rel=%.2f emergency=%s"
			% [
				actor.display_name,
				profile.id,
				profile.base_archetype,
				goal.get("description", state.secret_goal_id),
				state.goal_progress,
				int(goal.get("target", 0)),
				emotion_name(state.emotion),
				state.relationship_score,
				_promises.reputation_for(actor.actor_id) if _promises != null else 0,
				_promises.memories_for(actor.actor_id).size() if _promises != null else 0,
				state.latest_offer_score,
				state.latest_acceptance_threshold,
				state.recent_tell_id,
				state.tell_reliability,
				state.emergency_used,
			]
		)
		lines.append("  reason=%s metrics=%s" % [state.latest_offer_reason, state.metrics])
	return "\n".join(lines)

static func emotion_name(emotion: int) -> String:
	match emotion:
		GameConstants.Emotion.INTERESTED:
			return "관심"
		GameConstants.Emotion.NERVOUS:
			return "긴장"
		GameConstants.Emotion.ANGRY:
			return "분노"
		GameConstants.Emotion.AFRAID:
			return "공포"
		GameConstants.Emotion.SMUG:
			return "의기양양"
		_:
			return "평온"

static func offer_type_name(offer_type: int) -> String:
	match offer_type:
		GameConstants.OfferType.BUY_CARD:
			return "카드 구매"
		GameConstants.OfferType.KEEP_SEALED:
			return "개봉 금지"
		GameConstants.OfferType.SHARE_INFORMATION:
			return "정보 교환"
		GameConstants.OfferType.SKIP_AUCTION:
			return "입찰 포기"
		GameConstants.OfferType.HOLD_CARD:
			return "카드 보관"
		GameConstants.OfferType.TRANSFER_CARD:
			return "카드 이전 약속"
		GameConstants.OfferType.MUTUAL_PASS:
			return "상호 패스"
		_:
			return "알 수 없는 제안"

func _offer_score(actor: ActorState) -> Dictionary:
	var profile: NpcCharacterProfile = profile_for(actor.actor_id)
	var state: NpcRunState = state_for(actor.actor_id)
	var knowledge: KnowledgeState = _knowledge_states.get(actor.actor_id) as KnowledgeState
	var reward: int = knowledge.estimated_reward() if knowledge != null else 240
	var risk: int = knowledge.estimated_risk_cost() if knowledge != null else 180
	var known_count: int = knowledge.known_clue_ids.size() if knowledge != null else 0
	var personal_need: int = 50
	var risk_avoidance: int = 0
	match actor.character_id:
		GameConstants.CHARACTER_MARA:
			personal_need = 70 + (4 - mini(4, known_count)) * 15 + (90 if actor.hp <= 1 else 0)
			risk_avoidance = maxi(0, risk - reward) / 3
		GameConstants.CHARACTER_ROWAN:
			personal_need = 60 + (reward + risk) / 12 + (35 if actor.hp >= 2 else -20)
		GameConstants.CHARACTER_SARAH:
			personal_need = 55 + known_count * 22 + (45 if not _shareable_clue_id(actor.actor_id).is_empty() else 0)
	var card_interest: int = maxi(0, reward - risk) / 8
	var goal_bonus: int = _secret_goal_bonus(actor, state, knowledge)
	var relationship_modifier: int = (state.relationship_score if state != null else 0) * 15
	var reputation_modifier: int = (_promises.reputation_for(actor.actor_id) if _promises != null else 0) * 18
	var memory_modifier: int = _promises.memory_offer_modifier(actor.actor_id) if _promises != null else 0
	var promise_variation: int = _promises.offer_priority_variation(actor.actor_id, _run_state.current_round) if _promises != null else 0
	var urgency: int = _run_state.current_round * 5
	var strategic_value: int = profile.negotiation_aggression / 2 if profile != null else 20
	var score: int = personal_need + card_interest + risk_avoidance + goal_bonus + relationship_modifier + reputation_modifier + memory_modifier + promise_variation + urgency + strategic_value
	return {
		"score": score,
		"reason": "need=%d interest=%d avoid=%d goal=%d relation=%d reputation=%d memory=%d promise_rng=%d urgency=%d strategic=%d"
		% [personal_need, card_interest, risk_avoidance, goal_bonus, relationship_modifier, reputation_modifier, memory_modifier, promise_variation, urgency, strategic_value],
	}

func _choose_offer_type(actor: ActorState) -> int:
	var choices: Array[int] = []
	var state: NpcRunState = state_for(actor.actor_id)
	if state != null:
		match state.secret_goal_id:
			&"mara_no_sealed", &"mara_avoid_disaster":
				return GameConstants.OfferType.KEEP_SEALED
			&"rowan_bid_total", &"rowan_win_auctions":
				return GameConstants.OfferType.SKIP_AUCTION
			&"rowan_open_risk":
				if _first_tradeable_player_card(_actor_by_id(GameConstants.PLAYER_ID), actor) != null:
					return GameConstants.OfferType.BUY_CARD
			&"sarah_trade_twice":
				if _first_tradeable_player_card(_actor_by_id(GameConstants.PLAYER_ID), actor) != null:
					return GameConstants.OfferType.BUY_CARD
			&"sarah_gain_clues":
				if not _shareable_clue_id(actor.actor_id).is_empty():
					return GameConstants.OfferType.SHARE_INFORMATION
	match actor.character_id:
		GameConstants.CHARACTER_MARA:
			choices = [
				GameConstants.OfferType.KEEP_SEALED,
				GameConstants.OfferType.HOLD_CARD,
				GameConstants.OfferType.TRANSFER_CARD,
			]
		GameConstants.CHARACTER_ROWAN:
			choices = [
				GameConstants.OfferType.SKIP_AUCTION,
				GameConstants.OfferType.MUTUAL_PASS,
				GameConstants.OfferType.BUY_CARD,
				GameConstants.OfferType.TRANSFER_CARD,
			]
		GameConstants.CHARACTER_SARAH:
			choices = [
				GameConstants.OfferType.SHARE_INFORMATION,
				GameConstants.OfferType.HOLD_CARD,
				GameConstants.OfferType.MUTUAL_PASS,
				GameConstants.OfferType.BUY_CARD,
			]
		_:
			choices = [GameConstants.OfferType.SKIP_AUCTION]
	return choices[_rng.choose_index(choices.size())]

func _secret_goal_bonus(
	actor: ActorState,
	state: NpcRunState,
	knowledge: KnowledgeState
) -> int:
	if state == null or state.secret_goal_id.is_empty():
		return 0
	var goal: Dictionary = _content.goal(state.secret_goal_id)
	var target: int = maxi(1, int(goal.get("target", 1)))
	var remaining: int = maxi(0, target - state.goal_progress)
	var bonus: int = 20 + mini(60, remaining * 20)
	var estimated_risk: int = knowledge.estimated_risk_cost() if knowledge != null else 180
	match state.secret_goal_id:
		&"mara_no_sealed", &"mara_avoid_disaster":
			bonus += estimated_risk / 8
		&"mara_keep_hp":
			bonus += 50 if actor.hp <= 2 else 10
		&"rowan_bid_total", &"rowan_win_auctions":
			bonus += 35 if actor.gold >= 300 else 0
		&"rowan_open_risk":
			bonus += estimated_risk / 6
		&"sarah_trade_twice", &"sarah_gain_clues", &"sarah_reveal_cards":
			bonus += 25
	return bonus

func _offer_gold(actor: ActorState, profile: NpcCharacterProfile, offer_type: int) -> int:
	if offer_type == GameConstants.OfferType.SHARE_INFORMATION:
		return 0
	var state: NpcRunState = state_for(actor.actor_id)
	var relation: int = state.relationship_score if state != null else 0
	var reputation: int = _promises.reputation_for(actor.actor_id) if _promises != null else 0
	var amount: int = 100 + profile.negotiation_aggression + relation * 25 + reputation * 25 + _rng.randi_range(-25, 50)
	amount = maxi(GameConstants.COUNTER_INCREMENT, int(round(float(amount) / 50.0)) * 50)
	return mini(actor.gold, amount)

func _requested_action_for(offer_type: int) -> int:
	match offer_type:
		GameConstants.OfferType.BUY_CARD:
			return GameConstants.RequestedAction.SELL_CARD
		GameConstants.OfferType.KEEP_SEALED:
			return GameConstants.RequestedAction.DO_NOT_OPEN
		GameConstants.OfferType.SHARE_INFORMATION, GameConstants.OfferType.SKIP_AUCTION:
			return GameConstants.RequestedAction.PASS_CURRENT_AUCTION
		GameConstants.OfferType.HOLD_CARD:
			return GameConstants.RequestedAction.KEEP_CARD
		GameConstants.OfferType.TRANSFER_CARD:
			return GameConstants.RequestedAction.SELL_CARD
		GameConstants.OfferType.MUTUAL_PASS:
			return GameConstants.RequestedAction.PASS_CURRENT_AUCTION
		_:
			return GameConstants.RequestedAction.REVEAL_CLUE

func _dialogue_category_for(offer_type: int) -> StringName:
	match offer_type:
		GameConstants.OfferType.BUY_CARD:
			return &"buy_card"
		GameConstants.OfferType.KEEP_SEALED:
			return &"keep_sealed"
		GameConstants.OfferType.SHARE_INFORMATION:
			return &"share_information"
		GameConstants.OfferType.SKIP_AUCTION:
			return &"skip_auction"
		GameConstants.OfferType.HOLD_CARD:
			return &"hold_card"
		GameConstants.OfferType.TRANSFER_CARD:
			return &"transfer_card"
		GameConstants.OfferType.MUTUAL_PASS:
			return &"mutual_pass"
		_:
			return &"negotiation_start"

func _tell_trigger_for(state: NpcRunState) -> StringName:
	if state != null and state.emotion in [GameConstants.Emotion.AFRAID, GameConstants.Emotion.NERVOUS]:
		return &"fear"
	if state != null and state.emotion in [GameConstants.Emotion.INTERESTED, GameConstants.Emotion.SMUG]:
		return &"interest"
	return &"negotiation"

func _select_tell(profile: NpcCharacterProfile, trigger: StringName) -> Dictionary:
	var tells: Array[Dictionary] = _content.tells_for(profile, trigger)
	if tells.is_empty():
		tells = _content.tells_for(profile, &"")
	if tells.is_empty():
		return {}
	var total_weight: int = 0
	for tell: Dictionary in tells:
		total_weight += maxi(1, int(tell.get("weight", 1)))
	var roll: int = _rng.randi_range(1, total_weight)
	var selected: Dictionary = tells[0]
	for tell: Dictionary in tells:
		roll -= maxi(1, int(tell.get("weight", 1)))
		if roll <= 0:
			selected = tell
			break
	if _rng.randf() > float(selected.get("reliability", 0.5)):
		return {}
	return selected

func _apply_offer(offer: NegotiationOffer) -> bool:
	var issuer: ActorState = _actor_by_id(offer.issuer_id)
	var player: ActorState = _actor_by_id(GameConstants.PLAYER_ID)
	if issuer == null or player == null or issuer.gold < offer.offered_gold:
		return false
	if offer.creates_promise:
		var promise: PromiseState = _promises.create_from_offer(offer) if _promises != null else null
		if promise == null:
			return false
		_run_state.temporary_negotiation_warning = "활성 약속: %s" % PromiseManager.promise_type_name(promise.promise_type)
		return true
	match offer.offer_type:
		GameConstants.OfferType.BUY_CARD:
			var instance: CardInstance = player.instance_by_id(offer.target_card_instance_id)
			if instance == null or (instance.sealed and not issuer.has_inventory_space_for_sealed()):
				return false
			if not _effects.transfer_instance(instance, player, issuer, _actors):
				return false
			_pay_player(issuer, player, offer.offered_gold)
		GameConstants.OfferType.KEEP_SEALED:
			_pay_player(issuer, player, offer.offered_gold)
			_run_state.temporary_negotiation_warning = "이번 라운드 동안 봉인을 열지 말라는 요청을 수락했습니다."
		GameConstants.OfferType.SHARE_INFORMATION:
			var issuer_knowledge: KnowledgeState = _knowledge_states.get(issuer.actor_id) as KnowledgeState
			var player_knowledge: KnowledgeState = _knowledge_states.get(player.actor_id) as KnowledgeState
			if not _information.share_known_clue(issuer_knowledge, player_knowledge, offer.offered_clue_id):
				return false
			_run_state.player_forced_pass = true
		GameConstants.OfferType.SKIP_AUCTION:
			_pay_player(issuer, player, offer.offered_gold)
			_run_state.player_forced_pass = true
		GameConstants.OfferType.HOLD_CARD:
			_pay_player(issuer, player, offer.offered_gold)
			_run_state.temporary_negotiation_warning = "카드를 보관해 달라는 요청을 수락했습니다."
	return true

func _configure_promise_offer(
	offer: NegotiationOffer,
	issuer: ActorState,
	allow_future_skip: bool
) -> void:
	if offer.offer_type == GameConstants.OfferType.BUY_CARD:
		return
	offer.creates_promise = true
	offer.promise_target_lot_id = _run_state.current_lot_id
	offer.promise_reputation_reward = 1
	offer.promise_reputation_penalty = 2
	offer.promise_penalty_gold = 50
	offer.promise_target_round = _run_state.current_round
	offer.promise_obligor_ids = [GameConstants.PLAYER_ID]
	match offer.offer_type:
		GameConstants.OfferType.SKIP_AUCTION:
			offer.promise_type = GameConstants.PROMISE_SKIP_AUCTION
			if allow_future_skip and _rng.randf() <= 0.25:
				offer.promise_target_round += 1
			offer.promise_reward_gold = _reserved_reward_gold(issuer, offer.offered_gold, 100)
		GameConstants.OfferType.KEEP_SEALED:
			offer.promise_type = GameConstants.PROMISE_KEEP_CARD_SEALED
			offer.promise_target_round += 1
			offer.promise_target_card_instance_id = offer.target_card_instance_id
			offer.promise_reward_gold = _reserved_reward_gold(issuer, offer.offered_gold, 100)
		GameConstants.OfferType.HOLD_CARD:
			offer.promise_type = GameConstants.PROMISE_HOLD_CARD
			offer.promise_target_round += 1
			offer.promise_target_card_instance_id = offer.target_card_instance_id
			offer.promise_reward_gold = _reserved_reward_gold(issuer, offer.offered_gold, 100)
		GameConstants.OfferType.TRANSFER_CARD:
			offer.promise_type = GameConstants.PROMISE_TRANSFER_CARD
			offer.promise_target_round += 1
			offer.promise_target_actor_id = issuer.actor_id
			offer.promise_target_card_instance_id = offer.target_card_instance_id
			offer.promise_reward_gold = _reserved_reward_gold(issuer, offer.offered_gold, 150)
			offer.promise_penalty_gold = 100
		GameConstants.OfferType.SHARE_INFORMATION:
			offer.promise_type = GameConstants.PROMISE_SHARE_INFORMATION
			offer.promise_target_round += 1
			offer.promise_obligor_ids = [issuer.actor_id]
			offer.promise_reward_clue_id = offer.offered_clue_id
			offer.promise_penalty_gold = 0
		GameConstants.OfferType.MUTUAL_PASS:
			offer.promise_type = GameConstants.PROMISE_MUTUAL_PASS
			offer.promise_obligor_ids = [GameConstants.PLAYER_ID, issuer.actor_id]
			offer.promise_reward_gold = _reserved_reward_gold(issuer, offer.offered_gold, 100)
		_:
			offer.creates_promise = false

func _reserved_reward_gold(issuer: ActorState, immediate_gold: int, desired: int) -> int:
	return mini(desired, maxi(0, issuer.gold - immediate_gold))

func _pay_player(issuer: ActorState, player: ActorState, amount: int) -> void:
	if amount <= 0:
		return
	issuer.gold -= amount
	player.gold += amount
	_events.gold_changed.emit(issuer.actor_id, -amount, issuer.gold, &"")
	_events.gold_changed.emit(player.actor_id, amount, player.gold, &"")

func _advance_offer() -> void:
	_run_state.current_offer_index += 1
	if _run_state.current_offer_index >= _run_state.negotiation_offers.size():
		_finish_negotiation()
	_events.state_updated.emit()

func _finish_negotiation() -> void:
	if _run_state.negotiation_complete:
		return
	_run_state.negotiation_complete = true
	_events.negotiation_finished.emit(_run_state.current_round)
	_events.state_updated.emit()

func _change_relationship(actor_id: StringName, delta: int) -> void:
	var state: NpcRunState = state_for(actor_id)
	if state == null:
		return
	_events.relationship_changed.emit(actor_id, state.change_relationship(delta))

func _refresh_emotion(actor: ActorState) -> void:
	var state: NpcRunState = state_for(actor.actor_id)
	var knowledge: KnowledgeState = _knowledge_states.get(actor.actor_id) as KnowledgeState
	var risk: int = knowledge.estimated_risk_cost() if knowledge != null else 180
	var reward: int = knowledge.estimated_reward() if knowledge != null else 240
	var emotion: int = GameConstants.Emotion.CALM
	if actor.character_id == GameConstants.CHARACTER_MARA and actor.hp <= 1:
		emotion = GameConstants.Emotion.AFRAID
	elif actor.character_id == GameConstants.CHARACTER_ROWAN and reward + risk >= 500:
		emotion = GameConstants.Emotion.SMUG if actor.hp >= 2 else GameConstants.Emotion.INTERESTED
	elif state != null and state.relationship_score <= -2:
		emotion = GameConstants.Emotion.ANGRY
	elif risk > reward:
		emotion = GameConstants.Emotion.NERVOUS
	else:
		emotion = GameConstants.Emotion.INTERESTED
	_set_emotion(actor.actor_id, emotion)

func _set_emotion(actor_id: StringName, emotion: int) -> void:
	var state: NpcRunState = state_for(actor_id)
	if state == null or state.emotion == emotion:
		return
	state.emotion = emotion
	_events.emotion_changed.emit(actor_id, emotion)

func _update_goal_progress(actor_id: StringName) -> void:
	var actor: ActorState = _actor_by_id(actor_id)
	var state: NpcRunState = state_for(actor_id)
	var goal: Dictionary = goal_for(actor_id)
	if actor == null or state == null or goal.is_empty():
		return
	var metric: StringName = StringName(str(goal.get("metric", "")))
	var progress: int = 0
	match metric:
		&"sealed_zero":
			progress = 1 if actor.sealed_card_count() == 0 else 0
		&"minimum_hp":
			progress = actor.hp
		&"avoid_disaster":
			progress = 1 if int(state.metrics.get("high_risk_opened", 0)) == 0 else 0
		_:
			progress = int(state.metrics.get(metric, 0))
	state.goal_progress = progress
	_events.secret_goal_progressed.emit(actor_id, state.secret_goal_id, progress)

func _first_tradeable_player_card(player: ActorState, issuer: ActorState) -> CardInstance:
	if player == null or issuer == null:
		return null
	for instance: CardInstance in player.inventory:
		if not instance.is_available() or not instance.transferable_snapshot:
			continue
		if instance.sealed and not issuer.has_inventory_space_for_sealed():
			continue
		return instance
	return null

func _first_promisable_player_card(
	player: ActorState,
	issuer: ActorState,
	offer_type: int
) -> CardInstance:
	if player == null or issuer == null:
		return null
	if offer_type in [GameConstants.OfferType.BUY_CARD, GameConstants.OfferType.TRANSFER_CARD]:
		return _first_tradeable_player_card(player, issuer)
	if offer_type not in [GameConstants.OfferType.KEEP_SEALED, GameConstants.OfferType.HOLD_CARD]:
		return null
	for instance: CardInstance in player.inventory:
		if not instance.is_available():
			continue
		if offer_type == GameConstants.OfferType.KEEP_SEALED and not instance.sealed:
			continue
		return instance
	return null

func _shareable_clue_id(issuer_id: StringName) -> StringName:
	var source: KnowledgeState = _knowledge_states.get(issuer_id) as KnowledgeState
	var player: KnowledgeState = _knowledge_states.get(GameConstants.PLAYER_ID) as KnowledgeState
	return _first_unique_clue(source, player)

func _first_unique_clue(source: KnowledgeState, target: KnowledgeState) -> StringName:
	if source == null or target == null:
		return &""
	for clue_id: StringName in source.known_clue_ids:
		if not target.knows(clue_id):
			return clue_id
	return &""

func _actor_by_id(actor_id: StringName) -> ActorState:
	for actor: ActorState in _actors:
		if actor.actor_id == actor_id:
			return actor
	return null
