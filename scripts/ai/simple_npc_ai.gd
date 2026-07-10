class_name SimpleNpcAi
extends RefCounted

var maximum_bids: Dictionary = {}

func prepare_auction(
	actors: Array[ActorState],
	card: CardDefinition,
	minimum_increment: int,
	rng: CentralRng
) -> void:
	maximum_bids.clear()
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC or not actor.alive:
			continue
		if actor.gold < card.starting_bid:
			maximum_bids[actor.actor_id] = actor.gold
			continue
		var value_variation: int = rng.randi_range(-2, 4) * minimum_increment
		var valuation: int = maxi(card.starting_bid, card.base_value + value_variation)
		maximum_bids[actor.actor_id] = rng.randi_range(
			card.starting_bid,
			mini(actor.gold, valuation)
		)

func maximum_bid_for(actor_id: StringName) -> int:
	return int(maximum_bids.get(actor_id, 0))

func should_bid(actor: ActorState, required_bid: int, rng: CentralRng) -> bool:
	if not actor.alive or actor.has_passed:
		return false
	if required_bid > actor.gold or required_bid > maximum_bid_for(actor.actor_id):
		return false
	return rng.randf() <= 0.85
