class_name JudgmentPanel
extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var summary_label: RichTextLabel = %SummaryLabel
@onready var footer_label: Label = %FooterLabel
@onready var result_list: VBoxContainer = %ResultList

var _displayed_card_count: int = 0

func render(phase: int, summary_lines: PackedStringArray, actors: Array[ActorState]) -> void:
	var is_round_end: bool = phase == GameConstants.Phase.ROUND_END
	title_label.text = "라운드 정산" if is_round_end else "심판 결과"
	var ordered_lines: PackedStringArray = _ordered_lines(summary_lines)
	if ordered_lines.is_empty():
		summary_label.text = (
			"[color=#%s]이번 단계에서 발동한 효과가 없습니다.[/color]"
			% UiPalette.bbcode(UiPalette.MUTED)
		)
	else:
		summary_label.text = "\n".join(ordered_lines)
	_render_cards(ordered_lines)
	var alive_names: PackedStringArray = []
	for actor: ActorState in actors:
		if actor.alive:
			alive_names.append(actor.display_name)
	footer_label.text = "생존자 %d명 · %s" % [alive_names.size(), ", ".join(alive_names)]

func summary_text() -> String:
	return summary_label.get_parsed_text()

func displayed_card_count() -> int:
	return _displayed_card_count

func _ordered_lines(lines: PackedStringArray) -> PackedStringArray:
	var effects: PackedStringArray = []
	var promises: PackedStringArray = []
	var deaths: PackedStringArray = []
	for line: String in lines:
		if line.contains("사망"):
			deaths.append(line)
		elif line.contains("약속") or line.contains("배신") or line.contains("평판"):
			promises.append(line)
		else:
			effects.append(line)
	var result: PackedStringArray = []
	result.append_array(effects)
	result.append_array(promises)
	result.append_array(deaths)
	return result

func _render_cards(lines: PackedStringArray) -> void:
	for child: Node in result_list.get_children():
		result_list.remove_child(child)
		child.queue_free()
	_displayed_card_count = lines.size()
	if lines.is_empty():
		var empty_label: Label = Label.new()
		empty_label.custom_minimum_size = Vector2(390, 42)
		empty_label.text = "이번 단계에서 기록된 결과가 없습니다."
		empty_label.theme_type_variation = &"MutedLabel"
		result_list.add_child(empty_label)
		return
	for line: String in lines:
		var panel: PanelContainer = PanelContainer.new()
		var accent: Color = UiPalette.GOLD_MUTED
		if line.contains("사망") or line.contains("위반") or line.contains("배신"):
			accent = UiPalette.DANGER
		elif line.contains("이행") or line.contains("+"):
			accent = UiPalette.SUCCESS
		panel.add_theme_stylebox_override("panel", UiPalette.panel_style(accent, UiPalette.PANEL_ELEVATED))
		var label: RichTextLabel = RichTextLabel.new()
		label.custom_minimum_size = Vector2(390, 42)
		label.bbcode_enabled = true
		label.fit_content = false
		label.scroll_active = false
		label.text = line
		panel.add_child(label)
		result_list.add_child(panel)
