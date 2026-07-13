# LAST BID Milestone 3 — 낙찰 후 처리 및 봉인 시스템

> 상태: 구현 기준 사양. 현재 동작과 검증 결과는 `README.md`, `AGENTS.md`, `tests/test_runner.gd`를 기준으로 한다.

현재 Milestone 1, 2, 2.5까지 구현된 상태다.

이번 Milestone의 목적은 다음 구조를 실제 플레이로 완성하는 것이다.

> 낙찰은 결과가 아니라 새로운 문제의 시작이다.

낙찰자는 카드를 자동으로 완전 공개하거나 즉시 발동시키지 않고, 카드의 공개 상태와 위험을 고려해 개봉·보관·판매·소각 중 하나를 선택한다.

노션 기획상 Milestone 2에 포함되어 있었지만 현재 구현에서 빠진 봉인 3단계와 봉인 사고 확률도 이번 단계에 함께 구현한다.

## 현재 구현된 기능

- Godot 4.x + GDScript
- 플레이어 1명 + NPC 3명
- 10라운드 오름 입찰
- 체력, 골드, 카드 보유
- 즉시·지연 효과와 심판
- 승패 판정
- 고정 시드와 디버그 로그
- 실제 카드 정보와 공개 단서 분리
- 플레이어/NPC별 KnowledgeState
- 정보 토큰과 추가 조사
- 수집가·채권자·도박사의 평가 방식과 대사
- 도박사의 제한적인 허세 입찰
- PRE_INFO, AUCTION, POST_AUCTION, JUDGMENT, RUN_RESULT UX
- 디버그 패널 분리
- 동일 시드 재현

## 노션 기획과 현재 구현의 차이

### 봉인 및 사고 확률

노션 Milestone 2에는 봉인 확인과 사고 확률이 포함되어 있지만 현재 구현에서는 모든 단서가 사실 기반이며 조사 사고가 없다.

이번 Milestone에서 다음을 구현한다.

- 봉인 3단계
- 봉인별 정보 공개
- 봉인 해제 사고 확률
- 사고 발생 시 즉시 또는 축소 부작용
- 사고 확률의 사전 표시

### NPC 개성 구현 순서

노션에서는 NPC 개성이 Milestone 4였지만 현재 프로젝트에서는 수집가·채권자·도박사의 평가와 대사가 이미 구현되었다.

이번 작업에서는 현재 NPC 구조를 유지하고, 마라·볼트·세라로의 교체는 하지 않는다.

### 낙찰 후 공개

노션 원안대로 낙찰만으로 카드를 완전 공개하거나 개봉 효과를 발동시키지 않는다.

## 핵심 목표

- 낙찰 카드 자동 공개 및 자동 개봉 효과 제거
- POST_AUCTION 실제 선택 연결
- 봉인 3단계 및 사고 확률
- 부분 개봉 후 보관
- 카드 인벤토리
- NPC 판매 제안
- 카드 소각
- 카드 소유권 이전
- 인벤토리 제한
- 이전 후 지연 효과 정책
- NPC 낙찰 후 처리 AI
- 동일 시드 재현
- 기존 기능 및 테스트 유지

## 제외 기능

- 강제 선물
- 재출품
- 보험
- 복잡한 협상 및 역제안
- 약속과 배신
- 평판
- 거짓 정보 전달
- 위조 단서
- 플레이어 직업
- 패시브
- 상점
- 카드 18장 확장
- 최종 아트와 사운드

판매 제안은 한 번의 가격 제안과 수락/거절까지만 구현한다.

## 1. CardInstance 확장

다음 상태를 카드 인스턴스별로 관리한다.

- instance_id
- definition_id
- owner_id
- reveal_level
- opened_seals
- remaining_turns
- sealed
- consumed
- acquisition_round
- pending_effects
- transfer_history
- post_auction_resolved

원칙:

- CardDefinition과 CardInstance를 분리한다.
- 같은 카드 정의라도 서로 다른 공개 상태를 가질 수 있다.
- 카드 이전 시 instance_id는 유지하고 owner_id만 변경한다.
- UI가 CardDefinition 또는 CardInstance를 직접 변조하지 않는다.

