class_name RunResultPanel
extends PanelContainer

signal same_seed_requested
signal new_seed_requested
signal main_menu_requested

@onready var result_label: Label = %ResultLabel
@onready var stats_label: Label = %StatsLabel
@onready var betrayal_label: Label = %BetrayalLabel

func _ready() -> void:
	%SameSeedButton.pressed.connect(func() -> void: same_seed_requested.emit())
	%NewSeedButton.pressed.connect(func() -> void: new_seed_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	betrayal_label.tooltip_text = TooltipTerms.text("배신")

func render(
	controller: GameFlowController,
	debug_mode: bool,
	presentation_stats: Dictionary = {}
) -> void:
	var run: RunState = controller.run_state
	var player: ActorState = controller.actor_by_id(GameConstants.PLAYER_ID)
	result_label.text = "%s\n%s" % ["승리" if run.victory else "패배", run.result_reason]
	result_label.modulate = UiPalette.GOLD_BRIGHT if run.victory else UiPalette.DANGER
	var cards: String = player.owned_card_names(debug_mode, debug_mode) if player != null else "없음"
	var promise_counts: Dictionary = controller.promise_manager.result_counts() if controller.promise_manager != null else {}
	var reputation_lines: PackedStringArray = []
	for actor: ActorState in controller.actors:
		if actor.actor_type == GameConstants.ActorType.NPC:
			reputation_lines.append("%s %+d" % [actor.display_name, controller.reputation_for(actor.actor_id)])
	stats_label.text = (
		"종료 라운드  %d / %d\n최종 HP  %d / %d\n최종 GOLD  %d\n획득 카드  %s\n완전 개봉 %d · 판매 %d · 소각 %d\n사용한 정보 토큰  %d\n약속 이행 %d · 위반 %d · 취소 %d\n최종 Reputation  %s\nSEED  %d"
		% [
			run.current_round,
			GameConstants.TOTAL_ROUNDS,
			player.hp if player != null else 0,
			player.max_hp if player != null else 0,
			player.gold if player != null else 0,
			cards,
			int(presentation_stats.get("opened", 0)),
			int(presentation_stats.get("sold", 0)),
			int(presentation_stats.get("burned", 0)),
			GameConstants.STARTING_INFO_TOKENS - run.player_info_tokens,
			int(promise_counts.get("fulfilled", 0)),
			int(promise_counts.get("broken", 0)),
			int(promise_counts.get("cancelled", 0)),
			" · ".join(reputation_lines),
			run.rng_seed,
		]
	)
	var betrayal_lines: PackedStringArray = []
	for betrayal: Dictionary in run.betrayal_history:
		var actor: ActorState = controller.actor_by_id(betrayal.get("actor_id", &""))
		betrayal_lines.append(
			"R%d · %s · %s"
			% [
				int(betrayal.get("round", 0)),
				actor.display_name if actor != null else "NPC",
				str(betrayal.get("reason", "약속 위반")),
			]
		)
	betrayal_label.text = (
		"주요 배신 기록\n%s" % "\n".join(betrayal_lines.slice(0, 3))
		if not betrayal_lines.is_empty()
		else "주요 배신 기록 · 없음"
	)
