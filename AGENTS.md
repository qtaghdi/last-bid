# AGENTS.md

## Project Overview

**LAST BID** is a single-player auction mind-game built with Godot 4 and GDScript.

The initial development target is a text-first Milestone 1 prototype that validates the core auction loop before visual polish, negotiation, bluffing, reputation, or content expansion.

Primary prototype goals:

- Player 1 + NPC 3
- 10 rounds
- Ascending-price auction
- 6 prototype cards
- HP, gold, ownership, delayed effects
- Judgment phase
- Deterministic RNG seed
- Debug log
- Win / loss result
- Reproducible behavior from the same seed

## Required Technology

- Engine: Godot 4.x stable
- Language: GDScript
- UI: Godot Control nodes and Containers
- Data: Godot Resource preferred
- Animation: Minimal; Tween or AnimationPlayer only when necessary
- Version control: Git
- Target platform: Desktop, with Steam release planned later

Do not introduce Unity, C#, JavaScript runtimes, web frameworks, databases, or external backend services unless explicitly requested.

## Engine Version

Use the project-defined Godot 4 stable version.

- Do not upgrade the engine version without explicit approval.
- Record the selected version in `README.md`.
- Do not use beta, release candidate, dev, or nightly builds.
- Avoid APIs unavailable in the selected Godot version.

## Current Scope

Implement only Milestone 1 unless the user explicitly expands the scope.

Included:

- `RUN_SETUP`
- `PRE_INFO`
- `AUCTION`
- `POST_AUCTION`
- `JUDGMENT`
- `ROUND_END`
- `RUN_RESULT`
- Player and NPC actor states
- Auction turns
- Bid and pass actions
- Card acquisition
- Immediate and delayed card effects
- Actor death
- Deterministic RNG
- Debug logging
- Basic temporary UI
- Automated or headless tests where practical

Excluded:

- Negotiation
- Promises and betrayal
- Reputation
- Card seals
- Information tokens
- Bluffing
- Character jobs
- Passive items
- Shop
- Pixel-art production
- Audio
- Complex animation
- Multiplayer
- Steam SDK
- Achievements
- Save slots
- Meta progression
- LLM-powered NPC dialogue

Do not pre-build excluded systems or add speculative abstractions for them.

## Architecture Rules

### Game flow

`GameFlowController` is the only authority allowed to transition the main game phase.

UI code must not directly mutate the current phase.

Preferred flow:

1. UI emits an intent or calls a public action method.
2. A gameplay system validates the action.
3. State changes occur.
4. Signals are emitted.
5. UI updates from state or signals.

### Separation of concerns

Keep these responsibilities separate:

- Game flow
- Auction rules
- Card definitions
- Card instances
- Card-effect resolution
- NPC decisions
- Actor state
- RNG
- UI presentation
- Debug logging
- Tests

Do not place the whole game in one script.

### Data-driven cards

Do not hardcode each card directly inside UI scripts or phase-control code.

Use reusable card definitions and effect commands.

Minimum effect operations:

- `MODIFY_HP`
- `MODIFY_GOLD`
- `DELAY_EFFECT`
- `SELECT_OWNER`
- `SELECT_RICHEST`
- `SELECT_POOREST`
- `SELECT_RANDOM_ALIVE`
- `SET_GLOBAL_RULE`
- `CONSUME_CARD`

Complex special cases may use dedicated scripts only when a generic effect cannot express the rule clearly.

### Deterministic randomness

All gameplay randomness must use one centrally managed seeded RNG.

Do not call unrelated random functions from arbitrary scripts.

The same seed must reproduce:

- Card order
- NPC maximum bids
- NPC decisions
- Random targets
- Other gameplay-relevant random results

Cosmetic randomness must not alter gameplay RNG order.

## Core Rules

Starting state for all actors:

- Max HP: 3
- HP: 3
- Gold: 800
- Alive: true

Run rules:

- 10 total rounds
- One auction card per round
- Player death causes immediate loss
- Surviving through round 10 causes victory
- If only one actor remains alive, finish the run
- Dead actors cannot bid or be selected by effects unless a card explicitly says otherwise
- Zero gold does not cause elimination

Auction rules:

- Each card has a starting bid
- Default minimum raise: 50 gold
- Actor chooses bid or pass
- A passed actor cannot re-enter the current auction
- An actor cannot bid more than available gold
- Dead actors cannot act
- The final active bidder wins
- Winning gold is deducted once
- If nobody bids, discard the card
- Include a defensive limit against infinite auction loops

## Initial Cards

Implement these six cards for Milestone 1.

### Cursed Vault

- Owner gains 120 gold at each `ROUND_END`
- After 3 rounds, owner takes 2 damage

### Broken Chalice

- Prevent the owner's next lethal damage once
- Consume after triggering

