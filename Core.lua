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
        LOADED_MESSAGE = "CraftingClue Loaded",
        REAGENT_TITLE  = "Reagents: ",
        NOT_APPLICABLE = "N/A",
        UNKNOWN_ITEM   = "Item %d (uncached). Click on recipe again to display.",
    },
    UI = {
        FONT         = "GameFontHighlightSmall", -- The font used for displaying reagent info.
        ANCHOR_FRAME = "ClassTrainerSkillName",  -- The UI element to anchor our text to.
        OFFSET_X     = 0,
        OFFSET_Y     = -10,
        WIDTH        = 280,
        JUSTIFY      = "LEFT",
        COLORS       = {
            TITLE   = "ffffd100", -- WoW's default yellow for titles
            MISSING = "ffff4444", -- Red for not enough items
            DEFAULT = "ffcccccc", -- Light grey for sufficient items
            ERROR   = "ffff4444", -- Red for errors like N/A
        }
    },
    CORE = {
        ADDON_NAME       = "CraftingClue",
        RECIPES_HEADER   = "Recipes",   -- The header under which recipes are listed in the trainer.
        HEADER_CATEGORY  = "header",    -- The category type for headers in the trainer UI.
        AVAILABLE_STATUS = "available", -- The status for learnable recipes.
        DEBUG_MODE       = false,
    }
}

CraftingClue.LibCrafts = LibCrafts

local eventFrame = CreateFrame("Frame", 'CraftingClueEventFrame')
eventFrame:RegisterEvent("ADDON_LOADED")

-- A flag to ensure we only hook the trainer buttons once.
local buttonsHooked = false

-- Checks if a skill at a given index is categorized under a specific header.
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

-- Hooks the OnClick script of the trainer buttons to intercept clicks
-- and display reagent information.
function CraftingClue:HookTrainerRecipes()
    if buttonsHooked then return end

    -- Loop through all the skill buttons displayed in the class trainer UI.
    for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED do
        local button = _G["ClassTrainerSkill" .. i]
        if button and not button.hooked then
            local originalOnlClick = button:GetScript("OnClick")

            button:SetScript("OnClick", function()
                local skillIndex = button:GetID()
                local name, _, category = GetTrainerServiceInfo(skillIndex)

                -- We only care about recipes, not headers like "development skills".
                if category ~= self.Config.CORE.HEADER_CATEGORY and self:IsUnderHeader(skillIndex, self.Config.CORE.RECIPES_HEADER) then
                    self:UpdateReagentText(name)
                else
                    self:DisplayReagentText("")
                end
                
                -- Call the original OnClick function to maintain default behavior.
                if originalOnlClick then
                    originalOnlClick(button)
                end
            end)

            button.hooked = true
        end
    end

    buttonsHooked = true
end

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == CraftingClue.Config.CORE.ADDON_NAME then
        DEFAULT_CHAT_FRAME:AddMessage(CraftingClue.Config.TEXT.LOADED_MESSAGE)
        eventFrame:RegisterEvent("TRAINER_SHOW")
        eventFrame:RegisterEvent("TRAINER_UPDATE")
        eventFrame:RegisterEvent("TRAINER_CLOSED")
    elseif event == "TRAINER_SHOW" then
        if ClassTrainerFrame:IsVisible() then
            if IsTradeskillTrainer() then
                CraftingClue:HookTrainerRecipes()
            elseif CraftingClue.reagentText then
                CraftingClue.reagentText:Hide()
            end
        end
    elseif event == 'TRAINER_UPDATE' then
        if ClassTrainerFrame:IsVisible() and IsTradeskillTrainer() then
            CraftingClue:HookTrainerRecipes()

            -- Check if there are any visible, available services
            local numServices = GetNumTrainerServices()
            local hasAvailable = false
            for i = 1, numServices do
                local _, _, category, availability = GetTrainerServiceInfo(i)
                if category ~= CraftingClue.Config.CORE.HEADER_CATEGORY and availability == CraftingClue.Config.CORE.AVAILABLE_STATUS then
                    hasAvailable = true
                    break
                end
            end

            if not hasAvailable and CraftingClue.reagentText then
                CraftingClue:DisplayReagentText("")
            end
        end
    elseif event == "TRAINER_CLOSED" then
        if CraftingClue.reagentText then
            CraftingClue.reagentText:Hide()
        end
    end
end)
