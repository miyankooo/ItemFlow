# ItemFlow

## Target

- WoW Forever 1.60.x only, `## Interface: 16001`. No client branches, no `WOW_PROJECT_*`, no compat layer.
- Verify every API against Gethe `wow-ui-source` and Ketho `BlizzardInterfaceResources`, branch `forever`. Forever loads the Mainline loot, merchant and bag files.
- Renamed from FastLootSellRepair on 2026-10-22. Saved variables are `ItemFlowDB`.

## Rules

- Looting follows SpeedyAutoLoot by Yuyuli. `LootFrame` lives under a hidden parent from 5 s after login and after every `LOOT_CLOSED`, and comes back to UIParent only for manual loot, a slot left behind (lock, no bag room), a stuck error or a bind prompt. An empty or repeated `LOOT_READY` returns early, so a spammed interact never draws the window.
- The first `LOOT_READY` of a loot decides auto loot, with SpeedyAutoLoot's fallback `GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")`, because a spammed interact can flip the payload.
- Slots loot last first, one per 0.033 s ticker step, after SpeedyAutoLoot's bag room check, which lets only crafting reagents into the reagent bag. Quality never holds a slot back, also in a group: SpeedyAutoLoot ships `X-Family: [Family]` unreplaced, so its Classic-only roll threshold never runs on Forever, and the owner wants the same (2026-10-23). Blizzard's own `LOOT_OPENED` handler plays the fishing sound while the window is parked, so the addon plays none.
- With Fast Loot off the window stays on UIParent and the addon does not loot.
- Confirm Bind on Pickup while solo unregisters `LOOT_BIND_CONFIRM` from UIParent so Blizzard's popup never flashes, and registers it again in a group or when the setting is off.
- Buy Max Stack post-hooks the global `MerchantItemButton_OnClick`, which the merchant buttons call by name, and tops Blizzard's one purchase up with `BuyMerchantItem` within `GetMerchantItemMaxStack`, money, supply and whole bundles. Items Blizzard confirms first are left alone.
- The Buy Max Stack checkbox matches Forever's own checkboxes (Watch Faction in `Camelot/ReputationFrame.xml`): 26 px minimal art through `CheckboxWithLabelTemplate`, a `GameFontNormal` label 2 px to the right. It sits left of the merchant FilterDropdown, or in its place when `Enum.GameRule.MerchantFilterDisabled` hides it.
- The cheapest-item glow post-hooks `UpdateItems` on every bag frame and only toggles the addon's own texture. Never call Blizzard's bag update from addon code, or the bag buttons taint.
- Settings use the native vertical layout with checkboxes only. No native dropdowns: they taint Blizzard's settings on build 70532 (2026-10-21).
- Labels are Title Case. Tooltips and chat lines are sentences ending in a period.
- The toc version stays 1.0.0 until the first CurseForge release.
- Licence: MIT (LICENSE).

## Checks

- Run `luac -p` on every Lua file and `lua Tests/FastLoot.lua`, `lua Tests/RepairOnce.lua`, `lua Tests/Buy.lua` and `lua Tests/Bags.lua` after a change.
- `.github/workflows/release.yml` stays byte-identical to ChatScan's copy.
- Turn on `/console scriptErrors 1` before testing in game, and disable SpeedyAutoLoot.
