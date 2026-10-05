# FastLootSellRepair

## Target

- WoW Forever 1.60.x only, `## Interface: 16001`. No client branches, no `WOW_PROJECT_*`, no compat layer.
- `main` holds the Forever version. `1.15.x-backup` stays untouched.
- Verify every API against Gethe `wow-ui-source` and Ketho `BlizzardInterfaceResources`, branch `forever`.

## Rules

- `C_MerchantFrame.IsSellAllJunkEnabled()` alone picks Blizzard's sell-all-junk or the bag fallback. Keep the fallback: the Forever merchant frame offers sell-all-junk only while that call is true.
- Fast loot runs only when `LOOT_READY` or `LOOT_OPENED` reports auto-loot, so the game's auto-loot setting stays in charge.
- Chat lines start with the shared yellow `[Fast Loot Sell Repair]:` prefix from `YELLOW_FONT_COLOR`. Names and on/off states use `NORMAL_FONT_COLOR`, `GREEN_FONT_COLOR` and `GRAY_FONT_COLOR`. No literal `|cff` codes.
- Never add a `LICENSE` file. One gets added by hand.

## Checks

- Run `luac -p` on every Lua file after a change. The repo has no test harness.
- Turn on `/console scriptErrors 1` before testing in game.
