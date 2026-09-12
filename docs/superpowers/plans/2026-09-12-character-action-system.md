# Character Action System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the player circle placeholder with a reusable, pure-Dart character action controller and a manifest-driven Flame renderer, while preserving position sync, camera follow, zoom, and the existing `PlayerComponent({required position})` entry point.

**Architecture:** Small channel enums compose one immutable `CharacterAction`. A pure-Dart catalog, capability registry, controller, and resolver own action selection, fallback, interruption, resume, elapsed time, normalized progress, and frame index. A typed manifest and pure validator own sheet geometry. `CharacterComponent` is the only Flame adapter and renders the controller-selected frame from a `SpriteAnimation` without a second ticker. `PlayerComponent` remains world-position owner and façade; `UniversalOverworldGame` remains lifecycle, position, and camera owner.

**Tech Stack:** Dart 3.11, Flutter, Flame 1.38.2, `dart test` for domain, `flutter test` for Flame smoke tests. No new package.

**Spec:** `SPEC_MVP_CHARACTER_ACTION.md` (Approved v6)

## Global Constraints

- Work only in isolated worktree `/Users/appgongyong/share_tour/.worktrees/character-action-plan`, branch `feature/character-action-plan`. Do not edit or commit from primary checkout.
- Preserve unrelated dirty changes in primary checkout. Do not copy its untracked character assets or day/night edits into this branch.
- Follow TDD: RED test, GREEN implementation, focused test, then refactor. Every task ends with a focused verification and Conventional Commit.
- Before `flutter analyze` or `flutter test`, run `dart run build_runner build --delete-conflicting-outputs`. Generated `*.freezed.dart` and `*.g.dart` stay untracked.
- `lib/domain/character_action/` must import only Dart libraries. No Flutter, Flame, Riverpod, GPS, location, time, event, inventory, stamina, quest, or NPC behavior imports.
- Keep action commands and position synchronization separate. No per-frame inference from position, speed, GPS, or rendered-pixel delta.
- Keep `run` and `dash` as separate action identities. Never silently reuse dialogue, halfbody, portrait, expression, or another action's overworld asset.
- Current clean baseline has no committed character sheets and no `switchMap` in `UniversalOverworldGame`; asset completion and map-switch verification are explicit gates, not reasons to expand this feature into map work.
- Do not claim full-suite green until existing `assets/audio/` and generated-file baseline issues are resolved independently. Feature verification may use targeted tests while those external gates remain open.

## File and API Contract

Use these files unless implementation evidence requires a narrower equivalent; keep public names stable for tests and later NPC reuse.

- `lib/domain/character_action/character_direction.dart`: `CharacterDirection { front, left, back, right }`.
- `lib/domain/character_action/character_action.dart`: channel enums and immutable `CharacterAction`; canonical key format; shorthand normalization; same-channel conflict exception. Default action is `idle + standing + none + none + none`.
- `lib/domain/character_action/character_action_descriptor.dart`: immutable `CharacterActionDescriptor` with action, `loop`, `priority`, `canInterrupt`, `fallbackAction`, and `animationKey`; `CharacterActionDescriptorRegistry` keyed by canonical action key.
- `lib/domain/character_action/character_animation_manifest.dart`: pure manifest records, `AssetKind`, `DirectionAxis`, `PixelPoint`, `PixelPadding`, `PixelSpacing`, and `CharacterAnimationManifest`.
- `lib/domain/character_action/character_animation_resolver.dart`: deterministic exact-action/direction lookup and `ResolvedCharacterAnimation`; no capability checks, clock, or frame advancement.
- `lib/domain/character_action/character_action_state.dart`: immutable `CharacterActionState`, normalized resume snapshot, resolved animation, elapsed, frame index, and completion flag.
- `lib/domain/character_action/character_capability_registry.dart`: pure character capability lookup for special canonical keys; absent capability rejects special action before fallback resolution.
- `lib/domain/character_action/character_action_controller.dart`: sole playback clock; `play`, `setDirection`, `stop`, `update`; exposes current state and resolved animation; owns one resume snapshot only.
- `lib/domain/character_action/character_manifest_validator.dart`: pure structural/layout validator over manifest records plus decoded `CharacterSheetInfo`; rejects all Phase 0 malformed cases without decoding images itself.
- `lib/game/characters/character_asset_loader.dart`: Flame/image adapter that loads `assets/images/<assetPath>` exactly once, decodes RGBA metadata, and supplies sheet info/sprites to the component.
- `lib/game/components/character_component.dart`: Flame adapter; owns local render child, `SpriteAnimation`, anchor, filter quality, and controller update path. It never owns world position or a second ticker.
- `lib/game/components/player_component.dart`: compatibility façade and world-position owner; forwards action/direction to `CharacterComponent`/controller; no action policy.
- `lib/game/universal_overworld_game.dart`: optional character manifest and initial action/direction inputs; façade command methods; existing map, position, camera, zoom, and lifecycle flow preserved.
- `test/domain/character_action/`: pure-Dart model, manifest, resolver, controller, and architecture tests.
- `test/game/character_component_test.dart`, `test/game/player_component_test.dart`, `test/game/universal_overworld_game_test.dart`: Flame adapter and regression smoke tests.