### Black Ledger

At each `JUDGMENT`:

- Richest living actor gains 80 gold
- Poorest living actor takes 1 damage

Ties affect every tied actor.

### Golden Gallows

At the next `JUDGMENT`:

- Every richest living actor takes 2 damage
- Consume after triggering

### Blood Loan

- On acquisition, owner gains 500 gold
- After 2 rounds, charge 700 gold
- If insufficient, deduct available gold and deal 1 damage per missing 200 gold
- Define and document rounding behavior explicitly

### Price Surge

- Next round minimum raise becomes 150 gold
- Restore it to 50 gold after that round ends

## Suggested Project Structure

```text
scenes/
scripts/
  core/
  models/
  cards/
  ai/
  ui/
data/
  cards/
tests/
```

Suggested responsibilities:

```text
scripts/core/game_flow_controller.gd
scripts/core/rng_service.gd
scripts/core/event_bus.gd
scripts/core/auction_controller.gd
scripts/core/effect_resolver.gd
scripts/models/actor_state.gd
scripts/models/run_state.gd
scripts/models/card_definition.gd
scripts/models/card_instance.gd
scripts/ai/basic_npc_ai.gd
scripts/ui/main_game_ui.gd
tests/test_runner.gd
```

Exact names may differ when the existing repository already defines a coherent structure. Prefer preserving good existing structure over renaming everything.

## GDScript Style

- Use typed variables, parameters, and return values.
- Use `class_name` only for reusable domain types that benefit from global registration.
- Prefer enums or constants over scattered string literals.
- Keep methods focused and reasonably short.
- Use descriptive names.
- Avoid hidden state mutations.
- Avoid deep inheritance hierarchies.
- Prefer composition and explicit services.
- Add comments for non-obvious rules, not for obvious syntax.
- Treat warnings as problems worth fixing.

Example:

```gdscript
func can_bid(actor: ActorState, amount: int) -> bool:
    return actor.alive and not actor.has_passed and amount <= actor.gold
```

## Signals and Events

Use signals or an event bus for gameplay notifications such as:

- `phase_changed`
- `round_started`
- `round_finished`
- `bid_placed`
- `actor_passed`
- `auction_won`
- `card_acquired`
- `card_effect_triggered`
- `damage_applied`
- `gold_changed`
- `actor_died`
- `run_finished`
- `debug_logged`

Gameplay systems must not directly perform UI animations.

## UI Rules

Milestone 1 UI is temporary but must be usable.

Display:

- Round
- Current phase
- Current card name and description
- Starting bid
- Current bid
- Highest bidder
- Player HP and gold
- NPC HP and gold
- Bid
- Pass
- Continue / next phase when applicable
- Debug log
- Seed
- Win / loss result

Use `Container` nodes so the layout does not immediately break at another desktop resolution.

Do not spend time on final pixel-art presentation during Milestone 1.

## Testing

Primary headless command:

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

On macOS, when `godot` is not in PATH, use:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_runner.gd
```

Tests should cover at minimum:

- Same seed produces same card order
- Same seed produces same NPC decisions
- Cannot bid above available gold
- Passed actor cannot re-enter
- Dead actor cannot bid
- Delayed effects trigger at the correct round
- Price Surge restores the minimum raise
- Tied richest or poorest actors are all selected
- Player death produces loss
- Round 10 survival produces victory
- Auction cannot enter an infinite loop

When an automated test is impractical, document a deterministic manual verification procedure in `README.md`.

## Validation Before Completion

Before reporting a task as complete:

1. Run the headless test command.
2. Open or run the main scene if the environment permits.
3. Check Godot parser errors and warnings.
4. Confirm no generated cache files were committed.
5. Confirm deterministic tests pass more than once.
6. Update `README.md` when commands or structure changed.

Never claim tests passed when they were not executed.

If Godot is unavailable in the environment, report that clearly and provide the exact command the user should run.

## Git Rules

Do not commit generated Godot cache files.

The repository `.gitignore` should normally include:

```gitignore
.godot/
.import/
export.cfg
export_presets.cfg
.DS_Store
```

Do not remove user work or rewrite unrelated files.

Keep changes scoped to the requested task.

## Agent Workflow

When beginning a task:

1. Inspect the repository.
2. Read this file and `README.md`.
3. Identify the selected Godot version.
4. Inspect existing scenes, autoloads, tests, and data models.
5. Provide a brief implementation plan.
6. Implement the requested scope.
7. Run tests.
8. Summarize changed files and verification results.

Do not stop after only presenting a plan when implementation was requested.

## Completion Report

At the end of an implementation task, report:

- Files created
- Files modified
- Core behavior implemented
- Commands executed
- Test results
- Known limitations
- Recommended next step

Keep the report factual and concise.
