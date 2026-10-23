local _, ns = ...

-- The looting follows SpeedyAutoLoot by Yuyuli, cut to what Forever runs. Blizzard's LootFrame lives under a
-- hidden parent, so every loot opens invisibly, and the window comes back to UIParent only when the player has
-- to act. An empty loot from a spammed interact never reaches that point, so it never draws.

-- Above every real item quality, so "nothing is contested" needs no special case.
local QUALITY_CAP = 10

-- Loot methods that roll contested items instead of handing them out.
local ROLL_METHODS = {
  [Enum.LootMethod.Group] = true,
  [Enum.LootMethod.Needbeforegreed] = true,
  [Enum.LootMethod.Masterlooter] = true,
}

-- Errors that leave an item behind, so the player has to see the window.
local STUCK_ERRORS = {
  [ERR_INV_FULL] = true,
  [ERR_ITEM_MAX_COUNT] = true,
  [ERR_LOOT_ROLL_PENDING] = true,
}

-- One slot per tick, last slot first, as SpeedyAutoLoot does.
local LOOT_TICK = 0.033

-- A key bound to the keyring holds item family 256.
local KEY_FAMILY = 256

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:SetToplevel(true)
hiddenParent:Hide()

-- Edit Mode places the window on clients whose LootFrame has UpdateShownState.
local hasEditMode = type(LootFrame.UpdateShownState) == "function"

local isLooting, isHidden, lastNumLoot, lootFailure, initialAutoLoot, lootTicker = false, true, nil, false, false, nil
local lootThreshold = QUALITY_CAP

-- A loot replacement that took LOOT_OPENED from Blizzard's window owns it, so the window is left alone.
local function OwnsLootFrame()
  return LootFrame:IsEventRegistered("LOOT_OPENED")
end

-- The window opened under the hidden parent, so its open position is set again before it shows.
local function AnchorLootFrame()
  local frame = LootFrame
  if GetCVarBool("lootUnderMouse") then
    local x, y = GetCursorPosition()
    frame:ClearAllPoints()
    if hasEditMode then
      x = x / frame:GetEffectiveScale() - 30
      y = math.max(y / frame:GetEffectiveScale() + 50, 350)
      frame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)
    else
      x = x / frame:GetEffectiveScale()
      y = y / frame:GetEffectiveScale()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 40, y + 20)
    end
    frame:Raise()
  elseif hasEditMode then
    local anchor, scale = frame.systemInfo.anchorInfo, frame:GetScale()
    frame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX / scale, anchor.offsetY / scale)
  else
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -125)
  end
end

-- A delayed show comes after the window opened, so it anchors twice, as SpeedyAutoLoot does.
local function ShowLootFrame(delayed)
  isHidden = false
  if OwnsLootFrame() then
    LootFrame:SetParent(UIParent)
    LootFrame:SetFrameStrata("HIGH")
    AnchorLootFrame()
    if delayed then AnchorLootFrame() end
  end
end

-- With Fast Loot off the window stays on UIParent like any other.
local function ParkLootFrame()
  if not OwnsLootFrame() then return end
  LootFrame:SetParent(ns.db.fastLoot and hiddenParent or UIParent)
end

-- True when the item has room: the keyring, a stack it tops up or a free slot in a bag that takes its family.
local function ItemFits(itemLink, quantity)
  local stackCount = select(8, C_Item.GetItemInfo(itemLink))
  local itemFamily = C_Item.GetItemFamily(itemLink)

  if itemFamily == KEY_FAMILY then
    local hasKeyring = IsKeyRingEnabled and IsKeyRingEnabled() or (C_ActionBar.ShouldShowKeyring and C_ActionBar.ShouldShowKeyring())
    if hasKeyring and C_Container.GetContainerNumFreeSlots(Enum.BagIndex.Keyring) > 0 then return true end
  end

  -- Item info can still be loading, so an unknown stack size skips the stack check.
  local owned = C_Item.GetItemCount(itemLink)
  if stackCount and owned > 0 and stackCount > 1 and (stackCount - owned) % stackCount >= quantity then
    return true
  end

  for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
    local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
    if freeSlots > 0 and (not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0)) then
      return true
    end
  end
  return false
end

-- Only auto-confirm while solo; in a group the bind is a decision for the player.
local function ConfirmsBind()
  return ns.db.confirmBop and not (GetNumGroupMembers() > 1)
