class_name PostAuctionSystem
extends RefCounted

var active_instance: CardInstance
var last_result_message: String = ""
var last_accident_message: String = ""
var last_npc_decision: Dictionary = {}

var _run_state: RunState
var _events: EventBus
var _rng: CentralRng
var _effects: CardEffectSystem
var _npc_ai: SimpleNpcAi
var _information: InformationService
var _promise_manager: PromiseManager
var _resolved: bool = true

func setup(
	run_state: RunState,
	events: EventBus,
	rng: CentralRng,
	effects: CardEffectSystem,
	npc_ai: SimpleNpcAi,
	information: InformationService,
	promise_manager: PromiseManager = null
) -> void:
	_run_state = run_state
	_events = events
	_rng = rng
	_effects = effects
	_npc_ai = npc_ai
	_information = information
	_promise_manager = promise_manager
	reset()

func reset() -> void:
	active_instance = null
	last_result_message = ""
	last_accident_message = ""
	last_npc_decision = {}
	_resolved = true

func begin(
	instance: CardInstance,
	actors: Array[ActorState],
	knowledge_states: Dictionary
) -> void:
	active_instance = instance
	last_result_message = "낙찰된 카드가 없습니다."
	last_accident_message = ""
	last_npc_decision = {}
	_resolved = instance == null
	if instance == null:
		return
	instance.post_auction_resolved = false
	_events.post_auction_started.emit(instance.instance_id, instance.owner_id)
	var owner: ActorState = _actor_by_id(instance.owner_id, actors)
	if owner == null:
		_resolved = true
		return
	last_result_message = "%s의 낙찰 후 처리를 기다리는 중입니다." % owner.display_name
	if owner.actor_type == GameConstants.ActorType.NPC:
		_resolve_npc(owner, actors, knowledge_states)

func can_advance() -> bool:
	return _resolved or active_instance == null

func current_definition() -> CardDefinition:
	if active_instance == null:
		return null
	return CardCatalog.by_id(active_instance.definition_id)

func next_seal_number() -> int:
	if active_instance == null:
		return 0
	return mini(GameConstants.MAX_SEALS, active_instance.opened_seals + 1)

func next_accident_percent() -> int:
	var definition: CardDefinition = current_definition()
	if definition == null or active_instance == null or not active_instance.sealed:
		return 0
	return accident_percent(definition.risk_tier, next_seal_number())

func can_open(actor_id: StringName) -> bool:
	return (
		_active_owned_by(actor_id)
		and active_instance.sealed
		and active_instance.opened_seals < GameConstants.MAX_SEALS
		and not _resolved
	)

func open_next_seal(
	actor_id: StringName,
	actors: Array[ActorState],
	knowledge_states: Dictionary
) -> bool:
	if not can_open(actor_id):
		return false
	var owner: ActorState = _actor_by_id(actor_id, actors)
	var definition: CardDefinition = current_definition()
	if owner == null or definition == null or not owner.alive:
		return false
	var seal_number: int = active_instance.opened_seals + 1
	var chance: int = accident_percent(definition.risk_tier, seal_number)
	_events.seal_open_requested.emit(active_instance.instance_id, seal_number)
	var roll: int = _rng.randi_range(1, 100) if chance > 0 else 100
	var accident: bool = chance > 0 and roll <= chance
	_events.log_debug(
		"봉인 사고 판정: %s seal=%d chance=%d%% roll=%d result=%s"
		% [definition.actual_name, seal_number, chance, roll, "ACCIDENT" if accident else "SAFE"]
	)
	last_accident_message = ""
	if accident:
		last_accident_message = "봉인 사고 발생 · %s" % _accident_description(definition)
		_events.seal_accident_triggered.emit(
			active_instance.instance_id,
			seal_number,
			last_accident_message
		)
		if definition.seal_accident_effect != null:
			_effects.process_auxiliary_effect(
				active_instance,
				definition,
				definition.seal_accident_effect,
				owner,
				actors
			)
		if not owner.alive:
			last_result_message = "%s · 개봉자가 사망했습니다." % last_accident_message
			_complete("ACCIDENT")
			return true
	var reveal_text: String = active_instance.reveal_next_seal(definition)
	var knowledge: KnowledgeState = knowledge_states.get(actor_id) as KnowledgeState
	if knowledge != null:
		knowledge.reveal_level = maxi(knowledge.reveal_level, active_instance.reveal_level)
		if active_instance.reveal_level == GameConstants.RevealLevel.FULLY_REVEALED:
			knowledge.reveal_fully()
		_events.knowledge_changed.emit(actor_id, knowledge.card_instance_id)
	_events.seal_opened.emit(active_instance.instance_id, seal_number, reveal_text)
	last_result_message = "봉인 %d 개봉 · %s" % [seal_number, reveal_text]
	if not last_accident_message.is_empty():
		last_result_message += "\n%s" % last_accident_message
	if not active_instance.sealed:
		_effects.open_card(active_instance, owner, actors)
		_events.card_opened.emit(active_instance.instance_id, owner.actor_id)
		last_result_message += "\n완전 공개 · ON_OPEN 효과 처리"
		if not active_instance.is_available():
			_complete("OPEN")
			return true
	_events.state_updated.emit()
	return true

