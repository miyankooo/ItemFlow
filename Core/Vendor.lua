local _, ns = ...

-- Only 1.60 ships Blizzard's sell-all-junk API. 1.15 has no C_MerchantFrame junk calls, so it always sells from the bags.
local hasJunkApi = C_MerchantFrame ~= nil and C_MerchantFrame.IsSellAllJunkEnabled ~= nil

-- 1.60 adds the reagent bag to this total. 1.15 has no reagent bag and defines only NUM_BAG_SLOTS.
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS

-- Mirrors MerchantSellAllJunkButton, minus the confirmation popup.
local function SellJunkNatively()
  if C_MerchantFrame.GetNumJunkItems() > 0 then
    C_MerchantFrame.SellAllJunkItems()
  end
end

-- Used on 1.15, and on 1.60 whenever the client hides the sell-all-junk button, which it decides per game type.
local function SellJunkFromBags()
  for bag = BACKPACK_CONTAINER, LAST_BAG do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and not info.isLocked then
        C_Container.UseContainerItem(bag, slot)
      end
    end
  end
end

local function SellJunk()
  if not ns.db.sellJunk then
    return
  end

  if hasJunkApi and C_MerchantFrame.IsSellAllJunkEnabled() then
    SellJunkNatively()
  else
    SellJunkFromBags()
  end
end

-- The server tops guild funds up from personal money, exactly as the Blizzard button does.
local function RepairGear()
  if not ns.db.repairGear or not CanMerchantRepair() then
    return
  end

  local cost, canRepair = GetRepairAllCost()
  if not canRepair or cost <= 0 then
    return
  end

  if ns.db.guildRepair and CanGuildBankRepair() then
    RepairAllItems(true)
  elseif GetMoney() >= cost then
    RepairAllItems()
  else
    return
  end

  PlaySound(SOUNDKIT.ITEM_REPAIR)
  ns.Print("repaired for " .. C_CurrencyInfo.GetCoinTextureString(cost))
end

-- Selling pays out asynchronously, so PLAYER_MONEY retries a repair that was
-- unaffordable a moment ago. A finished repair costs nothing, so this cannot loop.
local vendorFrame = CreateFrame("Frame")
vendorFrame:RegisterEvent("MERCHANT_SHOW")
vendorFrame:RegisterEvent("MERCHANT_CLOSED")
vendorFrame:SetScript("OnEvent", function(self, event)
  if event == "MERCHANT_SHOW" then
    self:RegisterEvent("PLAYER_MONEY")
    SellJunk()
    RepairGear()
  elseif event == "MERCHANT_CLOSED" then
    self:UnregisterEvent("PLAYER_MONEY")
  else
    RepairGear()
  end
end)
