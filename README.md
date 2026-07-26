# voshond's QuickSelect

## Requirements

OpenMW 0.51 or newer is required.

## Description

voshond's QuickSelect is a PC-first fork of ZackHasaCat's
[Quickselect](https://gitlab.com/modding-openmw/quickselect/) for OpenMW. It
replaces the vanilla quick-item workflow with three directly addressable,
customisable hotbars for items, spells, and enchanted items.

Before enabling the mod, unbind the vanilla quick-item keys so they do not
conflict with QuickSelect.

The copy-ready Nexus Mods description is maintained in
[`docs/NEXUS_DESCRIPTION.bbcode`](docs/NEXUS_DESCRIPTION.bbcode).

### Highlights

- **Thirty direct hotkeys:** `1`–`0` activate the first bar,
  `Shift`/Mouse 4 + `1`–`0` the second, and `Ctrl`/Mouse 5 + `1`–`0` the
  third. `-` and `=` can also change the active bar.
- **Searchable assignment menus:** bind inventory items, spells, and enchanted
  items from QuickSelect's mouse-friendly picker, with tooltips and scrolling.
- **Correct individual-item handling:** assignments retain the exact item you
  selected, so same-record weapons or enchanted items with different condition
  or charge are not confused with one another.
- **Useful at-a-glance information:** configurable slot labels, stack counts,
  enchantment charges (including current/max and low-charge colours), equipped
  indicators, and the remaining uses of equipped probes, lockpicks, and repair
  tools.
- **Per-type low-stock warnings:** optional threshold colours for potions,
  repair tools, probes, lockpicks, and ammunition.
- **Configurable presentation:** choose one to three visible bars, top or
  bottom placement, icon size, horizontal and vertical spacing, text styling,
  and optional auto-fading after inactivity.

### PC-first behaviour

- Bars are directly addressable rather than treated as a single bar you must
  switch through first.
- Pressing a selected spell or enchanted item toggles its spell stance; choosing
  another spell keeps that stance ready.
- Pressing an equipped weapon, lockpick, probe, or light readies/switches it as
  appropriate; the optional **Auto-Unequip Sheathed Weapons** setting controls
  whether sheathing also unequips weapons, lockpicks, and probes.
- Armor, clothing, and accessories can optionally be toggled off with their
  assigned key.
- Controller input remains available where OpenMW exposes it, but the mod is
  designed and supported primarily for keyboard-and-mouse play.

### Differences from the original QuickSelect

This fork deliberately does not carry forward the original persistent-mode
toggle, hotbar-preview model, pause-while-selecting option, or keyboard arrow
key navigation. Visibility is controlled directly by the number of shown bars
and the optional fading setting; slot numbers are now configurable rather than
being permanently forced on.

## Credits

Author: voshond

Original author of QuickSelect: ZackHasaCat

## Installation

1. Download a release archive and extract its contents into an OpenMW data
   directory.
2. Add `voshondsQuickSelect.omwscripts` to your OpenMW Launcher content list.
3. Launch OpenMW and configure the mod from the in-game Settings menu.

## Report a problem

Please [open an issue on GitHub](https://github.com/voshond/openmw-quick-select/issues)
for bugs or questions.

## For developers

### Development scripts

All development scripts are organised in `dev-scripts/` and exposed through
root-level proxy scripts:

**Linux/macOS:**

```bash
./dev.sh <command> [options]
```

**Windows:**

```powershell
.\dev.ps1 <command> [options]
```

Available commands:

- `debug` — copy files and restart OpenMW.
- `deploy` — create a versioned release.
- `package` — build a distribution archive.

Run the Lua smoke tests without launching OpenMW:

```bash
luajit tests/ui_components_test.lua
luajit tests/hotbar_performance_test.lua
luajit tests/favorite_slots_migration_test.lua
luajit tests/actor_equipment_test.lua
luajit tests/favorite_item_test.lua
luajit tests/favorite_slots_test.lua
```

The rendering boundaries and performance lifecycle are documented in
[`docs/UI_RENDERING_ARCHITECTURE.md`](docs/UI_RENDERING_ARCHITECTURE.md) and
[`docs/PERFORMANCE_REFACTOR_PLAN.md`](docs/PERFORMANCE_REFACTOR_PLAN.md).

### Legacy quick-key assignments

Loading a save created before the script reorganisation automatically imports
its quick-key assignments. Assignments are stored in player-script save data,
not in player settings.

### Examples

```bash
# Debug the mod with focus on the existing OpenMW window
./dev.sh debug -focus

# Deploy a new version
./dev.sh deploy -v 1.2.3 -m "Bug fixes and improvements"

# Package the mod
./dev.sh package -v 1.2.3
```

### Deployment

To create a release:

1. Make sure all changes are committed.
2. Run `./dev.sh deploy` (Linux/macOS) or `.\dev.ps1 deploy` (Windows).
3. Enter a semantic version and optional release notes.

The deployment script updates `config.json` and `CHANGELOG.md`, creates and
pushes the release tag, and triggers the GitHub Actions release workflow.
