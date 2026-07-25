local InventoryGrid = {}

function InventoryGrid.fit(params)
    params = params or {}

    local iconSize = math.max(1, params.iconSize or 40)
    local gap = math.max(0, params.gap or 0)
    local requestedColumns = math.max(1, params.columns or 10)
    local minimumWidth = math.max(iconSize, params.minimumWidth or 360)
    local maximumWidth = math.max(minimumWidth, params.maximumWidth or minimumWidth)
    local stride = iconSize + gap

    -- A small icon size can make the requested number of columns narrower
    -- than the selector itself. Add columns in that case so the grid reaches
    -- the usable panel width instead of leaving a large empty strip.
    local columnsToFillMinimum = math.max(1, math.floor((minimumWidth + gap) / stride))
    local maximumColumns = math.max(1, math.floor((maximumWidth + gap) / stride))
    local columns = math.min(maximumColumns, math.max(requestedColumns, columnsToFillMinimum))
    local width = columns * iconSize + math.max(0, columns - 1) * gap

    return {
        columns = columns,
        width = width,
    }
end

return InventoryGrid
