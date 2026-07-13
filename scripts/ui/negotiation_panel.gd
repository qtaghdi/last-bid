class_name NegotiationPanel
extends PanelContainer

signal accept_requested
signal reject_requested
signal counter_requested(amount: int)

@onready var progress_label: Label = %ProgressLabel
@onready var issuer_label: Label = %IssuerLabel
@onready var state_label: Label = %StateLabel
@onready var tell_label: Label = %TellLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var offer_label: Label = %OfferLabel
@onready var result_label: Label = %ResultLabel
@onready var accept_button: Button = %AcceptButton
@onready var reject_button: Button = %RejectButton
@onready var counter_button: Button = %CounterButton

var _displayed_text: String = ""

func _ready() -> void:
	accept_button.pressed.connect(func() -> void: accept_requested.emit())
	reject_button.pressed.connect(func() -> void: reject_requested.emit())
	counter_button.pressed.connect(
		func() -> void:
			var amount: int = int(counter_button.get_meta("counter_amount", 0))
			counter_requested.emit(amount)
	)

func render(controller: GameFlowController) -> void:
	var offer: NegotiationOffer = controller.current_negotiation_offer()
	var total: int = controller.run_state.negotiation_offers.size()
	var current: int = mini(total, controller.run_state.current_offer_index + 1)
	progress_label.text = "OFFER %d / %d" % [current, total] if total > 0 else "OFFER 0 / 0"
	result_label.text = controller.negotiation.last_result_message if controller.negotiation != null else ""
	if offer == null:
		issuer_label.text = "협상 종료"
		state_label.text = "처리된 제안 %d개" % total
		tell_label.text = "경매를 시작할 수 있습니다."
		dialogue_label.text = "[color=#%s]이번 협상 결과를 확인하세요.[/color]" % UiPalette.bbcode(UiPalette.MUTED)
		offer_label.text = controller.run_state.temporary_negotiation_warning
		_set_action_visibility(false)
		_displayed_text = "\n".join([issuer_label.text, state_label.text, tell_label.text, result_label.text, offer_label.text])
		return
	var issuer: ActorState = controller.actor_by_id(offer.issuer_id)
	var state: NpcRunState = controller.npc_run_state_for(offer.issuer_id)
	issuer_label.text = issuer.display_name if issuer != null else String(offer.issuer_id)
	state_label.text = "감정: %s    관계: %+d" % [
		NegotiationSystem.emotion_name(state.emotion) if state != null else "평온",
		state.relationship_score if state != null else 0,
	]
	tell_label.text = "행동 신호 · %s" % offer.tell_text if not offer.tell_text.is_empty() else "행동 신호 · 뚜렷한 신호 없음"
	dialogue_label.text = "[color=#%s]“%s”[/color]" % [UiPalette.bbcode(UiPalette.GOLD_BRIGHT), offer.dialogue]
	offer_label.text = controller.negotiation_offer_summary(offer)
	_set_action_visibility(true)
	var counter_amount: int = offer.offered_gold + GameConstants.COUNTER_INCREMENT
	counter_button.text = "가격 올리기 · %d G" % counter_amount
	counter_button.set_meta("counter_amount", counter_amount)
	counter_button.disabled = (
		not offer.can_counter
		or offer.counter_count >= 1
		or issuer == null
		or counter_amount > issuer.gold
	)
	_displayed_text = "\n".join([
		issuer_label.text,
		state_label.text,
		tell_label.text,
		offer.dialogue,
		offer_label.text,
		result_label.text,
	])

func displayed_text() -> String:
	return _displayed_text

func _set_action_visibility(visible_value: bool) -> void:
	accept_button.visible = visible_value
	reject_button.visible = visible_value
	counter_button.visible = visible_value
