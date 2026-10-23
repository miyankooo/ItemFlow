local _, ns = ...

-- A right-click buys one purchase through Blizzard's MerchantItemButton_OnClick, which the merchant buttons
-- call by name. With Buy Max Stack on, a post-hook tops that purchase up to the item's max stack. Items Blizzard
-- asks about first, like extended costs and high prices, are left to its confirmation.
local function TopUp(button, mouseButton)
  if not ns.db.buyMaxStack or mouseButton ~= "RightButton" or MerchantFrame.selectedTab ~= 1 then return end
  if button.extendedCost or button.showNonrefundablePrompt
    or (button.price and button.price >= MERCHANT_HIGH_PRICE_COST) then
    return
  end

  local index = button:GetID()
  local info = C_MerchantFrame.GetItemInfo(index)
  if not (info and info.isPurchasable and info.stackCount > 0) then return end

  -- The first purchase has not left the money yet, so the affordable count still includes it.
  local wanted = GetMerchantItemMaxStack(index)
  if info.price > 0 then
    wanted = math.min(wanted, math.floor(GetMoney() / (info.price / info.stackCount)))
  end
  if info.numAvailable > 0 then
    wanted = math.min(wanted, info.numAvailable)
  end

  -- Items sold in bundles are bought in whole bundles, as Blizzard's stack split does.
  local extra = wanted - info.stackCount
  extra = extra - extra % info.stackCount
  if extra > 0 then BuyMerchantItem(index, extra) end
end

hooksecurefunc("MerchantItemButton_OnClick", TopUp)

-- Forever's own checkboxes, like Watch Faction in Camelot/ReputationFrame.xml, are 26 px minimal checkboxes with a
-- GameFontNormal label 2 px to the right. CheckboxWithLabelTemplate carries the same art.
local checkbox = CreateFrame("CheckButton", nil, MerchantFrame, "CheckboxWithLabelTemplate")
checkbox:SetSize(26, 26)
checkbox.Text:SetFontObject(GameFontNormal)
checkbox.Text:ClearAllPoints()
checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
checkbox.Text:SetText("Buy Max Stack")

-- The checkbox sits in the top bar, left of the filter dropdown, or in its place where a game rule hides it, as
-- MerchantFrame_Update does.
local labelWidth = checkbox.Text:GetUnboundedStringWidth() + 2
if C_GameRules.IsGameRuleActive(Enum.GameRule.MerchantFilterDisabled) then
  checkbox:SetPoint("RIGHT", MerchantFrame.FilterDropdown, "RIGHT", -labelWidth, 0)
else
  checkbox:SetPoint("RIGHT", MerchantFrame.FilterDropdown, "LEFT", -(labelWidth + 8), 0)
end
checkbox:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip_SetTitle(GameTooltip, "Buy Max Stack")
  GameTooltip_AddNormalLine(GameTooltip, "Right-clicking an item buys a full stack.")
  GameTooltip:Show()
end)
checkbox:SetScript("OnLeave", GameTooltip_Hide)
checkbox:SetScript("OnClick", function(self)
  ns.db.buyMaxStack = self:GetChecked()
  PlaySound(ns.db.buyMaxStack and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end)

-- The settings page can change the value between visits.
checkbox:SetScript("OnShow", function(self) self:SetChecked(ns.db.buyMaxStack) end)
