# Aurora-Pulse

Triple Mahjong (match-3 tiles) for the [Devfest Hackathon](https://www.devfest.ru/program/2dc181dc-2adf-47bf-af8d-b80f43d16fd2/).  
Prototype in **Godot 4** (GDScript), target port **Aurora OS** (touch-only).

## Repo

https://github.com/Geraa50/Aurora-Pulse

## Quick start

```powershell
git clone https://github.com/Geraa50/Aurora-Pulse.git
cd Aurora-Pulse
git submodule update --init --recursive
```

1. Install [Godot 4.3+](https://godotengine.org/) and open `game/project.godot`.
2. Read the dev plan: [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md).
3. Agent tooling: [`docs/TOOLS_SETUP.md`](docs/TOOLS_SETUP.md).

## Hackathon requirements

| Requirement | Status |
|-------------|--------|
| ≥ 1 complete level | Planned (Phase 2) |
| Touch-only control | UI buttons; no keyboard in export |
| Progress | HUD stub in `game/scenes/game.tscn` |
| Original / open assets | Track in [`docs/ASSETS.md`](docs/ASSETS.md) |

## Project layout

```
game/           Godot project
docs/           Plan, tools, asset licenses
features/       DAE feature specs (optional)
tools/          ast-index, caveman, DAE (submodules)
.cursor/        Cursor rules for agents
```

## Development plan

Full roadmap (RU): **[docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md)**

## Tools

| Tool | Purpose |
|------|---------|
| [ast-index](https://github.com/defendend/Claude-ast-index-search) | Fast GDScript symbol search |
| [caveman](https://github.com/JuliusBrussee/caveman) | Shorter agent replies in Cursor |
| [disciplined-agentic-engineering](https://github.com/swingerman/disciplined-agentic-engineering) | Spec-first / ATDD (Claude Code + `features/`) |
