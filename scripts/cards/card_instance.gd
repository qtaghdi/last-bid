class_name CardInstance
extends Resource

@export var instance_id: StringName = &""
@export var definition_id: StringName = &""
@export var owner_id: StringName = &""
@export var remaining_turns: int = 0
@export var consumed: bool = false

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
	instance.acquired_round = round_number
	for index: int in range(definition.effects.size()):
		var effect: CardEffectDefinition = definition.effects[index]
		if effect.effect_type == GameConstants.EffectType.DELAY_EFFECT:
			instance.delay_counters[index] = effect.delay_rounds
			instance.remaining_turns = maxi(instance.remaining_turns, effect.delay_rounds)
	return instance