## 2. 효과 트리거 구분

카드 효과를 다음 트리거로 구분한다.

- ON_ACQUIRE
- ON_OPEN
- WHILE_HELD
- ON_TRANSFER
- ON_BURN
- ON_JUDGMENT
- ON_ROUND_END
- DELAYED

낙찰만으로 ON_OPEN이 실행되면 안 된다.

보유 효과는 카드 정의에 따라 봉인 상태에서도 작동할 수 있다.

## 3. POST_AUCTION 흐름

```text
AUCTION
→ POST_AUCTION
→ JUDGMENT
```

플레이어 낙찰 시 가능한 행동:

- 봉인 열기
- 보관
- 판매
- 소각

NPC 낙찰 시 다음 정보를 사용해 자동 선택한다.

- 자신의 KnowledgeState
- 아키타입
- HP와 골드
- 인벤토리 공간
- 카드 추정 가치와 위험
- 현재 라운드

POST_AUCTION 처리가 완료되기 전에는 JUDGMENT로 이동하지 않는다.

## 4. 낙찰 직후 규칙

- 카드 owner_id를 낙찰자로 설정한다.
- 낙찰 비용은 한 번만 차감한다.
- 카드는 기본적으로 봉인 상태다.
- 낙찰만으로 FULLY_REVEALED가 되지 않는다.
- 낙찰만으로 ON_OPEN 효과가 실행되지 않는다.
- POST_AUCTION 처리는 카드당 한 번만 실행한다.
- 완료 후 post_auction_resolved를 true로 설정한다.

## 5. 봉인 3단계

### 봉인 1

다음 중 하나를 공개한다.

- 대상 유형
- 역할군
- 위험도 범위

### 봉인 2

다음 중 하나 이상을 공개한다.

- 핵심 효과 방향
- 보상 또는 패널티 유형
- 발동 시점

### 봉인 3

다음을 공개한다.

- 실제 카드명
- 정확한 수치
- 정확한 발동 조건
- 부작용

세 번째 봉인을 성공적으로 열면 FULLY_REVEALED로 변경한다.

초기 구현에서는 봉인을 순서대로 연다.

## 6. 봉인 사고 확률

노션 기준:

| 위험도 | 봉인 1 | 봉인 2 | 봉인 3 |
|---|---:|---:|---:|
| 낮음 | 0% | 5% | 10% |
| 중간 | 0% | 10% | 20% |
| 높음 | 5% | 20% | 35% |

규칙:

- 사고 확률은 개봉 전에 UI에 표시한다.
- actual risk tier를 판정에 사용한다.
- 중앙 gameplay RNG를 사용한다.
- 동일 시드에서 사고 여부가 재현되어야 한다.
- cosmetic RNG와 분리한다.
- 카드별 UI에 사고 확률을 하드코딩하지 않는다.

## 7. 봉인 사고 결과

사고 결과는 카드 데이터로 정의한다.

지원할 수 있는 결과:

- ON_OPEN 효과 일부 조기 발동
- 축소된 패널티
- 체력 피해
- 골드 손실
- 지연 카운트 감소
- 즉시 전역 효과

이번 Milestone에서는 가짜 단서나 오정보를 만들지 않는다.

사고 발생 시:

- 원인과 결과를 UI에 표시
- RNG와 결과를 디버그 로그에 기록
- 피해와 사망 판정
- 사망 시 즉시 RUN_RESULT 이동

## 8. 개봉 행동

1. 다음 봉인의 사고 확률 표시
2. 플레이어 확인
3. 사고 판정
4. 사고 결과 처리
5. 성공 시 정보 공개
6. reveal_level 갱신
7. 계속 열거나 멈추기 선택

플레이어는 봉인 하나만 열고 보관할 수 있다.

세 번째 봉인까지 열면:

- actual_name 공개
- 정확한 effects 공개
- FULLY_REVEALED
- ON_OPEN 효과 실행
- sealed = false

