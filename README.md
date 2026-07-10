# LAST BID — Milestone 1 Prototype

텍스트와 기본 버튼으로 핵심 경매 루프를 검증하는 Godot 프로토타입입니다. 플레이어 1명과 NPC 3명이 10라운드 동안 오름 입찰 경매를 진행하며, 낙찰 카드의 즉시·지연·심판 효과에 따라 생존 여부가 결정됩니다.

## 고정 기술 스택

- Engine: **Godot 4.7 stable** (`4.7.stable.official.5b4e0cb0f`)
- Language: GDScript
- UI: Godot Control Nodes + Container
- Data: Godot Resource (`.tres`)
- 테스트: 별도 애드온 없는 headless GDScript 테스트 러너

프로젝트 생성일(2026-07-10)의 [Godot 공식 최신 stable 릴리스](https://godotengine.org/download/archive/4.7-stable/)로 고정했습니다. 개발 중 엔진 버전을 임의로 올리지 마세요.

## 실행 방법

1. Godot 4.7 stable을 설치합니다.
2. Godot Project Manager에서 이 폴더의 `project.godot`을 Import합니다.
3. 프로젝트를 연 뒤 `F6`이 아닌 `F5`로 메인 씬을 실행합니다.
4. 상단 Seed 값을 확인하거나 바꾼 뒤 `새 게임`을 누릅니다.
5. `경매 시작` → `입찰` 또는 `패스` → `심판 진행` → `라운드 종료` → `다음 라운드` 순서로 진행합니다.

입찰 버튼은 현재 필요한 최소 입찰가를 자동으로 사용합니다. NPC 행동은 플레이어 입력 직후 자동 처리되며, 다시 플레이어 차례가 오거나 경매가 끝나면 멈춥니다.

일반 모드의 `PRE_INFO`와 `AUCTION`에서는 임시 물품명과 역할군·위험도 범위·예상 가치 범위·발동 시점·대상 유형만 구조화해 표시합니다. 정확한 보상/피해 수치, 발동 턴 수, 실제 카드명은 숨깁니다. 낙찰 이후에는 정확한 카드 이름이 공개되지만 전체 효과 수치는 계속 숨겨집니다. 상단 `DEBUG`를 켠 경우에만 내부 ID, 정확한 이름, 효과별 전체 설명과 디버그 로그를 확인할 수 있습니다.

아직 입찰이 없으면 현재가는 `입찰 없음`으로 표시되고, 시작가를 내는 버튼은 `첫 입찰 {금액} G`로 표시됩니다.

## 핵심 구조

```text
scenes/
  main.tscn                    Control/Container 기반 메인 UI
scripts/
  core/
    game_flow_controller.gd    Phase 전환의 유일한 관리자
    auction_system.gd          입찰, 패스, 낙찰 정산, 안전장치
    central_rng.gd             모든 무작위 결정의 단일 진입점
    event_bus.gd               규칙과 UI를 분리하는 Signal 모음
    game_constants.gd          Phase, 효과 타입, 공통 규칙
  models/
    actor_state.gd             참가자 체력/골드/카드/생존 상태
    run_state.gd               현재 라운드/Phase/입찰/전역 효과
  cards/
    card_definition.gd         정적 카드 Resource 모델
    card_instance.gd           런타임 소유/지연/소모 상태
    card_effect_system.gd      즉시·지연·심판·치명 피해 효과 처리
    card_catalog.gd            카드 Resource 카탈로그
  ai/
    simple_npc_ai.gd           시드 기반 최대 입찰가와 행동 결정
  ui/
    main_ui.gd                 입력 전달과 상태 표시만 담당
data/cards/                    6종 카드 `.tres`
tests/test_runner.gd           규칙 및 20회 연속 시뮬레이션
```

상태 전환은 다음 순서로만 진행됩니다.

```text
RUN_SETUP → PRE_INFO → AUCTION → POST_AUCTION
          → JUDGMENT → ROUND_END → PRE_INFO ... → RUN_RESULT
```

UI는 `GameFlowController`의 요청 메서드만 호출합니다. Phase 값을 직접 변경하거나 카드 연출을 실행하지 않습니다. 규칙 계층은 `EventBus` Signal로 변경 사실만 알립니다.

## 카드와 덱

데이터 파일은 `data/cards/`에 있으며 다음 6종을 구현합니다.

각 Resource는 실제 규칙 데이터와 별도로 `public_label`, `public_role_group`, `public_risk_range`, `public_value_range`, `public_trigger_timing`, `public_target_type`을 가집니다. 경매 전 UI는 이 구조화된 공개 데이터만 읽으므로 내부 ID, 실제 이름, 정확한 수치와 효과 설명이 표시 계층으로 새지 않습니다.

- 저주받은 금고: 매 `ROUND_END` +120골드, 3번째 `ROUND_END`에 소유자 체력 2 피해
- 깨진 성배: 다음 치명 피해를 1회 무효화하고 소모
- 검은 장부: 매 `JUDGMENT`에 부자 동률 전원 +80골드, 빈자 동률 전원 체력 1 피해
- 황금 교수대: 다음 `JUDGMENT`에 부자 동률 전원 체력 2 피해 후 소모
- 피의 대출: 즉시 +500골드, 2번째 `ROUND_END`에 700골드 상환, 부족한 200골드마다 체력 1 피해
- 가격 폭주: 다음 라운드 최소 인상액 150골드, 해당 라운드 종료 후 50골드 복구

10라운드를 구성하기 위해 6종을 각 1회 포함하고, 나머지 4장은 같은 카탈로그에서 중앙 RNG로 복제 선택한 뒤 전체를 섞습니다. 따라서 같은 Seed에서는 카드 순서와 NPC 행동이 모두 동일합니다.

## 자동 테스트

프로젝트 루트에서 다음 명령을 실행합니다.

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

Godot 실행 파일명이 `godot4`인 환경에서는 `godot4`로 바꿉니다. 성공 시 다음과 같이 종료 코드 `0`으로 끝납니다.

```text
LAST BID headless tests
PASS: 169 assertions
```

검증 범위:

- 동일 Seed의 중앙 RNG, 카드 순서, NPC 입찰/패스, 최종 결과 재현
- 6종 카드의 구조화된 공개 단서와 내부 정보 분리 및 공개 필드 내 숫자 차단
- PRE_INFO/AUCTION의 이름·ID·전체 효과 은닉 및 DEBUG 전용 공개
- 무입찰 현재가의 `입찰 없음` 표시와 `첫 입찰 {금액} G` 버튼 문구
- 보유 카드 목록의 내부 ID 비노출
- 골드 부족 입찰, 패스 후 재참여, 사망자 입찰 차단
- 저주와 대출 지연 효과의 정확한 발동 라운드
- 깨진 성배 치명 피해 무효 및 소모
- 검은 장부와 황금 교수대의 동률 대상 전원 처리
- 가격 폭주 적용 및 50골드 복구
- 플레이어 사망 시 패배, 10라운드 생존 시 승리
- 서로 다른 Seed 20개 연속 시뮬레이션의 정상 종료와 500단계 안전 한도

## 수동 검증 절차

1. Seed `20260710`으로 새 게임을 시작하고 10라운드 또는 사망까지 진행합니다.
2. `DEBUG`를 켠 뒤 같은 Seed로 다시 시작해 카드 등장 순서와 우측 로그의 NPC 입찰/패스가 같은지 비교합니다.
3. 경매에서 패스한 뒤 입찰 버튼이 다시 활성화되지 않는지 확인합니다.
4. 가격 폭주를 획득했다면 다음 라운드의 최소 인상이 150골드이고, 그 다음 라운드에는 50골드인지 확인합니다.
5. 체력이 0이 된 참가자가 이후 참가자 목록에는 사망으로 표시되고 경매/효과 대상에서 제외되는지 확인합니다.
6. Seed를 바꾼 뒤 `새 게임`을 눌러 카드 순서와 NPC 행동이 달라지는지 확인합니다.

## 현재 제한 사항

- 플레이어는 금액을 직접 입력하지 않고 항상 최소 인상액만 입찰합니다.
- NPC는 카드 가치와 시드 기반 확률만 사용하는 임시 AI입니다.
- 6종 카드로 10라운드를 구성하므로 한 런에서 일부 카드가 중복됩니다.
- 텍스트 UI와 제공된 타이틀 이미지 외의 픽셀 아트, 사운드, 복잡한 애니메이션은 없습니다.
- 저장/불러오기, 온라인 기능, 영구 성장, 접근성 설정은 아직 없습니다.
- GUT 대신 저장소 의존성을 늘리지 않는 자체 headless 테스트 러너를 사용합니다.

## 다음 Milestone 후보

- 협상, 약속, 배신, 평판을 포함한 심리전 상호작용
- 카드 봉인, 정보 토큰, 블러핑과 불완전 정보 UI
- 직업, 패시브 아이템, 상점과 장기 빌드 구성
- NPC 성향별 의사결정과 기억 모델
- 픽셀 아트 초상화, 카드 연출, 사운드 및 Tween 피드백
- 세이브 슬롯, 설정 메뉴, 게임패드/키보드 접근성
