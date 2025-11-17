-- Tooltip component for voshondsHotbars
-- Handles tooltip layer initialization and tooltip creation

local ui = require('openmw.ui')
local constants = require('scripts.voshondshotbars.core.constants')
local debug = require('scripts.voshondshotbars.utils.debug')

local tooltip = {}

-- ============================================================================
-- PRIVATE STATE
-- ============================================================================

-- Track if tooltip layer has been initialized
local tooltipLayerInitialized = false

-- ============================================================================
-- LAYER MANAGEMENT
-- ============================================================================

-- Check if a UI layer exists
-- @param layerName string
-- @return boolean
local function layerExists(layerName)
    for _, layer in ipairs(ui.layers) do
        if layer.name == layerName then
            return true
        end
    end
    return false
end

-- Initialize tooltip layer (should be called once on mod load)
-- Creates a non-interactive layer for tooltips above other UI elements
function tooltip.initLayer()
    if tooltipLayerInitialized then
        debug.ui("Tooltip layer already initialized")
        return true
    end

    -- Check if layer already exists (might be created by another mod)
    if layerExists(constants.LAYER_TOOLTIP) then
        debug.ui("TooltipLayer already exists")
        tooltipLayerInitialized = true
        return true
    end

    -- Create tooltip layer
    -- Layer hierarchy: HUD < Windows < TooltipLayer
    -- This ensures tooltips appear above everything else
    local success, err = pcall(function()
        -- Ensure Windows layer exists first
        if not layerExists(constants.LAYER_WINDOWS) then
            debug.ui("Creating Windows layer")
            ui.layers.insertAfter(constants.LAYER_HUD, constants.LAYER_WINDOWS, {
                interactive = true
            })
        end

        -- Create TooltipLayer after Windows
        debug.ui("Creating TooltipLayer")
        ui.layers.insertAfter(constants.LAYER_WINDOWS, constants.LAYER_TOOLTIP, {
            interactive = false  -- Tooltips don't intercept input
        })
    end)

    if success then
        tooltipLayerInitialized = true
        debug.ui("Tooltip layer initialized successfully")
        return true
    else
        debug.uiError("Failed to create tooltip layer: " .. tostring(err))
        return false
    end
end

-- Get the appropriate layer for tooltips
-- Falls back to HUD if tooltip layer doesn't exist
-- @return string layerName
function tooltip.getLayer()
    if layerExists(constants.LAYER_TOOLTIP) then
        return constants.LAYER_TOOLTIP
    else
        debug.uiWarning("TooltipLayer not found, falling back to HUD")
        return constants.LAYER_HUD
    end
end

-- ============================================================================
-- TOOLTIP CREATION
-- ============================================================================

--[[
    Create a simple text tooltip

    This is a basic tooltip component. For more complex tooltips
    (item stats, spell effects, etc.), use the ci_tooltipgen module.
]]

-- Create tooltip content element
-- @param text string
-- @param options table (optional)
--   - textSize: number (default 14)
--   - textColor: color (default white)
--   - backgroundColor: color (default semi-transparent black)
--   - padding: number (default 4)
--   - maxWidth: number (default 300)
-- @return table UI element
function tooltip.createTooltip(text, options)
    options = options or {}

    local textSize = options.textSize or 14
    local textColor = options.textColor or ui.util.color.rgb(1, 1, 1)
    local backgroundColor = options.backgroundColor or ui.util.color.rgba(0, 0, 0, 0.8)
    local padding = options.padding or 4
    local maxWidth = options.maxWidth or 300

    return {
        layer = tooltip.getLayer(),
        type = ui.TYPE.Container,
        props = {
            position = options.position,
            anchor = options.anchor,
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                template = require('openmw.interfaces').MWUI.templates.textNormal,
                props = {
                    text = text,
                    textSize = textSize,
                    textColor = textColor,
                    multiline = true,
                    wordWrap = true,
                    autoSize = true,
                },
            }
        }),
    }
end

-- Create positioned tooltip near cursor or element
-- @param text string
-- @param position vector2 (screen position)
-- @param options table (optional, same as createTooltip)
-- @return table UI element
function tooltip.createPositionedTooltip(text, position, options)
    options = options or {}
    options.position = position
    options.anchor = options.anchor or ui.util.vector2(0, 0)

    return tooltip.createTooltip(text, options)
end

-- ============================================================================
-- TOOLTIP HELPERS
-- ============================================================================

-- Calculate tooltip position to keep it on screen
-- @param cursorPos vector2 (cursor position)
-- @param tooltipSize vector2 (tooltip size)
-- @param offset vector2 (optional, offset from cursor, default (10, 10))
-- @return vector2 position
function tooltip.calculatePosition(cursorPos, tooltipSize, offset)
    offset = offset or ui.util.vector2(10, 10)

    local screenSize = ui.screenSize()
    local pos = cursorPos + offset

    -- Keep tooltip on screen (right edge)
    if pos.x + tooltipSize.x > screenSize.x then
        pos = ui.util.vector2(cursorPos.x - tooltipSize.x - offset.x, pos.y)
    end

    -- Keep tooltip on screen (bottom edge)
    if pos.y + tooltipSize.y > screenSize.y then
        pos = ui.util.vector2(pos.x, cursorPos.y - tooltipSize.y - offset.y)
    end

    -- Keep tooltip on screen (left edge)
    if pos.x < 0 then
        pos = ui.util.vector2(0, pos.y)
    end

    -- Keep tooltip on screen (top edge)
    if pos.y < 0 then
        pos = ui.util.vector2(pos.x, 0)
    end

    return pos
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Auto-initialize on module load
-- This ensures the layer is ready when other modules need it
tooltip.initLayer()

return tooltip
