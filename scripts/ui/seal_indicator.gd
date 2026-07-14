class_name SealIndicator
extends HBoxContainer

@onready var seal_labels: Array[Label] = [%Seal1, %Seal2, %Seal3]

var _state_text: String = "봉인 3개 잠김"

func _ready() -> void:
	tooltip_text = TooltipTerms.text("봉인")
	render(0, false)

func render(opened_seals: int, fully_revealed: bool) -> void:
	var states: PackedStringArray = []
	for index: int in range(GameConstants.MAX_SEALS):
		var opened: bool = fully_revealed or index < opened_seals
		var label: Label = seal_labels[index]
		label.text = "%s %d" % ["✦" if opened else "◇", index + 1]
		label.modulate = UiPalette.DANGER if opened and not fully_revealed else (
			UiPalette.GOLD_BRIGHT if opened else UiPalette.MUTED
		)
		states.append("%d:%s" % [index + 1, "열림" if opened else "잠김"])
	_state_text = " · ".join(states)

func displayed_state() -> String:
	return _state_text
