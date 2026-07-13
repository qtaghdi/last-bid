class_name ActorState
extends Resource

@export var actor_id: StringName = &""
@export var display_name: String = ""
@export var actor_type: int = GameConstants.ActorType.NPC
@export var archetype: StringName = &""
@export var character_id: StringName = &""
@export var hp: int = GameConstants.STARTING_HP
@export var max_hp: int = GameConstants.MAX_HP
@export var gold: int = GameConstants.STARTING_GOLD
@export var inventory: Array[CardInstance] = []
@export var alive: bool = true
@export var has_passed: bool = false

static func create(
	id_value: StringName,
	name_value: String,
	type_value: int,
	archetype_value: StringName = &"",
	character_value: StringName = &""
) -> ActorState:
	var actor: ActorState = ActorState.new()
	actor.actor_id = id_value
	actor.display_name = name_value
	actor.actor_type = type_value
	actor.archetype = archetype_value
	actor.character_id = character_value
	actor.hp = GameConstants.STARTING_HP
	actor.max_hp = GameConstants.MAX_HP
	actor.gold = GameConstants.STARTING_GOLD
	actor.inventory = []
	actor.alive = true
	actor.has_passed = false
	return actor

func reset_for_auction() -> void:
	has_passed = false

func sealed_card_count() -> int:
	var count: int = 0
	for instance: CardInstance in inventory:
		if instance.is_available() and instance.sealed:
			count += 1
	return count

func has_inventory_space_for_sealed() -> bool:
	return sealed_card_count() < GameConstants.MAX_SEALED_CARDS

func remove_instance(instance_id: StringName) -> CardInstance:
	for index: int in range(inventory.size()):
		if inventory[index].instance_id == instance_id:
			var instance: CardInstance = inventory[index]
			inventory.remove_at(index)
			return instance
	return null

func instance_by_id(instance_id: StringName) -> CardInstance:
	for instance: CardInstance in inventory:
		if instance.instance_id == instance_id:
			return instance
	return null

func owned_card_names(reveal_exact_names: bool = false, include_internal_ids: bool = false) -> String:
	var names: PackedStringArray = []
	for instance: CardInstance in inventory:
		if instance.is_available():
			var definition: CardDefinition = CardCatalog.by_id(instance.definition_id)
			if definition == null:
				names.append("알 수 없는 카드")
				continue
			var exact_visible: bool = (
				reveal_exact_names
				or instance.reveal_level == GameConstants.RevealLevel.FULLY_REVEALED
			)
			var visible_name: String = definition.actual_name if exact_visible else definition.public_name
			if include_internal_ids:
				visible_name += " [%s]" % definition.id
			names.append(visible_name)
	return ", ".join(names) if not names.is_empty() else "없음"
