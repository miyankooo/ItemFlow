local _, ns = ...

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

-- Opening in combat waits for combat to end, since the settings panel's open path has restrictions.
local waitingForCombat = false
function ns.OpenSettings()
  if not categoryID then return end
  if InCombatLockdown() then
    ns.Print("Opens after combat.")
    if not waitingForCombat then
      waitingForCombat = true
      EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
        waitingForCombat = false
        ns.OpenSettings()
      end)
    end
    return
  end
  Settings.OpenToCategory(categoryID)
end

-- One long command and one short alias. The bare command opens the main surface; help, intro and minimap
-- (where there is a minimap button) are the shared words, and any other word prints the hint.
SLASH_ITEMFLOW1, SLASH_ITEMFLOW2 = "/itemflow", "/if"
SlashCmdList.ITEMFLOW = function(message)
  local command = strtrim(message or ""):lower()
  if command == "" then
    ns.OpenSettings()
  elseif command == "help" or command == "?" then
    ns.Print("Type /if for the settings, /if intro to see the welcome line and the Buy Max Stack tip again, or /if help for this list.")
  elseif command == "intro" then
    ns.ReplayIntro()
  else
    ns.Print("Unknown command. Type /if help for the list.")
  end
end

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the menu row.
ItemFlow_CompartmentClick = ns.OpenSettings

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
