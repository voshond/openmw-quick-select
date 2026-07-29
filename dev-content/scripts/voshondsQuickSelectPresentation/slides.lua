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
        eyebrow = "QUICK SELECT",
        title = "Easy access items & spells",
        intro = "Everything you need, quickly accessible.",
        keyRows = {
            {
                slot = 1,
                key = "1–0",
                label = "Main bar",
                description = "Your regular ten slots visualised",
            },
            {
                slot = 11,
                key = "Shift + 1–0",
                alternate = "Mouse 4",
                label = "Second bar",
                description = "Hold Shift, or use Mouse 4 to access the second bar",
            },
            {
                slot = 21,
                key = "Ctrl + 1–0",
                alternate = "Mouse 5",
                label = "Third bar",
                description = "Hold Ctrl, or use Mouse 5 to access the third bar",
            },
        },
        output = "presentation/01-direct-hotkeys.png",
    },
    {
        id = "live-status",
        kind = "examples",
        eyebrow = "QUICK SELECT",
        title = "At a glance details",
        intro = "Counts, charges, and equipped items are there while I am playing.",
        examples = {
            {
                slots = { 1 },
                label = "Spell/Weapon equipped status",
                description = "See if you have an item equipped and draw/ready/sheet it",
            },
            {
                slots = { 15, 16, 17 },
                label = "Running low",
                description = "The count changes colour when I am nearly out.",
            },
            {
                slots = { 2 },
                label = "Items & Spells equipped/ready status",
                description = "A small marker shows what spell is selected or item is equipped",
            },
        },
        output = "presentation/02-live-status.png",
    },
    {
        id = "exact-items",
        kind = "examples",
        eyebrow = "QUICK SELECT",
        title = "Easy item status",
        intro = "Shows useful details about your items.",
        examples = {
            {
                slots = { 9, 10 },
                label = "Items left",
                description = "Quickly see how many items are left in your inventory.",
            },
            {
                slots = { 1 },
                label = "Enchantment updates",
                description = "Keep track of your enchantment charges",
            }
        },
        output = "presentation/03-exact-items.png",
    },
    {
        id = "options",
        kind = "options",
        eyebrow = "QUICK SELECT",
        title = "Extensive options",
        intro = "customise Quick Select to your liking with a wide range of options",
        optionGroups = {
            {
                title = "Layout",
                description = "Pick one, two, or three bars,\nand put them where you want.",
            },
            {
                title = "Spacing",
                description = "Change icon size and the gaps",
            },
            {
                title = "Text",
                description = "Tweak count and charge text,\ncolour, and shadows.",
            },
            {
                title = "Behaviour",
                description = "Set low-stock colours, fading,\nand visible rows.",
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
