# FastLootSellRepair — Memory

Updated 2026-09-25 after the dual-client port (decision: every addon in the folder supports both clients). Verified against Gethe `forever` @ `bd2470a` (1.60.1.70009), Gethe `classic_era` @ `33e177d` (1.15.9.69722) and the matching Ketho dumps. Nothing has run in a client.

## Current state

Instant auto-loot, junk selling and repairs at vendors. `/flsr` toggles five settings. No UI, no libraries.

| Item | State |
|---|---|
| Version | 1.0.0, both clients from one toc, `## Interface: 11509, 16001` |
| Author | `miyanko` |
| Git | Committed and pushed on 2026-09-25: `main` = `origin/main`. No `LICENSE`: removed on purpose on 2026-09-25, from every branch and all history; one gets added later by hand |

There are two per-client branches, both in `Core/Vendor.lua`:

- `hasJunkApi`: `C_MerchantFrame.IsSellAllJunkEnabled` / `GetNumJunkItems` / `SellAllJunkItems` exist only on 1.60. On Era, `C_MerchantFrame` only has `GetBuybackItemID`, so Era always sells greys from the bags.
- `LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS`: the first constant is 1.60 only (`Blizzard_FrameXMLBase/Constants.lua:170`). Era defines only `NUM_BAG_SLOTS` (`Classic/Constants.lua:209`).

Everything else is identical on both clients:

- `LOOT_READY(autoloot)`, `GetLootSlotInfo` (quality 5th, locked 6th)
- `C_PartyInfo.GetLootMethod`, `Enum.LootMethod`
- `C_Container.*` with `hasNoValue` / `isLocked`
- `RepairAllItems`, `SOUNDKIT.ITEM_REPAIR` (Vanilla `SoundKitConstants.lua:82`)

## Blockers, issues, challenges

1. Nothing has run in a client. The installed beta is 69913, the source is 70009, and there's no `_classic_era_` install.
2. Loot only runs when `LOOT_READY` reports `autoloot` true. That's by design, but untested.
3. `guildrepair` does nothing on Era, which has no guild bank: `CanGuildBankRepair` is false there, so the addon pays from personal money.

## Next steps

1. Run `/console scriptErrors 1` first on both clients.

Both clients:

- [ ] The addon list shows it, not out of date. `/flsr` prints five settings.
- [ ] With auto-loot on, kill a mob solo: every slot is looted before the window shows. With auto-loot off, nothing is looted.
- [ ] Group Loot: items at or above the threshold stay for the roll.
- [ ] `confirmbop` solo: the BoP prompt confirms itself. In a group it still asks.
- [ ] With damaged gear and enough money: repaired, cost printed, repair sound plays. With too little money until the greys sell: the repair follows.

Era:

- [ ] A vendor with greys sells them from the bags with no error. This proves `LAST_BAG` and the bag path.

Forever:

- [ ] Run `/dump C_MerchantFrame.IsSellAllJunkEnabled()`. Greys sell without a popup on either path.
- [ ] `guildrepair` on, in a guild with repair rights: the guild pays.
