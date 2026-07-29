local core = require("openmw.core")
local input = require("openmw.input")
local I = require("openmw.interfaces")
local storage = require("openmw.storage")
local ui = require("openmw.ui")
local util = require("openmw.util")

local Icon = require("scripts.voshondsquickselect.ui.icon")
local Snapshot = require("scripts.voshondsquickselect.presentation.hotbar_snapshot")
local utility = require("scripts.voshondsquickselect.legacy.utility")
local slides = require("scripts.voshondsquickselectpresentation.slides")

local settings = storage.playerSection("SettingsVoshondsQuickSelect")

local GOLD = util.color.rgb(0.84, 0.67, 0.37)
local MUTED_GOLD = util.color.rgb(0.68, 0.55, 0.34)
local WHITE = util.color.rgb(0.94, 0.91, 0.84)
local BLACK = util.color.rgb(0, 0, 0)
local HERO_WIDTH = 1300
local HERO_HEIGHT = 372
local GUI_SCALE = 2
local PRESENTATION_TEXT_SCALE = 1.5
local HERO_ICON_SIZE = 32
local FEATURE_ICON_SIZE = 32
local SLOT_PADDING = 4
local HOTBAR_GAP = 6
local HOTBAR_VERTICAL_GAP = 8
local READY_DELAY = 1.5
local FADE_TEXTURE = ui.texture({
    path = "textures/voshondsQuickSelectPresentation/left_fade.tga",
})

local root
local started = false
local slideIndex = 1
local readyAt
local readyAnnounced = false
local renderedWidth
local renderedHeight
local renderedExportSpec
local snapshotContext
local snapshotCache = {}
local pendingQuickKeysView
local pendingQuickKeysAt

local function round(value)
    return math.floor(value + 0.5)
end

local function logicalVector(vector)
    return util.vector2(vector.x / GUI_SCALE, vector.y / GUI_SCALE)
end

local function logicalScreen(screen)
    return logicalVector(screen)
end

local function destroyRoot()
    if root and root.layout then
        root:destroy()
    end
    root = nil
end

local function fadeLayout(position, size)
    return {
        type = ui.TYPE.Image,
        props = {
            resource = FADE_TEXTURE,
            position = logicalVector(position),
            size = logicalVector(size),
            alpha = 1,
            arrange = ui.ALIGNMENT.Start,
            align = ui.ALIGNMENT.Start,
        },
    }
end

local function textLayout(text, position, size, options)
    options = options or {}
    return {
        type = ui.TYPE.Text,
        template = options.template or I.MWUI.templates.textNormal,
        props = {
            autoSize = false,
            position = logicalVector(position),
            size = logicalVector(size),
            text = text,
            textSize = (options.textSize or 22) * PRESENTATION_TEXT_SCALE / GUI_SCALE,
            textColor = options.color or WHITE,
            textShadow = options.shadow ~= false,
            textShadowColor = BLACK,
            multiline = options.multiline ~= false,
            wordWrap = options.wordWrap ~= false,
            textAlignH = options.alignH or ui.ALIGNMENT.Start,
            textAlignV = options.alignV or ui.ALIGNMENT.Start,
        },
    }
end

