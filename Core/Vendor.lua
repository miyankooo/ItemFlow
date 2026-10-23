local _, ns = ...

-- Bags the player marked in the bag menu under "Ignore this bag", "Sell Junk".
local function IsBagExcluded(bag)
  if bag == BACKPACK_CONTAINER then
    return C_Container.GetBackpackSellJunkDisabled()
  end
  return C_Container.GetBagSlotFlag(bag, Enum.BagSlotFlags.ExcludeJunkSell)
end

-- Greys the vendor pays for. Locked slots are mid-move and cannot be sold yet. Count and total include whole stacks.
local function FindJunk()
  local junk, count, total = {}, 0, 0
  for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
    if not IsBagExcluded(bag) then
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and not info.isLocked then
          local sellPrice = select(11, C_Item.GetItemInfo(info.itemID)) or 0
          count = count + info.stackCount
          total = total + sellPrice * info.stackCount
          junk[#junk + 1] = { bag = bag, slot = slot }
        end
      end
    end
  end
  return junk, count, total
end

-- Uses Blizzard's sell-all-junk without its popup when offered, else the bags. The total is approximate if the client counts non-greys as junk.
local function SellJunk()
  if not ns.db.sellJunk then
    return
  end

  local junk, count, total = FindJunk()
  if #junk == 0 then
    return
  end

  if C_MerchantFrame.IsSellAllJunkEnabled() then
    C_MerchantFrame.SellAllJunkItems()
  else
    for _, item in ipairs(junk) do
      C_Container.UseContainerItem(item.bag, item.slot)
    end
  end

  ns.Print(("Sold %d junk |4item:items; for %s."):format(count, C_CurrencyInfo.GetCoinTextureString(total)))
end

-- False only while the repair waits for junk money. The server tops guild funds up from personal money, as the Blizzard button does.
local function TryRepair()
  if not ns.db.repairGear or not CanMerchantRepair() then
    return true
  end

  local cost, canRepair = GetRepairAllCost()
  if not canRepair or cost <= 0 then
    return true
  end

  if ns.db.guildRepair and CanGuildBankRepair() then
    RepairAllItems(true)
  elseif GetMoney() >= cost then
    RepairAllItems()
  else
    return false
  end

  PlaySound(SOUNDKIT.ITEM_REPAIR)
  ns.Print("Repaired your gear for " .. C_CurrencyInfo.GetCoinTextureString(cost) .. ".")
  return true
end

-- One repair per visit: GetRepairAllCost stays above zero until the server applies a sent repair, so PLAYER_MONEY is watched only while waiting.
local vendorFrame = CreateFrame("Frame")
vendorFrame:RegisterEvent("MERCHANT_SHOW")
vendorFrame:RegisterEvent("MERCHANT_CLOSED")
vendorFrame:SetScript("OnEvent", function(self, event)
  if event == "MERCHANT_SHOW" then
    SellJunk()
    if not TryRepair() then
      self:RegisterEvent("PLAYER_MONEY")
    end
  elseif event == "PLAYER_MONEY" then
    if TryRepair() then
      self:UnregisterEvent("PLAYER_MONEY")
    end
  else
    self:UnregisterEvent("PLAYER_MONEY")
  end
end)