무한 행동을 방지한다.

## 9. 보관 및 인벤토리

보관 시:

- 카드가 소유자 인벤토리에 남는다.
- 현재 공개 상태를 유지한다.
- 봉인 상태를 유지한다.
- remaining_turns를 유지하거나 시작한다.
- POST_AUCTION을 종료한다.

노션 기준 기본 봉인 카드 한도는 3장이다.

초기 구현은 봉인 카드만 한도에 포함한다.

봉인 카드 3장을 이미 보유한 경우:

- 보관 버튼 비활성
- 이유 표시
- 판매·소각·개봉 중 하나를 선택하도록 한다.

## 10. 판매 제안

플레이어는 현재 카드 한 장을 살아 있는 NPC 한 명에게 판매 제안할 수 있다.

구현 범위:

- 대상 NPC 선택
- 가격 입력 또는 가격 선택
- 공개할 단서 선택
- 수락 또는 거절
- 수락 시 골드 이동
- owner_id 이전
- transfer_history 기록
- remaining_turns 유지

이번에 제외:

- 거짓 정보
- 역제안
- 반복 협상
- 약속
- 평판
- 정보 요구

NPC 평가:

```text
purchase_value =
estimated_reward
- estimated_risk_cost
+ archetype_tag_bonus
+ inventory_synergy
- offered_price
+ urgency_modifier
```

NPC는 자신의 KnowledgeState와 플레이어가 공개한 정보만 사용한다.

실제 effects를 직접 참조하면 안 된다.

판매 조건:

- NPC 생존
- 인벤토리 여유
- 지불 가능한 골드
- transferable = true
- 평가 기준 충족

한 POST_AUCTION에서 판매 제안은 최대 1회다.

## 11. 소각

필수 데이터:

- burn_cost
- burn_effect
- burnable
- delayed effect cancellation policy

규칙:

- 골드 부족 시 불가
- 비용 차감
- 인벤토리 제거
- owner_id 해제
- destroyed 또는 consumed 처리
- burn_effect 실행
- 결과 UI와 로그 표시

기존 6장 중 최소 2장은 의미 있는 burn_effect를 갖게 한다.

## 12. 카드 이전 정책

다음 정책을 지원한다.

- FOLLOW_CURRENT_OWNER
- STAY_WITH_ORIGINAL_OWNER
- CANCEL_ON_TRANSFER
- TRIGGER_ON_TRANSFER

카드 이전 시:

- 기존 인벤토리에서 제거
- 새 인벤토리에 추가
- owner_id 변경
- remaining_turns 유지
- transfer_history 기록
- 예약 효과 대상 갱신
- 중복 참조 방지

## 13. 기존 카드 6장 마이그레이션

### 저주받은 금고

- 봉인 상태에서도 라운드 종료마다 +120 골드
- 3라운드 후 현재 소유자 체력 2 피해
- 이전 시 카운트 유지
- FOLLOW_CURRENT_OWNER
- 소각 시 체력 1 피해
- 중간 이상의 burn_cost

### 깨진 성배

- 개봉 후 치명 피해 1회 무효 활성화
- 발동 후 소비
- FOLLOW_CURRENT_OWNER
- 소각 시 기본 제거

### 검은 장부

- 초기 구현은 봉인 상태에서도 심판 효과 발동
- 가장 부유한 참가자 +80 골드
- 가장 가난한 참가자 체력 1 피해
- 동률 모두 처리
- FOLLOW_CURRENT_OWNER
- 소각 시 다음 심판 효과를 축소해 즉시 발동 가능

### 황금 교수대

- 다음 심판에 가장 부유한 참가자 체력 2 피해
- 발동 후 소비
- FOLLOW_CURRENT_OWNER
- 소각 시 가장 부유한 참가자 체력 1 피해

### 피의 대출

- 개봉 시 +500 골드
- 2라운드 후 700 골드 상환
- 부족한 200 골드당 체력 1 피해
- 채무자는 개봉한 actor로 고정
- STAY_WITH_ORIGINAL_OWNER
- 카드 이전 또는 소각으로 채무가 취소되지 않음

