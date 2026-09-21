# FastLootSellRepair

Instant auto-loot, automatic junk selling and automatic repairs for **WoW Forever 1.60.x** (Interface `16001`).

Three chores, no clicks, no configuration needed. Three Lua files, no libraries.

## What it does

**Instant looting** — loots every slot on `LOOT_READY`, before the loot window has a chance to open. This is the auto-loot behaviour of [SpeedyAutoLoot](https://www.curseforge.com/wow/addons/speedy-autoloot) reduced to its core. Slots the group is rolling on are left alone, so nothing is decided for your party.

**Junk selling** — calls `C_MerchantFrame.SellAllJunkItems()` when you open a vendor, the same API behind Blizzard's own sell-all-junk button, minus the confirmation popup. If the client hides that button, it falls back to selling grey items out of your bags.

**Repairing** — calls `RepairAllItems()` when you open a repair vendor, and reports the cost. Guild bank funds are off by default. Because selling pays out a moment after the vendor opens, a repair you could not afford on arrival is retried once the money lands.

## Install

Drop the `FastLootSellRepair` folder into:

```
World of Warcraft/_classic_beta_/Interface/AddOns/
```

## Commands

`/flsr` lists every setting and its state. `/flsr <name>` toggles one.

| Name | Default | Effect |
| --- | --- | --- |
| `fastloot` | on | Loot instantly instead of waiting for the loot window |
| `confirmbop` | off | Auto-confirm bind-on-pickup prompts while solo |
| `selljunk` | on | Sell grey items when a vendor opens |
| `repairgear` | on | Repair when a repair vendor opens |
| `guildrepair` | off | Pay repairs from guild bank funds when allowed |

Settings are per account (`FastLootSellRepairDB`).

## Compatibility

Written against build 1.60.1 and verified against the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source). Every API it uses was confirmed present in the shipped 1.60.1 client. It has not yet been run in game.

## Licence

MIT
