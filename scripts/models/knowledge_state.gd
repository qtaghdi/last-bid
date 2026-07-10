class_name KnowledgeState
extends Resource

@export var actor_id: StringName = &""
@export var card_instance_id: StringName = &""
@export var known_clue_ids: Array[StringName] = []
@export var believed_clues: Array[Dictionary] = []
@export var confidence_by_clue: Dictionary = {}
@export var reveal_level: int = GameConstants.RevealLevel.UNKNOWN

static func create(actor: StringName, lot_id: StringName) -> KnowledgeState:
	var state: KnowledgeState = KnowledgeState.new()
	state.actor_id = actor
	state.card_instance_id = lot_id
	return state

func learn_clue(clue: CardClueDefinition, confidence: float, is_hidden: bool) -> bool:
	if clue == null or knows(clue.clue_id):
		return false
	known_clue_ids.append(clue.clue_id)
	believed_clues.append(clue.to_belief(is_hidden))
	confidence_by_clue[clue.clue_id] = clampf(confidence, 0.0, 1.0)
	if is_hidden:
		reveal_level = maxi(reveal_level, GameConstants.RevealLevel.INVESTIGATED)
	else:
		reveal_level = maxi(reveal_level, GameConstants.RevealLevel.BASIC_CLUES)
	return true

func knows(clue_id: StringName) -> bool:
	return known_clue_ids.has(clue_id)

func reveal_fully() -> void:
	reveal_level = GameConstants.RevealLevel.FULLY_REVEALED

func knows_type(clue_type: StringName) -> bool:
	for belief: Dictionary in believed_clues:
		if belief.get("clue_type", &"") == clue_type:
			return true
	return false

func known_tags() -> PackedStringArray:
	var result: PackedStringArray = []
	for belief: Dictionary in believed_clues:
		var tags: PackedStringArray = belief.get("related_tags", PackedStringArray())
		for tag: String in tags:
			if not result.has(tag):
				result.append(tag)
	return result

func estimated_reward() -> int:
	return _weighted_average("estimated_reward")

func estimated_risk_cost() -> int:
	return _weighted_average("estimated_risk_cost")

func display_lines() -> PackedStringArray:
	var labels: Dictionary = {
		&"role": "역할군",
		&"risk": "위험도",
		&"value": "예상 가치",
		&"timing": "발동 시점",
		&"target": "대상",
	}
	var lines: PackedStringArray = []
	for belief: Dictionary in believed_clues:
		var clue_type: StringName = belief.get("clue_type", &"trait")
		var text: String = str(belief.get("display_text", ""))
		if bool(belief.get("is_hidden", false)):
			lines.append("조사 정보: %s" % text)
		else:
			lines.append("%s: %s" % [labels.get(clue_type, "단서"), text])
	return lines

func debug_summary() -> String:
	var lines: PackedStringArray = [
		"reveal=%s clues=%d" % [reveal_level, known_clue_ids.size()]
	]
	for belief: Dictionary in believed_clues:
		var clue_id: StringName = belief.get("clue_id", &"")
		lines.append(
			"- %s (%.2f): %s"
			% [clue_id, float(confidence_by_clue.get(clue_id, 0.0)), belief.get("display_text", "")]
		)
	return "\n".join(lines)

func _weighted_average(field: String) -> int:
	if believed_clues.is_empty():
		return 0
	var weighted_total: float = 0.0
	var total_confidence: float = 0.0
	for belief: Dictionary in believed_clues:
		var clue_id: StringName = belief.get("clue_id", &"")
		var confidence: float = float(confidence_by_clue.get(clue_id, 0.5))
		weighted_total += float(belief.get(field, 0)) * confidence
		total_confidence += confidence
	if total_confidence <= 0.0:
		return 0
	return roundi(weighted_total / total_confidence)
