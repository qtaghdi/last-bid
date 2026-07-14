# AGENTS.md

## Project Overview

**LAST BID** is a single-player auction mind-game built with Godot 4 and GDScript.

The current stable baseline is the completed Milestone 6 visual prototype. It preserves the Milestone 5 gameplay and deterministic RNG while replacing the text-heavy wireframe with a shared visual design system, responsive phase layouts, onboarding, tooltips, feedback, and accessibility settings.

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
- Per-lot `KnowledgeState` for the player and each NPC
- Two player information tokens and PRE_INFO investigation
- Collector, creditor, and gambler subjective valuation
- Deterministic NPC dialogue and limited gambler bluff bids
- Three seal levels and deterministic accident checks
- Open, keep, sell, and burn post-auction actions
- Transfer-aware delayed effects and a three-sealed-card inventory limit
- A NEGOTIATION phase between PRE_INFO and AUCTION
- Mara, Volt, and Sera character profiles built on the existing archetypes
- Five offer types with accept, reject, and one counter-offer
- Hidden goals, emotions, tells, temporary relationships, and one-use emergency abilities
- Six promise types with explicit fulfillment, violation, cancellation, reward, and penalty state
- NPC-specific reputation, five-entry recent memory, and deterministic betrayal decisions
- A themed three-column game shell with reusable participant, card, seal, promise, and result components
- Main menu, first-run coach marks, gameplay term tooltips, violation warnings, toasts, and minimal feedback motion
- Window mode, resolution, UI scale, text size, reduce-motion, tutorial replay, and debug-availability settings

## Required Technology

- Engine: Godot 4.7 stable (`4.7.stable.official.5b4e0cb0f`)
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

## Current Baseline — Milestone 6

The items below are implemented and must remain working. Preserve this baseline unless the user explicitly requests a change. Do not infer or pre-build future milestone features from placeholders in the UI or data.

Included:

- `RUN_SETUP`
- `PRE_INFO`
- `NEGOTIATION`
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
- Playable visual prototype UI
- Automated or headless tests where practical
- Actual card data separated from public and hidden clues
- Per-actor clue allocation and confidence
- Player investigation with two information tokens
- Archetype-specific NPC evaluation and maximum bids
- Deterministic short NPC dialogue
- One or two possible gambler bluff bids per auction
- Phase-specific PRE_INFO, AUCTION, POST_AUCTION, JUDGMENT, ROUND_END, and RUN_RESULT panels
- Shared top HUD, participant status cards, NPC reaction panel, and bottom action bar
- A separate, default-closed debug drawer
- Same-seed and new-seed restart actions
- Responsive 16:9 desktop layout at 1280×720, 1600×900, 1920×1080, and 2560×1440
- A post-auction action must resolve before JUDGMENT can begin
- Three sequential seals with data-driven reveal text and accident effects
- Actual risk tier determines seal accident probability through the central RNG
- Partial opening, sealed-card storage, and a three-card sealed inventory limit
- One player sale proposal per post-auction with target, price, and disclosed clue
- Card burning with cost, burn effects, and delayed-effect cancellation policy
- Ownership transfer with stable instance IDs, history, and remaining counters
- Deterministic collector, creditor, and gambler post-auction decisions
- Zero to two unique living NPC negotiation offers per round
- Buy-card, keep-sealed, share-information, skip-auction, and hold-card offers
- Accept, reject, and one price counter per offer
- Run-scoped relationship scores clamped to `-2...+2`
- Data-driven Mara, Volt, and Sera profiles, tells, secret goals, and dialogue
- Separate deterministic negotiation and dialogue RNG streams
- One-use emergency burn, life collateral, and information theft abilities
- `PromiseState` resources tracked by a dedicated `PromiseManager`
- Skip-auction, keep-sealed, hold-card, transfer-card, share-information, and mutual-pass promises
- Event-driven fulfillment, violation, expiry, cancellation, reward, and penalty resolution
- Run-scoped NPC reputation clamped to `-3...+3`, separate from relationship
- Up to five recent memories per NPC, with severe events retained preferentially
- Personality, reputation, relationship, survival pressure, revenge, and hidden goals in betrayal evaluation
- A deterministic promise/betrayal RNG stream that does not consume gameplay RNG
- Active promise, deadline, violation, reputation, memory, betrayal, result, and DEBUG presentation
- Shared named color, spacing, typography, radius, border, shadow, and motion tokens
- Reusable themed button, panel, card, character, badge, modal, toast, divider, progress, and scroll-list styles
- Three-column game shell with progressive disclosure and phase-specific context rails
- Replaceable portrait texture slots with geometric silhouette placeholders
- Independent three-seal visual state, card status badges, and reveal feedback
- Main menu with new-game, same-seed, seed-input, settings, and quit actions
- First-run PRE_INFO, NEGOTIATION, AUCTION, POST_AUCTION, and promise coach marks
- Fourteen action-oriented gameplay term tooltips
- Player confirmation before promise-violating bids, seal opening, burning, or sale; confirmation does not block forcing the action
- Presentation-only phase fades, price emphasis, damage flash, reveal emphasis, and toasts with reduce-motion support
- Window/fullscreen, resolution, 80/100/120 UI scale, text size, tutorial replay, and debug-availability settings

