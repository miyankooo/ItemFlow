local addonName, ns = ...

-- Marks the bag items to drop for room. With loot left behind for lack of space, each loot item is paired with a bag
-- stack, the most valuable loot with the cheapest stack, and a stack is marked when its loot is worth more, as
-- LootTriage by Krelock pairs them. Otherwise the cheapest stack is marked once the bags are nearly full. Values are
-- the lower of the vendor and a recent Auctionator price, and an item worth nothing to either is never marked.

-- Blizzard's own new-item glow in its legendary colour, so it reads as a mark rather than an item quality.
local GLOW_ATLAS = "bags-glow-orange"

-- The group loot Pass button's red cross (lootroll-toast-icon-pass-*), so the delete button reads as a native one.
local DELETE_ATLAS = "lootroll-toast-icon-pass-"

-- Blizzard asks before it deletes anything better than white, so only gray and white stacks get the delete button.
local MAX_DELETE_QUALITY = Enum.ItemQuality.Common

-- The cheapest stack waits until this few slots are free, so it only shows when loot is about to stop fitting.
local FREE_SLOTS_TO_GLOW = 2

-- An auction price seen longer ago than this no longer says what the item sells for.
local MAX_PRICE_AGE_DAYS = 7

-- Free slots in the bags that take any item. Profession bags and the reagent bag take only their own goods.
local function FreeSlots()
  local free = 0
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    local slots, family = C_Container.GetContainerNumFreeSlots(bag)
    if family == 0 then free = free + slots end
  end
  return free
end

-- Auctionator is optional. Its public API answers nil for an item it has no price for, and its age in days, or nil
-- past 21 days, for when it last saw one.
local function AuctionPrice(itemLink)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not api then return nil end

  local okAge, age = pcall(api.GetAuctionAgeByItemLink, addonName, itemLink)
  if not (okAge and type(age) == "number" and age <= MAX_PRICE_AGE_DAYS) then return nil end

  local ok, price = pcall(api.GetAuctionPriceByItemLink, addonName, itemLink)
  if ok and type(price) == "number" and price > 0 then return price end
end

-- The lower of the two prices for one item, ignoring a price it lacks. Nil when it has neither.
local function UnitValue(itemLink, hasNoValue)
  local vendor = not hasNoValue and select(11, C_Item.GetItemInfo(itemLink)) or 0
  local auction = AuctionPrice(itemLink)
  if vendor > 0 and auction then return math.min(vendor, auction) end
  if vendor > 0 then return vendor end
  return auction
end

local function ByValue(a, b)
  if a.value ~= b.value then return a.value < b.value end
  return a.bag * 100 + a.slot < b.bag * 100 + b.slot
end

-- Every priced stack in the bags that take any item, cheapest first. Only those free a slot for loot.
local function Candidates()
  local candidates = {}
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    if family == 0 then
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local unit = info and info.hyperlink and UnitValue(info.hyperlink, info.hasNoValue)
        if unit then
          candidates[#candidates + 1] = {
            bag = bag, slot = slot, itemID = info.itemID, quality = info.quality, value = unit * info.stackCount,
          }
        end
      end
    end
  end
  table.sort(candidates, ByValue)
  return candidates
end

local lootOpen = false

