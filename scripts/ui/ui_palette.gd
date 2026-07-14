class_name UiPalette
extends RefCounted

const BACKGROUND_PRIMARY: Color = Color("0b0a09")
const BACKGROUND_SECONDARY: Color = Color("141210")
const PANEL_PRIMARY: Color = Color("1d1a17")
const PANEL_ELEVATED: Color = Color("27221d")
const BORDER_DEFAULT: Color = Color("615039")
const BORDER_FOCUS: Color = Color("d1a75e")
const GOLD_PRIMARY: Color = Color("c49a52")
const GOLD_MUTED: Color = Color("8f7449")
const IVORY_PRIMARY: Color = Color("e8dfcf")
const TEXT_SECONDARY: Color = Color("a79e90")
const DANGER_PRIMARY: Color = Color("a64c43")
const SUCCESS_PRIMARY: Color = Color("5f8a68")
const DISABLED_PRIMARY: Color = Color("57524c")
const OVERLAY: Color = Color("050404d9")
const MARA_ACCENT: Color = Color("9f8060")
const VOLT_ACCENT: Color = Color("a94e42")
const SERA_ACCENT: Color = Color("7d8d78")

# Backward-compatible aliases keep gameplay presentation code centralized while
# the visual prototype migrates to the named design tokens above.
const BACKGROUND: Color = BACKGROUND_PRIMARY
const PANEL: Color = PANEL_PRIMARY
const PANEL_ALT: Color = PANEL_ELEVATED
const GOLD: Color = GOLD_PRIMARY
const GOLD_BRIGHT: Color = Color("e2bc73")
const DANGER: Color = DANGER_PRIMARY
const SUCCESS: Color = SUCCESS_PRIMARY
const IVORY: Color = IVORY_PRIMARY
const MUTED: Color = TEXT_SECONDARY
const DISABLED: Color = DISABLED_PRIMARY
const PLAYER: Color = Color("cfaa61")

const SPACE_1: int = 4
const SPACE_2: int = 8
const SPACE_3: int = 12
const SPACE_4: int = 16
const SPACE_5: int = 24
const SPACE_6: int = 32

const FONT_CAPTION: int = 12
const FONT_SMALL: int = 14
const FONT_BODY: int = 16
const FONT_SUBTITLE: int = 19
const FONT_TITLE: int = 24
const FONT_DISPLAY: int = 34

const CORNER_SMALL: int = 4
const CORNER_MEDIUM: int = 7
const CORNER_LARGE: int = 10
const BORDER_THIN: int = 1
const BORDER_FOCUS_WIDTH: int = 2

const MOTION_FAST: float = 0.12
const MOTION_NORMAL: float = 0.22
const MOTION_SLOW: float = 0.36

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
	style.corner_radius_top_left = CORNER_MEDIUM
	style.corner_radius_top_right = CORNER_MEDIUM
	style.corner_radius_bottom_left = CORNER_MEDIUM
	style.corner_radius_bottom_right = CORNER_MEDIUM
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style
