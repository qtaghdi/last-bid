class_name CardCatalog
extends RefCounted

const CARD_PATHS: PackedStringArray = [
	"res://data/cards/cursed_vault.tres",
	"res://data/cards/broken_chalice.tres",
	"res://data/cards/black_ledger.tres",
	"res://data/cards/golden_gallows.tres",
	"res://data/cards/blood_loan.tres",
	"res://data/cards/price_surge.tres",
]

static func load_all() -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = []
	for path: String in CARD_PATHS:
		var loaded: Resource = load(path)
		if loaded is CardDefinition:
			definitions.append(loaded as CardDefinition)
		else:
			push_error("CardDefinition을 불러오지 못했습니다: %s" % path)
	return definitions

static func by_id(card_id: StringName) -> CardDefinition:
	for definition: CardDefinition in load_all():
		if definition.id == card_id:
			return definition
	return null
