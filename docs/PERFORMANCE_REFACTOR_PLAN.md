# Hotbar rendering performance

The HUD hotbar uses a persistent UI tree. Ordinary state changes update only
the slots whose render snapshots changed; the root is rebuilt only when its
layout changes.

## Rendering pipeline

1. `presentation/hotbar_snapshot.lua` captures the render-relevant state of
   each visible slot. A capture cycle reads equipment, selected magic, spells,
   and inventory counts once and shares those results between slots.
2. `controllers/hud_hotbar.lua` coalesces invalidation requests until the next
   frame. It compares newly captured snapshots with the last rendered state.
3. `ui/hotbar_view.lua` owns the persistent HUD root and an independent
   `openmw.ui.Element` for every visible slot.
4. Changed slots receive a replacement layout and call `Element:update()`.
   Unchanged slots perform no UI work.

The existing `QuickSelect_Hotbar.drawHotbar()` interface remains available as
a compatibility invalidation request. It no longer destroys and immediately
recreates the HUD.

## Invalidation types

- `invalidateSlot(slot)` marks one assignment or item state as dirty.
- `invalidateState()` reconciles all visible slots without rebuilding the
  root.
- `invalidateDynamic()` reconciles only bound slots that can change while
  playing.
- `invalidateLayout()` rebuilds the root for icon size, spacing, placement, or
  visible-bar changes.

Multiple requests before the next frame form one invalidation batch.

## Polling

OpenMW 0.51 does not expose a general player-inventory-changed engine handler,
so external inventory, charge, and equipment changes still need reconciliation.
The controller polls every 0.5 seconds only while the HUD is visible.

Polling does not imply redrawing:

- empty slots are skipped;
- inventory counts are cached per record for the capture cycle;
- equipment and selected magic are read once per cycle;
- charge, count, condition, availability, and equipped state are compared;
- only snapshots that changed update their slot elements.

The previous self-rescheduling enchantment timer was removed. It rebuilt the
whole HUD twice per second whenever any charge-using item had been rendered,
including stale items that were no longer visible.

## Visibility and fading

Hiding the HUD or fading the bar changes the persistent root's `visible`
property. It does not destroy slot elements. Polling pauses while hidden and a
single reconciliation runs when the bar is shown again.

## Presentation caches

- `ui/icon.lua` caches OpenMW texture resources by path.
- Text and magic-charge styles are cached in
  `presentation/icon_renderer.lua` and refreshed by settings notifications.
- Player-dependent slot snapshots are not retained outside the currently
  rendered visible slots.

## Diagnostics

`QuickSelect_Hotbar.getPerformanceMetrics()` returns:

- `fullBuilds`
- `slotUpdates`
- `skippedSlotUpdates`
- `invalidationBatches`
- `dynamicPolls`

These counters are intentionally passive and do not print every frame.

## Verification

`tests/hotbar_performance_test.lua` verifies that:

- repeated redraw requests do not rebuild the root;
- unchanged snapshots do not update UI elements;
- count and charge changes update exactly one slot;
- dynamic polling can result in zero UI work;
- explicit layout invalidation performs a full rebuild.

Run:

```sh
luajit tests/ui_components_test.lua
luajit tests/hotbar_performance_test.lua
```
