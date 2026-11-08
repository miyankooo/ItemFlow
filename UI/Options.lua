local addonName, ns = ...

local categoryID

local function AddCheckbox(category, entry)
  local variable = "ITEM_FLOW_" .. strupper(entry.key)
  local setting = Settings.RegisterAddOnSetting(category, variable, entry.key, ItemFlowDB,
    Settings.VarType.Boolean, entry.label, entry.default)
  if entry.onChange then setting:SetValueChangedCallback(entry.onChange) end

  return Settings.CreateCheckbox(category, setting, entry.tooltip)
end

local function RegisterPanel()
  local category = Settings.RegisterVerticalLayoutCategory(ns.title)
  local rows = {}

  for _, entry in ipairs(ns.SETTINGS) do
    rows[entry.key] = AddCheckbox(category, entry)
    if entry.parent then
      rows[entry.key]:SetParentInitializer(rows[entry.parent], function() return ns.db[entry.parent] end)
    end
  end

  Settings.RegisterAddOnCategory(category)
  categoryID = category:GetID()
end

EventUtil.ContinueOnPlayerLogin(RegisterPanel)

local waitingForCombat = false

-- C_SettingsUtil.OpenSettingsPanel is flagged HasRestrictions, so a request in combat waits until combat ends, once however often it was asked.
local function OpenSettings()
  if not categoryID then
    return
  end

  if InCombatLockdown() then
    ns.Print("Opens after combat.")
    if not waitingForCombat then
      waitingForCombat = true
      EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
        waitingForCombat = false
        OpenSettings()
      end)
    end
    return
  end

  Settings.OpenToCategory(categoryID)
end

-- The intro's settings link is a native addon hyperlink. Blizzard hands every click on one to all addons through
-- EventRegistry's SetItemRef event (ItemRefHandlersShared.lua), so nothing is hooked. Gold is the colour of
-- Blizzard's own action links in chat (ItemRef.lua).
local LINK = LinkTypes.AddOn .. ":" .. addonName
local SETTINGS_LINK = NORMAL_FONT_COLOR:WrapTextInColorCode(LinkUtil.FormatLink(LinkTypes.AddOn, "[" .. SETTINGS .. "]", addonName))

-- Another addon's link can come from a line kept from restricted content, so it is checked before the comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
  if ns.CanAccess(link) and link == LINK then OpenSettings() end
end, ns)

-- One chat line on the account's first login. The game ships with Auto Loot off, which leaves Fast Loot idle.
local function PrintIntro()
  local autoLoot = GetCVarBool("autoLootDefault") and "" or " Fast Loot needs Auto Loot on (Options, Controls)."
  ns.Print("Loots fast, sells junk and repairs at vendors." .. autoLoot
    .. " Open the " .. SETTINGS_LINK .. " or type /if to turn each feature on or off.")
end

EventUtil.ContinueOnPlayerLogin(function()
  if ns.isFirstRun then PrintIntro() end
end)

SLASH_ITEMFLOW1, SLASH_ITEMFLOW2 = "/itemflow", "/if"
-- A bare /if opens the settings, the first word picks any other command.
SlashCmdList.ITEMFLOW = function(message)
  local command = strtrim(message):lower()

  if command == "" then
    OpenSettings()

  -- Replays the first run: the intro line now and the Buy Max Stack tip at the vendor.
  elseif command == "intro" then
    PrintIntro()
    ns.ResetBuyMaxStackTip()

  elseif command == "help" or command == "?" then
    ns.Print("Type /if for the settings, /if intro to see the welcome line and the Buy Max Stack tip again, or /if help for this list.")

  else
    ns.Print("Unknown command. Type /if help for the list.")
  end
end

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the menu row.
ItemFlow_CompartmentClick = OpenSettings

function ItemFlow_CompartmentEnter(_, menuButton)
  GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
  GameTooltip_SetTitle(GameTooltip, ns.title)

  -- The game's Auto Loot is off by default, which leaves Fast Loot idle without any other hint.
  if ns.db.fastLoot and not GetCVarBool("autoLootDefault") then
    GameTooltip_AddHighlightLine(GameTooltip, "Auto Loot is off, so Fast Loot waits for the Auto Loot key.")
  end
  GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
  GameTooltip:Show()
end

ItemFlow_CompartmentLeave = GameTooltip_Hide