-- What each loot item left behind for lack of room is worth, most valuable first. A quest item is always worth it.
local function LeftoverLoot()
  local values = {}
  for slot = 1, GetNumLootItems() do
    if LootSlotHasItem(slot) and GetLootSlotType(slot) == Enum.LootSlotType.Item then
      local link = GetLootSlotLink(slot)
      local _, _, quantity, _, _, _, isQuestItem = GetLootSlotInfo(slot)
      if link and not ns.ItemFits(link, quantity) then
        values[#values + 1] = isQuestItem and math.huge or (UnitValue(link) or 0) * quantity
      end
    end
  end
  table.sort(values, function(a, b) return a > b end)
  return values
end

local scannedAt, marks = nil, {}

-- The stacks to mark, keyed bag * 100 + slot. Every open bag window repaints in the same frame, so one scan serves
-- them all.
function ns.Marks()
  if scannedAt == GetTime() then return marks end
  scannedAt = GetTime()
  wipe(marks)
  if not ns.db.highlightCheapest then return marks end

  -- Pricing every stack is the costly part, so it only runs when something can be marked.
  local loot = lootOpen and LeftoverLoot() or {}
  local free = FreeSlots()
  if #loot == 0 and free > FREE_SLOTS_TO_GLOW then return marks end

  local candidates = Candidates()
  if #loot > 0 then
    for i, value in ipairs(loot) do
      local stack = candidates[i - free]
      if stack and value > stack.value then marks[stack.bag * 100 + stack.slot] = stack end
    end
  elseif candidates[1] then
    marks[candidates[1].bag * 100 + candidates[1].slot] = candidates[1]
  end
  return marks
end

-- The glow is the addon's own texture on Blizzard's button, which Blizzard's code never reads. It copies the button's
-- NewItemTexture (Mainline/ContainerFrame.xml): OVERLAY sublevel 2, ADD blend, atlas size, centred.
local function SetGlow(button, shown)
  local glow = button.itemFlowGlow
  if shown and not glow then
    glow = button:CreateTexture(nil, "OVERLAY", nil, 2)
    glow:SetPoint("CENTER")
    glow:SetAtlas(GLOW_ATLAS, true)
    glow:SetBlendMode("ADD")
    button.itemFlowGlow = glow
  end
  if glow then glow:SetShown(shown) end
end

-- DeleteCursorItem has restrictions, so the pickup and the delete both run inside the player's click. An item already
-- on the cursor stays untouched, and a refused delete puts the stack back.
local function DeleteStack(self)
  local stack = self.stack
  if CursorHasItem() then return end

  local info = C_Container.GetContainerItemInfo(stack.bag, stack.slot)
  if not info or info.itemID ~= stack.itemID or info.isLocked or info.quality > MAX_DELETE_QUALITY then return end
  C_Container.PickupContainerItem(stack.bag, stack.slot)
  DeleteCursorItem()
  if CursorHasItem() then ClearCursor() end
end

local function ShowDeleteTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip_SetTitle(GameTooltip, DELETE)
  GameTooltip_AddNormalLine(GameTooltip, "Deletes this stack to make room for loot worth more.")
  GameTooltip:Show()
end

-- A small red cross in the button's top right corner, the addon's own child frame on Blizzard's button.
local function SetDeleteButton(button, stack)
  local delete = button.itemFlowDelete
  local shown = stack ~= nil and stack.quality <= MAX_DELETE_QUALITY
  if shown and not delete then
    delete = CreateFrame("Button", nil, button)
    delete:SetSize(16, 16)
    delete:SetPoint("TOPRIGHT", 3, 3)
    delete:SetNormalAtlas(DELETE_ATLAS .. "up")
    delete:SetPushedAtlas(DELETE_ATLAS .. "down")
    delete:SetHighlightAtlas(DELETE_ATLAS .. "highlight", "ADD")
    delete:SetScript("OnClick", DeleteStack)
    delete:SetScript("OnEnter", ShowDeleteTooltip)
    delete:SetScript("OnLeave", GameTooltip_Hide)
    button.itemFlowDelete = delete
  end
  if delete then
    delete.stack = stack
    delete:SetShown(shown)
  end
end

-- Runs after Blizzard refreshed a bag window's buttons, so the marks follow items as they move, sell or go.
local function Paint(frame)
  local marked = ns.Marks()
  for _, button in frame:EnumerateValidItems() do
    local stack = marked[button:GetBagID() * 100 + button:GetID()]
    SetGlow(button, stack ~= nil)
    SetDeleteButton(button, stack)
  end
end

local function EachBagFrame(fn)
  fn(ContainerFrameCombinedBags)
  for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do fn(frame) end
end

-- Repaints only the addon's textures, never through Blizzard's bag update, so the bag buttons stay untainted.
function ns.RefreshBagGlow()
  scannedAt = nil
  EachBagFrame(function(frame)
    if frame:IsShown() then Paint(frame) end
  end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_UIPanels_Game", function()
  EachBagFrame(function(frame) hooksecurefunc(frame, "UpdateItems", Paint) end)
end)

-- Loot changes which stacks are worth the room, so open bags repaint on every loot event.
local lootEvents = CreateFrame("Frame")
lootEvents:RegisterEvent("LOOT_OPENED")
lootEvents:RegisterEvent("LOOT_SLOT_CLEARED")
lootEvents:RegisterEvent("LOOT_CLOSED")
lootEvents:SetScript("OnEvent", function(_, event)
  lootOpen = event ~= "LOOT_CLOSED"
  ns.RefreshBagGlow()
end)
