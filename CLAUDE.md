# ItemFlow

Features, settings and credits are in `README.md`.

## Target

- Forever loads the Mainline loot, merchant and bag files. Verify against those.
- Renamed from FastLootSellRepair. Saved variables are `ItemFlowDB`.

## Rules

- Looting follows SpeedyAutoLoot by Yuyuli. `LootFrame` lives under a hidden parent from 6 s after `ADDON_LOADED` and after every `LOOT_CLOSED`. It comes back to UIParent only for manual loot, a slot left behind (lock, no bag room), a stuck error or a bind prompt. An empty or repeated `LOOT_READY` returns early, so a spammed interact never draws the window.
- The first `LOOT_READY` of a loot decides auto loot, with SpeedyAutoLoot's fallback `GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")`, because a spammed interact can flip the payload.
- Slots loot last first, all in the frame of the first `LOOT_READY`, after SpeedyAutoLoot's bag room check, which lets only crafting reagents into the reagent bag. SpeedyAutoLoot spaces them 0.033 s apart. ItemFlow loots them in one frame on purpose. Quality never holds a slot back, also in a group: SpeedyAutoLoot ships `X-Family: [Family]` unreplaced, so its Classic-only roll threshold never runs on Forever. ItemFlow keeps it that way. Blizzard's own `LOOT_OPENED` handler plays the fishing sound (`FISHING_REEL_IN`) while the window is parked, so the addon plays none. Never add SpeedyAutoLoot's extra reel sound on top.
- With Fast Loot off the window stays on UIParent and the addon does not loot.
- Confirm Bind on Pickup while solo unregisters `LOOT_BIND_CONFIRM` from UIParent so Blizzard's popup never flashes. It registers it again in a group or when the setting is off. `GROUP_JOINED` and `GROUP_LEFT` set it from the event alone, as SpeedyAutoLoot does, because the roster can lag behind them.
- Buy Max Stack post-hooks the global `MerchantItemButton_OnClick`, which the merchant buttons call by name. It tops Blizzard's one purchase up with `BuyMerchantItem` within `GetMerchantItemMaxStack`, money, supply and whole bundles. Items Blizzard confirms first are left alone.
- The Buy Max Stack checkbox matches Forever's own checkboxes (Watch Faction in `Camelot/ReputationFrame.xml`): 26 px minimal art through `CheckboxWithLabelTemplate`, a `GameFontNormal` label 2 px to the right. It sits left of the merchant FilterDropdown, or in its place when `Enum.GameRule.MerchantFilterDisabled` hides it.
- Sell Junk calls only Blizzard's `C_MerchantFrame.SellAllJunkItems`, behind the `IsSellAllJunkEnabled` check that also shows the vendor window's button. It has no per-item fallback, since Sell All Junk is part of every vendor. The bag scan only counts greys for the chat line.
- Mark Items to Drop (key `highlightCheapest`) follows LootTriage by Krelock, rewritten since it ships no licence: while loot is open, every loot item that `ns.ItemFits` refuses is paired by value, best first, with the cheapest priced stack in general bags after the free slots. It marks the stack when the loot is worth more. A quest item is always worth it. Without such loot, the cheapest stack is marked at 2 or fewer free slots. Prices ignore Auctionator values older than 7 days (`GetAuctionAgeByItemLink`).
- Gray and white marked stacks get a delete button with the group loot Pass atlases (`lootroll-toast-icon-pass-*`). Its click picks the stack up and calls `DeleteCursorItem` in the same hardware event. It puts the stack back if the delete was refused. Better items never get it, since Blizzard asks before deleting them.
- The glow copies the button's `NewItemTexture`: `bags-glow-orange`, OVERLAY sublevel 2, ADD, atlas size, centred, no pulse so it never reads as a new item.
- The marks post-hook `UpdateItems` on every bag frame and loot events repaint open bags. They only toggle the addon's own texture and button. Never call Blizzard's bag update from addon code, or the bag buttons taint. The cheapest-item scan is cached per frame.
- Settings use the native vertical layout with checkboxes only.
- The keyring check uses only `C_ActionBar.ShouldShowKeyring`. `IsKeyRingEnabled` is gone on Forever.
- Left out on purpose: SpeedyAutoLoot's ElvUI and Loot Display support and its inventory-full sound.

## Checks

- Run `lua Tests/FastLoot.lua`, `lua Tests/RepairOnce.lua`, `lua Tests/Buy.lua` and `lua Tests/Bags.lua` after a change.
- Disable SpeedyAutoLoot and LootTriage before testing in game.

## Release

- `.pkgmeta` also keeps `CLAUDE.md` out of the package.