end

-- False when the slot stays behind: rolled on, locked or without room.
local function LootOneSlot(slot)
  local slotType = GetLootSlotType(slot)
  if slotType == Enum.LootSlotType.None then return true end

  local quantity, _, quality, locked = select(3, GetLootSlotInfo(slot))
  if locked or (quality and quality >= lootThreshold) then
    return false
  end
  if slotType ~= Enum.LootSlotType.Item or ItemFits(GetLootSlotLink(slot), quantity) then
    LootSlot(slot)
    if ConfirmsBind() then ConfirmLootSlot(slot) end
    return true
  end
  return false
end

local function CancelLootTicker()
  if lootTicker then lootTicker:Cancel() end
end

-- The last tick shows the window when a slot stayed behind.
local function StartLooting(numItems)
  CancelLootTicker()
  local slot = numItems
  lootTicker = C_Timer.NewTicker(LOOT_TICK, function()
    if slot >= 1 then
      if not LootOneSlot(slot) then lootFailure = true end
      slot = slot - 1
    else
      if lootFailure then ShowLootFrame() end
      CancelLootTicker()
    end
  end, numItems + 1)
end

-- A spammed interact can flip the isAutoLoot payload, so the first event of a loot decides. Empty and repeated
-- events change nothing, which keeps the window parked. With Fast Loot off the game loots on its own.
local function OnLootReady(isAutoLoot)
  isLooting = true
  if not ns.db.fastLoot then
    isHidden = false
    return
  end
  if not initialAutoLoot then
    initialAutoLoot = isAutoLoot or GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
  end

  local numItems = GetNumLootItems()
  if numItems == 0 or numItems == lastNumLoot then return end

  if initialAutoLoot then
    -- Looting a slot the group is rolling on would decide the roll for everyone.
    local rolls = IsInGroup() and ROLL_METHODS[C_PartyInfo.GetLootMethod()]
    lootThreshold = rolls and GetLootThreshold() or QUALITY_CAP
    StartLooting(numItems)
  else
    ShowLootFrame()
  end
  lastNumLoot = numItems
end

local function OnBindConfirm(slot)
  if not (isLooting and LootSlotHasItem(slot)) then return end
  if ConfirmsBind() then ConfirmLootSlot(slot) end
  if isHidden then ShowLootFrame(true) end
end

local function OnLootClosed()
  isLooting, isHidden, lastNumLoot, lootFailure, initialAutoLoot = false, true, nil, false, false
  CancelLootTicker()
  ParkLootFrame()
end

-- Blizzard's bind popup listens on UIParent. While solo with Confirm Bind on Pickup on, the addon confirms
-- instead, so the popup never flashes.
function ns.ApplyBindPopup()
  if ConfirmsBind() then
    UIParent:UnregisterEvent("LOOT_BIND_CONFIRM")
  else
    UIParent:RegisterEvent("LOOT_BIND_CONFIRM")
  end
end

ns.ApplyFastLoot = ParkLootFrame

-- Edit Mode shows the window to move it. Leaving Edit Mode parks it again.
if hasEditMode then
  hooksecurefunc(LootFrame, "UpdateShownState", function(frame)
    if frame.isInEditMode or not ns.db.fastLoot then
      frame:SetParent(UIParent)
    else
      frame:SetParent(hiddenParent)
    end
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("LOOT_BIND_CONFIRM")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:RegisterEvent("GROUP_JOINED")
events:RegisterEvent("GROUP_LEFT")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "LOOT_READY" or event == "LOOT_OPENED" then
    OnLootReady(...)
  elseif event == "LOOT_CLOSED" then
    OnLootClosed()
  elseif event == "LOOT_BIND_CONFIRM" then
    OnBindConfirm(...)
  elseif event == "UI_ERROR_MESSAGE" then
    if STUCK_ERRORS[select(2, ...)] and isLooting and isHidden then ShowLootFrame(true) end
  else
    ns.ApplyBindPopup()
  end
end)

-- Group events skip a /reload, so the popup state is set once at login. SpeedyAutoLoot parks the window a few
-- seconds after load, once the UI has placed it.
EventUtil.ContinueOnPlayerLogin(function()
  ns.ApplyBindPopup()
  C_Timer.After(5, ParkLootFrame)
end)
