-- Offline check of Core/Bags.lua: which stacks get marked, by the lower of the vendor and a recent Auctionator price.
-- Run from the repo root with `lua Tests/Bags.lua`.

-- Each item: { link, count, vendor, auction, noValue, auctionAgeDays, quality }. Each loot: { link, count, vendor,
-- fits, quest }. opts: free (free slots, default 0), auctionator, loot.
local function Marks(items, opts)
  opts = opts or {}
  BACKPACK_CONTAINER, NUM_BAG_SLOTS = 0, 0
  Enum = { ItemQuality = { Common = 1 }, LootSlotType = { Item = 1 } }
  local byLink = {}
  for _, item in ipairs(items) do byLink[item[1]] = item end
  for _, loot in ipairs(opts.loot or {}) do byLink[loot[1]] = loot end

  C_Container = {
    GetContainerNumFreeSlots = function() return opts.free or 0, 0 end,
    GetContainerNumSlots = function() return #items end,
    GetContainerItemInfo = function(_, slot)
      local item = items[slot]
      return item and { hyperlink = item[1], itemID = slot, stackCount = item[2], hasNoValue = item[5], quality = item[7] or 1 }
    end,
  }
  C_Item = { GetItemInfo = function(link) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, byLink[link][3] end }
  Auctionator = opts.auctionator and { API = { v1 = {
    GetAuctionPriceByItemLink = function(_, link) return byLink[link][4] end,
    GetAuctionAgeByItemLink = function(_, link)
      local age = byLink[link][6]
      if age == nil then return 0 end
      return age or nil
    end,
  } } } or nil

  local loot = opts.loot or {}
  GetNumLootItems = function() return #loot end
  LootSlotHasItem = function() return true end
  GetLootSlotType = function() return 1 end
  GetLootSlotLink = function(slot) return loot[slot][1] end
  GetLootSlotInfo = function(slot) return nil, nil, loot[slot][2], nil, nil, nil, loot[slot][5] end

  local handlers = {}
  CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(_, _, fn) handlers[#handlers + 1] = fn end }
  end
  EventUtil = { ContinueOnAddOnLoaded = function() end }
  ContainerFrameCombinedBags = { IsShown = function() return false end }
  ContainerFrameContainer = { ContainerFrames = {} }
  GetTime = function() return 0 end
  wipe = function(t) for k in pairs(t) do t[k] = nil end end

  local ns = { db = { highlightCheapest = true } }
  ns.ItemFits = function(link) return byLink[link][4] end
  assert(loadfile("Core/Bags.lua"))("ItemFlow", ns)
  if #loot > 0 then for _, fn in ipairs(handlers) do fn(nil, "LOOT_OPENED") end end

  local slots = {}
  for key in pairs(ns.Marks()) do slots[#slots + 1] = key end
  table.sort(slots)
  return slots
end

local failures = 0
local function Check(name, condition)
  print((condition and "  pass  " or "  FAIL  ") .. name)
  if not condition then failures = failures + 1 end
end

local function Is(slots, ...)
  local want = { ... }
  if #slots ~= #want then return false end
  for i, slot in ipairs(want) do if slots[i] ~= slot then return false end end
  return true
end

-- Without loot: the single cheapest stack once the bags are nearly full.
Check("vendor price only", Is(Marks({ { "a", 1, 50 }, { "b", 1, 20 }, { "c", 1, 90 } }), 2))
Check("stack value counts every item", Is(Marks({ { "a", 10, 5 }, { "b", 1, 20 } }), 2))
Check("the lower of vendor and auction", Is(Marks({ { "a", 1, 50, 10 }, { "b", 1, 20, 40 } }, { auctionator = true }), 1))
Check("auction price for an item vendors refuse", Is(Marks({ { "a", 1, 0, 15 }, { "b", 1, 20 } }, { auctionator = true }), 1))
Check("no value anywhere is never marked", Is(Marks({ { "quest", 1, 0 }, { "b", 1, 20 } }, { auctionator = true }), 2))
Check("no value flag skips the vendor price", Is(Marks({ { "a", 1, 5, nil, true }, { "b", 1, 20 } }, { auctionator = true }), 2))
Check("a stale auction price falls back to the vendor", Is(Marks({ { "a", 1, 50, 10, nil, 8 }, { "b", 1, 20 } }, { auctionator = true }), 2))
Check("an auction price past Auctionator's 21 days is ignored", Is(Marks({ { "a", 1, 50, 10, nil, false }, { "b", 1, 20 } }, { auctionator = true }), 2))
Check("nothing priced marks nothing", Is(Marks({ { "quest", 1, 0 } })))
Check("bags with room mark nothing", Is(Marks({ { "a", 1, 50 } }, { free = 3 })))
Check("2 free slots mark the cheapest", Is(Marks({ { "a", 1, 50 } }, { free = 2 }), 1))

-- With loot left behind: one stack per loot item worth more, the best loot against the cheapest stack.
local bags = { { "a", 1, 50 }, { "b", 1, 10 }, { "c", 1, 30 } }
Check("loot pairs with the cheapest stacks", Is(Marks(bags, { loot = { { "x", 1, 100 }, { "y", 1, 40 } } }), 2, 3))
Check("loot worth less marks nothing", Is(Marks(bags, { loot = { { "x", 1, 5 } } })))
Check("only loot worth more than its pair marks", Is(Marks(bags, { loot = { { "x", 1, 100 }, { "y", 1, 20 } } }), 2))
Check("loot that fits leaves the full-bags mark", Is(Marks(bags, { loot = { { "x", 1, 100, true } } }), 2))
Check("a quest item is always worth the room", Is(Marks(bags, { loot = { { "q", 1, 0, nil, true } } }), 2))
Check("a free slot takes the best loot first", Is(Marks(bags, { free = 1, loot = { { "x", 1, 100 }, { "y", 1, 40 } } }), 2))

print(failures == 0 and "Bags: all checks passed" or ("Bags: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
