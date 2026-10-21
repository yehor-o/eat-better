# Project state

_Last updated: 2026-10-21 evening (merged into `main`)_

## Where we are
Everything is in `main` (branch `claude/backup-snacks-prices-cooking` merged on the owner's
request, CI green). Checked in the simulator, not yet run on the iPhone (T-006). New work goes
on its own branch from `main`.

- **Core** (`Packages/EatBetterCore`, 48 tests): daily targets, recipe nutrition / scaling /
  household measures, fridge matching, shopping list, `Food`, `ClaudeFoodCode`, `MealSuggester`,
  `MealPlanner` (+ snacks and My products, D-024), `PackPrice` / `Catalog.applying` (D-025),
  `Backup` (file format and "add" merge, D-026).
- **Data**: 35 generic ingredients in the shared catalog; the owner's 41 recipes (each with its own
  storage days, D-029) and store prices for all 35 ingredients live in `Private/` (`recipes.json`, `prices.json`) and are bundled at
  build time. `Private/EatBetter-transfer.json` is the file for moving to the iPhone: fridge,
  My products, plan and settings, without profile, food log and ready portions.
- **App**:
  - Today: "What should I eat now?", "Log food", day totals, "Planned for today" with Ate it /
    Cook (D-027), ready portions.
  - Recipes: detail starts with "Portions: N" (1–12; the ingredient amounts follow it),
    "Start cooking" and "Cooked: N portions to Ready". Cooking mode: same portion count, one step per page
    in large text, step timers with a local notification (D-023), the screen stays on, "Cooked"
    adds servings × scale portions or "Eat 1 now, the rest to Ready".
  - Fridge: search (product or category), filter at home / not at home / category; tap a name →
    ingredient card with nutrition, measures, catalog price and the owner's
    own price / pack (T-011). Rows show pack and price.
  - Plan: breakfast, lunch, snack, dinner (+ a second snack when the day is short); snacks from
    snack recipes or My products; My products on the shopping list by pack (with price if set).
  - Settings: profile numbers typed with the keyboard ("Done" top right); language; Export /
    Import backup (Replace everything or Add to what is here).
  - App icon: bowl with a sprout (`App/Assets.xcassets`, drawn by `scripts/make-app-icon.py`).
  - Cooking timers beep inside the app (D-028) and notify on the locked screen (D-023).
  - My products have an optional pack price.
- **Checked in the simulator (UK UI)**: migration of the old store; store prices applied; own
  price saved with one tap while the keyboard is up, reset to catalog; plan fill with snacks
  (≈2650–2720 kcal against a 2693 target) and My product on the shopping list; cooking mode ×2
  → 6 portions in Ready, fridge unchanged; 4-minute timer → notification on the locked screen;
  export → file in Files; Replace import restores the file exactly; Add import twice → no
  duplicates; the transfer file gives an empty Today / Ready and no profile.
  Later the same day: portion stepper → 3 portions in Ready; "Planned for today" → Cook → Eat now
  marks the meal and logs it, product "Ate it" logs one pack; typed profile numbers are saved
  even when the app is killed right after; fridge search "овоч" and the "not at home" filter;
  the app icon on the home screen; eating and ticks survive an immediate app kill.
  Not checked by hand: EN UI of the new screens, timer sound (simulator has none), iCloud Drive.

## Next step
1. T-006: install on the iPhone (steps below), then Settings → Import backup →
   `EatBetter-transfer.json` (AirDrop it from `Private/` to the phone first) → Replace everything,
   then fill in the profile.
2. T-021 checks on the phone; T-020 recipe paste.

Install: Xcode → pick the iPhone → Run. Needs: cable, unlock, "Trust", Developer Mode on; after
the first install trust the developer profile in Settings → General → VPN & Device Management.
Command line alternative:
`xcodebuild build -project EatBetter.xcodeproj -scheme EatBetter -destination 'generic/platform=iOS' -allowProvisioningUpdates`
then `xcrun devicectl device install app --device <id> <DerivedData>/Build/Products/Debug-iphoneos/EatBetter.app`.

## Local setup
The repo lives in `~/Developer/eat-better` (D-018). Simulator UI tests from Claude Code: typing
Cyrillic into the simulator does not arrive; put text on the simulator clipboard with
`LANG=en_US.UTF-8 xcrun simctl pbcopy booted` instead.

## Known gaps
- Store prices come from two large chains standing in for the owner's own stores (D-025); the
  owner corrects them on the phone where they differ.
- Ready portions offered by "What to eat" are matched by title.
- Number formatting in a few older footers follows the region ("1,962 kcal"), not the UI language.
- Export after reinstalling needs a fresh backup first: export regularly (Settings shows the
  last export date).
- The simulator's own test data was replaced by the transfer file during testing; the earlier
  state is saved in `Private/simulator-store-2026-10-21/` (store files and a full export).
