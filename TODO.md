### Todos

- Item Count for Lockpicks/of that type
- Charge counter for probes, lockpicks, repair shit
- Add repair shit in the first place
- Configurable thresholds by item category
- Configurable thresholds for charge level colouring
- refactor to actionbars
- refactor rendering
- new screenshots
- move magic settings down
- trigger cast of spell?
- equip triangle instead of bar bottom left corner OR change border colour
- flash or permanent last activated thing text above bar
- item condition text?

### Hints

```lua Colour Blending
    local textAlpha = (magicChargeSettings:get("magicChargeTextAlpha") or 100) / 100
    local baseColor = magicChargeSettings:get("magicChargeTextColor") or util.color.rgba(0.2, 0.6, 1, 1)
    local baseColorWithAlpha = util.color.rgba(baseColor.r, baseColor.g, baseColor.b, textAlpha)

    -- Critical threshold (10% or less)
    local criticalColor = util.color.rgba(1.0, 0.1, 0.1, textAlpha)  -- red

    -- Warning threshold (30% or less)
    local warningColor = util.color.rgba(0.95, 0.65, 0.0, textAlpha) -- orange

    local percentage = charge / maxCharge
    Debug.log("EnchantCharge", "Charge percentage: " .. tostring(percentage * 100) .. "%")

    if percentage <= 0.1 then
        Debug.log("EnchantCharge", "Using critical color (<=10%)")
        return criticalColor
    elseif percentage <= 0.3 then
        Debug.log("EnchantCharge", "Using warning color (<=30%)")
        return warningColor
    else
        Debug.log("EnchantCharge", "Using normal color (>30%)")
        return baseColorWithAlpha
    end
end

local function textContent(text, isCharge, maxCharge)
    if not text or text == "" then
        return {}
    end
    refreshTextStyles()
    -- Always show charge values for enchanted items, only check showItemCounts for regular item counts
    local styles = getTextStyles()
    if not isCharge and not styles.showItemCounts then
        return {}
    end
    local count = tonumber(text)
    local color = styles.textColor
    local position = util.vector2(0.1, 0.05) -- Default position (upper left)
    -- Special handling for charge values
    if isCharge then
        local magicStyles = getMagicChargeStyles()
        if not magicStyles.showMagicCharges then
            return {}
        end

        -- Determine color based on charge percentage if maxCharge is available
        if maxCharge and tonumber(text) and tonumber(maxCharge) then
            color = getEnchantmentChargeColor(tonumber(text), tonumber(maxCharge))
        else
            color = magicStyles.textColor
        end

        local displayText = text
        if maxCharge and magicStyles.showMaxMagicCharges then
            displayText = tostring(text) .. "/" .. tostring(maxCharge)
        end
        return {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = displayText,
                textSize = magicStyles.textSize,
                relativePosition = position,
                anchor = position,
                arrange = ui.ALIGNMENT.Start,
                align = ui.ALIGNMENT.Start,
                textShadow = magicStyles.shadowEnabled,
                textShadowColor = magicStyles.shadowColor,
                textColor = color
            }
        }
    elseif count then
        color = getThresholdItemCountColor(count)
    end
    return {
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = {
            text = text,
            textSize = styles.itemCountTextSize,
            relativePosition = position,
            anchor = position,
            arrange = ui.ALIGNMENT.Start,
            align = ui.ALIGNMENT.Start,
            textShadow = TEXT_SHADOWS.enabled,
            textShadowColor = TEXT_SHADOWS.color,
            textColor = color
        }
    }
end

local function imageContent(resource, half, customOpacity)
    local size = getIconSize()
    local opacity = customOpacity or 1
    if half and customOpacity == nil then
        opacity = 0.5
    end

    -- Create a consistent size for all images
    local sizeX = size
    local sizeY = size

    if half then
        sizeY = sizeY / 2
    end

    if not resource then
        return {}
    end

    return {
        type = ui.TYPE.Image,
        props = {
            resource = resource,
            size = util.vector2(sizeX, sizeY),
            alpha = opacity,
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center
        }
    }
end
local function getTexture(path)
    if not savedTextures[path] and path then
        savedTextures[path] = ui.texture({ path = path })
    end
    return savedTextures[path]
end
local function formatNumber(num)
    local threshold = 1000
    local millionThreshold = 1000000

    if num >= millionThreshold then
        local formattedNum = math.floor(num / millionThreshold)
        return string.format("%dm", formattedNum)
    elseif num >= threshold then
        local formattedNum = math.floor(num / threshold)
        return string.format("%dk", formattedNum)
    else
        return tostring(num)
    end
end
local function FindEnchant(item)
    if not item or not item.id then
        return nil
    end
    if item.enchant then
        return item.enchant
    end
    if (item == nil or item.type == nil or item.type.records[item.recordId] == nil or item.type.records[item.recordId].enchant == nil or item.type.records[item.recordId].enchant == "") then
        return nil
    end
    return item.type.records[item.recordId].enchant
end

-- Helper to check if a table is empty
local function isEmptyTable(t)
    return type(t) == 'table' and next(t) == nil
end

local function getItemIcon(item, half, selected, slotNumber, slotPrefix, slotData)
    Debug.log("QuickSelect",
        "getItemIcon called for item: " ..
        tostring(item) ..
        ", type: " .. tostring(item and item.type) .. ", recordId: " .. tostring(item and item.recordId))
    if item and item.type and item.recordId then
        local record = item.type.records[item.recordId]
        Debug.log("QuickSelect",
            "Item record: " .. tostring(record and record.id) .. ", enchant: " .. tostring(record and record.enchant))
    end
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")

    -- Get magic icon with reduced opacity (0.7)
    local magicIconOpacity = 0.3
    local magicIcon = FindEnchant(item) and FindEnchant(item) ~= "" and getTexture("textures\\menu_icon_magic_mini.dds")
    local text = ""
    local chargeText = {}    -- Ensure chargeText is always defined
    local itemCountText = {} -- Ensure itemCountText is always defined
    if item and item.type then
        local record = item.type.records[item.recordId]
        local enchantmentId = record and record.enchant
        if not record then
            Debug.error("ci_icon_render", "No record for " .. item.recordId)
        else
            Debug.log("ci_icon_render", "Icon: " .. tostring(record.icon))
        end
        if item.count > 1 then
            text = formatNumber(item.count)
        end
        itemIcon = getTexture(record.icon)

        -- Add enchanted item charge display (upper left, replaces item count if enchanted)
        if enchantmentId and enchantmentId ~= "" then
            Debug.log("QuickSelect",
                "Found enchantmentId: " .. tostring(enchantmentId) .. " for item: " .. tostring(item.recordId))
            local enchantment = core.magic.enchantments.records[enchantmentId]

            -- Register this enchanted item for periodic updates
            registerEnchantedItem(item, slotNumber)

            -- Get charge directly when rendering the item
            local charge = getItemCharge(item)

            -- If direct charge retrieval failed, try to use cached or slot data value
            if charge == nil then
                local itemKey = item.recordId .. "_" .. (item.id or "")
                if enchantmentChargeCache[itemKey] then
                    charge = enchantmentChargeCache[itemKey]
                elseif slotData and slotData.lastKnownCharge then
                    charge = slotData.lastKnownCharge
                end
            end

            Debug.log("QuickSelect", "Final charge value: " .. tostring(charge))

            if enchantment then
                Debug.log("QuickSelect", "Enchantment type: " .. tostring(enchantment.type))

                -- Only show charge for enchantments that use charges
                local usesCharge = (
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnUse or
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnStrike or
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnce
                )

                Debug.log("QuickSelect", "usesCharge: " .. tostring(usesCharge) .. ", charge: " .. tostring(charge))

                if usesCharge and charge ~= nil then
                    charge = math.floor(charge)
                    local maxCharge = enchantment and enchantment.charge and math.floor(enchantment.charge) or "?"
                    Debug.log("QuickSelect",
                        "Displaying charge: " ..
                        tostring(charge) .. "/" .. tostring(maxCharge) .. " for item: " .. tostring(item.recordId))
                    chargeText = textContent(tostring(charge), true, maxCharge)
                    Debug.log("QuickSelect",
                        "chargeText from textContent: " .. tostring(chargeText.props and chargeText.props.text))

                    -- Update slotData with the current charge for future reference
                    if slotData then
                        slotData.lastKnownCharge = charge
                    end
                elseif usesCharge and charge == nil then
                    Debug.log("QuickSelect",
                        "Enchanted item has no charge property (even after fallback): " .. tostring(item.recordId))
                end
            end
        end
    end

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end

    -- Save item count text for the upper left
    itemCountText = textContent(tostring(text), false)

    -- Format the slot number with the prefix if available
    local slotText = slotNumber
    if slotPrefix and slotPrefix ~= "" then
        -- Calculate the slot's position within its bar (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        -- Display slot number with prefix
        slotText = slotPrefix .. slotPosition
    else
        -- For the first bar, just show the slot position (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        slotText = slotPosition
    end

    -- Refresh text styles to ensure we have the latest settings
    refreshTextStyles()

    -- Create slot number content only if enabled
    local slotNumberContent = {}
    local styles = getTextStyles()

    if styles.showSlotNumbers and slotNumber then
        slotNumberContent = {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(slotText),
                textSize = styles.slotNumberTextSize,
                relativePosition = util.vector2(0.85, 0.9),
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                textShadow = TEXT_SHADOWS.enabled,
                textShadowColor = TEXT_SHADOWS.color,
                textColor = TEXT_COLORS.slotNumber
            }
        }
    end

    -- Compose UI content
    local uiContent = { selectedContent, imageContent(magicIcon, half, magicIconOpacity), imageContent(itemIcon, half) }
    -- Insert chargeText if present, otherwise itemCountText
    if not isEmptyTable(chargeText) then
        Debug.log("QuickSelect",
            "Inserting chargeText into UI content array: " .. tostring(chargeText.props and chargeText.props.text))
        table.insert(uiContent, chargeText)
    elseif not isEmptyTable(itemCountText) then
        table.insert(uiContent, itemCountText)
    end
    -- Render the slot number as before
    --[[ if slotNumberContent and not isEmptyTable(slotNumberContent) then
        table.insert(uiContent, slotNumberContent)
    end ]] --
    Debug.log("QuickSelect",
        "Final UI content: " .. tostring(#uiContent) .. " elements, content: " .. tostring(uiContent))
    return ui.content(uiContent)
end
local function getSpellIcon(iconPath, half, selected, slotNumber, slotPrefix)
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")
    local pendingText = getTexture("icons\\buying.tga")

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end
    itemIcon = getTexture(iconPath)

    -- Format the slot number with the prefix if available
    local slotText = slotNumber
    if slotPrefix and slotPrefix ~= "" then
        -- Calculate the slot's position within its bar (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        -- Display slot number with prefix
        slotText = slotPrefix .. slotPosition
    else
        -- For the first bar, just show the slot position (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        slotText = slotPosition
    end

    -- Refresh text styles to ensure we have the latest settings
    refreshTextStyles()

    -- Create slot number content only if enabled
    local slotNumberContent = {}
    local styles = getTextStyles()

    if styles.showSlotNumbers and slotNumber then
        slotNumberContent = {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(slotText),
                textSize = styles.slotNumberTextSize,
                relativePosition = util.vector2(0.85, 0.9),
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                textShadow = TEXT_SHADOWS.enabled,
                textShadowColor = TEXT_SHADOWS.color,
                textColor = TEXT_COLORS.slotNumber
            }
        }
    end

    local context = ui.content {
        imageContent(itemIcon, half),
        selectedContent,
        -- Add slot number to bottom right if we have it and it's enabled
        slotNumberContent
    }

    return context
end
local function getEmptyIcon(half, num, selected, useNumber, slotPrefix)
    local size = getIconSize()
    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end

    -- Format the slot number with the prefix if available
    local text = num
    if slotPrefix and slotPrefix ~= "" then
        -- Calculate the slot's position within its bar (1-10)
        local slotPosition = ((num - 1) % 10) + 1
        -- Display slot number with prefix
        text = slotPrefix .. slotPosition
    else
        -- For the first bar, just show the slot position (1-10)
        local slotPosition = ((num - 1) % 10) + 1
        text = slotPosition
    end

    -- Calculate proper size for the text, matching the icon size
    local textSize = 14 -- Smaller size for slot numbers
    if half then
        textSize = textSize / 1.5
    end

    -- Refresh text styles to ensure we have the latest settings
    refreshTextStyles()

    -- Only show number if slot numbers are enabled
    local styles = getTextStyles()
    if not styles.showSlotNumbers then
        return ui.content { selectedContent }
    end

    return ui.content {
        selectedContent,
        {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(text),
                textSize = styles.slotNumberTextSize,
                relativePosition = util.vector2(0.85, 0.9),
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                textShadow = TEXT_SHADOWS.enabled,
                textShadowColor = TEXT_SHADOWS.color,
                textColor = TEXT_COLORS.slotNumber
            },
            num = num,
            events = {
                --          mouseMove = async:callback(mouseMove),
            },
        }
    }
end

return {
    interfaceName = "Controller_Icon_QS",
    interface = {
        version = 1,
        getItemIcon = getItemIcon,
        getSpellIcon = getSpellIcon,
        getEmptyIcon = getEmptyIcon,
        refreshTextStyles = refreshTextStyles,        -- Export this so it can be called when settings change
        refreshEnchantedItems = refreshEnchantedItems -- Export the refresh function
    },
    eventHandlers = {
    },
    engineHandlers = {
        onInit = function()
            -- Initialize the timer system
            Debug.log("EnchantCharge", "Initializing enchantment charge tracking system")

            -- Start with a clean state
            activeEnchantedItems = {}
            enchantmentChargeCache = {}
            refreshTimerActive = false

            -- Start the refresh timer after a short delay to allow other systems to initialize
            async:newUnsavableSimulationTimer(1.0, function()
                startRefreshTimer()
            end)
        end,
        onFrame = function()
            -- Only refresh text styles once per second at most
            local currentTime = core.getGameTime()
            if not lastTextStyleRefreshTime or currentTime - lastTextStyleRefreshTime >= 1.0 then
                refreshTextStyles()
                lastTextStyleRefreshTime = currentTime
            end

            -- We no longer refresh enchanted items every frame
            -- Instead, we use a timer that runs every REFRESH_INTERVAL seconds
        end
    }
}
```
