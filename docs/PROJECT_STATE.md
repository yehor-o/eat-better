# Project state

_Last updated: 2026-10-21 (language switch, log any food, what to eat, shopping-trip plan)_

## Where we are
Work branch `claude/first-simulator-run` (from `claude/meal-planning-app-4jzc5n`); nothing merged,
`main` does not exist yet. Runs in the simulator; not yet on the iPhone.

- **Core** (`Packages/EatBetterCore`, 35 tests): daily targets, recipe nutrition / scaling /
  household measures, fridge matching, shopping list, plus
  - `Food` + `PortionSize` + bundled `dishes.json` (25 typical dishes) — logging food not cooked
    at home (D-016);
  - `ClaudeFoodCode` — parses `EB1|name|kcal|P|F|C|portions` pasted from the Claude app;
  - `MealSuggester` — "What should I eat now?" (spec #7);
  - `MealPlanner` + `ShoppingSchedule` — plan until the next shopping trip, cook-ahead batches,
    shopping list with "check at home" (D-017).
- **App**:
  - Today: "What should I eat now?" sheet with "Another option"; "Log food" sheet (paste from
    Claude, eat again, My products, typical dishes, basic foods, manual numbers, containers →
    ready portions); identical ready portions grouped "×N".
  - Recipes: detail has "Cooked: N portions to Ready" for multi-serving recipes.
  - Plan: shopping weekdays, days × meals with auto-fill and per-slot menu, day totals,
    shopping list with ticks and "put bought items in the fridge".
  - Settings: language picker (D-015).
  - Important writes call `saveNow()`; the app also saves when leaving the foreground (D-019).
- **Checked in the simulator** (UK UI): language switch, paste from Claude → container →
  portions in Ready, typical dish sizes, My product with pack, suggestion sheet, plan fill,
  shopping list ticks → fridge, "Cooked" → 3 portions survive an immediate app kill.
  Not checked by hand: EN UI of the new screens, editing / deleting My products, "Another
  option" with several suggestions (covered by core tests).

## Next step
1. T-006: install on the iPhone. Xcode → pick the iPhone → Run. Needs: cable, unlock, "Trust",
   Developer Mode on; after the first install trust the developer profile in Settings → General →
   VPN & Device Management. Command line alternative:
   `xcodebuild build -project EatBetter.xcodeproj -scheme EatBetter -destination 'generic/platform=iOS' -allowProvisioningUpdates`
   then `xcrun devicectl device install app --device <id> <DerivedData>/Build/Products/Debug-iphoneos/EatBetter.app`.
2. T-015 backup, then T-008 own recipes.

## Local setup
The repo lives in `~/Developer/eat-better` (D-018). Simulator UI tests from Claude Code: typing
Cyrillic into the simulator does not arrive; put text on the simulator clipboard with
`LANG=en_US.UTF-8 xcrun simctl pbcopy booted` instead.

## Known gaps
- Planned days reach the protein target but only ~1600 kcal with the demo recipes (T-019, T-008).
- No backup yet (T-015) — don't rely on the app's data until it exists.
- Ready portions offered by "What to eat" are matched by title.
