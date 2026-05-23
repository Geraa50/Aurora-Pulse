# icons/

Иконки приложения **Aurora Pulse** для экспорта на Aurora OS / Sailfish OS.

## Размеры (Aurora OS launcher icon set)

| Файл | Размер | Плотность |
|------|--------|-----------|
| `icon-86.png`  | 86×86   | mdpi   |
| `icon-108.png` | 108×108 | hdpi   |
| `icon-128.png` | 128×128 | xhdpi  |
| `icon-172.png` | 172×172 | xxhdpi |

## Источник

Иконки сгенерированы из единого дизайна (см. `game/icon.svg` — три перекрывающиеся плитки на тёмно-синем фоне).
Для регенерации:

```powershell
python scripts/generate_icons.py
```

Скрипт рендерит каждый размер с 4× supersampling и downsample через Lanczos —
скруглённые углы остаются чёткими даже на 86 px.

## Использование

- **Godot export** (`game/project.godot`) использует `res://icon.svg` как иконку окна — это отдельная вещь.
- Эти PNG нужны для упаковки `.desktop` / RPM-пакета Aurora (см. План, фаза 4):
  - `/usr/share/icons/hicolor/86x86/apps/ru.aurora.pulse.png`
  - `/usr/share/icons/hicolor/108x108/apps/ru.aurora.pulse.png`
  - `/usr/share/icons/hicolor/128x128/apps/ru.aurora.pulse.png`
  - `/usr/share/icons/hicolor/172x172/apps/ru.aurora.pulse.png`
