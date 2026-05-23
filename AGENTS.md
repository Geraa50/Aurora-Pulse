# AGENTS.md — Aurora-Pulse

Godot 4 + GDScript. Triple Mahjong. Touch-only release. See `docs/DEVELOPMENT_PLAN.md`.

## Commands

```bash
# Index codebase (after clone)
ast-index rebuild

# Open project
# Godot → Import → game/project.godot
```

## Layout

- `game/` — Godot project
- `docs/` — plan, tools, assets licenses
- `features/` — DAE feature specs
- `tools/` — submodules (ast-index, caveman, dae)

## Agent tools

- **ast-index** — search GDScript symbols before grep
- **caveman** — terse replies; code stays normal
- **DAE** — spec-first for `features/*` (Claude Code plugins in `tools/dae`)

## Hackathon must-haves

1. One complete level  
2. Touch-only  
3. Score or progress HUD  
4. Licensed assets in `docs/ASSETS.md`
