# FastLootSellRepair — Memory

Updated 2026-09-30 after the Forever-only audit. The owner's decision now is WoW Forever 1.60.x only: `main` drops everything that exists only for Classic, and a `1.15.x-backup` branch keeps the Classic version. This supersedes the 2026-09-25 decision that every addon supports both clients. The audit verified against Gethe `forever` @ `966519cf` (1.60.1.70124) and Ketho `forever` @ `4149af64` (1.60.1.70009). The installed client is 1.60.1.70009. Nothing has run in a client yet.

## Current state

Instant auto-loot, junk selling and repairs at vendors. `/flsr` toggles five settings. No UI, no libraries.

| Item | State |
|---|---|
| Version | 2.0.0, Forever only: `## Interface: 16001`, `## Category: Inventory` |
| Author | `miyanko` |
| Git | `main` holds 2.0.0 (committed 2026-09-30, not pushed). `1.15.x-backup` = `bf6fe44` (the only commit that runs on 1.15) is on GitHub. No `LICENSE`: removed on purpose on 2026-09-25, from every branch and all history; one gets added later by hand |

The addon was born Forever-only. `52f23be` (1.0.0) had `## Interface: 16001`. All Classic support is the single commit `bf6fe44`, which touched only `Core/Vendor.lua` (`hasJunkApi`, `LAST_BAG`) and the toc Interface line.

Verified on Forever:

- `LOOT_READY(autoloot: bool)` (`LootDocumentation.lua`)
- `GetLootSlotInfo`, `LootSlot`, `LootSlotHasItem`, `ConfirmLootSlot`, `GetLootThreshold`, `C_PartyInfo.GetLootMethod`
- `Enum.LootMethod` has `Group`, `Needbeforegreed` and `Masterlooter` (`LuaEnum.lua:5478`)
- `C_MerchantFrame.IsSellAllJunkEnabled`, `GetNumJunkItems` and `SellAllJunkItems`
- `C_Container.*` with `hasNoValue` and `isLocked`
- `NUM_TOTAL_EQUIPPED_BAG_SLOTS` (`Blizzard_FrameXMLBase/Constants.lua:170`)
- `RepairAllItems(true)` behind `CanGuildBankRepair()`, which is exactly Blizzard's `MerchantGuildBankRepairButton` (`Mainline/MerchantFrame.xml:382`)
- `SOUNDKIT.ITEM_REPAIR`

The Forever merchant frame shows its sell-all-junk button only when `C_MerchantFrame.IsSellAllJunkEnabled()` is true (`Mainline/MerchantFrame.lua:482`). The bag fallback therefore stays useful on Forever.

## Forever-only rework (done 2026-09-30)

- FLSR-1: `## Interface: 16001` only, version 2.0.0.
- FLSR-2: `hasJunkApi` is gone; `IsSellAllJunkEnabled()` alone picks native selling or the bag fallback.
- FLSR-3: the bag loop runs to `NUM_TOTAL_EQUIPPED_BAG_SLOTS` directly.
- FLSR-4: `ROLL_METHODS` is a literal set.
- FLSR-5: `## Category: Inventory` replaces `## X-Category: Loot`.
- FLSR-7: the README is Forever only.
- FLSR-8: `1.15.x-backup` was created at `bf6fe44` and pushed.
- Chat output (owner decision 2026-09-30): the shared yellow `[Fast Loot Sell Repair]:` prefix from `YELLOW_FONT_COLOR`, and names and on/off states coloured with `NORMAL_FONT_COLOR`, `GREEN_FONT_COLOR` and `GRAY_FONT_COLOR`. No hex colour codes remain.

Still open:

- FLSR-6 (Low, UNVERIFIED): "repaired for …" prints before the server confirms, and with guild repair on and too little guild withdraw left, every `PLAYER_MONEY` at the vendor retries and reprints. A durability-confirmed version was tried and dropped: a failed guild repair fires no durability event, so it would block the personal-money retry for the rest of the visit. Decide after the in-game check below.

The addon has no UI panel; `/flsr` prints to chat.

Nothing to do:

- Loot logic: descending slot loop, roll threshold, BoP confirm only when solo.
- Settings: defaults merge on `ADDON_LOADED`, and an empty `FastLootSellRepairDB` is safe.
- Events: `PLAYER_MONEY` is registered only while the merchant is open.
- No secure frames, so no taint risk.

## Blockers, issues, challenges

1. Nothing has run in a client.
2. Loot only runs when `LOOT_READY` reports `autoloot` true. That's by design, but untested.

## Next steps

1. Review and push `main` (2.0.0).
2. Run `/console scriptErrors 1` first in game. Decide FLSR-6 after the guild-repair check.

Forever checks:

- [ ] The addon list shows it, not out of date. `/flsr` prints five settings.
- [ ] With auto-loot on, kill a mob solo: every slot is looted before the window shows. With auto-loot off, nothing is looted.
- [ ] Group Loot: items at or above the threshold stay for the roll.
- [ ] `confirmbop` solo: the BoP prompt confirms itself. In a group it still asks.
- [ ] With damaged gear and enough money: repaired, cost printed, repair sound plays. With too little money until the greys sell: the repair follows.
- [ ] Run `/dump C_MerchantFrame.IsSellAllJunkEnabled()`. Greys sell without a popup on either path.
- [ ] `guildrepair` on, in a guild with repair rights: the guild pays. With the guild withdraw limit used up, record what happens (FLSR-6).
