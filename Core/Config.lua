local addonName, ns = ...

ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

-- One ordered list feeds the saved defaults and the settings page. A row with a parent greys out while that setting is off. onChange runs after the setting is saved.
ns.SETTINGS = {
  { key = "fastLoot", default = true, label = "Fast Loot", tooltip = "Takes every item at once without showing the loot window. Needs Auto Loot on (Options, Controls), or hold the Auto Loot key.", onChange = function() ns.ApplyFastLoot() end },
  { key = "confirmBop", default = false, label = "Confirm Bind on Pickup", tooltip = "Confirms bind on pickup loot for you while you play solo. In a group you still decide.", onChange = function() ns.ApplyBindPopup() end },
  { key = "sellJunk", default = true, label = "Sell Junk", tooltip = "Sells your grey items when you open a vendor." },
  { key = "repairGear", default = true, label = "Repair Gear", tooltip = "Repairs your gear when you open a vendor who can repair." },
  { key = "guildRepair", default = false, label = "Guild Repair", tooltip = "Pays repairs from guild bank funds when your guild allows it. Your own money covers the rest.", parent = "repairGear" },
  { key = "buyMaxStack", default = false, label = "Buy Max Stack", tooltip = "Right-clicking an item at a vendor buys a full stack. The vendor window has the same checkbox." },
  { key = "highlightCheapest", default = true, label = "Mark Items to Drop", tooltip = "When loot stays behind for lack of room, your cheapest stacks worth less than that loot glow, one per loot item. With 2 or fewer free slots, the cheapest stack glows. Gray and white stacks get a red cross that deletes them. Values use the lower of the vendor price and an Auctionator price from the last 7 days.", onChange = function() ns.RefreshBagGlow() end },
}

-- Modules read this table lazily, so it is safe that it stays empty until ADDON_LOADED.
ns.db = {}

local PREFIX = YELLOW_FONT_COLOR:WrapTextInColorCode("[" .. ns.title .. "]:") .. " "

function ns.Print(message)
  print(PREFIX .. message)
end

local function LoadSettings()
  ItemFlowDB = ItemFlowDB or {}
  for _, entry in ipairs(ns.SETTINGS) do
    if ItemFlowDB[entry.key] == nil then
      ItemFlowDB[entry.key] = entry.default
    end
  end
  ns.db = ItemFlowDB
end

EventUtil.ContinueOnAddOnLoaded(addonName, LoadSettings)
