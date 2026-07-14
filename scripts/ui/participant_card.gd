class_name ParticipantCard
extends PanelContainer

@onready var portrait_slot: PanelContainer = %PortraitSlot
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var silhouette: SilhouettePortrait = %Silhouette
@onready var name_label: Label = %NameLabel
@onready var vital_badge: PanelContainer = %VitalBadge
@onready var vital_label: Label = %VitalLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var action_badge_row: HFlowContainer = %ActionBadgeRow
@onready var turn_badge: PanelContainer = %TurnBadge
@onready var highest_badge: PanelContainer = %HighestBadge
@onready var passed_badge: PanelContainer = %PassedBadge
@onready var negotiating_badge: PanelContainer = %NegotiatingBadge
@onready var observation_label: Label = %ObservationLabel
@onready var resource_label: Label = %ResourceLabel
@onready var details_button: Button = %DetailsButton
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var details_label: RichTextLabel = %DetailsLabel

var actor_id: StringName = &""
var _public_text: String = ""

func _ready() -> void:
	details_button.pressed.connect(_toggle_details)
	details_button.tooltip_text = "공개된 관계, Tell, 약속과 최근 대사를 펼칩니다."
	details_button.accessibility_name = "참가자 상세 펼치기"
	details_panel.visible = false
	portrait_texture.visible = portrait_texture.texture != null
	silhouette.visible = not portrait_texture.visible
	portrait_slot.tooltip_text = "캐릭터 초상화"

func render(
	actor: ActorState,
	controller: GameFlowController,
	debug_mode: bool,
	current_turn: bool
) -> void:
	actor_id = actor.actor_id
	name_label.text = actor.display_name
	name_label.tooltip_text = actor.display_name
	hp_bar.max_value = actor.max_hp
	hp_bar.value = actor.hp
	hp_label.text = "HP %d/%d" % [actor.hp, actor.max_hp]
	var survival_text: String = _render_survival_state(actor)
	var action_texts: PackedStringArray = _render_action_states(actor, controller, current_turn)
	var detail_lines: PackedStringArray = []
	if actor.actor_type == GameConstants.ActorType.NPC:
		_render_npc_information(actor, controller, debug_mode, detail_lines)
	else:
		_render_player_information(actor, detail_lines)
	details_label.text = "\n".join(detail_lines)
	_public_text = "\n".join(PackedStringArray([
		name_label.text,
		survival_text,
		hp_label.text,
		" · ".join(action_texts),
		observation_label.text,
		resource_label.text,
		details_label.text,
	]))
	_apply_visual_state(actor, controller, current_turn)

func displayed_text() -> String:
	return _public_text

func set_portrait(texture: Texture2D) -> void:
	portrait_texture.texture = texture
	portrait_texture.visible = texture != null
	silhouette.visible = texture == null

func _render_survival_state(actor: ActorState) -> String:
	var text: String = "정상"
	var accent: Color = UiPalette.SUCCESS
	if not actor.alive:
		text = "† 사망"
		accent = UiPalette.DANGER
	elif actor.hp < actor.max_hp:
		text = "! 위험" if actor.hp <= 1 else "! 부상"
		accent = UiPalette.DANGER
	vital_label.text = text
	vital_label.add_theme_color_override("font_color", accent)
	vital_badge.add_theme_stylebox_override(
		"panel",
		UiPalette.badge_style(accent, UiPalette.PANEL_PRIMARY)
	)
	return text

func _render_action_states(
	actor: ActorState,
	controller: GameFlowController,
	current_turn: bool
) -> PackedStringArray:
	var phase: int = controller.run_state.current_phase
	var in_auction: bool = phase == GameConstants.Phase.AUCTION
	var highest: bool = in_auction and controller.run_state.highest_bidder_id == actor.actor_id
	var passed: bool = in_auction and actor.has_passed
	var current_offer: NegotiationOffer = controller.current_negotiation_offer()
	var negotiating: bool = (
		phase == GameConstants.Phase.NEGOTIATION
		and current_offer != null
		and current_offer.issuer_id == actor.actor_id
	)
	var texts: PackedStringArray = []
	_set_action_badge(turn_badge, current_turn, "▶ 현재 차례", UiPalette.IVORY, texts)
	_set_action_badge(highest_badge, highest, "◆ 최고 입찰자", UiPalette.GOLD_BRIGHT, texts)
	_set_action_badge(passed_badge, passed, "× 패스", UiPalette.MUTED, texts)
	_set_action_badge(negotiating_badge, negotiating, "◇ 협상 중", UiPalette.INFORMATION_PRIMARY, texts)
	action_badge_row.visible = not texts.is_empty()
	return texts

