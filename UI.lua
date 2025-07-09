local _G = getfenv()
local CraftingClue = _G["CraftingClue"]

-- Creates the font string used to display reagent information if it doesn't already exist.
function CraftingClue:InitializeUI()
    if self.reagentText then return end

    self.reagentText = ClassTrainerFrame:CreateFontString(nil, "OVERLAY", self.Config.UI.FONT)
    self.reagentText:SetPoint("TOPLEFT", _G[self.Config.UI.ANCHOR_FRAME], "BOTTOMLEFT", self.Config.UI.OFFSET_X, self.Config.UI.OFFSET_Y)
    self.reagentText:SetWidth(self.Config.UI.WIDTH)
    self.reagentText:SetJustifyH(self.Config.UI.JUSTIFY)
    self.reagentText:Hide() -- Start with the text hidden.
end

-- Retrieves the name of an item. This function handles items that might not be
-- cached by the client yet by using a tooltip trick.
-- @param itemId (number): The ID of the item to look up.
-- @return (string): The item's name or a placeholder if it's uncached.
function CraftingClue:GetItemName(itemId)
    local itemName = GetItemInfo(itemId)
    if not itemName then
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:SetHyperlink("item:" .. itemId)
        GameTooltip:Hide()
    end
    return itemName or string.format(self.Config.TEXT.UNKNOWN_ITEM, itemId)
end

-- Formats and displays the final reagent string in the UI.
-- It ensures the UI element is initialized before setting and showing the text.
-- @param text (string): The formatted text to display.
function CraftingClue:ShowReagentText(text)
    self:InitializeUI()
    self.reagentText:SetText(text)
    self.reagentText:Show()
end

-- Hides the reagent information display and clears the last selected recipe name.
function CraftingClue:HideReagentText()
    if self.reagentText then
        self.lastRecipeName = nil
        self.reagentText:Hide()
    end
end

-- Fetches craft data for a given recipe and updates the reagent text display.
-- @param recipeName (string): The name of the recipe to look up.
function CraftingClue:UpdateReagentText(recipeName)
    local craft = self:GetCraftByName(recipeName)

    if not craft or not craft.reagent_id_to_count then
        self:ShowReagentText(self.Config.TEXT.REAGENT_TITLE .. "|c" .. self.Config.UI.COLORS.ERROR .. self.Config.TEXT.NOT_AVAILABLE .. "|r")
        return
    end

    local textParts = {}

    for reagentId, requiredCount in pairs(craft.reagent_id_to_count) do
        local itemName = self:GetItemName(reagentId)
        local playerCount = self:GetItemCountInBags(reagentId)
        -- Color the required count based on whether the player has enough.
        local countColor = (playerCount < requiredCount) and self.Config.UI.COLORS.MISSING or self.Config.UI.COLORS.DEFAULT
        local colorizedCount = "|c" .. countColor .. requiredCount .. "|r"

        table.insert(textParts, string.format("%s (%s)", itemName, colorizedCount))
    end

    local fullText = self.Config.TEXT.REAGENT_TITLE .. table.concat(textParts, ", ")
    self:ShowReagentText(fullText)
end

-- Counts the total number of a specific item in the player's bags.
-- @param itemId (number): The ID of the item to count.
-- @return (number): The total count of the item across all bags.
function CraftingClue:GetItemCountInBags(itemId)
    local count = 0
    -- Iterate through the player's bags (0 is the backpack, 1-4 are the equipped bags).
    for bag = 0, 4 do -- bags 0-4: backpack + bags
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, linkItemId = string.find(itemLink, "item:(%d+):")
                if linkItemId and tonumber(linkItemId) == itemId then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    count = count + (itemCount or 0)
                end
            end
        end
    end
    return count
end
