# Настройка инструментов разработки

Инструменты подключены как **git submodules** в `tools/` и через конфиг **Cursor** в `.cursor/`.

## Статус (локально)

| Инструмент | Submodule | CLI / Cursor | Примечание |
|------------|-----------|--------------|------------|
| [ast-index](https://github.com/defendend/Claude-ast-index-search) | `tools/ast-index` | `winget install defendend.ast-index` | Индекс: `ast-index rebuild` в корне репо |
| [caveman](https://github.com/JuliusBrussee/caveman) | `tools/caveman` | Skills в `~/.cursor/skills` | Правило: `.cursor/rules/caveman.mdc` |
| [DAE](https://github.com/swingerman/disciplined-agentic-engineering) | `tools/dae` | Claude Code plugins | Правило: `.cursor/rules/dae.mdc` |

После клонирования репозитория:

```powershell
git submodule update --init --recursive
```

---

## ast-index

**Установка (Windows):**

```powershell
winget install --id defendend.ast-index
```

**Индекс проекта:**

```powershell
cd C:\Users\Geraa\Desktop\pulse
ast-index rebuild
ast-index search Tile
```

**Cursor**

- Правило: `.cursor/rules/ast-index.mdc`
- Локальный marketplace: `.cursor-plugin/marketplace.json` → плагин из `tools/ast-index/plugin`
- В Cursor: *Settings → Rules / Plugins* — добавить marketplace из репо или symlink:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.cursor\plugins\local" | Out-Null
cmd /c mklink /J "$env:USERPROFILE\.cursor\plugins\local\ast-index" "C:\Users\Geraa\Desktop\pulse\tools\ast-index\plugin"
```

Перезагрузить Cursor.

**MCP (опционально):** бинарник `ast-index-mcp` не входит в winget-пакет. Собрать из submodule:

```powershell
# нужен Rust toolchain
cd tools\ast-index
cargo build --release -p ast-index-mcp
# скопировать target\release\ast-index-mcp.exe в PATH
```

Скопировать `.cursor/mcp.json.example` → `%USERPROFILE%\.cursor\mcp.json` и поправить пути.

---

## caveman

**Глобально (Cursor):**

```powershell
npx skills add JuliusBrussee/caveman -a cursor --yes
```

**Правило в репозитории (always-on):** уже есть `.cursor/rules/caveman.mdc`.

Переустановка из submodule:

```powershell
cd tools\caveman
node bin/install.js --only cursor --non-interactive
```

В сессии: `/caveman` или «caveman mode». Отключить: «normal mode».

---

## Disciplined Agentic Engineering (DAE)

Ориентирован на **Claude Code**. В Cursor используйте правила и папку `features/`.

**Claude Code:**

```text
/plugin marketplace add swingerman/disciplined-agentic-engineering
/plugin install engineer@disciplined-agentic-engineering
/plugin install atdd@disciplined-agentic-engineering
```

Локальный запуск marketplace из submodule:

```bash
claude --plugin-dir ./tools/dae
```

**В этом репо**

- `CHARTER.md` — архитектура и соглашения (заполнить на onboard)
- `features/NNN-name/` — `feature.md`, `acs.md`, `spec.md`, `plan.md`
- `.cursor/rules/dae.mdc` — краткий workflow для агента

---

## Обновление submodules

```powershell
git submodule update --remote tools/ast-index tools/caveman tools/dae
```

Коммитить указатель submodule после проверки совместимости.
