class_name RunState
extends Resource

@export var current_round: int = 0
@export var current_phase: int = GameConstants.Phase.RUN_SETUP
@export var current_card: CardDefinition
@export var current_lot_id: StringName = &""
@export var current_bid: int = 0
@export var highest_bidder_id: StringName = &""
@export var active_global_effects: Dictionary = {}
@export var rng_seed: int = GameConstants.DEFAULT_SEED
@export var current_min_increment: int = GameConstants.DEFAULT_MIN_INCREMENT
@export var deck: Array[CardDefinition] = []
@export var finished: bool = false
@export var victory: bool = false
@export var result_reason: String = ""
@export var player_info_tokens: int = GameConstants.STARTING_INFO_TOKENS

func reset(seed_value: int) -> void:
	current_round = 0
	current_phase = GameConstants.Phase.RUN_SETUP
	current_card = null
	current_lot_id = &""
	current_bid = 0
	highest_bidder_id = &""
	active_global_effects = {}
	rng_seed = seed_value
	current_min_increment = GameConstants.DEFAULT_MIN_INCREMENT
	deck = []
	finished = false
	victory = false
	result_reason = ""
	player_info_tokens = GameConstants.STARTING_INFO_TOKENS