local function append(content, layout)
    if layout then
        content[#content + 1] = layout
    end
end

local function slotPrefix(slot)
    if slot > 20 then
        return "c"
    elseif slot > 10 then
        return "s"
    end
    return ""
end

local function snapshotSlot(slot)
    if snapshotCache[slot] then
        return snapshotCache[slot]
    end

    local data = I.QuickSelect_Storage.getFavoriteItemData(slot) or {}
    local snapshot = Snapshot.capture(slot, data, snapshotContext)
    snapshotCache[slot] = snapshot

    print(table.concat({
        "VQS_PRESENTATION_SLOT",
        tostring(slot),
        tostring(snapshot.kind),
        tostring(snapshot.recordId or snapshot.assignmentId or ""),
        tostring(snapshot.totalCount or snapshot.count or ""),
        tostring(snapshot.charge or ""),
        snapshot.equipped and "equipped" or "",
    }, "|"))
    return snapshot
end

local function slotIconContent(snapshot, selected)
    local prefix = slotPrefix(snapshot.slot)
    if snapshot.kind == "item" and snapshot.item then
        return I.Controller_Icon_QS.getItemIcon(
            snapshot.item,
            false,
            selected,
            snapshot.slot,
            prefix,
            snapshot.data,
            snapshot.renderState
        )
    elseif (snapshot.kind == "spell" or snapshot.kind == "enchant") and snapshot.iconPath then
        return I.Controller_Icon_QS.getSpellIcon(
            snapshot.iconPath,
            false,
            selected,
            snapshot.slot,
            prefix
        )
    end

    return I.Controller_Icon_QS.getEmptyIcon(
        false,
        snapshot.slot,
        selected,
        true,
        prefix
    )
end

local function slotLayoutLogical(slot, position, selected, iconSize)
    local snapshot = snapshotSlot(slot)
    local boxSize = iconSize + SLOT_PADDING
    local framed = utility.renderItemBoxed(
        slotIconContent(snapshot, selected == true),
        util.vector2(boxSize, boxSize),
        nil,
        util.vector2(0.5, 0.5),
        { item = snapshot.item, num = snapshot.slot, data = snapshot.data }
    )

    local layers = { framed }
    if snapshot.equipped then
        layers[#layers + 1] = {
            type = ui.TYPE.Image,
            props = {
                resource = Icon.texture("textures/voshondsQuickSelect/equipped_indicator.dds"),
                size = util.vector2(16, 16),
                position = util.vector2(0, boxSize - 16),
                arrange = ui.ALIGNMENT.Start,
                align = ui.ALIGNMENT.Start,
                alpha = 1,
            },
        }
    end

    return {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            position = position,
            size = util.vector2(boxSize, boxSize),
        },
        content = ui.content(layers),
    }
end

local function slotLayout(slot, position, selected, iconSize)
    return slotLayoutLogical(
        slot,
        logicalVector(position),
        selected,
        iconSize
    )
end

local function addHotbar(content, origin, iconSize)
    local slotSize = iconSize + SLOT_PADDING
    local rows = { 21, 11, 1 }

    for rowIndex, firstSlot in ipairs(rows) do
        local y = origin.y + (rowIndex - 1) * (slotSize + HOTBAR_VERTICAL_GAP)
        for column = 0, 9 do
            local x = origin.x + column * (slotSize + HOTBAR_GAP)
            append(content, slotLayoutLogical(
                firstSlot + column,
                util.vector2(x, y),
                false,
                iconSize
            ))
        end
    end
end

local function addFeatureHotbar(content, screen)
    local layoutScreen = logicalScreen(screen)
    local slotSize = FEATURE_ICON_SIZE + SLOT_PADDING
    local width = slotSize * 10 + HOTBAR_GAP * 9
    local height = slotSize * 3 + HOTBAR_VERTICAL_GAP * 2
    addHotbar(
        content,
        util.vector2(round((layoutScreen.x - width) / 2), layoutScreen.y - height),
        FEATURE_ICON_SIZE
    )
end

local function addFeatureBackdrop(content, screen)
    append(content, fadeLayout(util.vector2(0, 0), screen))
end

local function addFeatureHeader(content, slide)
    append(content, textLayout(
        slide.eyebrow,
        util.vector2(88, 94),
        util.vector2(960, 30),
        {
            textSize = 18,
            color = MUTED_GOLD,
            multiline = false,
            wordWrap = false,
        }
    ))
    append(content, textLayout(
        slide.title,
        util.vector2(88, 142),
        util.vector2(1040, 150),
        {
            template = I.MWUI.templates.textHeader,
            textSize = 52,
            color = GOLD,
            multiline = true,
        }
    ))
    append(content, textLayout(
        slide.intro,
        util.vector2(88, 300),
        util.vector2(850, 84),
        {
            textSize = 25,
            color = WHITE,
        }
    ))
end

local function keyLayouts(slide, screen)
    local content = {}
    addFeatureBackdrop(content, screen)
    addFeatureHeader(content, slide)

    local rowY = 420
    for _, row in ipairs(slide.keyRows) do
        append(content, slotLayout(
            row.slot,
            util.vector2(88, rowY),
            false,
            FEATURE_ICON_SIZE
        ))

        local shortcut = row.key
        if row.alternate then
            shortcut = shortcut .. "   /   " .. row.alternate
        end
        append(content, textLayout(
            shortcut,
            util.vector2(190, rowY - 2),
            util.vector2(790, 38),
            {
                template = I.MWUI.templates.textHeader,
                textSize = 29,
                color = GOLD,
                multiline = false,
                wordWrap = false,
            }
        ))
        append(content, textLayout(
            row.label .. "  —  " .. row.description,
            util.vector2(190, rowY + 43),
            util.vector2(790, 100),
            {
                textSize = 22,
                color = WHITE,
            }
        ))
        rowY = rowY + 210
    end

    addFeatureHotbar(content, screen)
    return content, "full"