## Phase 0 — Asset Contract and Manifest Validation

### Task 0.1 — Establish clean baseline evidence

- [ ] Record `git status --short --branch`, `git worktree list`, and current test blockers in branch notes or task log; do not alter unrelated files.
- [ ] Run codegen, then targeted existing player/game tests. Preserve evidence that clean checkout is blocked by missing `assets/audio/` and that generated artifacts are environment outputs.
- [ ] Inspect any supplied character sheets with an image metadata tool before adding manifest records. If no valid RGBA sheets exist, keep real-asset integration gated and use synthetic decoded sheet metadata only in validator tests.
- [ ] Commit only if a small baseline note is needed; otherwise leave no code change.

### Task 0.2 — Add manifest value objects and geometry tests

- [ ] Add RED tests for `AssetKind`, row/column direction axes, positive dimensions/count/FPS/render size, normalized anchor, non-negative source origin/padding/spacing, canonical animation key, and immutable record equality.
- [ ] Implement manifest value objects in `lib/domain/character_action/character_animation_manifest.dart`.
- [ ] Add table-driven RED tests for region formulas:
  - row: `width = left + count*frameWidth + (count-1)*horizontal + right`; `height = top + 4*frameHeight + 3*vertical + bottom`;
  - column: `width = left + 4*frameWidth + 3*horizontal + right`; `height = top + count*frameHeight + (count-1)*vertical + bottom`;
  - first frame origin is `sourceOrigin + (left, top)`;
  - direction index is `front=0,left=1,back=2,right=3`, vertical for row and horizontal for column.
- [ ] Implement pure geometry helpers returning frame origins; reject negative or overflow arithmetic inputs.
- [ ] Run `dart test test/domain/character_action/character_animation_manifest_test.dart` and commit `feat: define character animation manifest contract`.

### Task 0.3 — Add pure manifest validator

- [ ] Add RED tests for every AC-CA-09 rejection: non-RGBA, illegal sizes/count/FPS including non-finite FPS, illegal anchor/render size/padding/spacing, undecodable/missing asset metadata, row/column boundary overflow, missing/duplicate direction, duplicate action/animation keys, non-overworld asset kind, shared run/dash identity, invalid/cyclic fallback, and non-transparent declared padding.
- [ ] Add tests proving zero-padding fully opaque frames pass and unregistered optional actions are not load errors.
- [ ] Implement `CharacterSheetInfo` as pure decoded metadata (`width`, `height`, `hasAlpha`, alpha sampling) and `CharacterManifestValidator` with finite, bounded, cycle-safe checks.
- [ ] Keep image decoding outside domain; validator receives metadata rather than `dart:ui.Image`.
- [ ] Run targeted validator tests and commit `feat: validate character animation manifests`.

### Task 0.4 — Add manifest fixtures and asset gate

- [ ] Add pure fixture builders for one valid RGBA four-direction row sheet and one valid column sheet; include nonzero source origin, padding, and spacing so formulas are exercised.
- [ ] Add tests confirming all four direction records for declared `idle` and declared actions share path/layout/source origin/frame geometry/render size, and optional unregistered actions resolve only at runtime.
- [ ] If valid production character sheets are available, add their manifest records and bundle-path tests. If not, document Phase 2 as blocked on RGBA conversion and fixed male/female sheet dimensions; do not invent production assets or use dialogue art.
- [ ] Commit fixture/contract changes only, `test: cover character manifest fixtures`.

