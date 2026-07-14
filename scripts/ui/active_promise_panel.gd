class_name ActivePromisePanel
extends PanelContainer

signal fulfill_requested(promise_id: StringName)

@onready var count_label: Label = %PromiseCountLabel
@onready var summary_label: RichTextLabel = %PromiseSummaryLabel
@onready var fulfill_button: Button = %FulfillButton

var _displayed_text: String = ""

func _ready() -> void:
	fulfill_button.pressed.connect(
		func() -> void:
			fulfill_requested.emit(StringName(fulfill_button.get_meta("promise_id", &"")))
	)

func render(controller: GameFlowController) -> void:
	var count: int = controller.run_state.active_promises.size()
	count_label.text = "%d ACTIVE" % count
	if count == 0:
		summary_label.text = "[color=#%s]현재 활성 약속이 없습니다.[/color]" % UiPalette.bbcode(UiPalette.MUTED)
		_displayed_text = "활성 약속 없음"
		fulfill_button.visible = false
		return
	var lines: PackedStringArray = []
	for promise: PromiseState in controller.run_state.active_promises:
		lines.append(
			"[b]%s[/b] · %s · %s"
			% [
				PromiseManager.promise_type_name(promise.promise_type),
				promise.target_display_name if not promise.target_display_name.is_empty() else "현재 경매",
				_deadline_text(promise, controller.run_state.current_round),
			]
		)
		lines.append("  %s" % controller.promise_manager.violation_text(promise.promise_type))
	summary_label.text = "\n".join(lines)
	_displayed_text = summary_label.get_parsed_text()
	var actionable: PromiseState = controller.promise_manager.actionable_player_promise()
	fulfill_button.visible = actionable != null
	if actionable != null:
		fulfill_button.text = (
			"카드 넘기기"
			if actionable.promise_type == GameConstants.PROMISE_TRANSFER_CARD
			else "단서 제공하기"
		)
		fulfill_button.set_meta("promise_id", actionable.promise_id)

func displayed_text() -> String:
	return _displayed_text

func _deadline_text(promise: PromiseState, current_round: int) -> String:
	var remaining: int = maxi(0, promise.target_round - current_round)
	return "현재 경매 종료" if remaining == 0 else "%d라운드 남음" % remaining
