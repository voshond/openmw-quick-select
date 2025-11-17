# OpenMW Hotbars - Complete Modernization Refactor Plan

## Project Setup

### New Branch Structure
- Branch: `refactor/v2-modernization`
- New folder: `scripts/voshondsHotbars/` (clean slate)
- Keep old `scripts/voshondsQuickSelect/` intact on main branch
- New mod file: `voshondsHotbars.omwscripts`

### Goals
1. **Full modernization** using Zerkish example patterns
2. **Code quality first** - readable, maintainable, well-organized
3. **Component-based architecture** - reusable UI components
4. **Smart performance** - texture caching, update gating, delta detection
5. **Clean file organization** - logical module structure
6. **Comprehensive inline documentation** - explain OpenMW patterns where critical

---

## Phase 1: Foundation & Core Architecture (Week 1)

### 1.1 Project Structure
```
scripts/voshondsHotbars/
├── core/
│   ├── main.lua                 # Main player script (entry point)
│   ├── constants.lua            # All magic numbers, config values ✅
│   └── interfaces.lua           # Interface registration helpers
├── data/
│   ├── storage.lua              # Persistent data management ✅
│   └── schemas.lua              # Data validation & type definitions ✅
├── ui/
│   ├── components/
│   │   ├── Icon.lua             # Icon rendering component
│   │   ├── Slot.lua             # Hotbar slot component
│   │   ├── Tooltip.lua          # Tooltip component
│   │   └── Button.lua           # Reusable button component
│   ├── hotbar.lua               # Hotbar layout & rendering
│   ├── selection_window.lua     # Item/spell selection UI
│   └── settings_ui.lua          # Settings rendering (if needed beyond registry)
├── utils/
│   ├── items.lua                # Item-related helpers
│   ├── spells.lua               # Spell/enchantment helpers
│   ├── text_styles.lua          # Centralized text styling ✅
│   ├── icons.lua                # Icon path resolution, caching ✅
│   └── debug.lua                # Debug logging system ✅
└── systems/
    ├── input.lua                # Input handling & hotkey mapping
    ├── equip.lua                # Equipment logic (toggle, stance preservation)
    ├── settings.lua             # Settings registration & defaults
    └── update_manager.lua       # Smart update system (gating, throttling)
```

### 1.2 Core Constants (`core/constants.lua`) ✅
Centralize all magic numbers:
- Hotbar configuration (slots per bar, total bars)
- UI sizing (icon sizes, padding, spacing)
- Update intervals (refresh rates, throttle times)
- Color defaults
- Slot mappings (1-10, s1-s10, c1-c10)
- **Includes utility functions:** `getSlotNumber()`, `formatSlotNumber()`, `isValidSlot()`

### 1.3 Data Layer (`data/storage.lua` + `data/schemas.lua`) ✅
- Clean data schema definitions
- Validation functions for all operations
- Type-safe slot access (1-30 bounds checking)
- Separation of concerns: storage vs business logic
- No UI code in storage layer
- **Migration support:** Automatically converts old storage format to new schema

**Schema Example:**
```lua
-- Slot data types:
-- Item: {type = "item", recordId = string}
-- Spell: {type = "spell", spellId = string}
-- Enchantment: {type = "enchant", itemId = string, enchantId = string}
-- Empty: {type = "empty"}
```

---

## Phase 2: UI Component Library (Week 2)

### 2.1 Adopt Zerkish Component Patterns

**Icon Component (`ui/components/Icon.lua`):**
- Single unified icon creator
- Parameters: item/spell data, size, options
- Handles: equipped indicator, charges, count, slot numbers
- Returns reusable UI element
- Built-in texture caching

**Slot Component (`ui/components/Slot.lua`):**
- Wrapper for icon with container
- Handles: positioning, sizing, interaction
- Click handlers
- Hover states

**Tooltip Component (`ui/components/Tooltip.lua`):**
- Single tooltip layer initialization
- Reusable tooltip creation
- Position calculation
- Content generation

### 2.2 Texture Caching System (`utils/icons.lua`)
Based on Zerkish pattern:
```lua
local textureCache = {}
function getCachedTexture(props)
    local key = buildCacheKey(props)
    if not textureCache[key] then
        textureCache[key] = ui.texture(props)
    end
    return textureCache[key]
end
```

### 2.3 Text Style Management (`utils/text_styles.lua`)
- Single source of truth for all text styling
- Export pre-configured styles
- Settings-driven customization
- No duplication across modules

