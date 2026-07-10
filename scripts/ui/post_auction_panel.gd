class_name PostAuctionPanel
extends PanelContainer

@onready var result_label: Label = %ResultLabel
@onready var ownership_label: Label = %OwnershipLabel

func render(controller: GameFlowController) -> void:
	var run: RunState = controller.run_state
	if run.current_card == null:
		return
	var winner_name: String = "낙찰 없음"
	var owner_name: String = "없음"
	if not run.highest_bidder_id.is_empty():
		var winner: ActorState = controller.actor_by_id(run.highest_bidder_id)
		if winner != null:
			winner_name = winner.display_name
			owner_name = winner.display_name
	var price_text: String = "-" if run.highest_bidder_id.is_empty() else "%d G" % run.current_bid
	result_label.text = "%s\n낙찰자  %s    낙찰가  %s" % [run.current_card.public_name, winner_name, price_text]
	var knowledge: KnowledgeState = controller.player_knowledge()
	ownership_label.text = "공개 상태  %s    현재 소유자  %s\n현재는 심판 단계로만 진행할 수 있습니다." % [
		_reveal_name(knowledge),
		owner_name,
	]

func _reveal_name(knowledge: KnowledgeState) -> String:
	if knowledge == null:
		return "미확인"
	match knowledge.reveal_level:
		GameConstants.RevealLevel.BASIC_CLUES:
			return "기본 단서"
		GameConstants.RevealLevel.INVESTIGATED:
			return "조사됨"
		GameConstants.RevealLevel.FULLY_REVEALED:
			return "완전 공개"
		_:
			return "미확인"
