class_name GameConstants
extends RefCounted

enum Phase {
	RUN_SETUP,
	PRE_INFO,
	NEGOTIATION,
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
	ON_OPEN,
	WHILE_HELD,
	ON_TRANSFER,
	ON_BURN,
	DELAYED,
}

enum RevealLevel {
	UNKNOWN,
	BASIC_CLUES,
	INVESTIGATED,
	FULLY_REVEALED,
}

enum TransferPolicy {
	FOLLOW_CURRENT_OWNER,
	STAY_WITH_ORIGINAL_OWNER,
	CANCEL_ON_TRANSFER,
	TRIGGER_ON_TRANSFER,
}

enum PostAuctionAction {
	OPEN,
	KEEP,
	SELL,
	BURN,
}

enum OfferType {
	BUY_CARD,
	KEEP_SEALED,
	SHARE_INFORMATION,
	SKIP_AUCTION,
	HOLD_CARD,
}

enum RequestedAction {
	SELL_CARD,
	DO_NOT_OPEN,
	PASS_CURRENT_AUCTION,
	KEEP_CARD,
	REVEAL_CLUE,
}

enum Emotion {
	CALM,
	INTERESTED,
	NERVOUS,
	ANGRY,
	AFRAID,
	SMUG,
}

const ARCHETYPE_COLLECTOR: StringName = &"collector"
const ARCHETYPE_CREDITOR: StringName = &"creditor"
const ARCHETYPE_GAMBLER: StringName = &"gambler"

const CHARACTER_MARA: StringName = &"mara"
const CHARACTER_VOLT: StringName = &"volt"
const CHARACTER_SERA: StringName = &"sera"

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
const MAX_SEALS: int = 3
const MAX_SEALED_CARDS: int = 3
const DEFAULT_SALE_PRICE: int = 200
const MAX_NEGOTIATION_OFFERS: int = 2
const NEGOTIATION_SCORE_THRESHOLD: int = 120
const COUNTER_INCREMENT: int = 50
const RELATIONSHIP_MIN: int = -2
const RELATIONSHIP_MAX: int = 2
const NEGOTIATION_SEED_SALT: int = 0x4E45474F
const DIALOGUE_SEED_SALT: int = 0x4449414C

static func phase_name(phase: int) -> String:
	match phase:
		Phase.RUN_SETUP:
			return "RUN_SETUP"
		Phase.PRE_INFO:
			return "PRE_INFO"
		Phase.NEGOTIATION:
			return "NEGOTIATION"
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
