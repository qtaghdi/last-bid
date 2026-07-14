class_name NpcMemoryEntry
extends Resource

@export var memory_id: StringName = &""
@export var actor_id: StringName = &""
@export var event_type: StringName = &""
@export var source_actor_id: StringName = &""
@export var target_actor_id: StringName = &""
@export var card_instance_id: StringName = &""
@export var round_number: int = 0
@export var severity: int = 1
@export var summary_key: StringName = &""
@export var summary_text: String = ""

static func create(
	id_value: StringName,
	owner_id: StringName,
	type_value: StringName,
	source_id: StringName,
	target_id: StringName,
	card_id: StringName,
	round_value: int,
	severity_value: int,
	summary: String
) -> NpcMemoryEntry:
	var entry: NpcMemoryEntry = NpcMemoryEntry.new()
	entry.memory_id = id_value
	entry.actor_id = owner_id
	entry.event_type = type_value
	entry.source_actor_id = source_id
	entry.target_actor_id = target_id
	entry.card_instance_id = card_id
	entry.round_number = round_value
	entry.severity = severity_value
	entry.summary_key = type_value
	entry.summary_text = summary
	return entry
