local _G = getfenv()

local CraftingClue = {}
_G["CraftingClue"] = CraftingClue

local LibStub = _G["LibStub"]
assert(LibStub, "LibStub not found")

local LibCrafts = LibStub:GetLibrary("LibCrafts-1.0", true)
assert(LibCrafts, "LibCrafts-1.0 not found")

-- Some configs, can be expanded or not. It might be already overkill.
CraftingClue.Config = {
    TEXT = {
        LOADED_MESSAGE = "CraftingClue Loaded", -- Message displayed in chat when the addon is loaded.
        REAGENT_TITLE  = "Reagents: ",          -- Prefix for the reagent list display.
        NOT_AVAILABLE = "N/A",                  -- Text displayed when reagent information is not available for a recipe.
        UNKNOWN_ITEM   = "Item %d (uncached). Click on recipe again to display.", -- Placeholder for uncached items.
    },
    UI = {
        FONT           = "GameFontHighlightSmall", -- The font used for displaying reagent information.
        ANCHOR_FRAME   = "ClassTrainerSkillName",  -- The UI element to anchor our reagent text to.
        OFFSET_X       = 0,                        -- X-axis offset from the anchor frame.
        OFFSET_Y       = -10,                      -- Y-axis offset from the anchor frame.
        WIDTH          = 280,                      -- The maximum width of the reagent text display.
        JUSTIFY        = "LEFT",                   -- Text justification (e.g., "LEFT", "CENTER", "RIGHT").
        COLORS         = {
            TITLE   = "ffffd100", -- WoW's default yellow for titles.
            MISSING = "ffff4444", -- Red color for reagents where the player has insufficient quantity.
            DEFAULT = "ffcccccc", -- Light grey color for reagents where the player has sufficient quantity.
            ERROR   = "ffff4444", -- Red color for error messages (e.g., reagent info N/A).
        }
    },
    CORE = {
        ADDON_NAME       = "CraftingClue", -- The official name of the addon.
        RECIPES_HEADER   = "Recipes",      -- The header text under which learnable recipes are typically listed in the trainer UI.
        HEADER_CATEGORY  = "header",       -- The category type string used by GetTrainerServiceInfo for headers.
        AVAILABLE_STATUS = "available",    -- The status string for learnable recipes (currently not directly used but available for future features).
        DEBUG_MODE       = false,          -- A boolean flag to enable/disable debug output (not fully implemented in this version).
    }
}

-- Stores a reference to the LibCrafts-1.0 library instance.
-- This library is used to fetch detailed crafting recipe data.
CraftingClue.LibCrafts = LibCrafts

-- Stores the name of the last clicked recipe in the trainer.
-- This is used to re-display reagent information if the trainer UI updates.
CraftingClue.lastRecipeName = nil

-- A flag to ensure we only hook the trainer buttons once.
local buttonsHooked = false


-- Checks if a skill at a given index is categorized under a specific header.
-- This is useful for differentiating between recipes and other trainer entries (like "Development Skills").
-- @param skillIndex (number): The index of the skill to check.
-- @param headerNameToMatch (string): The name of the header to look for.
-- @return (boolean): True if the skill is under the specified header, false otherwise.
function CraftingClue:IsUnderHeader(skillIndex, headerNameToMatch)
    -- Iterate backwards from the skill's position to find the preceding header.
    for i = skillIndex - 1, 1, -1 do
        local headerName, _, category = GetTrainerServiceInfo(i)
        if category == self.Config.CORE.HEADER_CATEGORY then
            -- We've found the most recent header. Check if it's the one we want.
            return headerName == headerNameToMatch
        end
    end
    return false
end

-- Hooks the OnClick script of the trainer buttons to intercept user clicks
-- and display relevant reagent information for crafting recipes.
function CraftingClue:HookTrainerRecipes()
    if buttonsHooked then return end

    -- Loop through all the skill buttons displayed in the class trainer UI.
    -- CLASS_TRAINER_SKILLS_DISPLAYED is a global variable indicating the number of visible skill buttons.
    for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED do
        local button = _G["ClassTrainerSkill" .. i]
        if button and not button.hooked then
            local originalOnClick = button:GetScript("OnClick")

            button:SetScript("OnClick", function()
                local skillIndex = button:GetID()
                local name, _, category = GetTrainerServiceInfo(skillIndex)

                -- We only care about recipes, not headers like "Development Skills".
                if category ~= self.Config.CORE.HEADER_CATEGORY and self:IsUnderHeader(skillIndex, self.Config.CORE.RECIPES_HEADER) then
                    self.lastRecipeName = name
                    self:UpdateReagentText(name)
                else
                    self:HideReagentText()
                end
                
                -- Call the original OnClick function to maintain default behavior.
                if originalOnClick then
                    originalOnClick(button)
                end
            end)

            button.hooked = true
        end
    end

    buttonsHooked = true
end

local eventFrame = CreateFrame("Frame", "CraftingClueEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == CraftingClue.Config.CORE.ADDON_NAME then
        DEFAULT_CHAT_FRAME:AddMessage(CraftingClue.Config.TEXT.LOADED_MESSAGE)
        eventFrame:RegisterEvent("TRAINER_UPDATE")
        eventFrame:RegisterEvent("TRAINER_CLOSED")
    elseif event == "TRAINER_UPDATE" then
        if ClassTrainerFrame:IsVisible() and IsTradeskillTrainer() then
            CraftingClue:HookTrainerRecipes()
            -- If a recipe was previously selected, refresh its reagent display.
            if CraftingClue.lastRecipeName then
                CraftingClue:UpdateReagentText(CraftingClue.lastRecipeName)
            end
        end
    elseif event == "TRAINER_CLOSED" then
        CraftingClue:HideReagentText()
    end
end)
