local addonName, ns = ...

-- Outside the vendor window the addon shows nothing but its settings page, so the account's first login points
-- there once, with a link that opens it. The line waits for login, when the page exists and the client's own load
-- lines are already in chat.

-- Blizzard hands every click on an addon link to all addons through the EventRegistry event SetItemRef
-- (Shared/ItemRefHandlersShared.lua), so nothing is hooked. Gold is the colour of Blizzard's own action links in
-- chat (ItemRef.lua).
local LINK = LinkTypes.AddOn .. ":" .. addonName

local function SurfaceLink(label)
  return NORMAL_FONT_COLOR:WrapTextInColorCode(LinkUtil.FormatLink(LinkTypes.AddOn, "[" .. label .. "]", addonName))
end

-- The game ships with Auto Loot off, which leaves Fast Loot idle.
function ns.PrintWelcome()
  local autoLoot = GetCVarBool("autoLootDefault") and "" or " Fast Loot needs Auto Loot on (Options, Controls)."
  ns.Print("Loots fast, sells junk and repairs at vendors." .. autoLoot
    .. " Open the " .. SurfaceLink(SETTINGS) .. " or type /if to turn each feature on or off.")
end

-- `/if intro` replays the onboarding: the welcome line now, and the Buy Max Stack tip at its next chance.
function ns.ReplayIntro()
  ns.PrintWelcome()
  ns.ResetBuyMaxStackTip()
end

-- Another addon's link can come from a line kept from restricted content, so it is checked before the comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
  if ns.CanAccess(link) and link == LINK then ns.OpenSettings() end
end, ns)

EventUtil.ContinueOnPlayerLogin(function()
  if ns.firstRun then ns.PrintWelcome() end
end)