Excluded:

- Permanent reputation
- Complex multi-condition or three-party contracts
- Permanent promise or reputation persistence between runs
- Repeated negotiation and multiple counter-offers
- Full bluffing systems beyond the gambler's limited auction bluff
- Character jobs
- Passive items
- Shop
- Pixel-art production
- Final character portraits, card illustrations, auction-house background, fonts, and icon production
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
- Negotiation rules and offer resolution
- Promise rules, reputation, memory, and betrayal resolution
- Character personality and run-scoped social state
- Actor state
- RNG
- UI presentation
- Debug logging
- Tests

Do not place the whole game in one script.

### Data-driven cards

Do not hardcode each card directly inside UI scripts or phase-control code.

Use reusable card definitions and effect commands.

Card definitions must keep exact effects separate from public and hidden clues. Normal UI and NPC AI must not read exact effects. NPC evaluation accepts `KnowledgeState`, not `CardDefinition`.

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

### Card instances and post-auction state

`CardInstance` owns per-copy mutable state such as owner, reveal level, opened seals, delay counters, transfer history, sealed/consumed state, and post-auction completion. `CardDefinition` remains immutable shared data.

The UI must never mutate either resource directly. It sends actions to `GameFlowController`, which delegates post-auction rules to `PostAuctionSystem` and effect execution to `CardEffectSystem`.

Auction settlement assigns ownership and charges the winning bid once. It must not fully reveal a card or execute `ON_OPEN`. A player-owned lot cannot advance from `POST_AUCTION` until one valid action resolves it. NPC-owned lots resolve through deterministic NPC policy and remain visible for review before advancing.

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

Negotiation generation, tells, hidden goals, acceptance, and emergency-use rolls use the dedicated deterministic negotiation RNG. Dialogue selection uses a separate deterministic dialogue RNG. Neither stream may consume the gameplay RNG.

Promise offer priority variation, NPC promise-breaking decisions, and revenge checks use a dedicated deterministic promise RNG. It must remain separate from gameplay, negotiation, and dialogue RNG streams.

Negotiation evaluation accepts `KnowledgeState` and public instance state. It must not inspect exact card effects or use `CardDefinition.effects` to choose an offer.

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

## Implemented Prototype Cards

These six Milestone 1 cards are implemented and covered by regression tests.

### Cursed Vault

- Owner gains 120 gold at each `ROUND_END`
- After 3 rounds, owner takes 2 damage
- Works while sealed and follows the current owner on transfer
- Burning costs 150 gold and deals 1 damage to the burner

### Broken Chalice

- After full opening, prevent the owner's next lethal damage once
- Consume after triggering

### Black Ledger

At each `JUDGMENT`:

- Richest living actor gains 80 gold
- Poorest living actor takes 1 damage

Ties affect every tied actor.

It works while sealed and follows the current owner.

### Golden Gallows

At the next `JUDGMENT`:

- Every richest living actor takes 2 damage
- Consume after triggering
- It works while sealed and follows the current owner

### Blood Loan

- On full opening, opener gains 500 gold
- After 2 rounds, charge 700 gold
- If insufficient, deduct available gold and deal 1 damage for each started 200 gold of shortage
- Shortage damage rounds up (`ceil(shortage / 200)`)
- The opener remains the debtor after transfer or burning (`STAY_WITH_ORIGINAL_OWNER`)

### Price Surge

- On full opening, next round minimum raise becomes 150 gold
- Restore it to 50 gold after that round ends
- It is non-transferable and can be burned for removal

