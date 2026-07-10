class_name GameConstants
extends RefCounted

enum Phase {
	RUN_SETUP,
	PRE_INFO,
	AUCTION,
	POST_AUCTION,
	JUDGMENT,
	ROUND_END,
	RUN_RESULT,
}

enum ActorType {
	PLAYER,
	NPC,
}

enum EffectType {
	MODIFY_HP,
	MODIFY_GOLD,
	DELAY_EFFECT,
	SELECT_OWNER,
	SELECT_RICHEST,
	SELECT_POOREST,
	SELECT_RANDOM_ALIVE,
	SET_GLOBAL_RULE,
	CONSUME_CARD,
}

enum EffectTrigger {
	ON_ACQUIRE,
	JUDGMENT,
	ROUND_END,
	ON_LETHAL_DAMAGE,
}

enum RevealLevel {
	UNKNOWN,
	BASIC_CLUES,
	INVESTIGATED,
	FULLY_REVEALED,
}

const ARCHETYPE_COLLECTOR: StringName = &"collector"
const ARCHETYPE_CREDITOR: StringName = &"creditor"
const ARCHETYPE_GAMBLER: StringName = &"gambler"

const PLAYER_ID: StringName = &"player"
const TOTAL_ROUNDS: int = 10
const STARTING_HP: int = 3
const MAX_HP: int = 3
const STARTING_GOLD: int = 800
const STARTING_INFO_TOKENS: int = 2
const DEFAULT_MIN_INCREMENT: int = 50
const PRICE_SURGE_INCREMENT: int = 150
const AUCTION_ACTION_LIMIT: int = 100
const DEFAULT_SEED: int = 20260710

static func phase_name(phase: int) -> String:
	match phase:
		Phase.RUN_SETUP:
			return "RUN_SETUP"
		Phase.PRE_INFO:
			return "PRE_INFO"
		Phase.AUCTION:
			return "AUCTION"
		Phase.POST_AUCTION:
			return "POST_AUCTION"
		Phase.JUDGMENT:
			return "JUDGMENT"
		Phase.ROUND_END:
			return "ROUND_END"
		Phase.RUN_RESULT:
			return "RUN_RESULT"
		_:
			return "UNKNOWN"
