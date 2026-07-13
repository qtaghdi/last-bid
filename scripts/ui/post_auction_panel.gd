class_name PostAuctionPanel
extends PanelContainer

signal open_requested
signal keep_requested
signal burn_requested
signal sale_requested(buyer_id: StringName, price: int, clue_id: StringName)

@onready var result_label: Label = %ResultLabel
@onready var ownership_label: Label = %OwnershipLabel
@onready var seal_status: RichTextLabel = %SealStatus
@onready var result_message: Label = %ResultMessage
@onready var open_button: Button = %OpenButton
@onready var keep_button: Button = %KeepButton
@onready var sell_button: Button = %SellButton
@onready var burn_button: Button = %BurnButton
@onready var sale_controls: HBoxContainer = %SaleControls
@onready var buyer_option: OptionButton = %BuyerOption
@onready var price_input: SpinBox = %PriceInput
@onready var clue_option: OptionButton = %ClueOption
@onready var offer_button: Button = %OfferButton

var _sale_expanded: bool = false

func _ready() -> void:
	open_button.pressed.connect(func() -> void: open_requested.emit())
	keep_button.pressed.connect(func() -> void: keep_requested.emit())
	burn_button.pressed.connect(func() -> void: burn_requested.emit())
	sell_button.pressed.connect(_toggle_sale_controls)
	offer_button.pressed.connect(_emit_sale_request)
	price_input.value = GameConstants.DEFAULT_SALE_PRICE

func render(controller: GameFlowController) -> void:
	var run: RunState = controller.run_state
	var instance: CardInstance = controller.current_post_instance()
	var definition: CardDefinition = CardCatalog.by_id(instance.definition_id) if instance != null else run.current_card
	if definition == null:
		return
	var owner: ActorState = controller.actor_by_id(instance.owner_id) if instance != null else null
	var owner_name: String = owner.display_name if owner != null else "없음"
	var price_text: String = "-" if run.highest_bidder_id.is_empty() else "%d G" % run.current_bid
	var visible_name: String = definition.public_name
	if instance != null and instance.reveal_level == GameConstants.RevealLevel.FULLY_REVEALED:
		visible_name = definition.actual_name
	result_label.text = "%s\n낙찰자  %s    낙찰가  %s" % [visible_name, owner_name, price_text]
	var sealed_count: int = owner.sealed_card_count() if owner != null else 0
	ownership_label.text = "공개 상태  %s    현재 소유자  %s    봉인 인벤토리  %d / %d" % [
		_reveal_name(instance),
		owner_name,
		sealed_count,
		GameConstants.MAX_SEALED_CARDS,
	]
	seal_status.text = _seal_text(controller, instance, definition)
	result_message.text = (
		controller.post_auction.last_result_message
		if controller.post_auction != null
		else "낙찰 후 처리 준비 중"
	)
	var player_owned: bool = instance != null and instance.owner_id == GameConstants.PLAYER_ID
	var unresolved: bool = instance != null and not instance.post_auction_resolved
	open_button.visible = player_owned and unresolved
	keep_button.visible = player_owned and unresolved
	sell_button.visible = player_owned and unresolved
	burn_button.visible = player_owned and unresolved
	open_button.disabled = not controller.can_open_next_seal()
	keep_button.disabled = not controller.can_keep_post_card()
	sell_button.disabled = not controller.can_sell_post_card()
	burn_button.disabled = not controller.can_burn_post_card()
	open_button.text = (
		"모든 봉인 개봉됨"
		if instance != null and not instance.sealed
		else "봉인 %d 열기 · 사고 %d%%" % [
			controller.post_auction.next_seal_number() if controller.post_auction != null else 0,
			controller.post_auction.next_accident_percent() if controller.post_auction != null else 0,
		]
	)
	burn_button.text = "소각 · %d G" % definition.burn_cost
	if not player_owned or not unresolved or sell_button.disabled:
		_sale_expanded = false
	sale_controls.visible = _sale_expanded
	if sale_controls.visible:
		_refresh_sale_options(controller)

func displayed_text() -> String:
	return "\n".join([result_label.text, ownership_label.text, seal_status.text, result_message.text])

func _seal_text(
	controller: GameFlowController,
	instance: CardInstance,
	definition: CardDefinition
) -> String:
	if instance == null:
		return "[color=#%s]낙찰 없음 · 바로 심판으로 진행할 수 있습니다.[/color]" % UiPalette.bbcode(UiPalette.MUTED)
	var lines: PackedStringArray = [
		"[b]봉인 %d / %d[/b]    다음 사고 확률  %d%%" % [
			instance.opened_seals,
			GameConstants.MAX_SEALS,
			controller.post_auction.next_accident_percent(),
		]
	]
	for index: int in range(instance.revealed_seal_texts.size()):
		lines.append("[color=#%s]◆ 봉인 %d  %s[/color]" % [
			UiPalette.bbcode(UiPalette.GOLD_BRIGHT),
			index + 1,
			instance.revealed_seal_texts[index],
		])
	if instance.reveal_level == GameConstants.RevealLevel.FULLY_REVEALED:
		lines.append("[b]%s[/b]" % definition.description)
	return "\n".join(lines)

func _refresh_sale_options(controller: GameFlowController) -> void:
	buyer_option.clear()
	for actor: ActorState in controller.sale_targets():
		buyer_option.add_item("%s · %d G" % [actor.display_name, actor.gold])
		buyer_option.set_item_metadata(buyer_option.item_count - 1, actor.actor_id)
	clue_option.clear()
	clue_option.add_item("단서 공개 안 함")
	clue_option.set_item_metadata(0, &"")
	var knowledge: KnowledgeState = controller.player_knowledge()
	if knowledge != null:
		for belief: Dictionary in knowledge.believed_clues:
			var clue_id: StringName = belief.get("clue_id", &"")
			clue_option.add_item(str(belief.get("display_text", "단서")))
			clue_option.set_item_metadata(clue_option.item_count - 1, clue_id)
	offer_button.disabled = buyer_option.item_count == 0

func _toggle_sale_controls() -> void:
	_sale_expanded = not _sale_expanded
	sale_controls.visible = _sale_expanded

func _emit_sale_request() -> void:
	if buyer_option.item_count == 0:
		return
	var buyer_id: StringName = buyer_option.get_item_metadata(buyer_option.selected) as StringName
	var clue_id: StringName = clue_option.get_item_metadata(clue_option.selected) as StringName
	sale_requested.emit(buyer_id, int(price_input.value), clue_id)

func _reveal_name(instance: CardInstance) -> String:
	if instance == null:
		return "미확인"
	match instance.reveal_level:
		GameConstants.RevealLevel.BASIC_CLUES:
			return "봉인 1 공개"
		GameConstants.RevealLevel.INVESTIGATED:
			return "부분 개봉"
		GameConstants.RevealLevel.FULLY_REVEALED:
			return "완전 공개"
		_:
			return "봉인됨"
