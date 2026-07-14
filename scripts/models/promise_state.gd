class_name PromiseState
extends Resource

@export var promise_id: StringName = &""
@export var issuer_id: StringName = &""
@export var receiver_id: StringName = &""
@export var promise_type: StringName = &""
@export var obligor_ids: Array[StringName] = []
@export var target_actor_id: StringName = &""
@export var target_card_instance_id: StringName = &""
@export var target_lot_id: StringName = &""
@export var target_display_name: String = ""
@export var created_round: int = 0
@export var target_round: int = 0
@export var expires_round: int = 0
@export var immediate_reward_gold: int = 0
@export var reward_gold: int = 0
@export var reward_clue_id: StringName = &""
@export var penalty_hp: int = 0
@export var penalty_gold: int = 0
@export var reputation_reward: int = 1
@export var reputation_penalty: int = 2
@export var conditions: Array[Dictionary] = []
@export var card_policy: StringName = GameConstants.PROMISE_BREAK_ON_DESTROY
@export var status: StringName = GameConstants.PROMISE_ACTIVE
@export var fulfilled_round: int = 0
@export var broken_round: int = 0
@export var fulfilled_by: StringName = &""
@export var broken_by: StringName = &""
@export var resolution_reason: String = ""
@export var immediate_reward_paid: bool = false
@export var reward_paid: bool = false
@export var penalty_applied: bool = false

func is_active() -> bool:
	return status == GameConstants.PROMISE_ACTIVE

func involves(actor_id: StringName) -> bool:
	return issuer_id == actor_id or receiver_id == actor_id or obligor_ids.has(actor_id)

func has_obligor(actor_id: StringName) -> bool:
	return obligor_ids.has(actor_id)

func condition_value(key: StringName, default_value: Variant = null) -> Variant:
	for condition: Dictionary in conditions:
		if StringName(str(condition.get("key", ""))) == key:
			return condition.get("value", default_value)
	return default_value

func set_condition(key: StringName, value: Variant) -> void:
	for condition: Dictionary in conditions:
		if StringName(str(condition.get("key", ""))) == key:
			condition["value"] = value
			return
	conditions.append({"key": key, "value": value})
