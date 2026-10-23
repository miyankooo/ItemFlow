# ItemFlow

Loots everything at once, sells your junk and repairs your gear at vendors, buys full stacks with a right-click and marks the cheapest item in your bags.

## Features

- Fast Loot takes every item without showing the loot window. The window only appears when something needs you: a roll, a locked item, full bags or a bind on pickup prompt.
- Spam-clicking or scroll-wheel looting never opens an empty loot window.
- Sell Junk sells every grey item when you open a vendor, through Blizzard's own Sell All Junk.
- Repair Gear repairs everything at a repair vendor, from guild funds if you allow it.
- Buy Max Stack makes a right-click at a vendor buy a full stack instead of one.
- Highlight Cheapest Item makes the stack in your bags worth the least glow, so you see what to sell or destroy first.

## Installation

1. Install it with the CurseForge app under WoW Forever, or copy the `ItemFlow` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Restart the game or type `/reload`.
3. Enable ItemFlow in the AddOns list. Disable SpeedyAutoLoot or any other auto loot addon, because both would handle the same loot window.

## Usage

1. Turn on Auto Loot under Options, Controls, or hold the Auto Loot key while you loot.
2. Open a vendor: junk sells and your gear repairs on their own.
3. Tick Buy Max Stack at the top of the vendor window, then right-click what you want to buy.
4. Open your bags: the orange glow marks your cheapest stack.

## Commands

| Command | Does |
| --- | --- |
| `/itemflow` | Opens the settings |
| `/if` | Short form of `/itemflow` |

## Settings

Open Options, AddOns, ItemFlow. Settings are saved per account.

| Setting | What it does | Default |
| --- | --- | --- |
| Fast Loot | Takes every item at once without showing the loot window | On |
| Confirm Bind on Pickup | Confirms bind on pickup loot for you while you play solo | Off |
| Sell Junk | Sells your grey items when you open a vendor | On |
| Repair Gear | Repairs your gear at a vendor who can repair | On |
| Guild Repair | Pays repairs from guild funds when your guild allows it | Off |
| Buy Max Stack | Right-clicking an item at a vendor buys a full stack | Off |
| Highlight Cheapest Item | Makes the stack worth the least glow in your bags | On |

## Requirements

WoW Forever 1.60.x (Interface `16001`). Auctionator is optional: without it the highlight uses vendor prices only.

## Restrictions

- The cheapest item is the stack worth the least, its price times its count. An item no vendor buys and Auctionator has no price for, such as a quest item, is never marked.
- Buy Max Stack leaves items Blizzard asks you to confirm, such as those paid with other items or costing 150 gold or more, to its usual prompt.
- Buy Max Stack buys what you can afford and what the vendor has in stock, up to one full stack.
- Opening the settings in combat opens them once combat ends.

## Credits

The looting follows SpeedyAutoLoot by Yuyuli.
