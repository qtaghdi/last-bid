# LAST BID 기여 및 Git 컨벤션

이 문서는 LAST BID 저장소의 브랜치, 커밋, Pull Request, 릴리스 규칙을 정의합니다. 코드와 문서를 변경할 때 모두 같은 규칙을 적용합니다.

## 기본 원칙

- `main`은 항상 실행 가능하고 테스트를 통과하는 기준 브랜치입니다.
- 장기 `develop` 브랜치는 사용하지 않습니다. 모든 작업은 최신 `main`에서 만든 짧은 작업 브랜치에서 진행합니다.
- 하나의 브랜치는 하나의 목적만 다룹니다. 기능 구현과 무관한 정리는 같은 PR에 섞지 않습니다.
- 게임 규칙과 결정론적 RNG를 바꾸는 작업은 테스트와 변경 이유를 함께 남깁니다.
- `.godot/`, `.import/`, export 설정, 비밀값, 로컬 전용 파일은 커밋하지 않습니다.

## 브랜치 규칙

형식:

```text
<type>/<short-kebab-description>
```

허용하는 `type`:

- `feat`: 플레이 가능한 기능 또는 콘텐츠
- `fix`: 버그 수정
- `docs`: 문서만 변경
- `refactor`: 동작을 유지하는 구조 개선
- `test`: 테스트 추가 또는 정리
- `perf`: 성능 개선
- `build`: 빌드 또는 export 구성
- `ci`: CI 워크플로 변경
- `chore`: 설정, 저장소 관리, 반복 작업
- `release`: 릴리스 준비

자동화 에이전트는 저장소 기본 접두사를 보존해 다음 형식을 사용합니다.

```text
codex/<type>-<short-kebab-description>
```

예시:

```text
feat/post-auction-actions
fix/auction-turn-lock
docs/git-convention
codex/test-judgment-summary
```

슬래시로 구분한 각 브랜치 이름 조각은 영문 소문자, 숫자, 하이픈만 사용하고 의미 없는 이름이나 개인 상태를 사용하지 않습니다.

## 커밋 메시지