---

## Phase 3: Smart Update System (Week 2-3)

### 3.1 Update Manager (`systems/update_manager.lua`)
Based on Zerkish smart gating:
- **State change detection** - only update when data actually changes
- **Visibility gating** - skip updates when UI hidden
- **Throttling** - configurable minimum interval between updates
- **Dirty flags** - track what needs redrawing
- **Batch operations** - combine multiple changes into single redraw

**API:**
```lua
UpdateManager.markDirty(reason)  -- Flag for update
UpdateManager.forceUpdate()      -- Immediate full redraw
UpdateManager.incrementalUpdate(slot) -- Update single slot
UpdateManager.shouldUpdate()     -- Check if update needed
```

### 3.2 Enchantment Tracking
- Configurable refresh interval (setting)
- Delta detection (only update if charges changed)
- Visibility check (don't update hidden hotbar)
- Batch charge updates for multiple items

### 3.3 Single Redraw Trigger
Replace triple-redraw with smart single update:
```lua
function triggerUpdate(immediate)
    UpdateManager.markDirty("storage_change")
    if immediate then
        UpdateManager.forceUpdate()
    end
end
```

---

## Phase 4: Core Functionality (Week 3)

### 4.1 Input System (`systems/input.lua`)
- Clean hotkey mapping (1-0, Shift+1-0, Ctrl+1-0, Mouse4/5+1-0)
- Slot number calculation
- Input validation
- Modifier key state tracking

### 4.2 Equipment System (`systems/equip.lua`)
- Toggle behavior (unequip if already equipped)
- Stance preservation (magic stance when switching spells)
- Equipment slot resolution
- Item/spell/enchant equip logic
- Clean separation from UI

### 4.3 Spell & Item Helpers
**`utils/spells.lua`:**
- `getSpellIcon(spellData)` - unified spell icon resolution
- `getEnchantmentData(enchantId)` - enchantment lookup
- `isSpellEquipped(spellId)` - equipped state check

**`utils/items.lua`:**
- `shouldShowCount(item)` - count display logic
- `getItemCharges(item)` - charge calculation
- `findItemInInventory(recordId)` - inventory search
- `getEquippedItems()` - currently equipped gear

---

## Phase 5: Hotbar UI (Week 3-4)

### 5.1 Hotbar Layout (`ui/hotbar.lua`)
- Component-based construction (use Icon, Slot components)
- Clean layout logic (positioning, sizing, spacing)
- Fade system integration
- State management (expanded, visible, fade timer)

### 5.2 Selection Window (`ui/selection_window.lua`)
- Reuse same components as hotbar
- Grid layout for items/spells
- Filter system (items, spells, enchantments)
- Search/categorization
- Clean assignment logic

### 5.3 Settings (`systems/settings.lua`)
- All existing settings preserved
- Add new settings:
  - Enchantment refresh interval
  - Update throttle interval
  - Visibility/performance options
- Settings groups maintained
- Good defaults

---

## Phase 6: Feature Parity (Week 4)

### 6.1 Complete Feature Checklist
- ✓ 3 hotbars (30 slots total)
- ✓ Direct access via 1-0 + modifiers
- ✓ Items, spells, enchantments support
- ✓ Toggle behavior (unequip on re-activate)
- ✓ Stance preservation
- ✓ Equipped indicators
- ✓ Charge/count display
- ✓ Icon rendering with tooltips
- ✓ Fade system
- ✓ All settings from original
- ✓ Debug logging system
- ✓ Selection window

### 6.2 Migration Considerations
- Old settings stored under `voshondsQuickSelect` namespace
- New settings under `voshondsHotbars` namespace
- Users can switch between versions without conflict
- Both can be installed simultaneously for testing

---

## Phase 7: Polish & Testing (Week 5)

### 7.1 Performance Validation
- Compare update frequency (before vs after)
- Memory usage testing
- CPU profiling with 30 enchanted items
- Verify texture caching effectiveness

### 7.2 Testing Matrix
- Empty hotbar
- Mixed content (items, spells, enchants)
- All 30 slots filled with enchanted items
- Rapid hotkey presses
- Settings changes during gameplay
- HUD visibility toggling
- Multiple hotbar switching

### 7.3 Code Quality
- Remove any remaining duplication
- Ensure consistent patterns throughout
- Verify all modules follow structure
- Clean up debug statements
- Final documentation pass

---

## Implementation Guidelines

### Code Style
- Clear variable names (no abbreviations unless obvious)
- Functions do one thing well
- Max function length: ~50 lines (extract helpers)
- Comment only complex OpenMW patterns or non-obvious logic
- Prefer composition over inheritance

### OpenMW Patterns to Document
- Interface registration & communication
- Storage persistence (playerSection)
- Async timer usage
- UI layer management
- Event handling patterns

### Error Handling
- Validate at boundaries (user input, external data)
- Fail fast for programmer errors
- Use pcall only for genuinely risky operations
- Log errors with context
- No silent failures

### Performance Rules
- Cache textures and heavy computations
- Gate updates with visibility/state checks
- Batch UI updates when possible
- Avoid full rebuilds unless necessary
- Profile before optimizing

---

## Success Metrics

### Code Quality
- **LoC Reduction:** Target 30-40% fewer lines vs original (~800 LoC vs ~1200 LoC)
- **Duplication:** Zero duplicated functions
- **Module Cohesion:** Each module has single clear responsibility

### Performance
- **Redraw Frequency:** 90% reduction in full redraws
- **Update Gating:** UI updates only on state changes
- **Memory:** Similar or better than original
- **Responsiveness:** No noticeable lag on hotkey press

### Maintainability
- **Clear structure:** Easy to find where functionality lives
- **Reusable components:** Add new features by composing existing components
- **Documented patterns:** Critical OpenMW usage explained
- **Testable:** Easy to test individual modules

---

## Deliverables

1. **Refactored codebase** in `scripts/voshondsHotbars/`
2. **New mod file** `voshondsHotbars.omwscripts`
3. **Updated config.json** with new paths for debug script
4. **PLAN.md** (this document) for future reference
5. **ARCHITECTURE.md** explaining module organization & data flow
6. **Updated README.md** for new mod name

---

## Migration Path (Future)

Once v2 is stable and tested:
1. Release as new mod version (v2.0.0)
2. Update CHANGELOG with breaking changes notice
3. Optional: Deprecate old version or maintain both
4. Merge refactor branch to main
5. Archive old code in `legacy/` folder

---

## Progress Tracking

### ✅ Phase 1: Foundation & Core Architecture - COMPLETE
- [x] Create new branch and project structure
- [x] `core/constants.lua` - All magic numbers centralized with utility functions (195 lines)
- [x] `data/schemas.lua` - Data validation, type definitions, and migration support (232 lines)
- [x] `data/storage.lua` - Clean persistent storage layer with full validation (220 lines)
- [x] `utils/debug.lua` - Module-based debug logging system (178 lines)
- [x] `utils/text_styles.lua` - Centralized text styling (197 lines, eliminates 77+ lines of duplication)
- [x] `utils/icons.lua` - Texture caching system with Zerkish pattern (243 lines)
- [x] `utils/items.lua` - Item helper functions (349 lines)
- [x] `utils/spells.lua` - Spell/enchantment helpers (380 lines)

### Phase 1 Summary
- **Total lines written:** ~1,994 lines of clean, well-documented code
- **Duplication eliminated:** 77+ lines from text styles, more to come
- **All core utilities complete** - Ready for Phase 2 (UI Components)
- **Texture caching implemented** - Zerkish pattern for performance
- **Migration support added** - Old storage format automatically converted
- **Comprehensive helpers** - Items, spells, icons, debugging all covered

### Current Status
**Ready to begin Phase 2: UI Component Library**

### Pending (Phase 2)
- [ ] `ui/components/Tooltip.lua` - Tooltip component
- [ ] `ui/components/Icon.lua` - Unified icon component
- [ ] `ui/components/Slot.lua` - Hotbar slot component

### Pending (Phase 3)
- [ ] `systems/update_manager.lua` - Smart update system
- [ ] `systems/settings.lua` - Settings registration

### Pending (Phase 4)
- [ ] `systems/input.lua` - Input handling
- [ ] `systems/equip.lua` - Equipment logic

### Pending (Phase 5)
- [ ] `ui/hotbar.lua` - Hotbar rendering
- [ ] `ui/selection_window.lua` - Item selection UI

### Pending (Phase 6)
- [ ] `core/main.lua` - Main entry point
- [ ] `voshondsHotbars.omwscripts` - Mod registration
- [ ] Update config.json

### Pending (Phase 7)
- [ ] Testing and validation
- [ ] ARCHITECTURE.md documentation
