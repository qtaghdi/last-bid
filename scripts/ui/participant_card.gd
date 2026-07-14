class_name ParticipantCard
extends PanelContainer

@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var silhouette: SilhouettePortrait = %Silhouette
@onready var name_label: Label = %NameLabel
@onready var status_label: Label = %StatusLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var gold_label: Label = %GoldLabel
@onready var emotion_label: Label = %EmotionLabel
@onready var details_button: Button = %DetailsButton
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var details_label: RichTextLabel = %DetailsLabel

var actor_id: StringName = &""
var _public_text: String = ""

func _ready() -> void:
	details_button.pressed.connect(_toggle_details)
	details_button.tooltip_text = "Relationship, Reputation, Tell, 최근 기억과 약속을 펼칩니다."
	details_panel.visible = false
	portrait_texture.visible = portrait_texture.texture != null
	silhouette.visible = not portrait_texture.visible

func render(
	actor: ActorState,
	controller: GameFlowController,
	debug_mode: bool,
	current_turn: bool
) -> void:
	actor_id = actor.actor_id
	name_label.text = "%s%s" % ["▶ " if current_turn else "", actor.display_name]
	status_label.text = _status_for(actor, controller)
	hp_bar.max_value = actor.max_hp
	hp_bar.value = actor.hp
	hp_label.text = "HP %d/%d" % [actor.hp, actor.max_hp]
	gold_label.text = "%d G" % actor.gold
	var detail_lines: PackedStringArray = [
		"보유 카드 · %s" % actor.owned_card_names(debug_mode, debug_mode),
	]
	if actor.actor_type == GameConstants.ActorType.NPC:
		var npc_state: NpcRunState = controller.npc_run_state_for(actor.actor_id)
		var emotion: String = (
			NegotiationSystem.emotion_name(npc_state.emotion)
			if npc_state != null
			else "평온"
		)
		emotion_label.text = "감정 · %s" % emotion
		if npc_state != null:
			detail_lines.append(
				"관계(Relationship) %+d · 평판(Reputation) %+d"
				% [npc_state.relationship_score, controller.reputation_for(actor.actor_id)]
			)
			detail_lines.append(
				"비장의 수단 · %s" % ("사용" if npc_state.emergency_used else "보유")
			)
			if not npc_state.recent_tell_text.is_empty():
				detail_lines.append("Tell · %s" % npc_state.recent_tell_text)
		detail_lines.append(
			"활성 약속 %d · 최근 배신 %s"
			% [
				controller.active_promise_count_for(actor.actor_id),
				"있음" if controller.recent_betrayal_by(actor.actor_id) else "없음",
			]
		)
		detail_lines.append("기억 · %s" % controller.recent_memory_for(actor.actor_id))
		var dialogue: String = controller.npc_dialogue_for(actor.actor_id)
		if not dialogue.is_empty():
			detail_lines.append(
				"[color=#%s]“%s”[/color]" % [UiPalette.bbcode(UiPalette.MUTED), dialogue]
			)
	else:
		emotion_label.text = "PLAYER"
	details_label.text = "\n".join(detail_lines)
	_public_text = "\n".join([
		name_label.text,
		status_label.text,
		hp_label.text,
		gold_label.text,
		emotion_label.text,
		details_label.text,
	])
	_apply_visual_state(actor, controller, current_turn)

func displayed_text() -> String:
	return _public_text

func set_portrait(texture: Texture2D) -> void:
	portrait_texture.texture = texture
	portrait_texture.visible = texture != null
	silhouette.visible = texture == null

func _toggle_details() -> void:
	details_panel.visible = not details_panel.visible
	details_button.text = "−" if details_panel.visible else "+"
	details_button.accessibility_name = (
		"참가자 상세 접기" if details_panel.visible else "참가자 상세 펼치기"
	)

func _apply_visual_state(
	actor: ActorState,
	controller: GameFlowController,
	current_turn: bool
) -> void:
	var accent: Color = UiPalette.PLAYER if actor.actor_type == GameConstants.ActorType.PLAYER else UiPalette.GOLD_MUTED
	if controller.run_state.highest_bidder_id == actor.actor_id:
		accent = UiPalette.GOLD_BRIGHT
	if current_turn:
		accent = UiPalette.IVORY
	if not actor.alive:
		accent = UiPalette.DANGER
	add_theme_stylebox_override("panel", UiPalette.panel_style(accent, UiPalette.PANEL_ELEVATED))
	silhouette.set_tint(accent)
	modulate.a = 0.48 if actor.has_passed or not actor.alive else 1.0

func _status_for(actor: ActorState, controller: GameFlowController) -> String:
	if not actor.alive:
		return "사망"
	if actor.has_passed and controller.run_state.current_phase == GameConstants.Phase.AUCTION:
		return "패스"
	if controller.run_state.highest_bidder_id == actor.actor_id:
		return "최고 입찰자"
	if controller.current_turn_actor_id() == actor.actor_id:
		return "현재 차례"
	return "생존"
