return {
    {
        id = "hero",
        kind = "hero",
        title = "voshond's\nQuick Select",
        output = "hero.png",
    },
    {
        id = "direct-hotkeys",
        kind = "keys",
        eyebrow = "QUICK SELECT  /  FEATURE 01",
        title = "Thirty direct hotkeys",
        intro = "Three independently addressable bars keep every favourite one press away.",
        keyRows = {
            {
                slot = 1,
                key = "1–0",
                label = "First bar",
                description = "Ten instant choices on the number row.",
            },
            {
                slot = 11,
                key = "Shift + 1–0",
                alternate = "Mouse 4",
                label = "Second bar",
                description = "Hold Shift, or switch bars from the mouse.",
            },
            {
                slot = 21,
                key = "Ctrl + 1–0",
                alternate = "Mouse 5",
                label = "Third bar",
                description = "Another ten slots when you need the room.",
            },
        },
        output = "presentation/01-direct-hotkeys.png",
    },
    {
        id = "live-status",
        kind = "examples",
        eyebrow = "QUICK SELECT  /  FEATURE 02",
        title = "Useful information,\nright on the icon",
        intro = "The hotbar reflects what is happening in your inventory as you play.",
        examples = {
            {
                slots = { 1 },
                label = "Enchantment charges",
                description = "See the current and maximum charge at a glance.",
            },
            {
                slots = { 15, 16, 17 },
                label = "Low-stock thresholds",
                description = "Counts change colour before you run out.",
            },
            {
                slots = { 2 },
                label = "Equipped state",
                description = "Know exactly what is ready without opening a menu.",
            },
        },
        output = "presentation/02-live-status.png",
    },
    {
        id = "exact-items",
        kind = "examples",
        eyebrow = "QUICK SELECT  /  FEATURE 03",
        title = "The exact item\nyou selected",
        intro = "Assignments follow a specific inventory instance—not merely its record name.",
        examples = {
            {
                slots = { 9, 10 },
                label = "Instance-aware assignments",
                description = "Condition and charge stay attached to the item you bound.",
            },
            {
                slots = { 1 },
                label = "Live condition and charge",
                description = "The icon updates as that exact item is used.",
            },
            {
                slots = { 20 },
                label = "Reliable after reloading",
                description = "Your favourite remains the same across saves and sessions.",
            },
        },
        output = "presentation/03-exact-items.png",
    },
    {
        id = "options",
        kind = "options",
        eyebrow = "QUICK SELECT  /  FEATURE 04",
        title = "Extensive options",
        intro = "Tune the hotbar to the interface you want—not the other way around.",
        optionGroups = {
            {
                title = "Layout",
                description = "Show one, two, or three bars\nat the top or bottom of the screen.",
            },
            {
                title = "Spacing",
                description = "Adjust icon size, row height,\nand the gap between every slot.",
            },
            {
                title = "Live text",
                description = "Control count and charge size,\ncolour, opacity, and shadows.",
            },
            {
                title = "Behaviour",
                description = "Choose low-stock thresholds,\nauto-fade, and always-visible rows.",
            },
        },
        previewSlots = { 1, 2, 3, 4 },
        output = "presentation/04-options.png",
    },
    {
        id = "quick-keys",
        kind = "quick-keys",
        quickKeysView = "hotbars",
        output = "presentation/05-quick-keys.png",
    },
    {
        id = "choose-slot",
        kind = "quick-keys",
        quickKeysView = "slot-actions",
        output = "presentation/06-choose-slot.png",
    },
    {
        id = "inventory-selector",
        kind = "quick-keys",
        quickKeysView = "inventory",
        output = "presentation/07-inventory-selector.png",
    },
    {
        id = "magic-selector",
        kind = "quick-keys",
        quickKeysView = "magic",
        output = "presentation/08-magic-selector.png",
    },
    {
        id = "script-settings",
        kind = "main-menu",
        captureAction = "open-script-settings",
        output = "presentation/09-script-settings.png",
    },
}
