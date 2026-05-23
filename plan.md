# Aurora-Pulse — План разработки

**Игра:** Triple Mahjong (Match-3 по тройкам)
**Движок:** Godot **4.4.1** + GDScript
**Цель:** Devfest Hackathon → порт на **Aurora OS** (touch-only)
**Базовое разрешение:** 1080×1920, portrait, `stretch.aspect=expand` — адаптация под телефон и планшет через якоря Control.

> Полный, детализированный план: [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md).
> Этот `plan.md` — краткий roadmap верхнего уровня и трекер фаз для агентов / DAE.

---

## Дисплей: единый layout телефон + планшет

| Параметр | Значение | Зачем |
|----------|----------|-------|
| `viewport` | 1080×1920 | Дизайн-референс портретного FHD |
| `stretch/mode` | `canvas_items` | Контент масштабируется, шрифты остаются чёткими |
| `stretch/aspect` | `expand` | На 9:21 (узкий телефон) и 3:4 (планшет) — **нет чёрных полос**, край UI заполняется через якоря |
| `handheld/orientation` | `1` (portrait) | Жёстко portrait, по ТЗ хакатона |
| `default_texture_filter` | `1` (Linear) | Чистая отрисовка плиток при любом DPI |

**Правило для UI:** все экраны строятся на `MarginContainer → VBoxContainer/HBoxContainer` с `anchors_preset=15` (full rect) у корня. Никаких абсолютных `offset_top=1200`. Минимальный размер кнопок `≥ 96 px` (≈ 48 dp на 2x плотности) — touch-friendly.

---

## Чеклист хакатона

- [ ] ≥ 1 завершённый уровень (победа + restart)
- [ ] Только касания (никаких обязательных hotkey в release)
- [ ] HUD: очки + прогресс (плитки/звёзды)
- [ ] Все ассеты в `docs/ASSETS.md` с лицензией
- [ ] Запись геймплея 30–60 с
- [ ] README с инструкцией сборки

---

## Фазы

### Фаза 0 — Окружение ✅ (закрыто)

- [x] Git submodules: `tools/ast-index`, `tools/caveman`, `tools/dae`
- [x] `.cursor/rules/` для агентов (+ дефолт `caveman lite`, конфиг `.ast-index.yaml`)
- [x] Godot 4.4.1 — `game/project.godot` адаптирован под телефон+планшет
- [x] Базовые сцены `main_menu.tscn`, `game.tscn` на якорях
- [x] Гайд стилистики: [`docs/STYLE.md`](docs/STYLE.md)

### Фаза 1 — Ядро механики ✅ (MVP закрыт)

| # | Задача | Статус |
|---|--------|--------|
| 1.1 | `tile.tscn` + `tile.gd` (id, type, layer, x, y) + цвет масти + цифра ранга + hover/press/shake/clear | ✅ |
| 1.2 | `match_rules.gd`: `is_tile_free` (учитывает `on_board`), `is_valid_triple`, `has_any_triple` | ✅ |
| 1.3 | `board.tscn` + `board.gd`: абсолютное позиционирование по (x, y, layer) + слоты выбора | ✅ |
| 1.4 | Выбор 3 одинаковых → удаление + очки, неуспех → возврат на поле | ✅ |
| 1.5 | Детект тупика через `MatchRules.has_any_triple` + пересборка уровня | ✅ |
| 1.6 | Многослойная пирамидальная форма + reverse-simulation генератор | ✅ |

Логика клика (см. `tz.md`): тап по свободной плитке → press-bounce → она переезжает в первый свободный слот (`state = IN_SLOT`, временно открывает перекрытые нижние плитки). Тап по заблокированной → shake + отказ. Когда 3 слота заполнены → авто-проверка тройки.

> **Feature DAE:** `features/001-core-triple-match/` (будет создана по ходу полировки).

### Фаза 2 — Один завершённый уровень ✅ (MVP закрыт)

| # | Задача | Статус |
|---|--------|--------|
| 2.1 | Экран победы (overlay 100% + «Дальше») | ✅ |
| 2.2 | HUD: уровень + очки + прогресс-бар сверху | ✅ |
| 2.3 | Главное меню → бесконечный поток уровней | ✅ |
| 2.4 | Hitbox ≥ 96 px (фактически 160×200 на плитку) | ✅ |
| 2.5 | Aurora-стилистика: градиент-фон, палитра мастей, скруглённые формы | ✅ |

> Бесконечный режим: после нажатия «Дальше» — `GameState.next_level()` и `Board.build_level(level + 1)`. Уровни растут по размеру и числу уникальных типов до 9 мастей одновременно.

