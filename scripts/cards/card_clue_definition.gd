class_name CardClueDefinition
extends Resource

@export var clue_id: StringName = &""
@export var clue_type: StringName = &"trait"
@export var display_text: String = ""
@export var related_tags: PackedStringArray = []
@export var estimated_reward: int = 300
@export var estimated_risk_cost: int = 100

func to_belief(is_hidden: bool) -> Dictionary:
	return {
		"clue_id": clue_id,
		"clue_type": clue_type,
		"display_text": display_text,
		"related_tags": related_tags.duplicate(),
		"estimated_reward": estimated_reward,
		"estimated_risk_cost": estimated_risk_cost,
		"is_hidden": is_hidden,
	}
