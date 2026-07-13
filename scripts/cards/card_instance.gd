class_name CardInstance
extends Resource

@export var instance_id: StringName = &""
@export var definition_id: StringName = &""
@export var owner_id: StringName = &""
@export var original_owner_id: StringName = &""
@export var effect_owner_id: StringName = &""
@export var reveal_level: int = GameConstants.RevealLevel.UNKNOWN
@export var opened_seals: int = 0
@export var remaining_turns: int = 0
@export var sealed: bool = true
@export var consumed: bool = false
@export var destroyed: bool = false
@export var acquisition_round: int = 0
@export var pending_effects: Dictionary = {}
@export var transfer_history: Array[Dictionary] = []
@export var revealed_seal_texts: PackedStringArray = []
@export var post_auction_resolved: bool = false
@export var sale_attempted: bool = false

var acquired_round: int = 0
var delay_counters: Dictionary = {}
var resolved_effects: Dictionary = {}

static func create(
	definition: CardDefinition,
	owner: StringName,
	round_number: int,
	serial: int
) -> CardInstance:
	var instance: CardInstance = CardInstance.new()
	instance.instance_id = StringName("%s_%d_%d" % [definition.id, round_number, serial])
	instance.definition_id = definition.id
	instance.owner_id = owner
	instance.original_owner_id = owner
	instance.effect_owner_id = owner
	instance.reveal_level = GameConstants.RevealLevel.UNKNOWN
	instance.opened_seals = 0
	instance.sealed = true
	instance.acquisition_round = round_number
	instance.acquired_round = round_number
	for index: int in range(definition.effects.size()):
		var effect: CardEffectDefinition = definition.effects[index]
		if effect.effect_type == GameConstants.EffectType.DELAY_EFFECT and not effect.requires_open:
			instance.delay_counters[index] = effect.delay_rounds
			instance.pending_effects[index] = true
			instance.remaining_turns = maxi(instance.remaining_turns, effect.delay_rounds)
	return instance

func is_available() -> bool:
	return not consumed and not destroyed

func record_transfer(from_id: StringName, to_id: StringName, round_number: int) -> void:
	transfer_history.append({
		"from": from_id,
		"to": to_id,
		"round": round_number,
	})
	owner_id = to_id

func reveal_next_seal(definition: CardDefinition) -> String:
	if opened_seals >= GameConstants.MAX_SEALS:
		return ""
	opened_seals += 1
	var reveal_text: String = ""
	if opened_seals <= definition.seal_reveal_texts.size():
		reveal_text = definition.seal_reveal_texts[opened_seals - 1]
	if not reveal_text.is_empty():
		revealed_seal_texts.append(reveal_text)
	if opened_seals >= GameConstants.MAX_SEALS:
		sealed = false
		reveal_level = GameConstants.RevealLevel.FULLY_REVEALED
	elif opened_seals >= 2:
		reveal_level = GameConstants.RevealLevel.INVESTIGATED
	else:
		reveal_level = GameConstants.RevealLevel.BASIC_CLUES
	return reveal_text
