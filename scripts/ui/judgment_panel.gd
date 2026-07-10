class_name JudgmentPanel
extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var summary_label: RichTextLabel = %SummaryLabel
@onready var footer_label: Label = %FooterLabel

func render(phase: int, summary_lines: PackedStringArray, actors: Array[ActorState]) -> void:
	var is_round_end: bool = phase == GameConstants.Phase.ROUND_END
	title_label.text = "라운드 정산" if is_round_end else "심판 결과"
	if summary_lines.is_empty():
		summary_label.text = (
			"[color=#%s]이번 단계에서 발동한 효과가 없습니다.[/color]"
			% UiPalette.bbcode(UiPalette.MUTED)
		)
	else:
		summary_label.text = "\n".join(summary_lines)
	var alive_names: PackedStringArray = []
	for actor: ActorState in actors:
		if actor.alive:
			alive_names.append(actor.display_name)
	footer_label.text = "생존자 %d명 · %s" % [alive_names.size(), ", ".join(alive_names)]

func summary_text() -> String:
	return summary_label.text
