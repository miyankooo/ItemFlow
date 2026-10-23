-- Offline check of Core/Buy.lua: a right-click tops Blizzard's one purchase up to a full stack, within money,
-- supply and bundles, and leaves items Blizzard confirms first alone. Run from the repo root with `lua Tests/Buy.lua`.

local topUp, bought

local function Frame()
  local f = { Text = {} }
  for _, name in ipairs({ "SetSize", "SetPoint", "SetScript", "SetChecked", "ClearAllPoints" }) do f[name] = function() end end
  for _, name in ipairs({ "SetFontObject", "ClearAllPoints", "SetPoint", "SetText" }) do f.Text[name] = function() end end
  f.Text.GetUnboundedStringWidth = function() return 80 end
  return f
end

local function Reset(opts)
  bought = nil
  MerchantFrame = { selectedTab = 1, FilterDropdown = Frame() }
  MERCHANT_HIGH_PRICE_COST = 1500000
  Enum = { GameRule = { MerchantFilterDisabled = 101 } }
  C_GameRules = { IsGameRuleActive = function() return false end }
  CreateFrame = Frame
  hooksecurefunc = function(_, fn) topUp = fn end
  C_MerchantFrame = { GetItemInfo = function() return opts.info end }
  GetMerchantItemMaxStack = function() return opts.maxStack or 20 end
  GetMoney = function() return opts.money or 100000 end
  BuyMerchantItem = function(_, quantity) bought = quantity end
  local ns = { db = { buyMaxStack = opts.on ~= false } }
  assert(loadfile("Core/Buy.lua"))("ItemFlow", ns)
end

local function Click(opts, mouseButton)
  topUp({ GetID = function() return 1 end, price = opts.info.price, extendedCost = opts.extendedCost }, mouseButton or "RightButton")
end

local failures = 0
local function Check(name, condition)
  print((condition and "  pass  " or "  FAIL  ") .. name)
  if not condition then failures = failures + 1 end
end

local function Case(opts, mouseButton)
  opts.info = opts.info or { price = 100, stackCount = 1, numAvailable = -1, isPurchasable = true }
  Reset(opts)
  Click(opts, mouseButton)
  return bought
end

Check("tops one up to a full stack", Case({}) == 19)
Check("off: buys nothing more", Case({ on = false }) == nil)
Check("left click: nothing", Case({}, "LeftButton") == nil)
Check("money caps the stack", Case({ money = 550 }) == 4)
Check("supply caps the stack", Case({ info = { price = 100, stackCount = 1, numAvailable = 3, isPurchasable = true } }) == 2)
Check("bundles stay whole", Case({ maxStack = 200, info = { price = 100, stackCount = 5, numAvailable = -1, isPurchasable = true } }) == 195)
Check("a full bundle buys nothing more", Case({ maxStack = 200, info = { price = 100, stackCount = 200, numAvailable = -1, isPurchasable = true } }) == nil)
Check("confirmed items are left to Blizzard", Case({ extendedCost = true }) == nil)
Check("high prices are left to Blizzard", Case({ info = { price = 2000000, stackCount = 1, numAvailable = -1, isPurchasable = true }, money = 1e9 }) == nil)

print(failures == 0 and "Buy: all checks passed" or ("Buy: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
