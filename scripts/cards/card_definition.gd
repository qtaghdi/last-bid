class_name CardDefinition
extends Resource

@export var id: StringName = &""
@export var actual_name: String = ""
@export_multiline var description: String = ""
@export var public_name: String = "미확인 출품물"
@export var category: StringName = &""
@export var risk_tier: StringName = &"unknown"
@export var risk_range: String = "미확인"
@export var value_tier: StringName = &"unknown"
@export var value_range: String = "미확인"
@export var trigger_timing: String = "미확인"
@export var target_type: String = "미확인"
@export var tags: PackedStringArray = []
@export var public_clues: Array[CardClueDefinition] = []
@export var hidden_clues: Array[CardClueDefinition] = []
@export var starting_bid: int = 0
@export var effects: Array[CardEffectDefinition] = []
@export var seal_reveal_texts: PackedStringArray = []
@export var seal_accident_effect: CardEffectDefinition
@export var effects_while_sealed: bool = false
@export var transferable: bool = true
@export var transfer_policy: int = GameConstants.TransferPolicy.FOLLOW_CURRENT_OWNER
@export var burnable: bool = true
@export var burn_cost: int = 100
@export var burn_effects: Array[CardEffectDefinition] = []
