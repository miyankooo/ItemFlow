-- Offline check of Core/Buy.lua: a right-click tops Blizzard's one purchase up to a full stack, within money,
-- supply and bundles, and leaves items Blizzard confirms first alone. Run from the repo root with `lua Tests/Buy.lua`.

local topUp, bought, purchases, checkbox, tip, pooled

local function Frame(template)
  local f = { template = template, Text = {}, scripts = {} }
  for _, name in ipairs({ "SetPoint", "SetChecked", "ClearAllPoints" }) do f[name] = function() end end
  for _, name in ipairs({ "ClearAllPoints", "SetText" }) do f.Text[name] = function() end end
  f.SetSize = function(self, width, height) self.width, self.height = width, height end
  f.SetHitRectInsets = function(self, _, right) self.hitRight = right end
  f.Text.SetFontObject = function(self, font) self.font = font end
  f.Text.SetPoint = function(self, _, _, _, x) self.x = x end
  f.Text.GetStringWidth = function() return 80 end
  f.Text.GetUnboundedStringWidth = function() return 80 end
  f.SetScript = function(self, name, fn) self.scripts[name] = fn end
  f.HookScript = function(self, name, fn)
    local script = self.scripts[name]
    self.scripts[name] = function(...)
      if script then script(...) end
      fn(...)
    end
  end
  f.GetChecked = function() return true end
  f.IsVisible = function() return true end
  return f
end

-- HelpTipTemplate as HelpTipTemplateMixin runs it: Close calls onAcknowledgeCallback only for an acknowledged tip,
-- and only Reset clears that mark (HelpTip.lua).
local function Tip(parent)
  local t = { parent = parent, shown = false, acknowledged = false, inits = 0 }
  function t:SetWidth(width) self.width = width end
  function t:IsShown() return self.shown end
  function t:Reset() self.info, self.acknowledged = nil, false end
  function t:Init(_, info, relativeRegion)
    self.info, self.relativeRegion, self.inits = info, relativeRegion, self.inits + 1
  end
  function t:Show() self.shown = true end
  -- What the target hiding does to its child tip.
  function t:Close()
    local info = self.info
    self.info, self.shown = nil, false
    if info and self.acknowledged then info.onAcknowledgeCallback() end
  end
  -- What the close button does.
  function t:Acknowledge()
    self.acknowledged = true
    self:Close()
  end
  return t
end

local function Reset(opts)
  bought, tip, pooled = nil, nil, false
  MerchantFrame = { selectedTab = 1, FilterDropdown = Frame() }
  MERCHANT_HIGH_PRICE_COST = 1500000
  Enum = { GameRule = { MerchantFilterDisabled = 101 } }
  C_GameRules = { IsGameRuleActive = function() return false end }
  GameFontHighlight = "GameFontHighlight"
  CreateFrame = function(_, _, parent, template)
    if template == "HelpTipTemplate" then
      tip = Tip(parent)
      return tip
    end
    checkbox = Frame(template)
    return checkbox
  end
  hooksecurefunc = function(_, fn) topUp = fn end
  HelpTip = {
    ButtonStyle = { Close = 1 },
    Point = { RightEdgeCenter = 1 },
    width = 226,
    Show = function() pooled = true end,
    Acknowledge = function() pooled = true end,
  }
  PlaySound = function() end
  GameTooltip_Hide = function() end
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

-- The checkbox on the vendor window.
Reset({})
Check("checkbox: Blizzard's checkbox at 24 px", checkbox.template == "CheckboxWithLabelTemplate"
  and checkbox.width == 24 and checkbox.height == 24)
Check("checkbox: a body label 4 px right that ticks the box",
  checkbox.Text.font == "GameFontHighlight" and checkbox.Text.x == 4 and checkbox.hitRight == -84)
Check("checkbox: has a tooltip", checkbox.scripts.OnEnter ~= nil and checkbox.scripts.OnLeave ~= nil)

-- The first-visit tip.
local function OpenVendor(opts)
  local ns = Reset(opts)
  checkbox.scripts.OnShow(checkbox)
  return ns
end

local ns = OpenVendor({ on = false })
Check("tip: shows on a first visit", tip ~= nil and tip.shown and ns.db.buyMaxStackTipSeen == false)
Check("tip: an own HelpTipTemplate on the checkbox, never Blizzard's pool",
  tip.parent == checkbox and tip.width == 226 and not pooled)
Check("tip: points at the label from its right", tip.relativeRegion == checkbox.Text and tip.info.targetPoint == 1)
Check("tip: one sentence that names the control", tip.info.text == "Tick Buy Max Stack, then right-click an item to buy a full stack.")
tip:Close()
Check("tip: hides with the vendor without being marked", ns.db.buyMaxStackTipSeen == false)
checkbox.scripts.OnShow(checkbox)
Check("tip: comes back at the next vendor", tip.shown)
tip:Acknowledge()
Check("tip: closing it marks it seen", ns.db.buyMaxStackTipSeen == true and not tip.shown)
checkbox.scripts.OnShow(checkbox)
Check("tip: a seen tip stays away", not tip.shown and tip.inits == 2)

ns = OpenVendor({ on = true })
Check("tip: players already using Buy Max Stack skip it", tip == nil and ns.db.buyMaxStackTipSeen == true)

ns = OpenVendor({ on = false })
checkbox.scripts.OnClick(checkbox)
Check("tip: using the checkbox closes it", ns.db.buyMaxStackTipSeen == true and not tip.shown and not pooled)

ns = OpenVendor({ on = true })
ns.ResetBuyMaxStackTip()
Check("tip: /if intro shows it again at an open vendor", tip ~= nil and tip.shown and ns.db.buyMaxStackTipSeen == false)

ns = OpenVendor({ on = false })
tip:Acknowledge()
ns.ResetBuyMaxStackTip()
tip:Close()
Check("tip: after /if intro, closing the vendor does not mark it seen", ns.db.buyMaxStackTipSeen == false)

ns = OpenVendor({ on = false })
ns.ResetBuyMaxStackTip()
Check("tip: /if intro leaves a tip on screen alone", tip.inits == 1)

print(failures == 0 and "Buy: all checks passed" or ("Buy: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
