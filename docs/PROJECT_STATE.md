# Project state

_Last updated: 2026-10-21 (backup, snacks, store prices, price editing, cooking mode)_

## Where we are
`main` holds everything up to the owner's recipes. Today's work is on the branch
`claude/backup-snacks-prices-cooking` (pushed, **not merged** — the owner merges after a look).
Checked in the simulator, not yet run on the iPhone.

- **Core** (`Packages/EatBetterCore`, 47 tests): daily targets, recipe nutrition / scaling /
  household measures, fridge matching, shopping list, `Food`, `ClaudeFoodCode`, `MealSuggester`,
  `MealPlanner` (+ snacks and My products, D-024), `PackPrice` / `Catalog.applying` (D-025),
  `Backup` (file format and "add" merge, D-026).
- **Data**: 33 generic ingredients in the shared catalog; the owner's 21 recipes and store prices
  for all 33 ingredients live in `Private/` (`recipes.json`, `prices.json`) and are bundled at
  build time. `Private/EatBetter-transfer.json` is the file for moving to the iPhone: fridge,
  My products, plan and settings, without profile, food log and ready portions.
- **App**:
  - Today: "What should I eat now?", "Log food", ready portions, day totals.
  - Recipes: detail with "Start cooking" at the top → cooking mode: ×1/×2/×3, one step per page
    in large text, step timers with a local notification (D-023), the screen stays on, "Cooked"
    adds servings × scale portions or "Eat 1 now, the rest to Ready".
  - Fridge: tap a name → ingredient card with nutrition, measures, catalog price and the owner's
    own price / pack (T-011). Rows show pack and price.
  - Plan: breakfast, lunch, snack, dinner (+ a second snack when the day is short); snacks from
    snack recipes or My products; My products on the shopping list by pack (with price if set).
  - Settings: language; Export / Import backup (Replace everything or Add to what is here).
  - My products have an optional pack price.
- **Checked in the simulator (UK UI)**: migration of the old store; store prices applied; own
  price saved with one tap while the keyboard is up, reset to catalog; plan fill with snacks
  (≈2650–2720 kcal against a 2693 target) and My product on the shopping list; cooking mode ×2
  → 6 portions in Ready, fridge unchanged; 4-minute timer → notification on the locked screen;
  export → file in Files; Replace import restores the file exactly; Add import twice → no
  duplicates; the transfer file gives an empty Today / Ready and no profile.
  Not checked by hand: EN UI of the new screens, timer sound (simulator), iCloud Drive.

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
