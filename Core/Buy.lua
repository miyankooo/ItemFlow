local _, ns = ...

-- A right-click buys one purchase through Blizzard's MerchantItemButton_OnClick, which the merchant buttons
-- call by name. With Buy Max Stack on, a post-hook tops that purchase up to the item's max stack. Items Blizzard
-- asks about first, extended costs and high prices, are left to its confirmation. The non-refundable flag alone
-- is no reason to stop: Forever marks every item with it and Blizzard still buys at once below the high price.
local function TopUp(button, mouseButton)
  if not ns.db.buyMaxStack or mouseButton ~= "RightButton" or MerchantFrame.selectedTab ~= 1 then return end
  if button.extendedCost or (button.price and button.price >= MERCHANT_HIGH_PRICE_COST) then return end

  local index = button:GetID()
  local info = C_MerchantFrame.GetItemInfo(index)
  if not (info and info.isPurchasable and info.stackCount > 0) then return end

  -- A full stack is the item's own stack size. GetMerchantItemMaxStack is the most one purchase may hold.
  local perPurchase = GetMerchantItemMaxStack(index)
  local wanted = C_Item.GetItemMaxStackSizeByID(GetMerchantItemID(index)) or perPurchase

  -- The first purchase has not left the money yet, so the affordable count still includes it.
  if info.price > 0 then
    wanted = math.min(wanted, math.floor(GetMoney() / (info.price / info.stackCount)))
  end
  if info.numAvailable > 0 then
    wanted = math.min(wanted, info.numAvailable)
  end

  -- Items sold in bundles are bought in whole bundles, as Blizzard's stack split does.
  local bundle = info.stackCount
  local extra = wanted - bundle
  extra = extra - extra % bundle
  perPurchase = math.max(perPurchase - perPurchase % bundle, bundle)
  while extra > 0 do
    local quantity = math.min(extra, perPurchase)
    BuyMerchantItem(index, quantity)
    extra = extra - quantity
  end
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

-- A first-visit HelpTip, the yellow callout Forever's Reputation and Currency tabs use, points at the label from
-- its right. It returns at every vendor until the player closes it or uses the checkbox, once per account.
local TIP = {
  text = "Tick Buy Max Stack, then right-click an item to buy a full stack.",
  buttonStyle = HelpTip.ButtonStyle.Close,
  targetPoint = HelpTip.Point.RightEdgeCenter,
  onAcknowledgeCallback = function() ns.db.buyMaxStackTipSeen = true end,
}

local function ShowTip()
  HelpTip:Show(checkbox, TIP, checkbox.Text)
end

checkbox:SetScript("OnClick", function(self)
  ns.db.buyMaxStack = self:GetChecked()
  PlaySound(ns.db.buyMaxStack and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
  HelpTip:Acknowledge(checkbox, TIP.text)
end)

checkbox:SetScript("OnShow", function(self)
  -- The settings page can change the value between visits.
  self:SetChecked(ns.db.buyMaxStack)

  -- Players who already use Buy Max Stack count as having seen the tip.
  if ns.db.buyMaxStackTipSeen == nil then ns.db.buyMaxStackTipSeen = ns.db.buyMaxStack end
  if not ns.db.buyMaxStackTipSeen then ShowTip() end
end)

-- `/if intro` replays the tip: it shows now at an open vendor, or at the next one.
function ns.ResetBuyMaxStackTip()
  ns.db.buyMaxStackTipSeen = false
  if checkbox:IsVisible() then ShowTip() end
end
