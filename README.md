# Dominos HoldToCastFix

Fixes **Press and Hold Casting** for Dominos action bar buttons by routing keybinds to Blizzard's native ActionButton frames.

## The Problem

Dominos replaces Blizzard's action bars with its own button frames. This breaks WoW's Press and Hold Casting feature (Settings > Accessibility) because the engine's `TryUseActionButton()` press-and-hold re-trigger loop only works with native ActionButton frames.

## The Fix

DominosHoldToCastFix uses `SetOverrideBinding()` with high priority to route keybinds back to Blizzard's native binding commands (e.g. `ACTIONBUTTON1`). This restores the engine's native press-and-hold re-trigger loop while keeping Dominos' visual action bars intact.

### Bar Paging & Combat Awareness

When your action bar pages away from its default state — such as entering a vehicle, dragonriding/skyriding, shapeshift forms, or forced mount encounters (e.g. Dimensius in Manaforge Omega) — the addon automatically detects this and clears its override bindings so your abilities work correctly. When you return to your normal bar, bindings are seamlessly restored.

This works even during combat using Blizzard's secure state driver system, so you'll never lose keybinds mid-encounter.

## Supported Bars

| Dominos Bar | Blizzard Equivalent |
|-------------|-------------------|
| Bar 1 | ActionButton 1-12 |
| Bar 3 | MultiBarBottomRight 1-12 |
| Bar 4 | MultiBarRight 1-12 |
| Bar 5 | MultiBarBottomLeft 1-12 |
| Bar 6 | MultiBarLeft 1-12 |
| Bar 12 | MultiBar5 1-12 |
| Bar 13 | MultiBar6 1-12 |
| Bar 14 | MultiBar7 1-12 |

Bars 2, 7, 8, 9, 10, 11 are Dominos-only and have no Blizzard counterpart, so they cannot be fixed with this approach.

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/dominos-holdtocastfix) or install via the CurseForge app.
2. Ensure Dominos is installed.
3. Reload your UI (`/reload`).

## Usage

- `/dominoshold` or `/dhtcf` — Open the configuration panel.
- Select which Dominos bar to fix, toggle enabled/disabled, and click Apply.
- Optional minimap button can be enabled from the config panel for quick access.

## Requirements

- World of Warcraft: Midnight (12.0.x)
- Dominos (optional dependency — the addon is designed for use with Dominos)

## License

MIT License — see [LICENSE](LICENSE) for details.
