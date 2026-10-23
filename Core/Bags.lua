local addonName, ns = ...

-- The cheapest stack in the bags glows, by the lower of its vendor and Auctionator price, so the first item to
-- sell or destroy stands out. An item worth nothing to either, like a quest item, is never picked.

-- Blizzard's own new-item glow in its legendary colour, so it reads as a mark rather than an item quality.
local GLOW_ATLAS = "bags-glow-orange"

-- Auctionator is optional. Its public API answers nil for an item it has no price for.
local function AuctionPrice(itemLink)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not api then return nil end

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

-- Bag and slot of the cheapest stack. Nil when nothing has a price.
function ns.FindCheapest()
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
  return bestBag, bestSlot
end

-- The glow is the addon's own texture on Blizzard's button, which Blizzard's code never reads.
local function SetGlow(button, shown)
  local glow = button.itemFlowGlow
  if shown and not glow then
    glow = button:CreateTexture(nil, "OVERLAY", nil, 2)
    glow:SetAllPoints(button.icon or button)
    glow:SetAtlas(GLOW_ATLAS)
    glow:SetBlendMode("ADD")
    button.itemFlowGlow = glow
  end
  if glow then glow:SetShown(shown) end
end

-- Runs after Blizzard refreshed a bag window's buttons, so the glow follows items as they move or sell.
local function Paint(frame)
  local bag, slot
  if ns.db.highlightCheapest then bag, slot = ns.FindCheapest() end
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
