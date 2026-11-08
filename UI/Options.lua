local _, ns = ...

-- Text in a font role: GameFontNormal (heading, gold), GameFontHighlight (body, white), GameFontDisable (muted,
-- grey), GameFontNormalLarge (title, 16 px, a dialog's subject line only).
local function CreateText(parent, fontObject, layer)
  local text = parent:CreateFontString(nil, layer or "ARTWORK")
  text:SetFontObject(fontObject or GameFontHighlight)
  text:SetJustifyH("LEFT")
  return text
end

-- A GameTooltip owned by the hovered frame, filled with Blizzard's GameTooltip_* line helpers. A frame whose
-- template already sets OnEnter gets HookScript instead.
local function AttachTooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- The addon's page in Blizzard's Settings window, as its own canvas, copying the settings list's look
-- (Blizzard_SettingsList.xml:14-30, Blizzard_SettingControls.xml, Blizzard_SettingControls.lua). Never a settings
-- list: a pick in a list dropdown runs addon code in Blizzard's pooled controls and taints its settings until /reload.
local ROW_HEIGHT, ROW_SPACING, LABEL_X, INTRO_Y, INTRO_GAP = 26, 9, 37, -64, 16
local categoryID

local function BuildPanel(introText, restoreDefaults)
  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(ns.title)
  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("TOP", 0, -50)
  local defaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defaults:SetSize(96, 22)
  defaults:SetPoint("TOPRIGHT", -36, -16)
  defaults:SetText(SETTINGS_DEFAULTS)
  defaults:SetScript("OnClick", restoreDefaults)
  panel.intro = CreateText(panel, GameFontHighlight)
  panel.intro:SetPoint("TOPLEFT", LABEL_X, INTRO_Y)
  panel.intro:SetPoint("TOPRIGHT", -LABEL_X, INTRO_Y)
  panel.intro:SetText(introText)
  return panel
end

-- One row below the intro, its label in GameFontNormal from x 37 to the row's centre less 85. A checkbox
-- (SettingsCheckboxTemplate) goes at the row's CENTER -80, a WowStyle1DropdownTemplate 220 wide at CENTER -48.
-- Within one page, controls share one left edge.
local function AddRow(panel, index, label, fillTooltip)
  local y = -INTRO_GAP - (index - 1) * (ROW_HEIGHT + ROW_SPACING)
  local row = CreateFrame("Frame", nil, panel)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", panel.intro, "BOTTOMLEFT", -LABEL_X, y)
  row:SetPoint("TOPRIGHT", panel.intro, "BOTTOMRIGHT", LABEL_X, y)
  row:EnableMouse(true)
  AttachTooltip(row, fillTooltip)
  local text = CreateText(row, GameFontNormal)
  text:SetPoint("LEFT", LABEL_X, 0)
  text:SetPoint("RIGHT", row, "CENTER", -85, 0)
  text:SetText(label)
  -- Kept so a dependent row can indent and grey out its label.
  row.label = text
  return row
end

local function RegisterPanel(panel)
  local category = Settings.RegisterCanvasLayoutCategory(panel, ns.title)
  Settings.RegisterAddOnCategory(category)
  categoryID = category:GetID()
end

-- What the addon does, where it works and what stays the game's own, before any row asks for a choice.
local INTRO = "Loots everything at once, sells your junk, repairs your gear and buys full stacks at vendors. "
  .. "Turn each feature on or off below.\n\n"
  .. "Fast Loot needs Auto Loot on (Options, Controls), or the Auto Loot key held. The loot window still shows "
  .. "when you have to act, such as with full bags or a roll.\n\n"
  .. "Junk sells through the vendor's own Sell All Junk, so bags set to ignore junk selling keep theirs. The game "
  .. "still asks before you loot a bind on pickup item or buy a costly one."

-- Blizzard's settings list indents a row that depends on another by 15 and greys it out while the other is off
-- (Blizzard_SettingControls.lua:1, 309-312, 359).
local CHILD_INDENT = 15

local checkboxes, rows = {}, {}

local function UpdateEnabled()
  for _, entry in ipairs(ns.SETTINGS) do
    if entry.parent then
      local enabled = ns.db[entry.parent] and true or false
      checkboxes[entry.key]:SetEnabled(enabled)
      rows[entry.key].label:SetTextColor((enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
      rows[entry.key]:DesaturateHierarchy(enabled and 0 or 1)
    end
  end
end

local function SetValue(entry, value)
  ns.db[entry.key] = value
  if entry.onChange then entry.onChange() end
  UpdateEnabled()
end

-- The vendor window's Buy Max Stack checkbox writes the same setting, so the page reads every value again each time
-- Blizzard shows it.
local function Refresh()
  for _, entry in ipairs(ns.SETTINGS) do checkboxes[entry.key]:SetValue(ns.db[entry.key]) end
  UpdateEnabled()
end

local function RestoreDefaults()
  for _, entry in ipairs(ns.SETTINGS) do
    ns.db[entry.key] = entry.default
    if entry.onChange then entry.onChange() end
  end
  Refresh()
end

-- The checkbox Blizzard's settings list builds for a checkbox row (SettingsCheckboxControlMixin), on the addon's own
-- canvas. A click on the row ticks it and each change plays the list's sound, as there.
local function AddCheckboxRow(panel, index, entry)
  local function FillTooltip(tooltip)
    GameTooltip_SetTitle(tooltip, entry.label)
    GameTooltip_AddNormalLine(tooltip, entry.tooltip)
  end

  local row = AddRow(panel, index, entry.label, FillTooltip)
  if entry.parent then row.label:SetPoint("LEFT", LABEL_X + CHILD_INDENT, 0) end

  local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
  checkbox:SetPoint("LEFT", row, "CENTER", -80, 0)
  checkbox:Init(ns.db[entry.key], function() FillTooltip(SettingsTooltip) end)
  checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, checked)
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    SetValue(entry, checked)
  end, row)
  row:SetScript("OnMouseUp", function()
    if checkbox:IsEnabled() then checkbox:Click() end
  end)

  checkboxes[entry.key], rows[entry.key] = checkbox, row
end

EventUtil.ContinueOnPlayerLogin(function()
  local panel = BuildPanel(INTRO, RestoreDefaults)
  for index, entry in ipairs(ns.SETTINGS) do AddCheckboxRow(panel, index, entry) end
  UpdateEnabled()
  -- Blizzard calls a canvas's OnRefresh each time it shows the page (Blizzard_SettingsPanel.lua:7-11).
  panel.OnRefresh = Refresh
  RegisterPanel(panel)
end)

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
    ns.Print("Type /if for the settings, /if intro to see the welcome line and the tip again, "
      .. "or /if help for this list.")
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

  -- The current state: each feature and whether it is on.
  for _, entry in ipairs(ns.SETTINGS) do
    GameTooltip_AddColoredDoubleLine(GameTooltip, entry.label,
      ns.db[entry.key] and VIDEO_OPTIONS_ENABLED or VIDEO_OPTIONS_DISABLED, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
  end

  -- The game's Auto Loot is off by default, which leaves Fast Loot idle without any other hint.
  if ns.db.fastLoot and not GetCVarBool("autoLootDefault") then
    GameTooltip_AddNormalLine(GameTooltip, "Auto Loot is off, so Fast Loot waits for the Auto Loot key.")
  end
  GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
  GameTooltip:Show()
end

ItemFlow_CompartmentLeave = GameTooltip_Hide
