class_name EventBus
extends Node

signal phase_changed(phase: int)
signal bid_placed(actor_id: StringName, amount: int)
signal actor_passed(actor_id: StringName)
signal auction_won(actor_id: StringName, card_id: StringName, amount: int)
signal card_acquired(actor_id: StringName, card_id: StringName)
signal card_effect_triggered(card_id: StringName, effect_type: int, target_ids: Array[StringName])
signal card_consumed(card_id: StringName, owner_id: StringName)
signal damage_applied(actor_id: StringName, amount: int, source_card_id: StringName)
signal gold_changed(actor_id: StringName, delta: int, new_total: int, source_card_id: StringName)
signal actor_died(actor_id: StringName)
signal round_started(round_number: int, card_id: StringName)
signal round_finished(round_number: int)
signal run_finished(victory: bool, reason: String)
signal debug_logged(message: String)
signal knowledge_changed(actor_id: StringName, card_instance_id: StringName)
signal information_tokens_changed(remaining: int)
signal npc_evaluation_ready(actor_id: StringName, breakdown: Dictionary)
signal npc_dialogue_spoken(actor_id: StringName, text: String, category: StringName)
signal state_updated

func log_debug(message: String) -> void:
	debug_logged.emit(message)
