-- Offline check of Core/Loot.lua: the loot window stays parked under a hidden parent, a fast loot and an empty
-- spammed loot never draw it, and loot left behind shows it. Run from the repo root with `lua Tests/FastLoot.lua`.

local state, handlers, tickers, loginCallback, timers

-- Visible means shown with every parent shown, as in the client.
local function NewFrame(parent, shown)
  local f = { parent = parent, shown = shown, events = {} }
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:GetParent() return self.parent end
  function f:SetParent(p) self.parent = p end
  function f:SetFrameStrata() end
  function f:SetToplevel() end
  function f:ClearAllPoints() end
  function f:SetPoint() end
  function f:Raise() end
  function f:GetEffectiveScale() return 1 end
  function f:RegisterEvent(event) self.events[event] = true end
  function f:UnregisterEvent(event) self.events[event] = nil end
  function f:IsEventRegistered(event) return self.events[event] == true end
  function f:SetScript(_, fn) handlers[#handlers + 1] = fn end
  return f
end

-- Fresh game stubs per case. Each slot is { quality, locked, fits }.
local function Reset(opts)
  state = { slots = opts.slots or { {}, {}, {} }, looted = {}, confirmed = 0, drawn = false }
  handlers, tickers, timers = {}, {}, {}

  Enum = {
    LootMethod = { Masterlooter = 2, Group = 3, Needbeforegreed = 4 },
    LootSlotType = { None = 0, Item = 1 },
    BagIndex = { Keyring = -1 },
  }
  ERR_INV_FULL, ERR_ITEM_MAX_COUNT, ERR_LOOT_ROLL_PENDING = "full", "max", "rolling"
  BACKPACK_CONTAINER, NUM_BAG_SLOTS = 0, 4

  UIParent = NewFrame(nil, true)
  UIParent.events.LOOT_BIND_CONFIRM = true
  LootFrame = NewFrame(UIParent, false)
  LootFrame.events.LOOT_OPENED = true
  CreateFrame = function(_, _, parent) return NewFrame(parent, true) end
  hooksecurefunc = function() end

  C_Timer = {
    NewTicker = function(_, fn, iterations)
      local ticker = { fn = fn, left = iterations }
      function ticker:Cancel() self.cancelled = true end
      tickers[#tickers + 1] = ticker
      return ticker
    end,
    After = function(_, fn) timers[#timers + 1] = fn end,
  }
  EventUtil = { ContinueOnPlayerLogin = function(fn) loginCallback = fn end }

  IsInGroup = function() return opts.group or false end
  GetNumGroupMembers = function() return opts.group and 5 or 1 end
  C_PartyInfo = { GetLootMethod = function() return 3 end }
  GetLootThreshold = function() return 2 end
  GetCVarBool = function(cvar)
    if cvar == "lootUnderMouse" then return true end
    return opts.autoLootDefault ~= false
  end
  GetCursorPosition = function() return 400, 300 end
  IsModifiedClick = function() return false end
  GetNumLootItems = function() return #state.slots end
  GetLootSlotType = function() return Enum.LootSlotType.Item end
  GetLootSlotLink = function(slot) return "item" .. slot end
  GetLootSlotInfo = function(slot)
    local s = state.slots[slot]
    return 1, "Item", 1, nil, s.quality or 1, s.locked or false
  end
  LootSlot = function(slot) state.looted[#state.looted + 1] = slot end
  LootSlotHasItem = function() return true end
  ConfirmLootSlot = function() state.confirmed = state.confirmed + 1 end

  C_Item = {
    GetItemInfo = function() return nil, nil, nil, nil, nil, nil, nil, 20 end,
    GetItemFamily = function() return 0 end,
    GetItemCount = function() return 0 end,
  }
  C_Container = { GetContainerNumFreeSlots = function() return opts.bagsFull and 0 or 10, 0 end }
  C_ActionBar = {}

  local ns = { db = { fastLoot = opts.fastLoot ~= false, confirmBop = opts.confirmBop or false } }
  assert(loadfile("Core/Loot.lua"))("ItemFlow", ns)
  loginCallback()
  for _, fn in ipairs(timers) do fn() end
  return ns
end

-- Every registered handler sees the event; Blizzard's LootFrame shows itself on LOOT_OPENED. The client draws after every event.
local function Fire(event, ...)
  if event == "LOOT_OPENED" then LootFrame:Show() end
  for _, fn in ipairs(handlers) do fn(nil, event, ...) end
  state.drawn = state.drawn or LootFrame:IsVisible()
end

-- Runs every ticker to the end, one slot per tick.
local function Tick()
  for _, ticker in ipairs(tickers) do
    while not ticker.cancelled and ticker.left > 0 do
      ticker.left = ticker.left - 1
      ticker.fn()
    end
  end
  state.drawn = state.drawn or LootFrame:IsVisible()
end

local function Close()
  LootFrame:Hide()
  Fire("LOOT_CLOSED")
end

local failures = 0
local function Check(name, condition)
  print((condition and "  pass  " or "  FAIL  ") .. name)
  if not condition then failures = failures + 1 end
end

-- Everything fits: every slot is taken once, last first, and the window never draws.
Reset({})
Check("parked after login", LootFrame:GetParent() ~= UIParent)
Fire("LOOT_READY", true)
Fire("LOOT_OPENED", true)
Tick()
Check("fast: each slot once, last first", #state.looted == 3 and state.looted[1] == 3 and state.looted[3] == 1)
Check("fast: the window never draws", not state.drawn)
Close()
Check("fast: parked again after close", LootFrame:GetParent() ~= UIParent)

-- The bug: a scroll-wheel interact reopens the emptied corpse, and its payload can read as manual loot.
state.slots, state.drawn = {}, false
Fire("LOOT_READY", false)
Fire("LOOT_OPENED", false)
Tick()
Check("empty spam loot: no window", not state.drawn)
Close()

-- A spammed interact that flips the payload mid-loot keeps the first decision.
Reset({})
Fire("LOOT_READY", true)
Fire("LOOT_OPENED", false)
Tick()
Check("flipped payload: still fast", #state.looted == 3 and not state.drawn)

-- Manual loot: the window shows as usual.
Reset({ autoLootDefault = false })
Fire("LOOT_READY", false)
Fire("LOOT_OPENED", false)
Check("manual: the window shows", state.drawn and #state.looted == 0)

-- A rolled or locked slot stays behind and the window shows at the end.
Reset({ group = true, slots = { {}, { quality = 3 }, { locked = true } } })
Fire("LOOT_READY", true)
Fire("LOOT_OPENED", true)
Tick()
Check("contested: only the free slot looted", #state.looted == 1 and state.looted[1] == 1)
Check("contested: the window shows", state.drawn)

-- Full bags: nothing fits, so nothing is looted and the window shows.
Reset({ bagsFull = true })
Fire("LOOT_READY", true)
Fire("LOOT_OPENED", true)
Tick()
Check("full bags: the window shows", #state.looted == 0 and state.drawn)

-- An inventory error during a hidden loot shows the window.
Reset({})
Fire("LOOT_READY", true)
Fire("LOOT_OPENED", true)
Fire("UI_ERROR_MESSAGE", 1, "full")
Check("error: the window shows", state.drawn)

-- Fast Loot off: the window stays on UIParent and the addon loots nothing.
Reset({ fastLoot = false })
Check("off: never parked", LootFrame:GetParent() == UIParent)
Fire("LOOT_READY", true)
Fire("LOOT_OPENED", true)
Tick()
Check("off: no looting", #state.looted == 0)

-- Confirm Bind on Pickup solo: the popup is muted and each looted slot confirmed.
local ns = Reset({ confirmBop = true })
Check("bop solo: popup muted", not UIParent.events.LOOT_BIND_CONFIRM)
Fire("LOOT_READY", true)
Tick()
Check("bop solo: confirmed per slot", state.confirmed == 3)
ns.db.confirmBop = false
ns.ApplyBindPopup()
Check("bop off: popup back", UIParent.events.LOOT_BIND_CONFIRM)

-- In a group the bind stays the player's decision.
Reset({ confirmBop = true, group = true })
Check("bop group: popup kept", UIParent.events.LOOT_BIND_CONFIRM)

print(failures == 0 and "FastLoot: all checks passed" or ("FastLoot: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
