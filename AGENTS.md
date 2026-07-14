# AGENTS.md

## Purpose and Document Ownership

This file contains concise implementation guardrails for agents working on **LAST BID**. Keep it short; do not duplicate full game specifications, milestone history, test inventories, or Git policy.

Document responsibilities:

- `README.md`: player-facing product and service introduction. Describe the game, experience, characters, core loop, and how to access the prototype.
- `README.md` must not become a development report. Do not add assertion counts, CI internals, detailed architecture, Git workflow, implementation changelogs, or speculative roadmaps.
- `docs/MILESTONES.md`: completed milestone scope and historical design decisions.
- `CONTRIBUTING.md`: branch, commit, PR, merge, release, and collaboration rules.
- `AGENTS.md`: current technical constraints, architecture boundaries, validation requirements, and agent workflow.
- Source code and tests are authoritative for exact runtime behavior.

When documentation overlaps, keep the detail in its owning document and link to it instead of copying it.

## Project Snapshot

**LAST BID** is a single-player auction mind-game built with Godot 4 and GDScript. The stable baseline is the completed Milestone 6 visual prototype.

Required technology:

- Engine: Godot 4.7 stable (`4.7.stable.official.5b4e0cb0f`)
- Language: typed GDScript
- UI: Godot `Control` nodes, `Container` layouts, and shared `Theme` resources
- Data: Godot `Resource` where practical
- Target: desktop; Steam release is a later concern

Do not change the engine version or introduce Unity, C#, JavaScript runtimes, web frameworks, databases, or backend services without explicit approval.

Current playable baseline:

- Player 1 + NPC 3, 10 rounds, ascending-price auction
- `PRE_INFO → NEGOTIATION → AUCTION → POST_AUCTION → JUDGMENT → ROUND_END`
- Hidden card identity, per-actor `KnowledgeState`, two information tokens, investigation
- Six prototype cards with immediate, delayed, ownership-aware, and judgment effects
- Mara, Sera, and Volt with distinct goals, emotions, tells, dialogue, and emergency abilities
- Three seals, deterministic accidents, open/keep/sell/burn actions, inventory limits
- Six promise types, fulfillment and violation, relationship, reputation, memory, and betrayal
- Separate deterministic gameplay, negotiation, dialogue, and promise RNG streams
- Milestone 6 visual shell, onboarding, tooltips, feedback, settings, and DEBUG drawer

Out of scope unless explicitly requested:

- New core systems inferred from placeholders
- Repeated negotiation, multiple counters, complex three-party contracts
- Permanent reputation, meta memory, jobs, passives, shop, or meta progression
- Final portraits, card art, audio, complex animation, or final localization
- Multiplayer, Steam SDK, achievements, save slots, or LLM dialogue

## Architecture Guardrails

### Game flow

`GameFlowController` is the only authority that transitions the main phase.

Preferred action flow:

1. UI sends an intent or calls a public controller action.
2. The responsible gameplay system validates it.
3. State changes once.
4. Events or signals announce the result.
5. UI renders from state.

UI must not mutate phases, card resources, actor state, promises, or RNG directly.

### Responsibility boundaries

Keep these areas separate:

- Game flow and phase authority
- Auction rules and settlement
- Card definitions, card instances, and effect execution
- Knowledge distribution and investigation
- NPC evaluation, decisions, bluffing, and dialogue
- Negotiation and offer resolution
- Promise lifecycle, reputation, memory, and betrayal
- Actor and run state
- Seeded RNG streams
- UI presentation and feedback
- Tests and debug reporting

Do not consolidate the game into one script. Add or relocate systems only with a concrete architectural reason and matching documentation updates.

### Cards and information boundaries

Cards are data-driven. `CardDefinition` is immutable shared data; `CardInstance` owns per-copy mutable state such as owner, reveal level, opened seals, delay counters, transfer history, sealed state, consumption, and post-auction completion.

Normal UI and NPC AI must not inspect exact effects before allowed:

- PRE_INFO and AUCTION show public name and structured clues only.
- Exact identity and effects appear only after the third seal or in DEBUG.
- NPC evaluation accepts `KnowledgeState` and public instance state, never `CardDefinition.effects`.
- DEBUG-only data must remain outside normal presentation.

Prefer reusable effect commands. Existing minimum operations include `MODIFY_HP`, `MODIFY_GOLD`, `DELAY_EFFECT`, target selectors, `SET_GLOBAL_RULE`, and `CONSUME_CARD`. Use dedicated scripts only when generic commands cannot express a rule clearly.

Auction settlement assigns ownership and charges the winning bid once. It does not fully reveal the card or execute `ON_OPEN`. A player-owned lot cannot leave POST_AUCTION until one valid action resolves it.

### Deterministic randomness

Gameplay randomness must use the central seeded RNG. Never call unrelated random functions from gameplay or UI scripts.

The same seed must reproduce card order, NPC evaluation and decisions, random targets, accidents, and other gameplay outcomes.

Keep RNG streams isolated:

