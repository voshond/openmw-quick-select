# UI rendering architecture

The UI is split into three layers. Dependencies point down; presentation modules never equip items or write storage.

## Components

`scripts/voshondsQuickSelect/ui/` contains small rendering primitives:

- `icon.lua` composes cached textures, backgrounds, images, text overlays, and events.
- `hotbar.lua` lays out any sequence of slots and owns spacing/measurement.
- `button.lua`, `search_bar.lua`, and `modal.lua` provide the common window controls.
- `scroll_bar.lua` owns the draggable handle, track, and arrow controls.
- `scroll_view.lua` clips and positions arbitrary fixed-size content, and can replace that content without replacing its outer element.
- `tooltip.lua` owns the tooltip layer and the lifecycle of the active tooltip. Tooltip rows are content-sized with a compact fixed line height.

Components accept declarative tables and return layouts or elements. They do not inspect the player, inventory, favorites, or settings storage.

## Presentation models

`qs_item_catalog.lua` converts OpenMW inventory and magic records into stable selector entries. It owns sorting and literal, case-insensitive filtering; magic entries include their effect names and IDs in the searchable text.

`ci_icon_render.lua` remains the compatibility presenter for hotbar slot state. It resolves counts, charge text, threshold colors, and the configured text styles, then delegates texture composition and caching to `ui/icon.lua`. Its existing `Controller_Icon_QS` interface is preserved.

## Controllers

- `qs_hotbar.lua` owns HUD visibility, fade/picking state, and refresh policy. It uses the shared hotbar component for layout.
- `select_items_win1.lua` owns only selection-window state: current view, target slot, catalog, query, search focus, and scroll element. It uses the same hotbar and icon components as the HUD, and exposes menu-open state so hotbar bindings stay inactive while typing.
- `QuickSelect_P.lua` owns key-to-slot activation and equipment/spell actions.
- `ci_favorite_storage.lua` owns the persisted 30-slot data model.

The selection flow is:

1. Render three shared hotbar rows.
2. Select a slot and choose inventory, magic, delete, or cancel.
3. Build a sorted catalog once.
4. Filter it as the query changes, replacing only the fixed-height scroll view's contents so the search field retains focus.
5. Save through the existing storage interface and close the UI mode.

## Search focus

OpenMW 0.51 exposes focus events but no public API that assigns focus to a specific Lua widget. The selector therefore uses a normal `TextEdit` and also captures printable keys at the controller while the field does not own focus. Search is immediately active when a selector opens, without depending on mouse interaction.

## Lifecycle rules

- A controller owns and destroys every root element it creates.
- Nested scroll elements are deep-destroyed after their parent window is detached.
- Only `ui/tooltip.lua` creates or destroys tooltip elements.
- Settings changes rebuild the currently visible view; storage and equipment behavior are not coupled to those rebuilds.
- Components cache texture resources, not player-dependent render state.
- Hotbar slot wrappers declare the same fixed footprint used for row measurement; configured horizontal and vertical gaps are direct UI-pixel values, including zero.

## Next migration slices

1. Move charge/count/equipped-state resolution out of `ci_icon_render.lua` into a slot presentation model.
2. Replace full HUD rebuild requests with keyed slot snapshots and dirty-slot updates.
3. Collapse the repeated redraw timers in `ci_favorite_storage.lua` into one coalesced invalidation API.
4. Move tooltip data generation behind a small presentation-model interface.
5. Add Lua tests for catalog filtering, slot labels, hotbar measurement, and snapshot diffing with OpenMW modules stubbed.
