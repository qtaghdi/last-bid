class_name NegotiationOffer
extends Resource

@export var offer_id: StringName = &""
@export var issuer_id: StringName = &""
@export var receiver_id: StringName = GameConstants.PLAYER_ID
@export var offer_type: int = GameConstants.OfferType.SKIP_AUCTION
@export var target_card_instance_id: StringName = &""
@export var target_lot_id: StringName = &""
@export var target_display_name: String = ""
@export var offered_gold: int = 0
@export var requested_action: int = GameConstants.RequestedAction.PASS_CURRENT_AUCTION
@export var offered_clue_id: StringName = &""
@export var expires_round: int = 0
@export var can_counter: bool = false
@export var counter_count: int = 0
@export var accepted: bool = false
@export var rejected: bool = false
@export var resolved: bool = false
@export var dialogue: String = ""
@export var tell_text: String = ""
@export var generation_score: int = 0
@export var generation_reason: String = ""
@export var acceptance_threshold: int = 0
@export var creates_promise: bool = false
@export var promise_type: StringName = &""
@export var promise_target_round: int = 0
@export var promise_target_actor_id: StringName = &""
@export var promise_target_card_instance_id: StringName = &""
@export var promise_target_lot_id: StringName = &""
@export var promise_obligor_ids: Array[StringName] = []
@export var promise_reward_gold: int = 0
@export var promise_reward_clue_id: StringName = &""
@export var promise_penalty_hp: int = 0
@export var promise_penalty_gold: int = 0
@export var promise_reputation_reward: int = 1
@export var promise_reputation_penalty: int = 2
@export var promise_card_policy: StringName = GameConstants.PROMISE_BREAK_ON_DESTROY

func is_pending() -> bool:
	return not resolved and not accepted and not rejected
