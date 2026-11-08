local addonName, ns = ...

-- The looting follows SpeedyAutoLoot by Yuyuli, cut to what Forever runs. Blizzard's LootFrame lives under a
-- hidden parent, so every loot opens invisibly, and the window comes back to UIParent only when the player has
-- to act. An empty loot from a spammed interact never reaches that point, so it never draws.

-- Errors that leave an item behind, so the player has to see the window.
local STUCK_ERRORS = {
  [ERR_INV_FULL] = true,
  [ERR_ITEM_MAX_COUNT] = true,
  [ERR_LOOT_ROLL_PENDING] = true,
}

-- A key bound to the keyring holds item family 256.
local KEY_FAMILY = 256

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:SetToplevel(true)
hiddenParent:Hide()

local isLooting, isHidden, lastNumLoot, lootFailure, initialAutoLoot = false, true, nil, false, false

-- The window opened under the hidden parent, so its open position is set again before it shows.
local function AnchorLootFrame()
  local frame = LootFrame
  if GetCVarBool("lootUnderMouse") then
    local x, y = GetCursorPosition()
    frame:ClearAllPoints()
    x = x / frame:GetEffectiveScale() - 30
    y = math.max(y / frame:GetEffectiveScale() + 50, 350)
    frame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)
    frame:Raise()
  else
    local anchor, scale = frame.systemInfo.anchorInfo, frame:GetScale()
    frame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX / scale, anchor.offsetY / scale)
  end
end

local function ShowLootFrame()
  isHidden = false
  LootFrame:SetParent(UIParent)
  LootFrame:SetFrameStrata("HIGH")
  AnchorLootFrame()
end

-- With Fast Loot off the window stays on UIParent like any other.
local function ParkLootFrame()
  LootFrame:SetParent(ns.db.fastLoot and hiddenParent or UIParent)
end

-- True when the item has room: the keyring, a stack it tops up, the reagent bag for a crafting reagent or a free
-- slot in a bag that takes its family.
local function ItemFits(itemLink, quantity)
  local stackCount, _, _, _, _, _, _, _, _, isCraftingReagent = select(8, C_Item.GetItemInfo(itemLink))
  local itemFamily = C_Item.GetItemFamily(itemLink)

  if itemFamily == KEY_FAMILY and C_ActionBar.ShouldShowKeyring()
    and C_Container.GetContainerNumFreeSlots(Enum.BagIndex.Keyring) > 0 then
    return true
  end

  -- Item info can still be loading, so an unknown stack size skips the stack check.
  local owned = C_Item.GetItemCount(itemLink)
  if stackCount and owned > 0 and stackCount > 1 and (stackCount - owned) % stackCount >= quantity then
    return true
  end

  for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
    local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
    if freeSlots > 0 then
      if bag == Enum.BagIndex.ReagentBag then
        if isCraftingReagent then return true end
      elseif not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
        return true
      end
    end
  end
  return false
end

-- False when the slot stays behind: locked or without room. Quality never holds a slot back, as in SpeedyAutoLoot
-- on Forever, whose group roll threshold only runs on Classic clients.
local function LootOneSlot(slot)
  local slotType = GetLootSlotType(slot)
  if slotType == Enum.LootSlotType.None then return true end

  local quantity, _, _, locked = select(3, GetLootSlotInfo(slot))
  if locked then return false end
  if slotType ~= Enum.LootSlotType.Item or ItemFits(GetLootSlotLink(slot), quantity) then
    LootSlot(slot)
    return true
  end
  return false
end

-- Every slot in the same frame, last first. SpeedyAutoLoot spaces them 33 ms apart, but the server answers each
-- request on its own and a refused slot still comes back as a stuck error, so the spacing only delays the loot.
local function StartLooting(numItems)
  for slot = numItems, 1, -1 do
    if not LootOneSlot(slot) then lootFailure = true end
  end
  if lootFailure then ShowLootFrame() end
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
    StartLooting(numItems)
  else
    ShowLootFrame()
  end
  lastNumLoot = numItems
end

-- Blizzard's popup asks about a bind on pickup item, so the window shows with it.
local function OnBindConfirm(slot)
  if isLooting and isHidden and LootSlotHasItem(slot) then ShowLootFrame() end
end

local function OnLootClosed()
  isLooting, isHidden, lastNumLoot, lootFailure, initialAutoLoot = false, true, nil, false, false
  ParkLootFrame()
end

ns.ApplyFastLoot = ParkLootFrame

-- Edit Mode shows the window to move it. Leaving Edit Mode parks it again.
hooksecurefunc(LootFrame, "UpdateShownState", function(frame)
  if frame.isInEditMode or not ns.db.fastLoot then
    frame:SetParent(UIParent)
  else
    frame:SetParent(hiddenParent)
  end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("LOOT_BIND_CONFIRM")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "LOOT_READY" or event == "LOOT_OPENED" then
    OnLootReady(...)
  elseif event == "LOOT_CLOSED" then
    OnLootClosed()
  elseif event == "LOOT_BIND_CONFIRM" then
    OnBindConfirm(...)
  elseif STUCK_ERRORS[select(2, ...)] and isLooting and isHidden then
    ShowLootFrame()
  end
end)

-- SpeedyAutoLoot parks the window 6 seconds after its ADDON_LOADED, once the UI has placed it.
EventUtil.ContinueOnAddOnLoaded(addonName, function() C_Timer.After(6, ParkLootFrame) end)
