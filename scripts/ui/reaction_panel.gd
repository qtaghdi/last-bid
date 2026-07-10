class_name ReactionPanel
extends PanelContainer

@onready var reaction_list: VBoxContainer = %ReactionList

var _labels: Dictionary = {}

func render(controller: GameFlowController) -> void:
	_ensure_rows(controller.actors)
	for actor: ActorState in controller.actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		var label: Label = _labels[actor.actor_id]
		var dialogue: String = controller.npc_dialogue_for(actor.actor_id)
		label.text = "%s\n“%s”" % [actor.display_name, dialogue if not dialogue.is_empty() else "..."]

func _ensure_rows(actors: Array[ActorState]) -> void:
	if not _labels.is_empty():
		return
	for actor: ActorState in actors:
		if actor.actor_type != GameConstants.ActorType.NPC:
			continue
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.MUTED, UiPalette.PANEL_ALT))
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(220, 82)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		reaction_list.add_child(panel)
		_labels[actor.actor_id] = label
