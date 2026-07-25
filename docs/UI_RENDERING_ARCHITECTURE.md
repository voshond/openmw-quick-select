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

`services/item_catalog.lua` converts OpenMW inventory and magic records into stable selector entries. It owns sorting and literal, case-insensitive filtering; magic entries include their effect names and IDs in the searchable text.

`presentation/icon_renderer.lua` remains the compatibility presenter for hotbar slot state. It resolves counts, charge text, threshold colors, and the configured text styles, then delegates texture composition and caching to `ui/icon.lua`. Its existing `Controller_Icon_QS` interface is preserved.

`presentation/hotbar_snapshot.lua` captures the player-dependent values that
can change a HUD slot: assignment identity, availability, icon, count, charge,
condition, equipped state, selection, and visual-style generation. Snapshots
are comparable without touching the UI.

## Controllers

- `controllers/hud_hotbar.lua` owns HUD visibility, fade/picking state,
  invalidation batching, snapshot reconciliation, and the narrow fallback poll
  for external player-state changes.
- `controllers/quick_keys.lua` owns only selection-window state: current view, target slot, catalog, query, search focus, and scroll element. It uses the same hotbar and icon components as the HUD, and exposes menu-open state so hotbar bindings stay inactive while typing.
- `controllers/player.lua` owns key-to-slot activation and equipment/spell actions.
- `services/favorite_slots.lua` owns the persisted 30-slot data model.

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
- The HUD root remains alive across ordinary slot, visibility, and fade
  changes. `ui/hotbar_view.lua` gives each slot an independent element so a
  dirty slot can update without updating or replacing the root.
- Nested scroll elements are deep-destroyed after their parent window is detached.
- Only `ui/tooltip.lua` creates or destroys tooltip elements.
- Settings changes rebuild the currently visible view; storage and equipment behavior are not coupled to those rebuilds.
- Components cache texture resources, not player-dependent render state.
- Known storage actions invalidate their affected slot. Repeated requests are
  coalesced and snapshot equality suppresses redundant UI work.
- Hotbar slot wrappers declare the same fixed footprint used for row measurement; configured horizontal and vertical gaps are direct UI-pixel values, including zero.

## Remaining migration slices

1. Move tooltip data generation behind a small presentation-model interface.
2. Gradually reduce the legacy responsibilities left in
   `presentation/icon_renderer.lua`.
3. Add gameplay profiling captures for large inventories and three visible
   hotbars.
