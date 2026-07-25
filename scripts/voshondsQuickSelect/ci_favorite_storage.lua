-- Compatibility bridge for saves made before the module reorganisation.
--
-- OpenMW associates a script's saved state with its registered script path.
-- Keep this original path registered so its old `{ storedItems = ... }` payload
-- can be handed to the current favorite-slots service when an older save loads.

local I = require("openmw.interfaces")

return {
    engineHandlers = {
        onLoad = function(data)
            local legacySlots = data and data.storedItems
            if legacySlots and I.QuickSelect_Storage and I.QuickSelect_Storage.importLegacyFavorites then
                I.QuickSelect_Storage.importLegacyFavorites(legacySlots)
            end
        end,
    },
}