end

local function exampleLayouts(slide, screen)
    local content = {}
    addFeatureBackdrop(content, screen)
    addFeatureHeader(content, slide)

    local rowY = 418
    for _, example in ipairs(slide.examples) do
        local iconX = 88
        for _, slot in ipairs(example.slots) do
            append(content, slotLayout(
                slot,
                util.vector2(iconX, rowY),
                example.selectedSlot == slot,
                FEATURE_ICON_SIZE
            ))
            iconX = iconX + (FEATURE_ICON_SIZE + SLOT_PADDING) * GUI_SCALE + 12
        end

        append(content, textLayout(
            example.label,
            util.vector2(88, rowY + 85),
            util.vector2(850, 38),
            {
                template = I.MWUI.templates.textHeader,
                textSize = 29,
                color = GOLD,
                multiline = false,
                wordWrap = false,
            }
        ))
        append(content, textLayout(
            example.description,
            util.vector2(88, rowY + 127),
            util.vector2(880, 100),
            {
                textSize = 22,
                color = WHITE,
            }
        ))
        rowY = rowY + 235
    end

    addFeatureHotbar(content, screen)
    return content, "full"
end

local function optionLayouts(slide, screen)
    local content = {}
    addFeatureBackdrop(content, screen)
    addFeatureHeader(content, slide)

    local columns = { 88, 510 }
    for index, group in ipairs(slide.optionGroups) do
        local column = columns[((index - 1) % 2) + 1]
        local row = math.floor((index - 1) / 2)
        local y = 420 + row * 245
        append(content, textLayout(
            group.title,
            util.vector2(column, y),
            util.vector2(390, 40),
            {
                template = I.MWUI.templates.textHeader,
                textSize = 30,
                color = GOLD,
                multiline = false,
                wordWrap = false,
            }
        ))
        append(content, textLayout(
            group.description,
            util.vector2(column, y + 50),
            util.vector2(400, 150),
            {
                textSize = 22,
                color = WHITE,
            }
        ))
    end

    append(content, textLayout(
        "See it as I change it",
        util.vector2(88, 910),
        util.vector2(700, 38),
        {
            template = I.MWUI.templates.textHeader,
            textSize = 29,
            color = GOLD,
            multiline = false,
            wordWrap = false,
        }
    ))
    local iconX = 88
    for _, slot in ipairs(slide.previewSlots) do
        append(content, slotLayout(
            slot,
            util.vector2(iconX, 970),
            false,
            FEATURE_ICON_SIZE
        ))
        iconX = iconX + (FEATURE_ICON_SIZE + SLOT_PADDING) * GUI_SCALE + 12
    end
    append(content, textLayout(
        "I can see each change straight away.",
        util.vector2(88, 1060),
        util.vector2(820, 40),
        {
            textSize = 22,
            color = WHITE,
            multiline = false,
            wordWrap = false,
        }
    ))

    addFeatureHotbar(content, screen)
    return content, "full"
end

local function heroLayouts(slide, screen)
    local content = {}
    local x = round((screen.x - HERO_WIDTH) / 2)
    local y = math.max(0, screen.y - HERO_HEIGHT)

    append(content, fadeLayout(
        util.vector2(x, y),
        util.vector2(1700, HERO_HEIGHT)
    ))
    append(content, textLayout(
        slide.title,
        util.vector2(x + 44, y + 75),
        util.vector2(500, 150),
        {
            template = I.MWUI.templates.textHeader,
            textSize = 42,
            color = GOLD,
            multiline = true,
            wordWrap = false,
        }
    ))
    addHotbar(
        content,
        util.vector2((x + 450) / GUI_SCALE, (y + 62) / GUI_SCALE),
        HERO_ICON_SIZE
    )

    local crop = table.concat({
        tostring(HERO_WIDTH),
        "x",
        tostring(HERO_HEIGHT),
        "+",
        tostring(x),
        "+",
        tostring(y),
    })
    return content, crop
end

