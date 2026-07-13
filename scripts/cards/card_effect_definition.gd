class_name CardEffectDefinition
extends Resource

@export var trigger: int = GameConstants.EffectTrigger.ON_ACQUIRE
@export var effect_type: int = GameConstants.EffectType.MODIFY_HP
@export var target_selector: int = GameConstants.EffectType.SELECT_OWNER
@export var amount: int = 0
@export var delay_rounds: int = 0
@export var nested_effect_type: int = -1
@export var global_rule: StringName = &""
@export var duration_rounds: int = 0
@export var overflow_hp_per_gold: int = 0
@export var consume_after_trigger: bool = false
@export var requires_open: bool = false
@export var description: String = ""