- Gameplay RNG: cards, auctions, effects, accidents, NPC gameplay decisions
- Negotiation RNG: offers, goals, tells, acceptance, emergency decisions
- Dialogue RNG: dialogue selection only
- Promise RNG: offer priority variation, betrayal, and promise-related checks

Cosmetic motion must not consume gameplay RNG. Rules must never depend on animation completion.

### Events

Use `EventBus` signals for gameplay and presentation notifications. Extend the existing event vocabulary when possible instead of coupling systems directly.

Gameplay systems do not perform UI animations. UI listens to state and events for fades, flashes, toasts, and emphasis.

## Core Invariants

Starting actor state:

- Max HP 3, HP 3, gold 800, alive

Run rules:

- 10 total rounds and one lot per round
- Player death causes immediate defeat
- Round 10 survival causes victory
- One remaining living actor ends the run
- Dead actors cannot bid or be selected unless a card explicitly allows it
- Zero gold does not eliminate an actor

Auction rules:

- Default minimum raise: 50 gold
- Passed actors cannot re-enter the current auction
- Actors cannot bid above available gold
- Final active bidder wins and pays once
- No bids discards the card
- Keep the defensive auction action limit

Exact card, negotiation, post-auction, and promise behavior lives in `data/`, gameplay systems, and regression tests. Read those sources before changing a rule; do not reconstruct behavior from prose alone.

## UI Guardrails

The Milestone 6 visual prototype must remain playable without DEBUG.

- Use shared palette and `Theme` tokens; do not scatter colors or spacing through scripts and scenes.
- Keep phase-specific actions hidden outside their phase.
- Use containers and preserve 16:9 layouts at 1280×720, 1600×900, 1920×1080, and 2560×1440.
- Support UI scale 80%, 100%, and 120%, text sizing, and Reduce Motion.
- Show state with text or symbols as well as color.
- Keep participant secondary details collapsed by default.
- Promise-violating actions warn first but may still be forced.
- Onboarding shows one non-blocking coach mark at a time and can be skipped, disabled, or replayed.
- Placeholder silhouettes and geometric card visuals must remain easy to replace with final resources.

Do not add final art, audio, elaborate animation, or speculative UI for excluded systems without explicit request.

## Repository Map

```text
scenes/main.tscn                 # Main visual shell
scenes/ui/                       # Reusable UI scenes
scripts/core/game_flow_controller.gd
scripts/core/auction_system.gd
scripts/core/post_auction_system.gd
scripts/core/negotiation_system.gd
scripts/core/promise_manager.gd
scripts/core/central_rng.gd
scripts/cards/                   # Definitions, instances, effects, catalog
scripts/knowledge/               # Knowledge and investigation
scripts/ai/                      # NPC evaluation and dialogue
scripts/models/                  # Run, actor, knowledge, promise state
scripts/ui/                      # Presentation-only scripts
data/cards/                      # Card resources
data/npcs/                       # Character resources
themes/                          # Shared themes
tests/test_runner.gd             # Headless regression suite
```

Preserve these responsibility boundaries. Update this map only when the structure actually changes.

## GDScript Style

- Type variables, parameters, and return values.
- Use `class_name` only for reusable domain types.
- Prefer enums and constants over scattered strings.
- Keep methods focused and mutations explicit.
- Prefer composition over deep inheritance.
- Comment non-obvious rules, not obvious syntax.
- Treat parser warnings as issues worth fixing.

## Validation

Primary command:

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

macOS fallback:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_runner.gd
```

Before completing an implementation task:

1. Run the headless regression suite.
2. Run it again in an independent process when determinism or RNG is affected.
3. Run or open the main scene when the environment permits.
4. Check parser errors, warnings, and `git diff --check`.
5. Confirm `.godot/`, `.import/`, generated exports, secrets, and local prompt files are not staged.
6. Add focused regression coverage for changed behavior.
7. Document a deterministic manual procedure when automation is impractical.

Never claim a test passed unless it was executed. If Godot is unavailable, report that and provide the exact command for the user.

## Git and Collaboration

Follow `CONTRIBUTING.md`; do not duplicate its full policy here.

Required summary:

- Keep `main` runnable and work on a short-lived typed branch.
- Automation branches use `codex/<type>-<description>`.
- Commits and PR titles use English Conventional Commits: `type(scope): imperative summary`.
- Prefer atomic commits and one purpose per PR.
- Use Squash and merge by default.
- Do not force-push or rewrite shared history without coordination.
- Preserve unrelated user changes and never commit generated or local-only files.
- PRs are Ready by default for this project; do not create Draft PRs unless explicitly requested.

## Agent Workflow

1. Read `AGENTS.md`, relevant source and tests, plus `CONTRIBUTING.md` for Git work.
2. Inspect the current branch, worktree, engine version, scenes, autoloads, and affected systems.
3. State a brief plan, then implement the requested scope.
4. Preserve architecture and information boundaries.
5. Validate in proportion to risk.
6. Update only the owning documentation when commands, structure, or completed behavior changes.
7. Report changed files, behavior, commands, results, limitations, and the next useful step.

Do not stop after presenting a plan when implementation was requested.