### 가격 폭주

- 개봉 시 다음 라운드 최소 인상액 150 골드
- 한 라운드 후 복구
- 소각 시 제거
- 비이전 카드 또는 CANCEL_ON_TRANSFER

기존 테스트와 현재 카드 수치를 우선하고, 변경한 규칙은 README에 기록한다.

## 14. NPC 낙찰 후 처리

선택지:

- OPEN
- KEEP
- BURN

SELL은 NPC가 플레이어에게 먼저 제안하는 협상 기능이 필요하므로 이번에는 제외하거나 KEEP/BURN 재평가로 대체한다.

### 수집가

- 희귀·저주·소유 카드 보관 선호
- 위험해도 개봉 가능
- 인벤토리가 가득 차면 낮은 가치 카드 소각

### 채권자

- 경제·계약·대출 카드 선호
- 손실 위험이 높으면 소각
- 가격과 안정성에 민감

### 도박사

- 고위험·고수익 카드 개봉 선호
- 높은 사고 확률을 감수
- 변동성 있는 카드 보관 가능

동일 시드에서 같은 행동을 해야 한다.

## 15. UI 연결

Milestone 2.5 POST_AUCTION 화면을 실제 기능과 연결한다.

표시:

- public_name
- reveal level
- 열린 봉인 수
- 다음 봉인 사고 확률
- 현재 소유자
- 인벤토리 여유
- 낙찰가
- 가능한 행동

버튼:

- 봉인 열기
- 보관
- 판매
- 소각
- 계속

규칙:

- 불가능한 행동은 비활성
- 비활성 이유 표시
- 처리 전 계속 비활성
- 개봉 전 사고 확률 표시
- FULLY_REVEALED 후 실제 효과 표시
- 판매 시 NPC와 가격 선택
- 소각 시 비용과 공개된 위험 표시

## 16. JUDGMENT 연결

다음을 정상 반영한다.

- 보관 카드의 지연 효과
- 개봉으로 발생한 예약 효과
- 판매로 변경된 소유자
- 소각으로 제거된 카드
- 사고 피해와 사망
- 카드 소비
- 전역 규칙

로그 없이도 원인을 이해할 수 있게 표시한다.

## 17. 이벤트

권장 이벤트:

- post_auction_started
- post_auction_completed
- seal_open_requested
- seal_opened
- seal_accident_triggered
- card_opened
- card_kept
- sale_proposed
- sale_accepted
- sale_rejected
- card_transferred
- card_burned
- inventory_limit_reached
- card_owner_changed

규칙 코드는 UI 애니메이션을 직접 실행하지 않는다.

## 18. 테스트

기존 Milestone 1, 2, 2.5 테스트를 모두 유지한다.

### POST_AUCTION

- 낙찰 후 바로 JUDGMENT로 이동하지 않음
- 처리 완료 전 계속 불가
- 자동 FULLY_REVEALED 금지
- 자동 ON_OPEN 금지
- 처리가 카드당 한 번만 실행

### 봉인

- 순서대로 열림
- 사고 확률 정확
- 동일 시드 사고 재현
- UI에 사고 확률 표시
- 세 번째 봉인 성공 시 FULLY_REVEALED
- 사고 효과 실행
- 사고 사망 시 즉시 패배

### 보관

- 인벤토리 추가
- 봉인 상태 유지
- remaining_turns 유지
- 봉인 카드 3장 제한
- 한도 초과 보관 불가

### 판매

- 죽은 NPC에게 판매 불가
- 골드 부족 NPC 구매 불가
- transferable false 판매 불가
- 미공개 effects 참조 금지
- 성공 시 골드와 소유권 이동
- remaining_turns 유지
- 거절 시 소유권 유지
- 판매 제안 1회 제한

### 소각

- 골드 부족 시 불가
- 비용 차감
- 인벤토리 제거
- burn_effect 실행
- 지연 효과 정책 적용

### 이전

- FOLLOW_CURRENT_OWNER 정상
- STAY_WITH_ORIGINAL_OWNER 정상
- transfer_history 기록
- 중복 인벤토리 참조 없음
- 사망 actor 이전 불가

