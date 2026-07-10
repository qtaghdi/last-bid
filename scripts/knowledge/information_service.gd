class_name InformationService
extends RefCounted

var _rng: CentralRng
var _events: EventBus

func setup(rng: CentralRng, events: EventBus) -> void:
	_rng = rng
	_events = events

func distribute(
	card: CardDefinition,
	lot_id: StringName,
	actors: Array[ActorState]
) -> Dictionary:
	var states: Dictionary = {}
	for actor: ActorState in actors:
		var state: KnowledgeState = KnowledgeState.create(actor.actor_id, lot_id)
		states[actor.actor_id] = state
		var base_count: int = 2 if actor.actor_type == GameConstants.ActorType.PLAYER else 1
		_learn_random_clues(state, card.public_clues, base_count, false, 0.72, 0.92)
		if actor.actor_type == GameConstants.ActorType.NPC:
			_try_award_archetype_clue(state, card, actor.archetype)
		_events.knowledge_changed.emit(actor.actor_id, lot_id)
	return states

func investigate(state: KnowledgeState, card: CardDefinition) -> CardClueDefinition:
	var candidates: Array[CardClueDefinition] = []
	for clue: CardClueDefinition in card.hidden_clues:
		if not state.knows(clue.clue_id):
			candidates.append(clue)
	if candidates.is_empty():
		return null
	var selected: CardClueDefinition = candidates[_rng.choose_index(candidates.size())]
	state.learn_clue(selected, 1.0, true)
	_events.knowledge_changed.emit(state.actor_id, state.card_instance_id)
	return selected

func can_investigate(state: KnowledgeState, card: CardDefinition) -> bool:
	if state == null:
		return false
	for clue: CardClueDefinition in card.hidden_clues:
		if not state.knows(clue.clue_id):
			return true
	return false

func _learn_random_clues(
	state: KnowledgeState,
	clues: Array[CardClueDefinition],
	count: int,
	is_hidden: bool,
	minimum_confidence: float,
	maximum_confidence: float
) -> void:
	var candidates: Array[CardClueDefinition] = clues.duplicate()
	for _index: int in range(mini(count, candidates.size())):
		var selected_index: int = _rng.choose_index(candidates.size())
		var selected: CardClueDefinition = candidates.pop_at(selected_index)
		var confidence: float = lerpf(minimum_confidence, maximum_confidence, _rng.randf())
		state.learn_clue(selected, confidence, is_hidden)

func _try_award_archetype_clue(
	state: KnowledgeState,
	card: CardDefinition,
	archetype: StringName
) -> void:
	var preferred_tags: PackedStringArray = preferred_tags_for(archetype)
	if not _has_overlap(card.tags, preferred_tags) or _rng.randf() > 0.75:
		return
	var preferred: Array[CardClueDefinition] = []
	var fallback: Array[CardClueDefinition] = []
	for clue: CardClueDefinition in card.public_clues + card.hidden_clues:
		if state.knows(clue.clue_id):
			continue
		fallback.append(clue)
		if _has_overlap(clue.related_tags, preferred_tags):
			preferred.append(clue)
	var candidates: Array[CardClueDefinition] = preferred if not preferred.is_empty() else fallback
	if candidates.is_empty():
		return
	var selected: CardClueDefinition = candidates[_rng.choose_index(candidates.size())]
	state.learn_clue(selected, lerpf(0.68, 0.9, _rng.randf()), card.hidden_clues.has(selected))

static func preferred_tags_for(archetype: StringName) -> PackedStringArray:
	match archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			return PackedStringArray(["rare", "cursed", "ownership", "collection", "unique"])
		GameConstants.ARCHETYPE_CREDITOR:
			return PackedStringArray(["economy", "contract", "loan", "income", "debt"])
		GameConstants.ARCHETYPE_GAMBLER:
			return PackedStringArray(["high_risk", "high_reward", "disaster", "immediate", "gamble"])
		_:
			return PackedStringArray()

static func _has_overlap(first: PackedStringArray, second: PackedStringArray) -> bool:
	for value: String in first:
		if second.has(value):
			return true
	return false
