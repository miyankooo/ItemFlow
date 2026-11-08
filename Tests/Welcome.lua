-- Offline check of the first-use onboarding in Core/Config.lua, UI/Options.lua and UI/Welcome.lua: the welcome line,
-- its settings link, the slash commands and the settings page. Run from the repo root with `lua Tests/Welcome.lua`.

local ns, lines, opened, loginCallbacks, linkCallbacks, regenCallbacks, addonLoaded
local panel, checkboxes, defaultsButton, tipReset, tooltip, autoLoot, inCombat, secret

-- Chat lines go to the stubbed print, test results to the real one.
local realPrint = print

local function noop() end

-- Unknown methods (PascalCase, as the client's) do nothing; unknown fields stay nil.
local MOCK = { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return noop end end }

-- SetPoint keeps the x offset per anchor point, so a check can read where a label or control starts.
local function SetPoint(self, point, ...)
  local args = { ... }
  self.x = self.x or {}
  self.x[point] = type(args[1]) == "number" and args[1] or args[3]
end

local function Region()
  return setmetatable({ SetText = function(self, text) self.text = text end, SetPoint = SetPoint }, MOCK)
end

local function Frame(template)
  local f = setmetatable({ template = template, scripts = {} }, MOCK)
  f.SetScript = function(self, name, fn) self.scripts[name] = fn end
  f.SetPoint = SetPoint
  f.CreateFontString = Region
  f.CreateTexture = Region
  f.Init = function(self, value, fill) self.checked, self.fillTooltip = value, fill end
  f.SetValue = function(self, value) self.checked = value end
  f.RegisterCallback = function(self, _, fn) self.onValueChanged = fn end
  f.SetEnabled = function(self, enabled) self.enabled = enabled end
  f.IsEnabled = function(self) return self.enabled ~= false end
  -- SettingsCheckboxMixin:Init's OnClick reports the new state through OnValueChanged.
  f.Click = function(self)
    self.checked = not self.checked
    self.onValueChanged(nil, self.checked)
  end
  if template == "SettingsCheckboxTemplate" then checkboxes[#checkboxes + 1] = f end
  if template == "UIPanelButtonTemplate" then defaultsButton = f end
  return f
end

local function Color(hex)
  return { WrapTextInColorCode = function(_, text) return "|cff" .. hex .. text .. "|r" end, GetRGB = noop }
end

-- Fresh client stubs per load, so no case leaks saved settings, callbacks or chat lines into the next.
local function Load(opts)
  lines, opened, loginCallbacks, linkCallbacks, regenCallbacks = {}, {}, {}, {}, {}
  panel, checkboxes, tipReset, inCombat, secret = nil, {}, false, false, false
  autoLoot = opts.autoLoot ~= false
  ItemFlowDB = opts.db

  print = function(message) lines[#lines + 1] = message end
  strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  C_AddOns = { GetAddOnMetadata = function() return "Item Flow" end }
  NORMAL_FONT_COLOR, GRAY_FONT_COLOR, HIGHLIGHT_FONT_COLOR = Color("ffd200"), Color("808080"), Color("ffffff")
  issecretvalue = function() return secret end
  GetCVarBool = function(cvar) return cvar == "autoLootDefault" and autoLoot end
  InCombatLockdown = function() return inCombat end
  PlaySound = noop
  SOUNDKIT = {}
  SETTINGS, SETTINGS_DEFAULTS = "Settings", "Defaults"
  VIDEO_OPTIONS_ENABLED, VIDEO_OPTIONS_DISABLED = "Enabled", "Disabled"
  LinkTypes = { AddOn = "addon" }
  LinkUtil = {
    FormatLink = function(linkType, text, ...)
      return table.concat({ "|H" .. linkType, ... }, ":") .. "|h" .. text .. "|h"
    end,
  }
  EventRegistry = {
    RegisterCallback = function(_, event, fn, owner)
      if event == "SetItemRef" then linkCallbacks[#linkCallbacks + 1] = { fn = fn, owner = owner } end
    end,
  }
  EventUtil = {
    ContinueOnAddOnLoaded = function(_, fn) addonLoaded = fn end,
    ContinueOnPlayerLogin = function(fn) loginCallbacks[#loginCallbacks + 1] = fn end,
    RegisterOnceFrameEventAndCallback = function(_, fn) regenCallbacks[#regenCallbacks + 1] = fn end,
  }
  Settings = {
    RegisterCanvasLayoutCategory = function(frame) panel = frame return { GetID = function() return 42 end } end,
    RegisterVerticalLayoutCategory = function() error("the settings page must be a canvas") end,
    RegisterAddOnCategory = noop,
    OpenToCategory = function(id) opened[#opened + 1] = id end,
  }
  SettingsCheckboxMixin = { Event = { OnValueChanged = "OnValueChanged" } }
  CreateFrame = function(_, _, parent, template)
    local frame = Frame(template)
    frame.parent = parent
    return frame
  end
  GameFontHighlight, GameFontNormal = {}, {}

  tooltip = { lines = {} }
  local function Add(text) tooltip.lines[#tooltip.lines + 1] = text end
  GameTooltip = setmetatable({}, MOCK)
  SettingsTooltip = setmetatable({}, MOCK)
  GameTooltip_Hide = noop
  GameTooltip_SetTitle = function(_, text) tooltip.title = text end
  GameTooltip_AddNormalLine = function(_, text) Add(text) end
  GameTooltip_AddHighlightLine = function(_, text) Add(text) end
  GameTooltip_AddInstructionLine = function(_, text) tooltip.instruction = text end
  GameTooltip_AddColoredDoubleLine = function(_, left, right) Add(left .. ": " .. right) end

  SlashCmdList = {}
  ns = { ApplyFastLoot = noop, ResetBuyMaxStackTip = function() tipReset = true end }
  for _, file in ipairs({ "Core/Config.lua", "UI/Options.lua", "UI/Welcome.lua" }) do
    assert(loadfile(file))("ItemFlow", ns)
  end
  addonLoaded()
end

local function Login()
  for _, fn in ipairs(loginCallbacks) do fn() end
end

local function ClickLink(link)
  for _, callback in ipairs(linkCallbacks) do callback.fn(callback.owner, link) end
end

local function Slash(message)
  SlashCmdList.ITEMFLOW(message)
  return lines[#lines]
end

local failures = 0
local function Check(name, condition)
  realPrint((condition and "  pass  " or "  FAIL  ") .. name)
  if not condition then failures = failures + 1 end
end

local PREFIX = "|cffffd200[Item Flow]|r: "
local LINK = "|cffffd200|Haddon:ItemFlow|h[Settings]|h|r"
local WELCOME = PREFIX .. "Loots fast, sells junk and repairs at vendors. Open the " .. LINK
  .. " or type /if to turn each feature on or off."
local HELP = PREFIX .. "Type /if for the settings, /if intro to see the welcome line and the tip again, "
  .. "or /if help for this list."

-- The welcome line.
Load({})
Check("first load: sets the first-run flag and prints nothing", ns.firstRun == true and #lines == 0)
Login()
Check("login: exactly one welcome line", #lines == 1)
Check("login: the gold title, then the uncoloured message", lines[1]:sub(1, #PREFIX) == PREFIX)
Check("login: the line carries the settings link and the alias",
  lines[1]:find(LINK, 1, true) ~= nil and lines[1]:find(" /if ", 1, true) ~= nil)
Check("login: the line reads as the shared shape", lines[1] == WELCOME)

ClickLink("addon:ItemFlow")
Check("link: a click opens the settings", #opened == 1 and opened[1] == 42)
ClickLink("addon:OtherAddon")
Check("link: another addon's link does nothing", #opened == 1)
secret = true
ClickLink("addon:ItemFlow")
secret = false
Check("link: a secret link does nothing", #opened == 1)

Load({ autoLoot = false })
Login()
Check("login: with Auto Loot off the note comes last",
  lines[1] == WELCOME .. " Fast Loot needs Auto Loot on (Options, Controls).")

Load({ db = {} })
Login()
Check("later login: prints nothing", ns.firstRun == false and #lines == 0)

-- Slash commands.
Check("help: one line naming every command", Slash("help") == HELP and Slash("?") == HELP)
local before = #lines
Check("intro: prints the welcome line again", Slash("intro") == WELCOME and #lines == before + 1)
Check("intro: the Buy Max Stack tip shows again", tipReset)
before = #opened
Check("unknown word: prints the hint and opens nothing",
  Slash("bogus") == PREFIX .. "Unknown command. Type /if help for the list." and #opened == before)
Slash("")
Check("bare command: opens the settings", #opened == before + 1)
inCombat = true
Check("in combat: waits", Slash("") == PREFIX .. "Opens after combat." and #opened == before + 1)
inCombat = false
regenCallbacks[1]()
Check("in combat: opens once combat ends", #opened == before + 2)

-- The settings page.
Check("page: a canvas with the intro first",
  panel ~= nil and panel.intro.text:find("^Loots everything at once") ~= nil)
Check("page: one Blizzard settings checkbox per setting", #checkboxes == #ns.SETTINGS)
local byKey = {}
for index, entry in ipairs(ns.SETTINGS) do byKey[entry.key] = checkboxes[index] end
local edge = true
for _, checkbox in ipairs(checkboxes) do edge = edge and checkbox.x.LEFT == -40 end
Check("page: every checkbox starts at the row's centre less 40", edge)
Check("page: Guild Repair's label is indented 15",
  byKey.guildRepair.parent.label.x.LEFT == 52 and byKey.repairGear.parent.label.x.LEFT == 37)
byKey.sellJunk:Click()
Check("page: a click saves the setting", ns.db.sellJunk == false)
byKey.sellJunk.parent.scripts.OnMouseUp()
Check("page: a click on the row ticks its box", ns.db.sellJunk == true)
byKey.repairGear:Click()
Check("page: Guild Repair greys out while Repair Gear is off", byKey.guildRepair.enabled == false)
byKey.guildRepair.parent.scripts.OnMouseUp()
Check("page: a greyed row ignores clicks", ns.db.guildRepair == false)
byKey.repairGear:Click()
Check("page: and comes back with it", byKey.guildRepair.enabled == true)
ns.db.buyMaxStack = true
panel:OnRefresh()
Check("page: shows a value the vendor window changed", byKey.buyMaxStack.checked == true)
byKey.repairGear:Click()
defaultsButton.scripts.OnClick()
local defaults = true
for index, entry in ipairs(ns.SETTINGS) do
  defaults = defaults and ns.db[entry.key] == entry.default and checkboxes[index].checked == entry.default
end
Check("page: Defaults restores every setting and the boxes", defaults and byKey.guildRepair.enabled == true)
local tooltips = true
for index, entry in ipairs(ns.SETTINGS) do
  tooltip.lines = {}
  checkboxes[index].fillTooltip()
  tooltips = tooltips and tooltip.title == entry.label and tooltip.lines[1] == entry.tooltip
    and checkboxes[index].parent.scripts.OnEnter ~= nil
end
Check("page: every row and checkbox has a tooltip", tooltips)

-- The addon menu entry.
Load({ db = {}, autoLoot = false })
Login()
ItemFlow_CompartmentEnter("ItemFlow", Frame())
Check("addon menu: each feature and its state, then the click", tooltip.title == "Item Flow"
  and tooltip.lines[1] == "Fast Loot: Enabled" and tooltip.lines[4] == "Guild Repair: Disabled"
  and tooltip.instruction == "Click to open the settings.")
Check("addon menu: names Auto Loot while it is off", tooltip.lines[#ns.SETTINGS + 1] ~= nil)
ItemFlow_CompartmentClick("ItemFlow")
Check("addon menu: a click opens the settings", #opened == 1)

realPrint(failures == 0 and "Welcome: all checks passed" or ("Welcome: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
