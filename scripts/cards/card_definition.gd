class_name CardDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var public_label: String = "미확인 출품물"
@export var public_role_group: String = "미확인"
@export var public_risk_range: String = "미확인"
@export var public_value_range: String = "미확인"
@export var public_trigger_timing: String = "미확인"
@export var public_target_type: String = "미확인"
@export var category: StringName = &""
@export var base_value: int = 0
@export var starting_bid: int = 0
@export var effects: Array[CardEffectDefinition] = []
