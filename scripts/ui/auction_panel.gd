class_name AuctionPanel
extends PanelContainer

@onready var price_label: Label = %PriceLabel
@onready var detail_label: Label = %DetailLabel
@onready var guidance_label: Label = %GuidanceLabel

var reduce_motion: bool = false
var _last_bid_value: int = -1
var _price_tween: Tween

func render(controller: GameFlowController) -> void:
	var run: RunState = controller.run_state
	if run.current_card == null:
		price_label.text = "경매 준비 중"
		detail_label.text = ""
		guidance_label.text = ""
		return
	var current_price: String = "입찰 없음" if run.highest_bidder_id.is_empty() else "%d G" % run.current_bid
	var displayed_bid: int = -1 if run.highest_bidder_id.is_empty() else run.current_bid
	var next_bid: int = controller.current_required_bid()
	var highest_name: String = "없음"
	if not run.highest_bidder_id.is_empty():
		var highest: ActorState = controller.actor_by_id(run.highest_bidder_id)
		highest_name = highest.display_name if highest != null else "없음"
	var turn_name: String = "대기"
	var turn_actor: ActorState = controller.actor_by_id(controller.current_turn_actor_id())
	if turn_actor != null:
		turn_name = turn_actor.display_name
	price_label.text = "현재가  %s" % current_price
	detail_label.text = (
		"시작가  %d G    다음 입찰  %d G\n최고 입찰자  %s    최소 인상  %d G\n현재 차례  %s"
		% [run.current_card.starting_bid, next_bid, highest_name, run.current_min_increment, turn_name]
	)
	guidance_label.text = action_guidance(controller)
	if _last_bid_value != displayed_bid:
		_play_price_emphasis()
	_last_bid_value = displayed_bid

func action_guidance(controller: GameFlowController) -> String:
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	if player == null or not player.alive:
		return "플레이어가 행동할 수 없습니다."
	if player.has_passed:
		return "이미 패스하여 이번 경매에 다시 참여할 수 없습니다."
	if controller.current_turn_actor_id() != GameConstants.PLAYER_ID:
		return "NPC의 차례입니다. 잠시 기다리세요."
	if not controller.can_player_bid():
		return "다음 입찰가를 지불할 골드가 부족합니다."
	return "입찰가를 올리거나 이번 경매에서 패스하세요."

func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled

func _play_price_emphasis() -> void:
	if reduce_motion or not is_inside_tree():
		return
	if _price_tween != null and _price_tween.is_valid():
		_price_tween.kill()
	price_label.pivot_offset = price_label.size * 0.5
	price_label.scale = Vector2(1.06, 1.06)
	price_label.modulate = UiPalette.GOLD_BRIGHT
	_price_tween = create_tween()
	_price_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_price_tween.parallel().tween_property(
		price_label,
		"scale",
		Vector2.ONE,
		UiPalette.MOTION_NORMAL
	)
	_price_tween.parallel().tween_property(
		price_label,
		"modulate",
		Color.WHITE,
		UiPalette.MOTION_NORMAL
	)