func can_keep(actor_id: StringName, actors: Array[ActorState]) -> bool:
	if not _active_owned_by(actor_id) or _resolved:
		return false
	var owner: ActorState = _actor_by_id(actor_id, actors)
	if owner == null:
		return false
	return not active_instance.sealed or owner.sealed_card_count() <= GameConstants.MAX_SEALED_CARDS

func keep(actor_id: StringName, actors: Array[ActorState]) -> bool:
	if not _active_owned_by(actor_id) or _resolved:
		return false
	var owner: ActorState = _actor_by_id(actor_id, actors)
	if owner == null or not owner.alive:
		return false
	if active_instance.sealed and owner.sealed_card_count() > GameConstants.MAX_SEALED_CARDS:
		_events.inventory_limit_reached.emit(owner.actor_id)
		last_result_message = "봉인 카드 한도 3장을 초과해 보관할 수 없습니다."
		return false
	_events.card_kept.emit(active_instance.instance_id, owner.actor_id)
	last_result_message = "%s이(가) 카드를 현재 상태로 보관했습니다." % owner.display_name
	_complete("KEEP")
	return true

func can_burn(actor_id: StringName, actors: Array[ActorState]) -> bool:
	if not _active_owned_by(actor_id) or _resolved:
		return false
	var owner: ActorState = _actor_by_id(actor_id, actors)
	var definition: CardDefinition = current_definition()
	return owner != null and definition != null and definition.burnable and owner.gold >= definition.burn_cost

func burn(actor_id: StringName, actors: Array[ActorState]) -> bool:
	if not can_burn(actor_id, actors):
		return false
	var owner: ActorState = _actor_by_id(actor_id, actors)
	var definition: CardDefinition = current_definition()
	if not _effects.burn_instance(active_instance, owner, actors):
		return false
	last_result_message = "%s 소각 완료 · 비용 %d G" % [definition.public_name, definition.burn_cost]
	_complete("BURN")
	return true

func can_sell(actor_id: StringName, actors: Array[ActorState]) -> bool:
	if (
		not _active_owned_by(actor_id)
		or actor_id != GameConstants.PLAYER_ID
		or _resolved
		or active_instance.sale_attempted
	):
		return false
	var definition: CardDefinition = current_definition()
	if definition == null or not definition.transferable:
		return false
	return not available_sale_targets(actors).is_empty()

func available_sale_targets(actors: Array[ActorState]) -> Array[ActorState]:
	var targets: Array[ActorState] = []
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC or not actor.alive:
			continue
		if active_instance != null and active_instance.sealed and not actor.has_inventory_space_for_sealed():
			continue
		targets.append(actor)
	return targets

func propose_sale(
	seller_id: StringName,
	buyer_id: StringName,
	price: int,
	disclosed_clue_id: StringName,
	actors: Array[ActorState],
	knowledge_states: Dictionary
) -> bool:
	if not can_sell(seller_id, actors) or price < 0:
		return false
	var seller: ActorState = _actor_by_id(seller_id, actors)
	var buyer: ActorState = _actor_by_id(buyer_id, actors)
	if seller == null or buyer == null or buyer.actor_type != GameConstants.ActorType.NPC:
		return false
	if not buyer.alive or buyer.gold < price:
		return false
	if active_instance.sealed and not buyer.has_inventory_space_for_sealed():
		return false
	active_instance.sale_attempted = true
	_events.sale_proposed.emit(active_instance.instance_id, buyer.actor_id, price)
	var seller_knowledge: KnowledgeState = knowledge_states.get(seller.actor_id) as KnowledgeState
	var buyer_knowledge: KnowledgeState = knowledge_states.get(buyer.actor_id) as KnowledgeState
	if not disclosed_clue_id.is_empty():
		_information.share_known_clue(seller_knowledge, buyer_knowledge, disclosed_clue_id)
	var evaluation: Dictionary = _npc_ai.evaluate_purchase(
		buyer,
		buyer_knowledge,
		_inventory_tags(buyer),
		actors,
		_run_state.current_round,
		price
	)
	if int(evaluation.get("purchase_value", -1)) < 0:
		_events.sale_rejected.emit(active_instance.instance_id, buyer.actor_id, price)
		last_result_message = "%s이(가) %d G 판매 제안을 거절했습니다." % [buyer.display_name, price]
		_events.state_updated.emit()
		return false
	buyer.gold -= price
	seller.gold += price
	var source_id: StringName = active_instance.definition_id
	_events.gold_changed.emit(buyer.actor_id, -price, buyer.gold, source_id)
	_events.gold_changed.emit(seller.actor_id, price, seller.gold, source_id)
	if not _effects.transfer_instance(active_instance, seller, buyer, actors):
		buyer.gold += price
		seller.gold -= price
		return false
	_events.sale_accepted.emit(active_instance.instance_id, buyer.actor_id, price)
	last_result_message = "%s에게 %d G로 판매했습니다." % [buyer.display_name, price]
	_complete("SELL")
	return true

