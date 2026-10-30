-- Offline check of Core/Bags.lua: the cheapest stack by the lower of vendor and a recent Auctionator price, skipping
-- items worth nothing, and the glow waiting for nearly full bags. Run from the repo root with `lua Tests/Bags.lua`.

-- Each item: { link, count, vendor, auction, noValue, auctionAgeDays }.
local function Find(items, withAuctionator)
  BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0, 0
  C_Container = {
    GetContainerNumSlots = function() return #items end,
    GetContainerItemInfo = function(_, slot)
      local item = items[slot]
      return item and { hyperlink = item[1], stackCount = item[2], hasNoValue = item[5] }
    end,
  }
  local byLink = {}
  for _, item in ipairs(items) do byLink[item[1]] = item end
  C_Item = { GetItemInfo = function(link) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, byLink[link][3] end }
  Auctionator = withAuctionator and { API = { v1 = {
    GetAuctionPriceByItemLink = function(_, link) return byLink[link][4] end,
    GetAuctionAgeByItemLink = function(_, link) local age = byLink[link][6]; if age == nil then return 0 end; return age or nil end,
  } } } or nil
  EventUtil = { ContinueOnAddOnLoaded = function() end }
  GetTime = function() return 0 end
  local ns = { db = {} }
  assert(loadfile("Core/Bags.lua"))("ItemFlow", ns)
  local _, slot = ns.FindCheapest()
  return slot
end

local failures = 0
local function Check(name, condition)
  print((condition and "  pass  " or "  FAIL  ") .. name)
  if not condition then failures = failures + 1 end
end

Check("vendor price only", Find({ { "a", 1, 50 }, { "b", 1, 20 }, { "c", 1, 90 } }) == 2)
Check("stack value counts every item", Find({ { "a", 10, 5 }, { "b", 1, 20 } }) == 2)
Check("the lower of vendor and auction", Find({ { "a", 1, 50, 10 }, { "b", 1, 20, 40 } }, true) == 1)
Check("auction price for an item vendors refuse", Find({ { "a", 1, 0, 15 }, { "b", 1, 20 } }, true) == 1)
Check("no value anywhere is never picked", Find({ { "quest", 1, 0 }, { "b", 1, 20 } }, true) == 2)
Check("no value flag skips the vendor price", Find({ { "a", 1, 5, nil, true }, { "b", 1, 20 } }, true) == 2)
Check("nothing priced finds nothing", Find({ { "quest", 1, 0 } }) == nil)
Check("a stale auction price falls back to the vendor", Find({ { "a", 1, 50, 10, nil, 8 }, { "b", 1, 20 } }, true) == 2)
Check("an auction price past Auctionator's 21 days is ignored", Find({ { "a", 1, 50, 10, nil, false }, { "b", 1, 20 } }, true) == 2)

-- Free slots per bag as { free, family }: family 0 takes any item.
local function NearlyFull(bags)
  BACKPACK_CONTAINER, NUM_BAG_SLOTS = 0, #bags - 1
  C_Container = { GetContainerNumFreeSlots = function(bag) return bags[bag + 1][1], bags[bag + 1][2] end }
  local ns = { db = {} }
  assert(loadfile("Core/Bags.lua"))("ItemFlow", ns)
  return ns.BagsNearlyFull()
end

Check("glow waits while bags have room", not NearlyFull({ { 3, 0 }, { 0, 0 } }))
Check("glow shows at 2 free slots", NearlyFull({ { 1, 0 }, { 1, 0 } }))
Check("profession bag room does not count", NearlyFull({ { 0, 0 }, { 12, 8 } }))

print(failures == 0 and "Bags: all checks passed" or ("Bags: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
