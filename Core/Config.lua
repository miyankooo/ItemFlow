local addonName, ns = ...

local DEFAULTS = {
  fastLoot = true,
  confirmBop = false,
  sellJunk = true,
  repairGear = true,
  guildRepair = false,
}

local LABELS = {
  fastLoot = "Instant looting",
  confirmBop = "Auto-confirm bind-on-pickup while solo",
  sellJunk = "Sell junk at vendors",
  repairGear = "Repair at vendors",
  guildRepair = "Repair from guild bank funds",
}

-- Fixed order so the status listing stays stable across sessions.
local KEYS = { "fastLoot", "confirmBop", "sellJunk", "repairGear", "guildRepair" }

-- Modules read this table lazily, so it is safe that it stays empty until ADDON_LOADED.
ns.db = {}

function ns.Print(message)
  print("|cff58C6FAFLSR|r " .. message)
end

local function LoadSettings()
  FastLootSellRepairDB = FastLootSellRepairDB or {}
  for key, value in pairs(DEFAULTS) do
    if FastLootSellRepairDB[key] == nil then
      FastLootSellRepairDB[key] = value
    end
  end
  ns.db = FastLootSellRepairDB
end

local function StateText(key)
  return ns.db[key] and "|cff37DB33on|r" or "|cffB6B6B6off|r"
end

local function PrintStatus()
  ns.Print("toggle a setting with /flsr <name>")
  for _, key in ipairs(KEYS) do
    ns.Print(("  |cffFFC700%s|r %s - %s"):format(key:lower(), StateText(key), LABELS[key]))
  end
end

local function ToggleSetting(name)
  for _, key in ipairs(KEYS) do
    if key:lower() == name then
      ns.db[key] = not ns.db[key]
      ns.Print(LABELS[key] .. " " .. StateText(key))
      return true
    end
  end
  return false
end

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, _, loadedAddon)
  if loadedAddon == addonName then
    LoadSettings()
    self:UnregisterEvent("ADDON_LOADED")
  end
end)

SLASH_FASTLOOTSELLREPAIR1, SLASH_FASTLOOTSELLREPAIR2 = "/flsr", "/fastlootsellrepair"
function SlashCmdList.FASTLOOTSELLREPAIR(input)
  if not ToggleSetting(strtrim(input or ""):lower()) then
    PrintStatus()
  end
end
