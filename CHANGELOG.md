# Dominos HoldToCastFix

## [v1.0.0](https://github.com/danielbehrens/Dominos-HoldToCastFix/tree/v1.0.0) (2026-02-10)
[Full Changelog](https://github.com/danielbehrens/Dominos-HoldToCastFix/commits/v1.0.0)

- Initial release
- Routes keybinds for a selected Dominos bar to Blizzard's native ActionButton frames, restoring Press and Hold Casting functionality
- Secure state driver for bar1 paging detection — automatically clears bindings during vehicles, dragonriding, shapeshift forms, and forced mount encounters (e.g. Dimensius in Manaforge Omega), and restores them when returning to the default bar
- Works during combat via Blizzard's SecureHandlerStateTemplate
- Configuration panel (`/dominoshold` or `/dhtcf`)
- Optional draggable minimap button with active/inactive status indicator
- Support for bars 1, 3, 4, 5, 6, 12, 13, 14
