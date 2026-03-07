# Dominos HoldToCastFix

## [v2.0.0](https://github.com/danielbehrens/Dominos-HoldToCastFix/tree/v2.1.0) (2026-03-07)
[Full Changelog](https://github.com/danielbehrens/Dominos-HoldToCastFix/compare/v1.0.0...v2.0.0)

### Added
- **Debug panel** — click "Debug" in the config window to see live addon state, binding info, and an event log. Great for troubleshooting issues.
- **Copy button** — easily copy debug info to your clipboard to share in bug reports.
- **Minimap button** — optional minimap icon with left-click to open config, right-click to toggle on/off. Draggable around the minimap.
- **Druid form support** — hold-to-cast now stays active when switching forms (Cat, Bear, Moonkin, etc.).
- **Vehicle & dragonriding handling** — bindings are automatically cleared during vehicles and dragonriding, then restored when you exit.
- **Combat safety** — if a binding change is needed during combat, it's queued and applied as soon as combat ends.

### Fixed
- **Fixed bindings not restoring after vehicles** — the old version could silently fail to clear bindings during vehicle transitions. The binding system has been rebuilt to handle this correctly.
- **Fixed potential issues on zone changes** — bindings are now re-applied on loading screens to keep everything in sync.

### Changed
- Simplified to Bar 1 only — after extensive testing, non-Bar 1 action bars don't support hold-to-cast due to a WoW engine limitation (only Bar 1 uses the engine-level system that enables hold-to-cast repeating).

## [v1.0.0](https://github.com/danielbehrens/Dominos-HoldToCastFix/tree/v1.0.0) (2026-02-10)
[Full Changelog](https://github.com/danielbehrens/Dominos-HoldToCastFix/commits/v1.0.0) [Previous Releases](https://github.com/danielbehrens/Dominos-HoldToCastFix/releases)

- Add Wago Addons integration for automated releases  
