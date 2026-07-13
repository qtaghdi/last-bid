class_name NpcCharacterProfile
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_archetype: StringName = &""
@export var preferred_tags: PackedStringArray = []
@export var avoided_tags: PackedStringArray = []
@export var risk_tolerance: float = 0.5
@export var negotiation_aggression: int = 50
@export var lie_frequency: float = 0.0
@export var fear_threshold: int = 1
@export var counter_offer_tolerance: int = 100
@export var secret_goal_pool: PackedStringArray = []
@export var emergency_ability_id: StringName = &""
@export var tell_pattern_ids: PackedStringArray = []
@export var dialogue_resource_id: StringName = &""

static func from_dictionary(data: Dictionary) -> NpcCharacterProfile:
	var profile: NpcCharacterProfile = NpcCharacterProfile.new()
	profile.id = StringName(str(data.get("id", "")))
	profile.display_name = str(data.get("display_name", ""))
	profile.base_archetype = StringName(str(data.get("base_archetype", "")))
	profile.preferred_tags = PackedStringArray(data.get("preferred_tags", []))
	profile.avoided_tags = PackedStringArray(data.get("avoided_tags", []))
	profile.risk_tolerance = float(data.get("risk_tolerance", 0.5))
	profile.negotiation_aggression = int(data.get("negotiation_aggression", 50))
	profile.lie_frequency = float(data.get("lie_frequency", 0.0))
	profile.fear_threshold = int(data.get("fear_threshold", 1))
	profile.counter_offer_tolerance = int(data.get("counter_offer_tolerance", 100))
	profile.secret_goal_pool = PackedStringArray(data.get("secret_goal_pool", []))
	profile.emergency_ability_id = StringName(str(data.get("emergency_ability_id", "")))
	profile.tell_pattern_ids = PackedStringArray(data.get("tell_pattern_ids", []))
	profile.dialogue_resource_id = StringName(str(data.get("dialogue_resource_id", profile.id)))
	return profile
