-- Offline check of Core/Buy.lua: a right-click tops Blizzard's one purchase up to a full stack, within money,
-- supply and bundles, and leaves items Blizzard confirms first alone. Run from the repo root with `lua Tests/Buy.lua`.

local topUp, bought, purchases, checkbox, shownTip, acknowledged

local function Frame()
  local f = { Text = {}, scripts = {} }
  for _, name in ipairs({ "SetSize", "SetPoint", "SetChecked", "ClearAllPoints" }) do f[name] = function() end end
  for _, name in ipairs({ "SetFontObject", "ClearAllPoints", "SetPoint", "SetText" }) do f.Text[name] = function() end end
  f.Text.GetUnboundedStringWidth = function() return 80 end
  f.SetScript = function(self, name, fn) self.scripts[name] = fn end
  f.GetChecked = function() return true end
  f.IsVisible = function() return true end
  return f
end

local function Reset(opts)
  bought, shownTip, acknowledged = nil, nil, false
  MerchantFrame = { selectedTab = 1, FilterDropdown = Frame() }
  MERCHANT_HIGH_PRICE_COST = 1500000
  Enum = { GameRule = { MerchantFilterDisabled = 101 } }
  C_GameRules = { IsGameRuleActive = function() return false end }
  CreateFrame = function() checkbox = Frame() return checkbox end
  hooksecurefunc = function(_, fn) topUp = fn end
  HelpTip = {
    ButtonStyle = { Close = 1 },
    Point = { RightEdgeCenter = 1 },
    Show = function(_, _, info) shownTip = info end,
    Acknowledge = function() acknowledged = true end,
  }
  PlaySound = function() end
  SOUNDKIT = {}
  C_MerchantFrame = { GetItemInfo = function() return opts.info end }
  GetMerchantItemMaxStack = function() return opts.perPurchase or opts.maxStack or 20 end
  GetMerchantItemID = function() return 159 end
  C_Item = { GetItemMaxStackSizeByID = function() return opts.maxStack or 20 end }
  GetMoney = function() return opts.money or 100000 end
  purchases = {}
  BuyMerchantItem = function(_, quantity)
    purchases[#purchases + 1] = quantity
    bought = (bought or 0) + quantity
  end
  local ns = { db = { buyMaxStack = opts.on ~= false, buyMaxStackTipSeen = opts.tipSeen } }
  assert(loadfile("Core/Buy.lua"))("ItemFlow", ns)
  return ns
end

local function Click(opts, mouseButton)
  topUp({ GetID = function() return 1 end, price = opts.info.price, extendedCost = opts.extendedCost,
    showNonrefundablePrompt = opts.nonrefundable }, mouseButton or "RightButton")
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
Check("non-refundable items still top up", Case({ nonrefundable = true }) == 19)
Check("the item's stack size wins over one purchase", Case({ maxStack = 200, perPurchase = 20 }) == 199 and #purchases == 10)
Check("bundles stay whole across purchases", Case({ maxStack = 200, perPurchase = 22, info = { price = 100, stackCount = 5, numAvailable = -1, isPurchasable = true } }) == 195 and purchases[1] == 20)
Check("confirmed items are left to Blizzard", Case({ extendedCost = true }) == nil)
Check("high prices are left to Blizzard", Case({ info = { price = 2000000, stackCount = 1, numAvailable = -1, isPurchasable = true }, money = 1e9 }) == nil)

-- The first-visit tip.
local function OpenVendor(opts)
  local ns = Reset(opts)
  checkbox.scripts.OnShow(checkbox)
  return ns
end

local ns = OpenVendor({ on = false })
Check("tip: shows on a first visit", shownTip ~= nil and ns.db.buyMaxStackTipSeen == false)
shownTip.onAcknowledgeCallback()
Check("tip: closing it marks it seen", ns.db.buyMaxStackTipSeen == true)
shownTip = nil
checkbox.scripts.OnShow(checkbox)
Check("tip: a seen tip stays away", shownTip == nil)

ns = OpenVendor({ on = true })
Check("tip: players already using Buy Max Stack skip it", shownTip == nil and ns.db.buyMaxStackTipSeen == true)

OpenVendor({ on = false })
checkbox.scripts.OnClick(checkbox)
Check("tip: using the checkbox closes it", acknowledged)

ns = OpenVendor({ on = true })
ns.ResetBuyMaxStackTip()
Check("tip: /if intro shows it again at an open vendor", shownTip ~= nil and ns.db.buyMaxStackTipSeen == false)

print(failures == 0 and "Buy: all checks passed" or ("Buy: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
