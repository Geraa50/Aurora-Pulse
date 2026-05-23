# Aurora-Pulse — Project Charter (DAE)

> Черновик. Уточните на onboard (DAE checkpoint 0).

## Purpose

Touch-first Triple Mahjong for Devfest; prototype in Godot 4 (GDScript), port target Aurora OS.

## Architecture

- **Layers:** `scenes` (presentation) → `scripts/board|rules|levels` (domain) → `autoload` (app state). No gameplay logic in UI nodes beyond binding.
- **Dependencies:** UI may call `GameState` and board API; `match_rules` has no scene/node deps.
- **Forbidden:** keyboard-required gameplay in export builds; paid/asset-store art without license file.

## Conventions

- GDScript 2.x, typed where helpful
- Snake_case files, PascalCase node types in docs
- One level data file per level under `game/scripts/levels/` or `game/data/`

## Quality

- Unit tests for `match_rules.gd` before level polish
- Manual touch QA on target aspect ratio (9:16)

## Autonomy

- Agent may implement approved specs in `features/` without changing charter
- Charter changes require human sign-off

## Verification

- Hackathon checklist in `docs/DEVELOPMENT_PLAN.md` §1
- Optional: GUT + Gherkin from DAE `atdd` plugin