[Conventional Commits](https://www.conventionalcommits.org/) 형식을 사용합니다.

```text
<type>(<scope>): <summary>
```

### Type

- `feat`: 사용자에게 보이는 기능 추가
- `fix`: 잘못된 동작 수정
- `docs`: 문서만 변경
- `refactor`: 기능 변화 없는 코드 구조 변경
- `test`: 테스트 추가 또는 수정
- `perf`: 성능 개선
- `build`: 빌드 또는 export 구성
- `ci`: CI 워크플로 변경
- `chore`: 나머지 저장소 관리 작업
- `revert`: 이전 변경 되돌리기

### Scope

Scope는 필수이며 다음 값을 우선 사용합니다.

```text
flow, auction, cards, ai, knowledge, ui, data, tests, docs, repo, release
```

새 scope가 필요하면 파일명이 아니라 책임 영역을 나타내는 짧은 소문자를 사용합니다.

### 작성 규칙

- Summary는 영문 명령형 소문자로 작성하고 마침표를 붙이지 않습니다.
- 첫 줄은 72자 이내를 권장합니다.
- 무엇을 바꿨는지는 summary에, 왜 바꿨는지는 필요한 경우 본문에 적습니다.
- 하나의 커밋에는 하나의 논리적 변경만 담습니다.
- 임시 `wip`, `fix`, `update` 메시지를 `main` 이력에 남기지 않습니다.
- 호환성을 깨는 변경은 `type(scope)!:`와 `BREAKING CHANGE:` footer를 사용합니다.
- 이슈가 있으면 `Refs: #123` 또는 `Closes: #123`을 footer에 작성합니다.

좋은 예:

```text
feat(ui): add phase-specific auction panels
fix(auction): prevent passed actors from bidding again
test(knowledge): cover deterministic clue allocation
docs(repo): establish git conventions
```

피해야 할 예:

```text
update
fix bug
작업중
feat: stuff
```

이 컨벤션은 도입 이후 새 커밋부터 적용합니다. 기존 공개 이력을 형식만 맞추기 위해 다시 작성하지 않습니다.

저장소의 커밋 템플릿을 사용하려면 저장소 루트에서 최초 한 번 실행합니다.

```bash
git config --local commit.template "$PWD/.gitmessage"
```

## 작업 흐름

1. 최신 `main`을 기준으로 작업 브랜치를 만듭니다.
2. 변경 범위를 작게 유지하고 논리 단위로 커밋합니다.
3. 관련 자동 테스트와 수동 UX 검증을 수행합니다.
4. 문서, 테스트 수, 실행 방법 또는 구조가 달라졌다면 같은 PR에서 문서를 갱신합니다.
5. `main`을 대상으로 PR을 만들고 템플릿을 채웁니다.
6. 기본 병합 방식은 **Squash and merge**입니다.
7. Squash 커밋 제목도 커밋 컨벤션을 따라야 합니다.

공유 브랜치를 강제로 push하거나 이미 공개된 커밋을 다시 쓰기 전에는 반드시 협의합니다.

## PR 규칙

- PR 제목은 커밋 메시지와 같은 `type(scope): summary` 형식을 사용합니다.
- 변경 이유, 사용자 영향, 테스트 결과를 PR 본문에 기록합니다.
- UI 변경은 확인한 단계와 해상도를 적고 필요하면 이미지를 첨부합니다.
- 게임 규칙 변경은 같은 Seed 재현성에 미치는 영향을 명시합니다.
- 리뷰 가능한 크기를 유지합니다. 서로 독립적인 기능은 별도 PR로 나눕니다.
- 모든 체크가 통과하고 미해결 리뷰가 없어야 병합합니다.

PR 전 최소 검증:

```bash
godot --headless --path . -s res://tests/test_runner.gd
git diff --check
```

macOS에서 `godot`이 PATH에 없다면:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_runner.gd
```

## CI와 브랜치 보호

`.github/workflows/ci.yml`은 `main` 대상 PR과 `main` push에서 다음 검증을 수행합니다.

- 변경 범위 `git diff --check`
- Godot 4.7 헤드리스 import
- 전체 회귀 테스트 2회 실행

GitHub의 `main` 브랜치 보호 규칙에는 다음 설정을 권장합니다.

- `Godot 4.7 regression` 상태 체크 필수
- 병합 전 브랜치를 최신 `main` 기준으로 갱신
- 필수 체크가 끝나기 전 병합 금지
- force push와 branch deletion 금지

CI가 실패하면 로컬에서 동일한 헤드리스 테스트를 재현한 뒤 원인을 수정합니다. 실패한 체크를 우회하거나 관리자 권한으로 병합하지 않습니다.

## 버전과 태그

정식 릴리스 전에는 `0.x.y` 형태의 [Semantic Versioning](https://semver.org/)을 사용합니다.

- 기능 또는 호환성 변화: minor 증가 (`v0.2.0`)
- 호환되는 버그 수정·문서·내부 개선: patch 증가 (`v0.2.1`)
- 릴리스 태그: `vMAJOR.MINOR.PATCH`
- 태그는 테스트를 통과한 `main`의 릴리스 커밋에만 생성합니다.

## 문서 책임

- `README.md`: 현재 플레이 가능 상태, 실행·검증 방법, 다음 개발 방향
- `AGENTS.md`: 구현 제약, 아키텍처 규칙, 에이전트 작업 절차
- `CONTRIBUTING.md`: Git과 협업 규칙
- `.github/pull_request_template.md`: 모든 PR의 완료 체크리스트

과거 기획 프롬프트나 완료된 사양은 현재 동작 설명으로 사용하지 않습니다. 보관이 필요하면 명확하게 역사 문서임을 표시하고, 현재 기준은 README와 테스트를 우선합니다.
