class_name NpcRunState
extends Resource

@export var character_id: StringName = &""
@export var secret_goal_id: StringName = &""
@export var relationship_score: int = 0
@export var emotion: int = GameConstants.Emotion.CALM
@export var recent_tell_id: StringName = &""
@export var recent_tell_text: String = ""
@export var tell_reliability: float = 0.0
@export var emergency_used: bool = false
@export var latest_offer_score: int = 0
@export var latest_offer_reason: String = ""
@export var latest_acceptance_threshold: int = 0
@export var goal_progress: int = 0
@export var metrics: Dictionary = {}

static func create(character: StringName, goal_id: StringName) -> NpcRunState:
	var state: NpcRunState = NpcRunState.new()
	state.character_id = character
	state.secret_goal_id = goal_id
	state.metrics = {
		"cumulative_bid": 0,
		"auctions_won": 0,
		"high_risk_opened": 0,
		"trades": 0,
		"clues": 0,
		"fully_revealed": 0,
		"rejections": 0,
	}
	return state

func change_relationship(delta: int) -> int:
	relationship_score = clampi(
		relationship_score + delta,
		GameConstants.RELATIONSHIP_MIN,
		GameConstants.RELATIONSHIP_MAX
	)
	return relationship_score

func add_metric(metric: StringName, amount: int = 1) -> int:
	metrics[metric] = int(metrics.get(metric, 0)) + amount
	return int(metrics[metric])
