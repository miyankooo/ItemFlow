-- Offline check of Core/Bags.lua: the cheapest stack by the lower of vendor and Auctionator price, skipping
-- items worth nothing. Run from the repo root with `lua Tests/Bags.lua`.

-- Each item: { link, count, vendor, auction, noValue }.
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
  Auctionator = withAuctionator and { API = { v1 = { GetAuctionPriceByItemLink = function(_, link) return byLink[link][4] end } } } or nil
  EventUtil = { ContinueOnAddOnLoaded = function() end }
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

print(failures == 0 and "Bags: all checks passed" or ("Bags: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
