# FastLootSellRepair

Three vendor and looting chores handled for you: instant looting, junk selling and gear repair. No configuration needed.

## Features

- **Instant looting** — loots every slot the moment loot is ready, before the loot window opens. Slots your group is rolling on are left alone.
- **Junk selling** — sells all grey items when you open a vendor, without the confirmation popup.
- **Gear repair** — repairs when you open a repair vendor and reports the cost. A repair you could not afford on arrival is retried once your junk money lands.
- **Optional bind-on-pickup confirm** — auto-confirms BoP prompts while solo.

## Installation

1. Copy the `FastLootSellRepair/` folder into the `Interface/AddOns/` folder of your client: `_classic_era_` for Classic Era, `_classic_beta_` for the WoW Forever beta.
2. Restart the game or `/reload`.
3. Enable **Fast Loot Sell Repair** in the AddOns list.

## Commands

`/flsr` lists every setting and its state. `/flsr <name>` toggles one.

| Name | Default | Effect |
| --- | --- | --- |
| `fastloot` | on | Loot instantly instead of waiting for the loot window |
| `confirmbop` | off | Auto-confirm bind-on-pickup prompts while solo |
| `selljunk` | on | Sell grey items when a vendor opens |
| `repairgear` | on | Repair when a repair vendor opens |
| `guildrepair` | off | Pay repairs from guild bank funds when allowed |

Settings are saved per account.

## Requirements

One folder runs on both clients:

| Client | Interface | Junk selling |
| --- | --- | --- |
| Classic Era 1.15.x | `11509` | Sells grey items from your bags |
| WoW Forever 1.60.x | `16001` | Uses Blizzard's sell-all-junk, bags as fallback |

Written against builds 1.15.9 and 1.60.1 and not yet run in game.