### Фаза 3 — Контент и ассеты (2 дня)

- [ ] 4–6 типов плиток (SVG/PNG, CC0 или свои)
- [ ] Заполнить `docs/ASSETS.md` (источник, лицензия, автор)
- [ ] Опционально 1–2 SFX (CC0)
- [ ] Баланс `level_01`: 12–24 плитки, 3–8 минут на прохождение

### Фаза 4 — Aurora OS port (3–5 дней, после MVP)

- [ ] Решить путь экспорта (Godot export / RPM-обёртка / QML shell)
- [ ] Убрать любые keyboard shortcuts из release (`InputMap`)
- [ ] Подготовить иконку, `.desktop`, права для Harbor / Aurora
- [ ] Тест на эмуляторе/устройстве Aurora SDK
- [ ] Тег `aurora-experimental`

> Если Godot на Aurora нестабилен — план Б: меню на QML + Godot для уровня, или чистый QML/Qt с переиспользованием правил из `match_rules.gd` (логика без зависимостей от движка).

### Фаза 5 — Сдача (1 день)

- [ ] Геймплей-видео 30–60 с
- [ ] Скриншоты на телефоне и планшете (доказать адаптивность)
- [ ] README с шагами сборки
- [ ] Push в `main`, проверка чеклиста §1

---

## Архитектура (актуальная)

```
game/
├── project.godot                  ✅ portrait 1080×1920, window 720×1280
├── scenes/
│   ├── main_menu.tscn             ✅ Aurora-gradient + Play / Exit
│   ├── game.tscn                  ✅ Background + HUD + Board + LevelComplete overlay
│   ├── board.tscn                 ✅ PlayArea (Tiles) + SlotsRow (3 слота)
│   └── tile.tscn                  ✅ Panel(сплошной цвет) + RankLabel
├── scripts/
│   ├── autoload/
│   │   └── game_state.gd          ✅ level, score, переходы сцен, сигналы
│   ├── board/
│   │   ├── board.gd               ✅ build_level, click→slot, resolve_triple
│   │   └── tile.gd                ✅ states, hover/press/shake/clear анимации
│   ├── rules/
│   │   ├── match_rules.gd         ✅ is_tile_free учитывает on_board
│   │   └── tile_types.gd          ✅ 27 типов (3 масти × 9 рангов) + палитра
│   ├── levels/
│   │   └── level_generator.gd     ✅ pyramid shape + reverse-simulation
│   └── ui/
│       ├── game_screen.gd         ✅ HUD ↔ Board ↔ GameState, Next-кнопка
│       └── main_menu.gd           ✅ Play / Exit
└── assets/
    ├── tiles/                     [Phase 3 — заменить цвет на ассеты]
    └── fonts/                     [Phase 3]
```

**Слои зависимостей:** `scenes` → `scripts/board|rules|levels` → `autoload`. Правила (`match_rules.gd`) не знают про сцены — тестируются отдельно.

---

## Команды

```powershell
# индекс кода (после клонирования)
ast-index rebuild

# поиск символа
ast-index search "Tile"
ast-index symbol "MatchRules"

# режим terse-ответов
/caveman           # full
/caveman lite      # мягкий
/caveman ultra     # экстремальный
normal mode        # выключить
```

Открыть проект: Godot 4.4.1 → Import → `game/project.godot`.

---

## Тесты

| Уровень | Что | Чем |
|---------|-----|-----|
| Unit | `is_tile_free`, `is_valid_triple`, подсчёт очков | GUT |
| Acceptance (DAE) | Given board / When select 3 / Then cleared | `features/*/spec.md` (Gherkin) |
| Touch | Hitbox, отмена выбора, вращение | Ручной QA на устройстве |
| Регресс | После порта на Aurora | те же unit-тесты |

---

## Риски

| Риск | Митигация |
|------|-----------|
| Godot на Aurora нестабилен | План Б — QML/Qt c переиспользованием правил |
| Нехватка времени | Жёсткий MVP: 1 уровень, без звука/анимаций |
| Ассет-блок | Kenney CC0, OpenGameArt; запретить commercial art |
| UI ломается на планшете | `aspect=expand` + якоря — проверять на 9:16, 3:4, 9:21 в эмуляторе Godot (Project Settings → Display) |

---

## Ссылки

- Репо: https://github.com/Geraa50/Aurora-Pulse
- Полный план (RU): [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md)
- Инструменты агента: [`docs/TOOLS_SETUP.md`](docs/TOOLS_SETUP.md)
- Charter (DAE): [`CHARTER.md`](CHARTER.md)
