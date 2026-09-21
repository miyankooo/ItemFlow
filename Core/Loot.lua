local _, ns = ...

-- Above every real item quality, so "nothing is contested" needs no special case.
local QUALITY_CAP = 10

-- Loot methods that roll contested items instead of handing them out. Built at load
-- because 1.60 may not expose every member Blizzard defines on retail.
local ROLL_METHODS = {}
for _, name in ipairs({ "Group", "Needbeforegreed", "Masterlooter" }) do
  local method = Enum.LootMethod[name]
  if method then
    ROLL_METHODS[method] = true
  end
end

-- Looting a slot the group is rolling on would decide the roll for everyone.
local function RollThreshold()
  if not IsInGroup() or not ROLL_METHODS[C_PartyInfo.GetLootMethod()] then
    return QUALITY_CAP
  end
  return GetLootThreshold() or QUALITY_CAP
end

-- Descending so clearing a slot never shifts one we have not visited yet.
local function LootEverything()
  local threshold = RollThreshold()
  for slot = GetNumLootItems(), 1, -1 do
    local texture, _, _, _, quality, locked = GetLootSlotInfo(slot)
    if texture and not locked and (not quality or quality < threshold) then
      LootSlot(slot)
    end
  end
end

-- LOOT_READY beats the loot window to the punch, which is what removes the delay.
-- LOOT_OPENED repeats the pass for anything the first one could not take yet.
local function OnLootAvailable(isAutoLoot)
  if ns.db.fastLoot and isAutoLoot then
    LootEverything()
  end
end

-- Only auto-confirm while solo; in a group the bind is a decision for the player.
local function OnBindConfirm(slot)
  if ns.db.confirmBop and not IsInGroup() and LootSlotHasItem(slot) then
    ConfirmLootSlot(slot)
  end
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_READY")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:RegisterEvent("LOOT_BIND_CONFIRM")
lootFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "LOOT_BIND_CONFIRM" then
    OnBindConfirm(...)
  else
    OnLootAvailable(...)
  end
end)
