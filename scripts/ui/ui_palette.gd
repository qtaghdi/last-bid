class_name UiPalette
extends RefCounted

const BACKGROUND: Color = Color("12100f")
const PANEL: Color = Color("201d1a")
const PANEL_ALT: Color = Color("29241f")
const GOLD: Color = Color("c39a52")
const GOLD_BRIGHT: Color = Color("e0bd78")
const DANGER: Color = Color("8f3f39")
const IVORY: Color = Color("e5dcc8")
const MUTED: Color = Color("938b80")
const DISABLED: Color = Color("5f5a54")
const PLAYER: Color = Color("cfaa61")

static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

static func bbcode(color: Color) -> String:
	return color.to_html(false)

static func phase_label(phase: int) -> String:
	match phase:
		GameConstants.Phase.RUN_SETUP:
			return "게임 준비"
		GameConstants.Phase.PRE_INFO:
			return "사전 정보"
		GameConstants.Phase.NEGOTIATION:
			return "협상"
		GameConstants.Phase.AUCTION:
			return "경매"
		GameConstants.Phase.POST_AUCTION:
			return "낙찰 후 처리"
		GameConstants.Phase.JUDGMENT:
			return "심판"
		GameConstants.Phase.ROUND_END:
			return "라운드 종료"
		GameConstants.Phase.RUN_RESULT:
			return "게임 결과"
		_:
			return "알 수 없음"

static func panel_style(border_color: Color = GOLD, background: Color = PANEL) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style
