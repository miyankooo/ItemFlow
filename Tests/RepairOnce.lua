-- Offline check of Core/Vendor.lua: junk sale line and one repair per merchant visit. Run from the repo root with `lua Tests/RepairOnce.lua`.

local state, frame, ns

-- Fresh game stubs per case, so no case leaks money, bags or registered events into the next.
local function Reset(opts)
  state = {
    money = opts.money or 0,
    cost = opts.cost or 0,
    guildAllowed = opts.guildAllowed or false,
    nativeJunk = opts.nativeJunk or false,
    greys = opts.greys or 0,
    stack = opts.stack or 1,
    excludedBag = opts.excludedBag,
    repairs = {},
    sold = 0,
    nativeSales = 0,
    sounds = 0,
    lines = {},
    events = {},
  }

  BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0, 4
  Enum = { ItemQuality = { Poor = 0 }, BagSlotFlags = { ExcludeJunkSell = 64 } }
  SOUNDKIT = { ITEM_REPAIR = 7994 }

  -- Bags 0 and 1 hold the same greys, so a case can exclude one of them and see the other still sold.
  C_Container = {
    GetContainerNumSlots = function(bag) return bag <= 1 and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot)
      if slot <= state.greys and (bag == 0 or state.excludedBag) then
        return { quality = 0, hasNoValue = false, isLocked = false, itemID = 1, stackCount = state.stack }
      end
    end,
    GetBackpackSellJunkDisabled = function() return state.excludedBag == 0 end,
    GetBagSlotFlag = function(bag, flag) return flag == 64 and state.excludedBag == bag end,
    UseContainerItem = function() state.sold = state.sold + 1 end,
  }
  C_Item = { GetItemInfo = function() return "Grey", nil, 0, 1, 1, "", "", 1, "", 0, 25 end }
  C_MerchantFrame = {
    IsSellAllJunkEnabled = function() return state.nativeJunk end,
    SellAllJunkItems = function() state.nativeSales = state.nativeSales + 1 end,
  }
  C_CurrencyInfo = { GetCoinTextureString = function(amount) return amount .. "c" end }

  CanMerchantRepair = function() return true end
  GetRepairAllCost = function() return state.cost, state.cost > 0 end
  CanGuildBankRepair = function() return state.guildAllowed end
  GetMoney = function() return state.money end

  -- The server applies a repair later, so the cost stays unchanged here on purpose.
  RepairAllItems = function(guild) state.repairs[#state.repairs + 1] = guild and "guild" or "personal" end
  PlaySound = function() state.sounds = state.sounds + 1 end

  CreateFrame = function()
    local f = {}
    function f:RegisterEvent(event) state.events[event] = true end
    function f:UnregisterEvent(event) state.events[event] = nil end
    function f:SetScript(_, handler) self.handler = handler end
    frame = f
    return f
  end

  ns = {
    db = { sellJunk = true, repairGear = true, guildRepair = opts.guildRepair or false },
    Print = function(message) state.lines[#state.lines + 1] = message end,
  }
  assert(loadfile("Core/Vendor.lua"))("ItemFlow", ns)
end

-- Delivers an event only while it is registered, as the client does.
local function Fire(event)
  if state.events[event] then
    frame.handler(frame, event)
  end
end

local failures = 0

local function Check(name, condition)
  if not condition then
    failures = failures + 1
    print("FAIL " .. name)
  end
end

-- Enough money on arrival: one repair, and the sale's money events change nothing.
Reset({ money = 1000, cost = 300, greys = 6 })
Fire("MERCHANT_SHOW")
for _ = 1, 6 do Fire("PLAYER_MONEY") end
Check("rich: one repair", #state.repairs == 1)
Check("rich: one sound", state.sounds == 1)
Check("rich: no money watch", not state.events.PLAYER_MONEY)
Check("rich: sale line", state.lines[1] == "Sold 6 junk |4item:items; for 150c.")
Check("rich: repair line", state.lines[2] == "Repaired your gear for 300c.")
Check("rich: two lines", #state.lines == 2)
Check("rich: bag fallback sold six", state.sold == 6)

-- Short of money until the second payout: the repair follows once, then the watch stops.
Reset({ money = 100, cost = 300, greys = 6 })
Fire("MERCHANT_SHOW")
Check("poor: waits", #state.repairs == 0 and state.events.PLAYER_MONEY)
state.money = 200
Fire("PLAYER_MONEY")
Check("poor: still waits", #state.repairs == 0)
state.money = 400
Fire("PLAYER_MONEY")
for _ = 1, 4 do Fire("PLAYER_MONEY") end
Check("poor: one repair", #state.repairs == 1 and state.repairs[1] == "personal")
Check("poor: watch stopped", not state.events.PLAYER_MONEY)

-- Closing the vendor while waiting stops the watch without a repair.
Reset({ money = 0, cost = 300 })
Fire("MERCHANT_SHOW")
Fire("MERCHANT_CLOSED")
Fire("PLAYER_MONEY")
Check("closed: no repair", #state.repairs == 0)
Check("closed: no watch", not state.events.PLAYER_MONEY)
Check("closed: silent", #state.lines == 0)

-- Guild repair goes out once even without personal money, and nothing retries it.
Reset({ money = 0, cost = 300, guildRepair = true, guildAllowed = true })
Fire("MERCHANT_SHOW")
Fire("PLAYER_MONEY")
Check("guild: one guild repair", #state.repairs == 1 and state.repairs[1] == "guild")
Check("guild: no watch", not state.events.PLAYER_MONEY)

-- Nothing to sell or repair: no line at all.
Reset({ money = 1000, cost = 0 })
Fire("MERCHANT_SHOW")
Check("idle: silent", #state.lines == 0 and #state.repairs == 0)

-- Native sell-all-junk: one call, singular wording comes from the grammar escape.
Reset({ money = 1000, cost = 0, greys = 1, nativeJunk = true })
Fire("MERCHANT_SHOW")
Check("native: one call", state.nativeSales == 1 and state.sold == 0)
Check("native: line", state.lines[1] == "Sold 1 junk |4item:items; for 25c.")

-- Stacks count every item in them, for the line and the coins alike.
Reset({ money = 1000, cost = 0, greys = 2, stack = 5 })
Fire("MERCHANT_SHOW")
Check("stacks: line", state.lines[1] == "Sold 10 junk |4item:items; for 250c.")
Check("stacks: two slots sold", state.sold == 2)

-- A bag marked to ignore junk selling is neither sold from nor counted.
Reset({ money = 1000, cost = 0, greys = 2, excludedBag = 1 })
Fire("MERCHANT_SHOW")
Check("excluded bag: line", state.lines[1] == "Sold 2 junk |4item:items; for 50c.")
Check("excluded bag: only backpack sold", state.sold == 2)

-- The same holds for the backpack, which has its own flag.
Reset({ money = 1000, cost = 0, greys = 2, excludedBag = 0 })
Fire("MERCHANT_SHOW")
Check("excluded backpack: only bag sold", state.sold == 2 and state.lines[1] == "Sold 2 junk |4item:items; for 50c.")

if failures > 0 then
  os.exit(1)
end
print("RepairOnce: all checks passed")
