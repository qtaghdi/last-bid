class_name CardInfoPanel
extends PanelContainer

@onready var card_name_label: Label = %CardNameLabel
@onready var reveal_label: Label = %RevealLabel
@onready var clue_list: RichTextLabel = %ClueList
@onready var state_badge_label: Label = %StateBadgeLabel
@onready var capability_label: Label = %CapabilityLabel
@onready var seal_indicator: SealIndicator = %SealIndicator

func _ready() -> void:
	$Column/IdentityRow/ImageFrame/Image.modulate = UiPalette.with_alpha(UiPalette.GOLD, 0.52)
	clue_list.tooltip_text = "\n".join([
		"위험도 · %s" % TooltipTerms.text("위험도"),
		"가치 · %s" % TooltipTerms.text("가치"),
		"발동 시점 · %s" % TooltipTerms.text("발동 시점"),
		"대상 · %s" % TooltipTerms.text("대상"),
		"지연 효과 · %s" % TooltipTerms.text("지연 효과"),
	])
	seal_indicator.tooltip_text = TooltipTerms.text("봉인")

func render(
	card: CardDefinition,
	knowledge: KnowledgeState,
	debug_mode: bool,
	debug_effect_report: String
) -> void:
	if card == null:
		card_name_label.text = "출품 준비 중"
		reveal_label.text = ""
		state_badge_label.text = "대기"
		capability_label.text = ""
		seal_indicator.render(0, false)
		clue_list.text = ""
		return
	if debug_mode:
		card_name_label.text = "%s  [ID: %s]" % [card.actual_name, card.id]
		reveal_label.text = "DEBUG · FULLY REVEALED"
		state_badge_label.text = "완전 공개"
		capability_label.text = "이전 %s · 소각 %s" % [
			"가능" if card.transferable else "불가",
			"가능" if card.burnable else "불가",
		]
		seal_indicator.render(GameConstants.MAX_SEALS, true)
		clue_list.text = debug_effect_report
		return
	card_name_label.text = card.public_name
	reveal_label.text = _reveal_label(knowledge)
	state_badge_label.text = _status_badge(knowledge)
	var fully_revealed: bool = (
		knowledge != null
		and knowledge.reveal_level == GameConstants.RevealLevel.FULLY_REVEALED
	)
	capability_label.text = (
		"이전 %s · 소각 %s"
		% ["가능" if card.transferable else "불가", "가능" if card.burnable else "불가"]
		if fully_revealed
		else "이전·소각 정책 · 낙찰 후 확인"
	)
	seal_indicator.render(GameConstants.MAX_SEALS if fully_revealed else 0, fully_revealed)
	clue_list.text = _knowledge_text(knowledge)

func displayed_name() -> String:
	return card_name_label.text

func displayed_clues() -> String:
	return clue_list.text

func _knowledge_text(knowledge: KnowledgeState) -> String:
	if knowledge == null or knowledge.believed_clues.is_empty():
		return "[color=#%s]공개된 단서가 없습니다.[/color]" % UiPalette.bbcode(UiPalette.MUTED)
	var lines: PackedStringArray = []
	for belief: Dictionary in knowledge.believed_clues:
		var text: String = str(belief.get("display_text", ""))
		if bool(belief.get("is_hidden", false)):
			lines.append(
				"[color=#%s]◆ 새 조사 단서  %s[/color]"
				% [UiPalette.bbcode(UiPalette.GOLD_BRIGHT), text]
			)
		else:
			var type_name: String = _clue_type_name(belief.get("clue_type", &"trait"))
			lines.append("[b]%s[/b]  %s" % [type_name, text])
	return "\n".join(lines)

func _reveal_label(knowledge: KnowledgeState) -> String:
	if knowledge == null:
		return "미확인"
	match knowledge.reveal_level:
		GameConstants.RevealLevel.UNKNOWN:
			return "미확인"
		GameConstants.RevealLevel.BASIC_CLUES:
			return "기본 단서"
		GameConstants.RevealLevel.INVESTIGATED:
			return "조사됨"
		GameConstants.RevealLevel.FULLY_REVEALED:
			return "완전 공개"
		_:
			return "미확인"

func _clue_type_name(clue_type: StringName) -> String:
	match clue_type:
		&"role":
			return "역할군"
		&"risk":
			return "위험도"
		&"value":
			return "예상 가치"
		&"timing":
			return "발동 시점"
		&"target":
			return "대상"
		_:
			return "단서"

func _status_badge(knowledge: KnowledgeState) -> String:
	if knowledge == null:
		return "미확인"
	match knowledge.reveal_level:
		GameConstants.RevealLevel.INVESTIGATED:
			return "조사됨"
		GameConstants.RevealLevel.FULLY_REVEALED:
			return "완전 공개"
		_:
			return "미확인"