## Current Project Structure

```text
scenes/
  main.tscn
  ui/
scripts/
  core/       # Game flow, auction, events, constants, central RNG
  models/     # Run, actor, and knowledge state
  cards/      # Card data types, catalog, instances, and effect resolution
  ai/         # NPC evaluation, decisions, bluffing, and dialogue
  knowledge/  # Per-actor clue distribution and investigation
  ui/         # Presentation-only component scripts
data/
  cards/      # Card Resource data
  npcs/       # Character profiles, secret goals, tells, and dialogue
tests/        # Headless regression runner
themes/       # Shared UI Theme resources
```

Key responsibilities:

```text
scripts/core/game_flow_controller.gd  # Main phase authority and public actions
scripts/core/auction_system.gd        # Bid/pass rules and settlement
scripts/core/central_rng.gd           # Seeded gameplay randomness
scripts/core/event_bus.gd             # Gameplay and presentation events
scripts/core/post_auction_system.gd   # Seals, accidents, keep/sale/burn/transfer
scripts/core/negotiation_system.gd    # Offers, relationships, emotions, goals, tells
scripts/core/promise_manager.gd       # Promise lifecycle, reputation, memory, betrayal
scripts/cards/card_effect_system.gd   # Immediate and delayed effect resolution
scripts/knowledge/information_service.gd
scripts/ai/simple_npc_ai.gd
scripts/ui/main_ui.gd                 # Phase-aware presentation orchestration
tests/test_runner.gd                  # Deterministic headless regression suite
```

Preserve these responsibility boundaries. Renaming or relocating them requires a concrete architectural reason and corresponding documentation updates.

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
- `card_consumed`
- `damage_applied`
- `gold_changed`
- `actor_died`
- `run_finished`
- `debug_logged`
- `knowledge_changed`
- `information_tokens_changed`
- `npc_evaluation_ready`
- `npc_dialogue_spoken`
- `post_auction_started`
- `post_auction_completed`
- `seal_opened`
- `seal_accident_triggered`
- `card_opened`
- `card_kept`
- `sale_proposed`
- `sale_accepted`
- `sale_rejected`
- `card_transferred`
- `card_burned`
- `inventory_limit_reached`
- `card_owner_changed`
- `negotiation_started`
- `negotiation_finished`
- `offer_created`
- `offer_countered`
- `offer_accepted`
- `offer_rejected`
- `relationship_changed`
- `emotion_changed`
- `tell_triggered`
- `secret_goal_progressed`
- `emergency_ability_used`
- `promise_created`
- `promise_accepted`
- `promise_fulfilled`
- `promise_broken`
- `promise_expired`
- `promise_cancelled`
- `reputation_changed`
- `npc_memory_added`
- `betrayal_committed`
- `betrayal_reacted`
- `active_promises_changed`

Gameplay systems must not directly perform UI animations.

## UI Rules

The Milestone 6 visual prototype is the current playable UX baseline and must remain usable without reading the debug log.

Display:

- Round
- Current phase
- Public lot name and player-known structured clues
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
- Player-known clue subset and information-token count
- PRE_INFO investigation action
- NPC recent dialogue and auction status
- Debug-only actual information, knowledge, evaluation, maximum bid, and bluff state
- Phase-specific panels that hide actions unavailable in the current phase
- A judgment summary with triggered cards, targets, HP/gold changes, deaths, and consumed cards
- Result statistics with same-seed and new-seed restart actions
- Post-auction seal progress, next accident probability, owner, and sealed inventory usage
- Open, keep, sell, and burn controls with disabled reasons
- Sale target, price, and disclosed-clue selection
- Exact identity and effects only after the third seal or in DEBUG
- Negotiation issuer, emotion, tell, dialogue, terms, target, and relationship
- Accept, reject, and one counter-offer action during NEGOTIATION
- Participant character name, emotion, recent tell, relationship, and emergency-use state
- Hidden goals, offer scores, acceptance thresholds, tell reliability, and RNG state only in DEBUG
- Promise type, public target, deadline, immediate reward, fulfillment reward, and violation penalty before acceptance
- Active promises with remaining deadline, violation condition, and direct fulfillment action where applicable
- NPC reputation, one recent memory summary, active promise count, and recent betrayal state
- Promise fulfillment, violation, cancellation, and NPC betrayal results outside the debug log
- Full PromiseState fields, betrayal scores, memory severity, internal IDs, and promise RNG state only in DEBUG
- Main menu and same-seed/explicit-seed start actions
- A three-column information hierarchy with secondary participant details collapsed by default
- Three independent seal slots and card status badges that also use text or symbols, not color alone
- First-run coach marks that show one step at a time, can be skipped or disabled, and can be replayed from settings
- Tooltips for risk, value, timing, target, seals, accident chance, tells, relationship, reputation, promises, betrayal, delayed effects, judgment, and information tokens
- Confirmation before a player intentionally violates an active promise, while preserving the option to proceed
- Window/fullscreen, supported resolution, UI scale, text size, reduce-motion, tutorial, and debug availability controls

