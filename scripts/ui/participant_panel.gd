class_name ParticipantPanel
extends PanelContainer

const PARTICIPANT_CARD_SCENE: PackedScene = preload("res://scenes/ui/participant_card.tscn")
const CHARACTER_ASSET_RESOLVER: GDScript = preload("res://scripts/ui/character_asset_resolver.gd")

@onready var list: VBoxContainer = %ParticipantList

var _cards: Dictionary = {}
var _combined_text: String = ""

func render(controller: GameFlowController, debug_mode: bool) -> void:
	_ensure_cards(controller.actors)
	var combined: PackedStringArray = []
	for actor: ActorState in controller.actors:
		var card: ParticipantCard = _cards[actor.actor_id] as ParticipantCard
		var current_turn: bool = controller.current_turn_actor_id() == actor.actor_id
		card.render(actor, controller, debug_mode, current_turn)
		card.set_portrait(CHARACTER_ASSET_RESOLVER.load_portrait(actor.character_id))
		combined.append(card.displayed_text())
	_combined_text = "\n".join(combined)

func combined_text() -> String:
	return _combined_text

func _ensure_cards(actors: Array[ActorState]) -> void:
	if not _cards.is_empty():
		return
	for actor: ActorState in actors:
		var card: ParticipantCard = PARTICIPANT_CARD_SCENE.instantiate() as ParticipantCard
		card.name = "Actor_%s" % actor.actor_id
		list.add_child(card)
		_cards[actor.actor_id] = card