## Phase 1 — Pure-Dart Playback Core

### Task 1.1 — Implement action channels and canonicalization

- [ ] Add RED tests for defaults, equality across all channels, exact canonical field order/casing, `sit`, `drink`, `sit + drink`, `walk + oneHand`, and `run + guide.point`.
- [ ] Add RED tests proving duplicate values in one channel are rejected instead of last-write-wins; unknown shorthand and invalid special namespace are rejected.
- [ ] Implement small channel enums plus immutable `CharacterAction`, `canonicalKey`, and `fromShorthand(Iterable<String>)`; represent absent special as canonical `special=none`.
- [ ] Run `dart test test/domain/character_action/character_action_test.dart`; commit `feat: add composable character actions`.

### Task 1.2 — Implement descriptors and capability registry

- [ ] Add RED tests for fixed priorities/fallbacks of `idle`, `walk`, `run`, `eat`, `drink`, `sleep`, `dash`, and `jump`; special descriptors require explicit priority/loop/canInterrupt/fallback.
- [ ] Add RED tests proving no implicit special priority, no descriptor inheritance for unregistered combinations, capability denial, and fallback target existence.
- [ ] Implement `CharacterActionDescriptor`, registry lookup by canonical key, and `CharacterCapabilityRegistry` keyed by character id and special canonical key.
- [ ] Run descriptor/capability tests; commit `feat: add character action descriptors`.

### Task 1.3 — Implement deterministic resolver

- [ ] Add RED tests for exact character/action/direction lookup, resolved metadata completeness, stable animation key, asset kind enforcement, and no time/random/global-state dependency.
- [ ] Implement resolver as a pure lookup over validated manifest data. It returns no frame advancement; controller supplies current frame index.
- [ ] Add tests proving unregistered canonical actions do not decompose into locomotion or special descriptors and resolve directly through character idle fallback policy.
- [ ] Run `dart test test/domain/character_action/character_animation_resolver_test.dart`; commit `feat: resolve character animations deterministically`.

### Task 1.4 — Implement state machine and single clock

- [ ] Add RED table-driven tests for duration `frameCount/fps`, first frame, loop after one/two durations, non-loop last frame and one-time completion, normalized direction progress, same-action no reset, and action-switch reset.
- [ ] Add RED interruption tests: sleep rejects walk; jump overrides lower priority; same-priority special cannot bypass non-interruptible action; eat can replace same-priority interruptible action; rejected command preserves state.
- [ ] Add RED resume tests for `walk → dash → jump → walk`, single resume snapshot under nested one-shots, invalid resume fallback, and `stop()` clearing resume state in `walk → dash → stop → jump → idle`.
- [ ] Implement `CharacterActionState` and `CharacterActionController`. `update(dt)` is only elapsed/frame/completion mutator; reject non-finite/negative `dt`; loop wraps, non-loop clamps; completion restores one resume snapshot or valid fallback/idle.
- [ ] Run all pure core tests, then `dart test test/domain/character_action/`; commit `feat: add single-clock character action controller`.

### Task 1.5 — Enforce pure-domain boundary

- [ ] Add/update architecture test scanning `lib/domain/character_action/**/*.dart` for forbidden Flutter, Flame, Riverpod, GPS/location, and vector UI imports.
- [ ] Run architecture plus all character domain tests; commit `test: enforce pure character action boundary`.

## Phase 2 — Flame Wiring

### Task 2.1 — Add asset loader and manual SpriteAnimation frame adapter

- [ ] Add RED component tests around a synthetic in-memory/fixture RGBA sheet: exact relative asset path, row/column frame source positions, no duplicate `assets/images/` prefix, normalized anchor, logical render size, and `FilterQuality.none`.
- [ ] Implement `CharacterAssetLoader` outside domain. Use Flame image loading once; construct `Sprite` frames from manifest source origins/padding/spacing and store them in a `SpriteAnimation` with manifest FPS/loop metadata.
- [ ] Implement `CharacterComponent` as a `PositionComponent` with a local-zero `SpriteComponent` child. On every `update(dt)`, call controller exactly once, select controller frame index, and render; do not attach a ticker or let `SpriteAnimation` advance itself.
- [ ] Keep unloaded/no-manifest compatibility renderer as existing red placeholder so old constructor can instantiate without synchronous image decode.
- [ ] Run `flutter test test/game/character_component_test.dart`; commit `feat: add manifest-driven character component`.

