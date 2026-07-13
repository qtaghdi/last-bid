class_name ParticipantPanel
extends PanelContainer

@onready var list: VBoxContainer = %ParticipantList

var _cards: Dictionary = {}
var _combined_text: String = ""

func render(controller: GameFlowController, debug_mode: bool) -> void:
	_ensure_cards(controller.actors)
	var combined: PackedStringArray = []
	for actor: ActorState in controller.actors:
		var nodes: Dictionary = _cards[actor.actor_id]
		var panel: PanelContainer = nodes["panel"]
		var label: RichTextLabel = nodes["label"]
		var status: String = _status_for(actor, controller)
		var current_turn: bool = controller.current_turn_actor_id() == actor.actor_id
		var heading: String = "%s%s · %s" % [
			"▶ " if current_turn else "",
			actor.display_name,
			_archetype_name(actor),
		]
		var dialogue: String = controller.npc_dialogue_for(actor.actor_id)
		var lines: PackedStringArray = [
			"[b]%s[/b]  [%s]" % [heading, status],
			"HP %d/%d    GOLD %d" % [actor.hp, actor.max_hp, actor.gold],
			"CARD %s" % actor.owned_card_names(debug_mode, debug_mode),
		]
		if actor.actor_type == GameConstants.ActorType.NPC:
			var npc_state: NpcRunState = controller.npc_run_state_for(actor.actor_id)
			if npc_state != null:
				lines.append(
					"감정 %s · 관계 %+d · 비장 %s"
					% [
						NegotiationSystem.emotion_name(npc_state.emotion),
						npc_state.relationship_score,
						"사용" if npc_state.emergency_used else "보유",
					]
				)
				if not npc_state.recent_tell_text.is_empty():
					lines.append("신호 · %s" % npc_state.recent_tell_text)
		if actor.actor_type == GameConstants.ActorType.NPC and not dialogue.is_empty():
			lines.append(
				"[color=#%s]“%s”[/color]" % [UiPalette.bbcode(UiPalette.MUTED), dialogue]
			)
		label.text = "\n".join(lines)
		combined.append(label.text)
		_apply_state_style(panel, actor, controller, current_turn)
	_combined_text = "\n".join(combined)

func combined_text() -> String:
	return _combined_text

func _ensure_cards(actors: Array[ActorState]) -> void:
	if not _cards.is_empty():
		return
	for actor: ActorState in actors:
		var panel: PanelContainer = PanelContainer.new()
		panel.name = "Actor_%s" % actor.actor_id
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var label: RichTextLabel = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = false
		label.scroll_active = false
		label.custom_minimum_size = Vector2(0, 88)
		panel.add_child(label)
		list.add_child(panel)
		_cards[actor.actor_id] = {"panel": panel, "label": label}

func _apply_state_style(
	panel: PanelContainer,
	actor: ActorState,
	controller: GameFlowController,
	current_turn: bool
) -> void:
	var border: Color = UiPalette.GOLD if actor.actor_type == GameConstants.ActorType.PLAYER else UiPalette.MUTED
	if controller.run_state.highest_bidder_id == actor.actor_id:
		border = UiPalette.GOLD_BRIGHT
	if current_turn:
		border = UiPalette.IVORY
	if not actor.alive:
		border = UiPalette.DANGER
	panel.add_theme_stylebox_override("panel", UiPalette.panel_style(border, UiPalette.PANEL_ALT))
	panel.modulate.a = 0.45 if actor.has_passed or not actor.alive else 1.0

func _status_for(actor: ActorState, controller: GameFlowController) -> String:
	if not actor.alive:
		return "사망"
	if actor.has_passed and controller.run_state.current_phase == GameConstants.Phase.AUCTION:
		return "패스"
	if controller.run_state.highest_bidder_id == actor.actor_id:
		return "최고 입찰자"
	if controller.run_state.current_phase == GameConstants.Phase.AUCTION:
		return "입찰 가능"
	return "생존"

func _archetype_name(actor: ActorState) -> String:
	if actor.actor_type == GameConstants.ActorType.PLAYER:
		return "직접 조작"
	match actor.archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			return "수집가 성향"
		GameConstants.ARCHETYPE_CREDITOR:
			return "채권자 성향"
		GameConstants.ARCHETYPE_GAMBLER:
			return "도박사 성향"
		_:
			return "NPC"