### NPC

- 수집가는 희귀·저주 카드 보관 선호
- 채권자는 고위험 손실 카드 보수적 처리
- 도박사는 고위험 카드 개봉 선호
- 동일 시드 행동 재현
- 인벤토리 제한 적용

### 회귀

- 기존 경매 유지
- KnowledgeState 유지
- 실제 정보 조기 노출 없음
- 기존 NPC 평가와 대사 유지
- 20회 자동 런에서 무한 루프 없음
- 이전 후 JUDGMENT 대상 오류 없음

## 19. 수동 검증 시나리오

### 부분 개봉 후 보관

1. 카드 낙찰
2. 봉인 1개 개봉
3. 사고 확률 확인
4. 보관
5. 다음 라운드 공개 상태 유지 확인

### 사고 재현

1. 고위험 카드 낙찰
2. 봉인 2 또는 3 개봉
3. 사고 결과 확인
4. 같은 시드에서 재현

### 판매

1. 카드 낙찰
2. NPC와 가격 선택
3. 수락 또는 거절 확인
4. 성공 시 골드와 owner_id 확인

### 이전 후 지연 효과

1. 저주받은 금고 낙찰
2. 1라운드 보유
3. NPC에게 판매
4. remaining_turns 유지
5. 새 소유자 피해 확인

### 피의 대출

1. 피의 대출 개봉
2. +500 골드
3. 카드 이전
4. 2라운드 후 원래 개봉자가 상환하는지 확인

### 인벤토리 제한

1. 봉인 카드 3장 보유
2. 새 카드 낙찰
3. 보관 불가 확인
4. 판매 또는 소각 후 보관 가능 확인

## 20. 완료 조건

- 낙찰 카드 자동 공개 없음
- 자동 ON_OPEN 없음
- POST_AUCTION 실제 선택 가능
- 봉인 3단계 작동
- 사고 확률 UI 표시
- 동일 시드 사고 재현
- 부분 개봉 후 보관 가능
- NPC 판매 가능
- 판매 성공 시 소유권 이전
- 소각과 burn_effect 작동
- 인벤토리 제한 작동
- 이전 정책 정상
- NPC도 낙찰 후 처리
- JUDGMENT에서 결과 원인 확인 가능
- 기존 기능과 테스트 유지
- 20회 자동 런 무한 루프 없음

## 작업 순서

1. 프로젝트 구조와 테스트 분석
2. 전체 기존 테스트 실행
3. CardInstance 및 effect trigger 확장
4. POST_AUCTION 연결
5. 봉인 데이터와 사고 판정
6. 개봉
7. 보관과 인벤토리 제한
8. 판매와 이전
9. 소각과 burn_effect
10. 기존 카드 6장 마이그레이션
11. NPC 처리 AI
12. UI 연결
13. JUDGMENT 연동
14. 테스트 추가
15. 20회 자동 시뮬레이션
16. README 및 AGENTS.md 업데이트

계획만 제시하고 멈추지 말고 실제 구현까지 완료해줘.

대규모 전면 리팩터링보다 기존 구조를 유지하며 작은 단계로 확장해줘.

CardDefinition, CardInstance, KnowledgeState, ActorState의 책임을 섞지 마.

UI는 상태를 읽고 사용자 액션을 전달하며, 규칙 처리와 phase 전환은 GameFlowController 및 게임 시스템이 담당한다.

작업 완료 후 다음을 보고해줘.

- 생성 및 수정 파일
- CardInstance 변경점
- 봉인 시스템 구조
- 사고 확률 및 결과 구조
- POST_AUCTION 흐름
- 개봉·보관·판매·소각 규칙
- 카드 이전 정책
- 기존 카드 6장 마이그레이션
- NPC 처리 규칙
- UI 연결 방식
- 실행 명령
- 테스트 결과
- 자동 시뮬레이션 결과
- 수동 검증 결과
- 알려진 제한 사항
- 다음 Milestone 권장 작업