### Task 2.2 — Convert PlayerComponent to façade

- [ ] Extend existing tests for old constructor, `syncTo` copy semantics, world position unchanged by async load, pre-load `play`/`setDirection` retained through first render, and local child position zero.
- [ ] Replace circle ownership with façade ownership while preserving `PlayerComponent({required position})`; manifest/loader dependencies remain optional or injected through a non-breaking factory/setter.
- [ ] Forward `play(action)` and `setDirection(direction)` only; do not duplicate action state or playback clock. `syncTo` changes only façade world position.
- [ ] Run player component tests; commit `refactor: make player component character facade`.

### Task 2.3 — Wire UniversalOverworldGame commands

- [ ] Add RED tests for optional `initialAction`/`initialDirection`, default idle/front, invalid initial fallback, command forwarding after load, and no direct player reference before creation.
- [ ] Add `playPlayerAction(CharacterAction)` and `setPlayerDirection(CharacterDirection)`; pass initial values to PlayerComponent; keep `onTick → syncTo → cameraFollow.targetCenter` order and all existing zoom/tap/lifecycle behavior.
- [ ] Verify update calls do not mutate action without command and command does not mutate position without sync.
- [ ] Run `flutter test test/game/player_component_test.dart test/game/universal_overworld_game_test.dart` and commit `feat: expose character commands from overworld game`.

### Task 2.4 — Integration regression gate

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] Run targeted character domain/game tests, `flutter analyze`, and existing map/camera tests.
- [ ] If `switchMap` exists in this branch by an independent change, add regression coverage only; otherwise record gate as not present and do not implement map switching here.
- [ ] Verify component add/remove lifecycle and camera follow/zoom behavior before committing `test: verify character overworld integration`.

## Phase 3 — Generic Life Actions

### Task 3.1 — Add pure action aliases and descriptors

- [ ] Add tests and descriptors for `eat`, `drink`, `sleep`, `crouch → posture=crouching`, `sit → posture=sitting`, `supine`, `prone`, `oneHand`, and `twoHands`.
- [ ] Add only animation commands and manifest records; no inventory, time, stamina, event, quest, or gameplay side effects.
- [ ] Run pure domain tests and commit `feat: add generic character life actions`.

### Task 3.2 — Wire available life-action assets

- [ ] Add only validated RGBA overworld records; missing optional records must follow explicit descriptor fallback or idle.
- [ ] Add targeted Flame smoke tests for one-shot/loop rendering and fallback; do not convert dialogue or halfbody assets.
- [ ] Run targeted tests and commit `feat: wire generic character life animations`.

## Phase 4 — NPC and Special Registry

### Task 4.1 — Reuse core for special actions

- [ ] Add `CharacterLayerComponent` only if multiple characters require common world-layer lifecycle; keep controller/resolver shared.
- [ ] Register `guide.point`, `guide.waveFlag`, `protagonist.inspectArtifact`, `npc.openShop`, and `npc.greet` only when each character has capability and valid four-direction overworld records.
- [ ] Add tests for capability denial, explicit special descriptor fields, namespaced canonical keys, and fallback to idle without NPC decision logic.
- [ ] Commit `feat: add character special action registry`.

### Task 4.2 — Final acceptance gate

- [ ] Run codegen, all pure character tests, targeted Flame tests, architecture tests, and `flutter analyze`.
- [ ] Run full `flutter test` only after unrelated `assets/audio/` baseline dependency is present; record pre-existing failures separately from character-action failures.
- [ ] Verify AC-CA-01 through AC-CA-18 against tests and source review: no second clock, no duplicate action state, no forbidden domain imports, no position/action coupling, no semantic asset fallback.
- [ ] Produce verification note with commands, pass/fail output, asset gate status, and map-switch gate status before claiming completion.

## Stop Conditions

- Stop before Phase 2 real-sprite integration if no RGBA overworld sheets pass manifest validation. Core and synthetic validator work may continue.
- Stop and report if adding a requested feature requires GPS, inventory, time, event, stamina, quest, or NPC behavior dependencies.
- Stop before full-suite completion while `assets/audio/` remains absent from clean checkout; do not “fix” by copying primary worktree untracked files.
- Stop before map-switch assertions if current branch still lacks `switchMap`; do not broaden scope.
