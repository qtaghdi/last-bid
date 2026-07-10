<div align="center">

<img src="./public/main-title.png" alt="LAST BID" width="760" />

<br />

**불완전한 정보와 상대의 행동을 바탕으로 마지막 입찰을 결정하는 심리 경매 로그라이크**

</div>

---

## LAST BID

**LAST BID**는 위험한 물건들이 거래되는 비밀 경매장을 배경으로 한 싱글 플레이 심리 경매 게임입니다.

플레이어는 경매에 등장한 카드의 정확한 효과를 처음부터 알 수 없습니다.  
제한적으로 공개된 단서와 상대 참가자들의 반응, 입찰 패턴, 성향을 관찰해 카드의 가치와 위험을 추론해야 합니다.

높은 가격에 낙찰받는 것이 항상 좋은 선택은 아닙니다.  
어떤 물건은 당장의 이익을 주지만 이후 더 큰 대가를 요구하고, 어떤 물건은 다른 참가자의 자산이나 생존 상태에 따라 전혀 다른 결과를 만듭니다.

플레이어는 매 라운드 다음을 판단하게 됩니다.

- 이 물건은 어떤 효과를 가진 카드인가
- 상대는 왜 이 카드에 관심을 보이는가
- 지금 가격까지 따라갈 가치가 있는가
- 이번 입찰을 포기하는 것이 더 나은가
- 현재의 이익과 미래의 위험 중 무엇을 선택할 것인가

---

## 핵심 특징

### 불완전한 카드 정보

카드는 처음부터 실제 이름과 정확한 효과를 전부 공개하지 않습니다.

플레이어는 역할군, 위험도, 가치 범위, 발동 시점, 대상 유형과 같은 제한된 단서를 통해 카드의 정체를 추론합니다.

추가 조사를 사용하면 더 많은 정보를 얻을 수 있지만, 사용할 수 있는 정보 자원은 제한되어 있습니다.

### 서로 다른 AI 참가자

플레이어는 각기 다른 성향을 가진 세 명의 AI 참가자와 경쟁합니다.

- **수집가**  
  희귀하거나 저주받은 물건, 소유 가치가 높은 카드에 관심을 보입니다.

- **채권자**  
  안정적인 수익, 계약, 대출, 경제적 우위를 중요하게 판단합니다.

- **도박사**  
  고위험·고수익 카드를 선호하며 때로는 허세 입찰을 시도합니다.

각 참가자는 서로 다른 정보를 가지고 있으며, 자신이 알고 있는 단서와 성향에 따라 카드의 가치를 다르게 평가합니다.

### 위험한 경매

경매에 등장하는 카드들은 단순한 보상 아이템이 아닙니다.

일부 카드는 골드를 제공하지만 일정 시간이 지나면 피해를 주고, 일부 카드는 다음 심판 단계나 다음 경매의 규칙을 바꿉니다.

카드의 가치는 현재 체력, 골드, 보유 카드, 남은 라운드와 상대 참가자의 상태에 따라 계속 달라집니다.

---

## 실행 방법

Godot 4.7 stable에서 프로젝트를 열거나 다음 명령으로 실행합니다.

```bash
godot --path .
```

macOS에서 `godot`이 PATH에 없다면:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

메인 씬은 `scenes/main.tscn`이며 기본 해상도는 1280×720입니다.

---

## 현재 개발 상태

현재 안정 기준선은 **Milestone 2.5 UX Prototype 구현 완료** 상태입니다. 다음 마일스톤의 세부 범위는 구현 전에 별도 기획으로 확정합니다.

### Milestone 1 완료

기본적인 게임 진행 구조와 카드 효과 시스템이 구현되었습니다.

- 플레이어 1명과 AI 참가자 3명
- 총 10라운드 진행
- 오름 입찰 방식의 경매
- 입찰 및 패스
- 낙찰자 결정
- 체력과 골드
- 카드 획득 및 보유
- 즉시 효과와 지연 효과
- 심판 단계
- 참가자 사망 처리
- 승리 및 패배 판정
- 고정 난수 시드
- 같은 시드에서 같은 결과 재현
- 디버그 로그
- 기본 카드 6종

### Milestone 2 구현 완료

LAST BID의 핵심인 정보 비대칭과 NPC 성향을 검증할 수 있는 규칙 계층을 구현했습니다.

- 실제 카드 정보와 공개 단서 분리
- 플레이어와 NPC별 지식 상태
- 정보 토큰과 추가 조사
- 수집가, 채권자, 도박사의 고유 평가 방식
- NPC 성향에 따른 입찰 행동
- NPC 반응 대사
- 도박사의 제한적인 허세 입찰
- 같은 시드에서 정보 배분과 AI 행동 재현

구현 구조:

- `CardDefinition`: 실제 이름·위험/가치·효과와 공개/숨김 단서 분리
- `CardClueDefinition`: 단서 텍스트, 관련 태그, 주관적 보상/위험 추정치
- `KnowledgeState`: 참가자별 알려진 단서, 믿음, 신뢰도, 공개 수준
- `InformationService`: 기본 단서 배분과 정보 토큰 조사
- `SimpleNpcAi`: 자신이 아는 단서만 사용하는 아키타입 평가와 최대 입찰가
- `NpcDialogueService`: 같은 시드에서 재현되는 상황별 대사
- DEBUG Drawer: 실제 카드, 모든 단서, 참가자 지식, NPC 평가와 허세 상태

