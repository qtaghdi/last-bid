class_name NpcContentCatalog
extends RefCounted

const PROFILE_PATH: String = "res://data/npcs/npc_profiles.json"

var _profiles: Dictionary = {}
var _goals: Dictionary = {}
var _tells: Dictionary = {}

func _init() -> void:
	_load_data()

func all_profiles() -> Array[NpcCharacterProfile]:
	var result: Array[NpcCharacterProfile] = []
	for profile: NpcCharacterProfile in _profiles.values():
		result.append(profile)
	return result

func profile(character_id: StringName) -> NpcCharacterProfile:
	return _profiles.get(character_id) as NpcCharacterProfile

func goal(goal_id: StringName) -> Dictionary:
	return (_goals.get(goal_id, {}) as Dictionary).duplicate(true)

func tells_for(profile: NpcCharacterProfile, trigger: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile == null:
		return result
	for tell_id: String in profile.tell_pattern_ids:
		var tell: Dictionary = _tells.get(StringName(tell_id), {}) as Dictionary
		if tell.is_empty():
			continue
		if trigger.is_empty() or StringName(str(tell.get("trigger_type", ""))) == trigger:
			result.append(tell.duplicate(true))
	return result

func _load_data() -> void:
	var raw: String = FileAccess.get_file_as_string(PROFILE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed as Dictionary
	for profile_data: Dictionary in data.get("profiles", []):
		var profile: NpcCharacterProfile = NpcCharacterProfile.from_dictionary(profile_data)
		_profiles[profile.id] = profile
	for goal_data: Dictionary in data.get("secret_goals", []):
		_goals[StringName(str(goal_data.get("id", "")))] = goal_data
	for tell_data: Dictionary in data.get("tells", []):
		_tells[StringName(str(tell_data.get("id", "")))] = tell_data
