local _G = getfenv()

local CraftingClue = _G.CraftingClue
assert(CraftingClue, "CraftingClue Error: CraftingClue table not found in data.lua. Ensure core.lua loaded first.")
assert(CraftingClue.LibCrafts, "CraftingClue Error: CraftingClue.LibCrafts not found in data.lua. LibCrafts dependency missing or not initialized.")


-- Retrieves craft details from LibCrafts by the recipe's localized name.
-- Note: This relies on an exact match with the localized spell name stored in LibCrafts.
-- @param recipeName (string): The localized name of the recipe/spell.
-- @return (table | nil): The craft data table if found, otherwise nil.
function CraftingClue:GetCraftByName(recipeName)
    if not recipeName or not self.LibCrafts.spell_id_to_craft then
        return nil
    end

    -- Iterate through all the crafts provided by LibCrafts.
    for spellId, craftData in pairs(self.LibCrafts.spell_id_to_craft) do
        if craftData.localized_spell_name == recipeName then
            return craftData
        end
    end
    return nil
end