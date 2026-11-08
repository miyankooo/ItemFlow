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

-- A GameTooltip owned by the hovered frame, filled with Blizzard's GameTooltip_* line helpers. A frame whose
-- template already sets OnEnter gets HookScript instead.
local function AttachTooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- CheckboxWithLabelTemplate: the minimal art Blizzard's Settings use, at the 24 px AddonList gives it
-- (Blizzard_AddOnList/AddonList.xml:73-74). The label joins the hit rect, so a click on it toggles the box.
local function CreateCheckbox(parent, label)
  local checkbox = CreateFrame("CheckButton", nil, parent, "CheckboxWithLabelTemplate")
  checkbox:SetSize(24, 24)
  checkbox.Text:SetFontObject(GameFontHighlight)
  checkbox.Text:ClearAllPoints()
  checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
  checkbox.Text:SetText(label)
  checkbox:SetHitRectInsets(0, -(4 + checkbox.Text:GetStringWidth()), 0, 0)
  return checkbox
end

local checkbox = CreateCheckbox(MerchantFrame, "Buy Max Stack")

-- The checkbox sits in the top bar, its label 8 left of the filter dropdown, or in the dropdown's place where a game
-- rule hides it, as MerchantFrame_Update does.
local labelWidth = checkbox.Text:GetUnboundedStringWidth() + 4
if C_GameRules.IsGameRuleActive(Enum.GameRule.MerchantFilterDisabled) then
  checkbox:SetPoint("RIGHT", MerchantFrame.FilterDropdown, "RIGHT", -labelWidth, 0)
else
  checkbox:SetPoint("RIGHT", MerchantFrame.FilterDropdown, "LEFT", -(labelWidth + 8), 0)
end
AttachTooltip(checkbox, function(tooltip)
  GameTooltip_SetTitle(tooltip, "Buy Max Stack")
  GameTooltip_AddNormalLine(tooltip, "Right-clicking an item buys a full stack.")
end)

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