local function configureHotbar(slide)
    local iconSize = slide.kind == "hero" and HERO_ICON_SIZE or FEATURE_ICON_SIZE
    settings:set("visibleHotbars", 3)
    -- Feature slides draw a presentation copy above the fade texture. Let the
    -- regular HUD copy disappear before the capture so the bar is rendered
    -- exactly once.
    settings:set("enableFadingBars", true)
    -- The hero supplies its own enlarged hotbar above the fade. Move the live
    -- HUD copy outside the bottom crop so the two cannot overlap.
    settings:set("hotBarOnTop", slide.kind == "hero")
    settings:set("iconSize", iconSize)
    settings:set("hotbarGutterSize", HOTBAR_GAP)
    settings:set("hotbarVerticalSpacing", HOTBAR_VERTICAL_GAP)

    if I.Controller_Icon_QS and I.Controller_Icon_QS.refreshTextStyles then
        I.Controller_Icon_QS.refreshTextStyles()
    end
    if I.QuickSelect_Hotbar then
        I.QuickSelect_Hotbar.invalidateLayout(nil, false)
    end
end

local function renderSlide()
    destroyRoot()
    if I.UI.getMode() ~= nil then
        I.UI.setMode()
    end

    local screen = ui.screenSize()
    local slide = slides[slideIndex]
    configureHotbar(slide)
    snapshotContext = Snapshot.begin()
    snapshotCache = {}

    local content
    local exportSpec
    if slide.kind == "hero" then
        content, exportSpec = heroLayouts(slide, screen)
    elseif slide.kind == "keys" then
        content, exportSpec = keyLayouts(slide, screen)
    elseif slide.kind == "examples" then
        content, exportSpec = exampleLayouts(slide, screen)
    elseif slide.kind == "options" then
        content, exportSpec = optionLayouts(slide, screen)
    elseif slide.kind == "quick-keys" then
        I.UI.setMode(I.UI.MODE.QuickKeysMenu)
        if slide.quickKeysView ~= "hotbars" then
            pendingQuickKeysView = slide.quickKeysView
            pendingQuickKeysAt = core.getRealTime() + 0.2
        end
        content, exportSpec = {}, "full"
    elseif slide.kind == "main-menu" then
        I.UI.setMode(I.UI.MODE.MainMenu)
        content, exportSpec = {}, "full"
    else
        error("Unsupported presentation slide kind: " .. tostring(slide.kind))
    end

    root = ui.create({
        layer = "Notification",
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = logicalScreen(screen),
        },
        content = ui.content(content),
    })

    renderedWidth = screen.x
    renderedHeight = screen.y
    renderedExportSpec = exportSpec
    readyAt = core.getRealTime() + READY_DELAY
    if pendingQuickKeysView then
        readyAt = readyAt + 0.2
    end
    readyAnnounced = false
end

local function applyPendingQuickKeysView()
    if not pendingQuickKeysView or core.getRealTime() < pendingQuickKeysAt then
        return
    end

    local view = pendingQuickKeysView
    pendingQuickKeysView = nil
    pendingQuickKeysAt = nil
    if view == "slot-actions" then
        I.QuickSelect_Win1.openSlotActions(1)
    elseif view == "inventory" then
        I.QuickSelect_Win1.openInventorySelector(1)
    elseif view == "magic" then
        I.QuickSelect_Win1.openMagicSelector(1)
    end
end

local function start()
    started = true
    renderSlide()
end

local function announceReady()
    if readyAnnounced or not root or core.getRealTime() < readyAt then
        return
    end

    readyAnnounced = true
    local slide = slides[slideIndex]
    print(table.concat({
        "VQS_PRESENTATION_READY",
        tostring(slideIndex),
        slide.id,
        tostring(#slides),
        renderedExportSpec,
        slide.captureAction or "none",
    }, "|"))
end

local function advance()
    if slideIndex >= #slides then
        print("VQS_PRESENTATION_DONE|" .. tostring(#slides))
        destroyRoot()
        core.quit()
        return
    end

    slideIndex = slideIndex + 1
    renderSlide()
end

local function previous()
    if slideIndex <= 1 then
        return
    end
    slideIndex = slideIndex - 1
    renderSlide()
end

return {
    engineHandlers = {
        onFrame = function()
            if not started then
                start()
            else
                local screen = ui.screenSize()
                if renderedWidth ~= screen.x or renderedHeight ~= screen.y then
                    renderSlide()
                end
            end
            applyPendingQuickKeysView()
            announceReady()
        end,
        onKeyPress = function(key)
            if key.code == input.KEY.RightArrow or key.code == input.KEY.PageDown then
                advance()
                return true
            elseif key.code == input.KEY.LeftArrow or key.code == input.KEY.PageUp then
                previous()
                return true
            elseif key.code == input.KEY.Escape then
                if slides[slideIndex].kind == "main-menu" then
                    return true
                end
                destroyRoot()
                core.quit()
                return true
            end
        end,
    },
}
