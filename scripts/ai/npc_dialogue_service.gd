class_name NpcDialogueService
extends RefCounted

const DIALOGUE_PATH: String = "res://data/npcs/npc_dialogue.json"

var dialogue_seed: int = 0
var _rng: CentralRng
var _dialogue: Dictionary = {}

func _init(seed_value: int = GameConstants.DEFAULT_SEED) -> void:
	reseed(seed_value)
	_load_dialogue()

func reseed(seed_value: int) -> void:
	dialogue_seed = seed_value ^ GameConstants.DIALOGUE_SEED_SALT
	_rng = CentralRng.new(dialogue_seed)

func select_line(
	character_or_archetype: StringName,
	category: StringName,
	_unused_gameplay_rng: CentralRng = null
) -> String:
	var character_id: StringName = _normalize_character(character_or_archetype)
	var character_data: Dictionary = _dialogue.get(String(character_id), {}) as Dictionary
	var values: Array = character_data.get(String(category), []) as Array
	if values.is_empty():
		values = character_data.get("pass", []) as Array
	if values.is_empty():
		return "..."
	return str(values[_rng.choose_index(values.size())])

func line_count(character_id: StringName) -> int:
	var count: int = 0
	var character_data: Dictionary = _dialogue.get(String(character_id), {}) as Dictionary
	for values: Array in character_data.values():
		count += values.size()
	return count

func categories(character_id: StringName) -> PackedStringArray:
	var result: PackedStringArray = []
	var character_data: Dictionary = _dialogue.get(String(character_id), {}) as Dictionary
	for category: String in character_data.keys():
		result.append(category)
	return result

func _load_dialogue() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_PATH))
	_dialogue = parsed as Dictionary if parsed is Dictionary else {}

func _normalize_character(value: StringName) -> StringName:
	match value:
		GameConstants.ARCHETYPE_COLLECTOR:
			return GameConstants.CHARACTER_MARA
		GameConstants.ARCHETYPE_GAMBLER:
			return GameConstants.CHARACTER_VOLT
		GameConstants.ARCHETYPE_CREDITOR:
			return GameConstants.CHARACTER_SERA
		_:
			return value
