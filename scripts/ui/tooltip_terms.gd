class_name TooltipTerms
extends RefCounted

const REQUIRED_TERMS: PackedStringArray = [
	"위험도",
	"가치",
	"발동 시점",
	"대상",
	"봉인",
	"사고 확률",
	"Tell",
	"Relationship",
	"Reputation",
	"약속",
	"배신",
	"지연 효과",
	"심판",
	"정보 토큰",
]

const DEFINITIONS: Dictionary = {
	"위험도": "카드가 손실이나 피해를 만들 가능성입니다. 범위만 공개되므로 단서와 함께 판단하세요.",
	"가치": "카드가 줄 것으로 예상되는 이익 범위입니다. 정확한 보상 수치는 완전 공개 전까지 숨겨집니다.",
	"발동 시점": "카드가 영향을 주기 시작하는 시점입니다. 즉시, 지연, 심판 등으로 구분합니다.",
	"대상": "카드 효과가 향할 수 있는 참가자 유형입니다. 실제 대상은 조건에 따라 달라질 수 있습니다.",
	"봉인": "봉인을 열수록 정보가 늘지만 사고 위험이 있습니다. 세 번째 봉인에서 실제 정보가 공개됩니다.",
	"사고 확률": "다음 봉인을 열 때 불리한 결과가 발생할 확률입니다. 사고 판정은 Seed로 재현됩니다.",
	"Tell": "NPC의 감정이 드러나는 행동 신호입니다. 항상 진실을 보장하지는 않습니다.",
	"Relationship": "이번 런에서 형성된 친밀도입니다. 제안 빈도와 조건에 영향을 줍니다.",
	"Reputation": "약속과 거래로 쌓인 신뢰도입니다. NPC마다 따로 기록되고 새 런에서 초기화됩니다.",
	"약속": "수락 후 기한까지 유지되는 조건입니다. 지키거나 위반할 수 있으며 상대가 결과를 기억합니다.",
	"배신": "NPC가 자신의 약속을 의도적으로 어긴 상태입니다. 성격과 상황에 따라 결정론적으로 판단됩니다.",
	"지연 효과": "즉시 발동하지 않고 남은 라운드가 지난 뒤 적용되는 카드 효과입니다.",
	"심판": "라운드의 카드 효과와 약속 결과를 순서대로 정산하는 단계입니다.",
	"정보 토큰": "PRE_INFO에서 새 단서를 조사할 때 소비합니다. 이번 런에서 사용할 수 있는 수량이 제한됩니다.",
}

static func text(term: String) -> String:
	return str(DEFINITIONS.get(term, "추가 설명이 준비되지 않았습니다."))

static func has_all_required() -> bool:
	for term: String in REQUIRED_TERMS:
		if not DEFINITIONS.has(term) or str(DEFINITIONS[term]).is_empty():
			return false
	return true