func _set_action_badge(
	badge: PanelContainer,
	visible: bool,
	text: String,
	accent: Color,
	texts: PackedStringArray
) -> void:
	badge.visible = visible
	if not visible:
		return
	var label: Label = badge.get_child(0) as Label
	label.text = text
	label.add_theme_color_override("font_color", accent)
	badge.add_theme_stylebox_override("panel", UiPalette.badge_style(accent, UiPalette.PANEL_ELEVATED))
	texts.append(text)

func _render_npc_information(
	actor: ActorState,
	controller: GameFlowController,
	debug_mode: bool,
	detail_lines: PackedStringArray
) -> void:
	var npc_state: NpcRunState = controller.npc_run_state_for(actor.actor_id)
	var emotion: String = (
		NegotiationSystem.emotion_name(npc_state.emotion)
		if npc_state != null
		else "알 수 없음"
	)
	var observed_tell: String = _observed_tell_for(actor.actor_id, controller)
	var tell_summary: String = observed_tell if not observed_tell.is_empty() else "알 수 없음"
	observation_label.text = "감정 · %s · Tell · %s" % [emotion, tell_summary]
	observation_label.tooltip_text = observation_label.text
	resource_label.text = "◇ 골드 비공개 · 보유 카드 비공개"
	resource_label.tooltip_text = "NPC의 정확한 골드와 보유 카드는 공개 정보가 아닙니다."
	detail_lines.append("보유 카드 · 비공개")
	if npc_state != null:
		detail_lines.append(
			"관계(Relationship) %+d · 평판(Reputation) %+d"
			% [npc_state.relationship_score, controller.reputation_for(actor.actor_id)]
		)
	detail_lines.append("Tell · %s" % tell_summary)
	detail_lines.append(
		"활성 약속 %d · 최근 배신 %s"
		% [
			controller.active_promise_count_for(actor.actor_id),
			"있음" if controller.recent_betrayal_by(actor.actor_id) else "없음",
		]
	)
	var dialogue: String = controller.npc_dialogue_for(actor.actor_id)
	if not dialogue.is_empty():
		detail_lines.append(
			"[color=#%s]“%s”[/color]" % [UiPalette.bbcode(UiPalette.MUTED), dialogue]
		)
	if debug_mode and npc_state != null:
		detail_lines.append(
			"DEBUG · 비장의 수단 %s" % ("사용" if npc_state.emergency_used else "보유")
		)
		detail_lines.append(
			"DEBUG · 내부 Tell %s"
			% (npc_state.recent_tell_text if not npc_state.recent_tell_text.is_empty() else "없음")
		)
		detail_lines.append("DEBUG · 기억 %s" % controller.recent_memory_for(actor.actor_id))

func _render_player_information(actor: ActorState, detail_lines: PackedStringArray) -> void:
	observation_label.text = "플레이어 · 공개 상태"
	observation_label.tooltip_text = observation_label.text
	resource_label.text = "%d G · 보유 카드 %d" % [actor.gold, _available_card_count(actor)]
	resource_label.tooltip_text = resource_label.text
	detail_lines.append("보유 카드 · %s" % actor.owned_card_names(false, false))

func _available_card_count(actor: ActorState) -> int:
	var count: int = 0
	for instance: CardInstance in actor.inventory:
		if instance.is_available():
			count += 1
	return count

func _observed_tell_for(actor_id_value: StringName, controller: GameFlowController) -> String:
	var offers: Array[NegotiationOffer] = controller.run_state.negotiation_offers
	if offers.is_empty():
		return ""
	var observed_through: int = -1
	if controller.run_state.negotiation_complete:
		observed_through = offers.size() - 1
	elif controller.run_state.current_phase == GameConstants.Phase.NEGOTIATION:
		observed_through = mini(controller.run_state.current_offer_index, offers.size() - 1)
	for index: int in range(observed_through + 1):
		var offer: NegotiationOffer = offers[index]
		if offer.issuer_id == actor_id_value and not offer.tell_text.is_empty():
			return offer.tell_text
	return ""

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
	var accent: Color = (
		UiPalette.PLAYER
		if actor.actor_type == GameConstants.ActorType.PLAYER
		else UiPalette.BORDER_DEFAULT
	)
	var in_auction: bool = controller.run_state.current_phase == GameConstants.Phase.AUCTION
	if actor.hp < actor.max_hp:
		accent = UiPalette.DANGER
	if in_auction and controller.run_state.highest_bidder_id == actor.actor_id:
		accent = UiPalette.GOLD_BRIGHT
	if current_turn:
		accent = UiPalette.IVORY
	if not actor.alive:
		accent = UiPalette.DANGER
	add_theme_stylebox_override("panel", UiPalette.panel_style(accent, UiPalette.PANEL_ELEVATED))
	silhouette.set_tint(accent)
	var portrait_alpha: float = 0.42 if not actor.alive else (0.72 if actor.has_passed else 1.0)
	portrait_texture.modulate = Color(1.0, 1.0, 1.0, portrait_alpha)
	silhouette.modulate.a = portrait_alpha
	modulate.a = 1.0