Use `Container` nodes so the layout does not immediately break at another desktop resolution.

Keep palette and interactive states in a shared Theme or UI palette rather than scattering colors through scripts and scenes.

Treat the visual prototype as non-production presentation. Do not add final pixel art, final illustrations, audio, or elaborate animation unless explicitly requested.

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
- Same seed produces the same clue allocation, dialogue, and bluff intent
- Investigation consumes exactly one token and never duplicates clues
- NPC AI does not accept `CardDefinition` or access `effects`
- Each archetype values its preferred known tags more highly
- PRE_INFO and AUCTION show only their valid actions and normal UI never exposes exact card data
- Player-turn, passed, insufficient-gold, and zero-information-token disabled states
- Investigated clues, highest bidder, judgment summary, phase panel visibility, and same-seed restart
- The combined minimum layout fits the 1280×720 content area
- The root UI expands in a 1920×1080 viewport
- Post-auction cannot advance before resolution and executes only once
- Seal percentages match the risk table and accidents replay with the same seed
- Third-seal opening reveals exact information and executes `ON_OPEN`
- Inventory, sale, burn, and all transfer-policy guards
- NPC post-auction archetype preferences and deterministic decisions
- Twenty seeded full runs finish without an infinite loop after post-auction actions
- PRE_INFO transitions to NEGOTIATION and unresolved offers block AUCTION
- At most two unique living NPCs offer per round, deterministically
- Offer acceptance, rejection, counter limits, payment, information, and forced-pass effects
- Relationship bounds/reset and influence on generation, price, and acceptance
- Character emotions, tell pools/reliability, hidden-goal selection, and normal-UI secrecy
- Mara, Volt, and Sera emergency abilities are one-use
- Dialogue is data-driven and dialogue/negotiation RNG do not consume gameplay RNG
- Twenty seeded full runs finish with negotiation enabled
- Accepted offers create unique typed PromiseState resources and rejected offers do not
- All six promise types fulfill and break on their documented events
- Immediate rewards, fulfillment rewards, and penalties are applied at most once
- Reputation and relationship remain within their independent bounds and reset on a new run
- NPC memories are limited to five and affect offers, counters, dialogue, and betrayal
- Mara, Volt, and Sera have distinct deterministic betrayal behavior
- Actor death and destroyed-card policies cancel or resolve promises without penalizing unavoidable failure
- Active promise and result UI hides internal IDs while DEBUG exposes full state
- Twenty seeded full runs finish with promise acceptance enabled
- The shared Theme and required reusable style resources load successfully
- Main menu, settings, first-run onboarding, skip/disable/replay, tooltips, and feedback layers remain operational
- Participant cards keep secondary relationship, reputation, tell, memory, and promise details collapsed by default
- Three seal slots reflect sealed, partially opened, and fully revealed state
- Promise-violating actions warn first and can still be forced by the player
- All phase layouts fit 1280×720 at 80%, 100%, and 120% UI scale
- Root UI expands at 1280×720, 1600×900, 1920×1080, and 2560×1440
- Three simultaneous active promises remain usable without overflowing the minimum layout

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

Read and follow `CONTRIBUTING.md` for the authoritative branch, commit, PR, merge, and release conventions.

Required summary:

- Keep `main` runnable and passing tests.
- Work on a short-lived typed branch; automation uses `codex/<type>-<description>`.
- Use `type(scope): imperative summary` Conventional Commits.
- Prefer atomic commits and one purpose per PR.
- Use Squash and merge by default and keep the squash title convention-compliant.
- Do not rewrite a shared branch or force push without coordination.
- Do not commit generated Godot cache files, secrets, or local-only artifacts.

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
2. Read this file, `README.md`, and `CONTRIBUTING.md`.
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
