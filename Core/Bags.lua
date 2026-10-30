local addonName, ns = ...

-- When the bags are nearly full, the cheapest stack glows, by the lower of its vendor and Auctionator price, so the
-- first item to sell or destroy for loot room stands out. An item worth nothing to either, like a quest item, is never picked.

-- Blizzard's own new-item glow in its legendary colour, so it reads as a mark rather than an item quality.
local GLOW_ATLAS = "bags-glow-orange"

-- The glow waits until this few slots are free, so it only shows when loot is about to stop fitting.
local FREE_SLOTS_TO_GLOW = 2

-- An auction price seen longer ago than this no longer says what the item sells for.
local MAX_PRICE_AGE_DAYS = 7

-- Free slots in the bags that take any item. Profession bags and the reagent bag take only their own goods.
function ns.BagsNearlyFull()
  local free = 0
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    local slots, family = C_Container.GetContainerNumFreeSlots(bag)
    if family == 0 then free = free + slots end
  end
  return free <= FREE_SLOTS_TO_GLOW
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
local function UnitValue(info)
  local vendor = not info.hasNoValue and select(11, C_Item.GetItemInfo(info.hyperlink)) or 0
  local auction = AuctionPrice(info.hyperlink)
  if vendor > 0 and auction then return math.min(vendor, auction) end
  if vendor > 0 then return vendor end
  return auction
end

local scannedAt, cheapestBag, cheapestSlot

-- Bag and slot of the cheapest stack. Nil when nothing has a price. Every open bag window repaints in the same
-- frame, so one scan serves them all.
function ns.FindCheapest()
  if scannedAt == GetTime() then return cheapestBag, cheapestSlot end
  local bestBag, bestSlot, bestValue
  for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local unit = info and info.hyperlink and UnitValue(info)
      if unit then
        local value = unit * info.stackCount
        if not bestValue or value < bestValue then
          bestBag, bestSlot, bestValue = bag, slot, value
        end
      end
    end
  end
  scannedAt, cheapestBag, cheapestSlot = GetTime(), bestBag, bestSlot
  return bestBag, bestSlot
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

-- Runs after Blizzard refreshed a bag window's buttons, so the glow follows items as they move or sell.
local function Paint(frame)
  local bag, slot
  if ns.db.highlightCheapest and ns.BagsNearlyFull() then bag, slot = ns.FindCheapest() end
  for _, button in frame:EnumerateValidItems() do
    SetGlow(button, button:GetBagID() == bag and button:GetID() == slot)
  end
end

local function EachBagFrame(fn)
  fn(ContainerFrameCombinedBags)
  for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do fn(frame) end
end

-- Repaints only the addon's textures, never through Blizzard's bag update, so the bag buttons stay untainted.
function ns.RefreshBagGlow()
  EachBagFrame(function(frame)
    if frame:IsShown() then Paint(frame) end
  end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_UIPanels_Game", function()
  EachBagFrame(function(frame) hooksecurefunc(frame, "UpdateItems", Paint) end)
end)