func action_block_reason(actor_id: StringName, actors: Array[ActorState]) -> String:
	if active_instance == null:
		return "처리할 낙찰 카드가 없습니다."
	if _resolved:
		return "낙찰 후 처리가 완료되었습니다."
	if active_instance.owner_id != actor_id:
		return "NPC가 자동으로 낙찰 후 처리를 진행합니다."
	var owner: ActorState = _actor_by_id(actor_id, actors)
	var definition: CardDefinition = current_definition()
	if owner != null and active_instance.sealed and owner.sealed_card_count() > GameConstants.MAX_SEALED_CARDS:
		return "봉인 카드 한도를 초과했습니다. 개봉·판매·소각 중 하나를 선택하세요."
	if definition != null and definition.burnable and owner != null and owner.gold < definition.burn_cost:
		return "소각 비용이 부족할 수 있습니다."
	return "봉인을 더 열거나 현재 상태로 처리할 방법을 선택하세요."

static func accident_percent(risk_tier: StringName, seal_number: int) -> int:
	var index: int = clampi(seal_number - 1, 0, GameConstants.MAX_SEALS - 1)
	match risk_tier:
		&"low":
			return [0, 5, 10][index]
		&"medium":
			return [0, 10, 20][index]
		&"high":
			return [5, 20, 35][index]
		_:
			return [0, 10, 20][index]

func _resolve_npc(
	owner: ActorState,
	actors: Array[ActorState],
	knowledge_states: Dictionary
) -> void:
	var knowledge: KnowledgeState = knowledge_states.get(owner.actor_id) as KnowledgeState
	if (
		_promise_manager != null
		and _promise_manager.npc_should_preserve_card(owner.actor_id, active_instance.instance_id)
	):
		last_npc_decision = {
			"action": GameConstants.PostAuctionAction.KEEP,
			"reason": "활성 약속 이행",
		}
		keep(owner.actor_id, actors)
		return
	last_npc_decision = _npc_ai.choose_post_auction_action(
		owner,
		knowledge,
		owner.sealed_card_count() <= GameConstants.MAX_SEALED_CARDS,
		_run_state.current_round
	)
	var action: int = int(last_npc_decision.get("action", GameConstants.PostAuctionAction.KEEP))
	if action == GameConstants.PostAuctionAction.OPEN:
		var seals_to_open: int = int(last_npc_decision.get("seals_to_open", 1))
		for _seal: int in range(seals_to_open):
			if not owner.alive or not can_open(owner.actor_id):
				break
			open_next_seal(owner.actor_id, actors, knowledge_states)
		if not owner.alive:
			return
		if keep(owner.actor_id, actors):
			return
		while can_open(owner.actor_id):
			open_next_seal(owner.actor_id, actors, knowledge_states)
		keep(owner.actor_id, actors)
		return
	if action == GameConstants.PostAuctionAction.BURN and burn(owner.actor_id, actors):
		return
	if keep(owner.actor_id, actors):
		return
	while can_open(owner.actor_id):
		open_next_seal(owner.actor_id, actors, knowledge_states)
	if owner.alive:
		keep(owner.actor_id, actors)

func _complete(action: StringName) -> void:
	_resolved = true
	if active_instance != null:
		active_instance.post_auction_resolved = true
		_events.post_auction_completed.emit(active_instance.instance_id, action)
	_events.state_updated.emit()

func _active_owned_by(actor_id: StringName) -> bool:
	return active_instance != null and active_instance.owner_id == actor_id and active_instance.is_available()

func _actor_by_id(actor_id: StringName, actors: Array[ActorState]) -> ActorState:
	for actor: ActorState in actors:
		if actor.actor_id == actor_id:
			return actor
	return null

func _inventory_tags(actor: ActorState) -> PackedStringArray:
	var result: PackedStringArray = []
	for instance: CardInstance in actor.inventory:
		if not instance.is_available():
			continue
		var definition: CardDefinition = CardCatalog.by_id(instance.definition_id)
		if definition == null:
			continue
		for tag: String in definition.tags:
			if not result.has(tag):
				result.append(tag)
	return result

func _accident_description(definition: CardDefinition) -> String:
	if definition.seal_accident_effect == null:
		return "부작용 없음"
	return definition.seal_accident_effect.description