### Milestone 2.5 UX Prototype 구현 완료

최종 아트 전에 전체 플레이 흐름과 정보 위계를 검증할 수 있는 Control/Container 기반 와이어프레임을 구현했습니다.

- 공통 HUD: 라운드, 사용자용 단계명, Seed, 정보 토큰, DEBUG 토글
- 참가자 패널: HP, 골드, 공개 보유 카드, 생존/패스/최고 입찰자/현재 차례, NPC 최근 대사
- PRE_INFO: 공개 출품명과 플레이어가 아는 구조화 단서, 추가 조사 결과 강조, NPC 첫 반응
- AUCTION: 시작가, 현재가, 다음 입찰가, 최고 입찰자, 현재 차례, 최소 인상폭, 행동 불가 안내
- POST_AUCTION: 낙찰 결과와 Milestone 3의 개봉/보관/판매/소각 자리
- JUDGMENT / ROUND_END: 실제 발동 카드, 대상, HP·골드 변화, 사망·소모와 생존자 요약
- RUN_RESULT: 최종 상태와 같은 Seed/새 Seed 재시작
- DEBUG Drawer: 실제 카드 정보, 모든 단서, 참가자별 지식, NPC 평가·최대 입찰·허세, RNG Seed와 로그
- 공통 `wireframe_theme.tres`와 `UiPalette`로 어두운 회색·금색·적색·아이보리 팔레트 관리

UI는 액션을 `GameFlowController`에 전달하고 상태와 이벤트만 읽습니다. 단계 전환 권한과 게임 규칙, 결정론적 RNG 순서는 기존 컨트롤러와 시스템에 유지됩니다.

주요 UI 서브씬:

```text
scenes/ui/
  top_hud.tscn
  participant_panel.tscn
  card_info_panel.tscn
  reaction_panel.tscn
  auction_panel.tscn
  post_auction_panel.tscn
  judgment_panel.tscn
  result_panel.tscn
  debug_drawer.tscn
```

### 검증

자동 검증:

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

Milestone 1·2 회귀 테스트와 함께 단계별 패널 가시성, 일반 UI 정보 은닉, DEBUG 전용 실제 효과, 조사 결과 표시, 입찰 버튼 상태, 최고 입찰자 표시, 심판 요약, 동일 Seed 재시작, 1280×720 최소 레이아웃과 1920×1080 루트 확장을 포함해 `281 assertions`를 검증합니다.

수동 UX 검증 절차:

1. 프로젝트를 실행하고 1280×720에서 PRE_INFO의 참가자·카드·NPC 반응·하단 액션이 한 화면에 들어오는지 확인합니다.
2. `추가 조사` 후 금색 `◆ 새 조사 단서`가 카드 패널에 나타나고 INFO가 감소하는지 확인합니다.
3. 경매를 시작해 `입찰 없음`, `첫 입찰 N G`, 현재 차례와 입찰 불가 안내가 즉시 갱신되는지 확인합니다.
4. 패스 후 POST_AUCTION → JUDGMENT → ROUND_END로 진행하며 단계별 패널과 결과 요약을 확인합니다.
5. DEBUG를 열어 실제 정보가 Drawer 안에서만 보이는지 확인합니다.
6. 플레이어 사망 또는 10라운드 생존 후 결과 통계와 같은 Seed 재시작을 확인합니다.
7. 창을 1920×1080으로 확대해 Anchor/Container 확장, 텍스트 줄바꿈, 패널 잘림 여부를 다시 확인합니다.

---

## 개발 및 Git 워크플로

저장소는 `main` 기반의 짧은 작업 브랜치와 Conventional Commits, Squash and merge를 사용합니다.

- 브랜치: `feat/post-auction-actions`, `fix/auction-turn-lock`
- 커밋·PR: `feat(ui): add phase-specific auction panels`
- 자동화 브랜치: `codex/<type>-<short-description>`

전체 브랜치·커밋·PR·릴리스 규칙은 [CONTRIBUTING.md](./CONTRIBUTING.md)를 따릅니다. PR 작성 시 저장소 템플릿의 테스트 및 결정론적 RNG 체크리스트를 완료해야 합니다.

---

## 다음 개발 후보

다음 마일스톤에서는 경매 이후의 선택과 참가자 간 상호작용을 우선 검토합니다. 아래 항목은 확정 범위가 아니라 기획 후보입니다.

- 낙찰 후 개봉, 보관, 판매, 소각
- 참가자 간 거래와 협상
- 약속과 배신
- 평판 시스템
- 플레이어 직업과 패시브
- 상점과 메타 진행
- 최종 UI
- 픽셀 초상화와 표정
- 사운드와 경매 연출
- Steam 출시 준비

---

## 개발 환경

- **Engine:** Godot 4.7 stable (`4.7.stable.official.5b4e0cb0f`)
- **Language:** GDScript
- **Platform:** Desktop

---

<div align="center">

<img src="./public/last_bid_symbol_extracted.png" alt="LAST BID Symbol" width="110" />

<br />

<img src="./public/last_bid_wordmark_extracted.png" alt="LAST BID Wordmark" width="260" />

</div>
