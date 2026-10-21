# Tasks

Status: `[ ]` todo · `[~]` in progress · `[x]` done. Numbers refer to [SPEC.md](SPEC.md) must-haves.

## Next
- [~] T-006 **Run on the iPhone** — signing is set up and a signed device build succeeds. Left:
      connect the iPhone, install, trust the developer profile (steps in PROJECT_STATE.md), then
      import the transfer backup from `Private/` (Settings → Import backup → Replace everything).
- [ ] T-020 Paste a recipe from the Claude app on the phone (recipe code → stored on device,
      merged with `Private/recipes.json`) — D-021.
- [ ] T-021 Check on the iPhone: timer notification with the phone locked, backup export to
      Files / iCloud Drive and import back, EN UI of the new screens.
- [ ] T-022 Refresh `Private/prices.json` now and then (D-025); ideally from the owner's own
      stores once their prices can be read.

## Done
- [x] T-001 Project docs: CLAUDE.md, SPEC, PROJECT_STATE, DECISIONS, TASKS, DATA_FORMAT
- [x] T-002 Core package: models, `DailyTargets`, recipe nutrition + scaling + household amounts,
      `PantryMatcher`, `ShoppingPlanner` — with tests
- [x] T-003 Shared ingredient catalog and demo recipes
- [x] T-004 App skeleton: tabs Today / Recipes / Fridge / Plan / Settings, SwiftData models,
      private-data build phase, EN/UK strings
- [x] T-005 CI: core tests on Linux, simulator build on macOS
- [x] T-007 Store prices for all 33 catalog ingredients in `Private/prices.json` (D-025)
- [x] T-008 Private recipe set: 21 dishes in `Private/recipes.json` (D-020, D-021)
- [x] T-009 Log any food (D-016): typical dishes, My products, paste from Claude, outside food
      as ready portions, manual numbers — spec #11
- [x] T-010 "What should I eat now?" in core + button on Today — spec #7
- [x] T-011 Ingredient card from the Fridge: nutrition, measures, catalog price, own price and
      pack size, back to catalog price — spec #2
- [x] T-012 Cooking mode: one step at a time, large text, ×1/×2/×3, step timers with a local
      notification (D-023), "Cooked" adds servings × scale portions — spec #8
- [x] T-013 Plan until the next shopping trip (D-017) — spec #9
- [x] T-014 Plan auto-fill in core: cook-ahead batches, protein, reuse, cost; shopping list with
      packs, total and "check at home" — spec #9, #10
- [x] T-015 Backup export / import with "Replace everything" or "Add to what is here" (D-026) —
      spec #12
- [x] T-016 Localization pass: `scripts/check-localization.py` finds no missing Ukrainian
      strings — spec #13
- [x] T-017 UI nits from the first simulator run
- [x] T-018 In-app language switch (D-015)
- [x] T-023 Recipe: choose how many portions to cook (1–12); ingredients follow it, "Cooked"
      puts that many portions into Ready, cooking mode starts with the same number
- [x] T-024 Save right away after eating, logging, fridge and shopping ticks, My products (D-019)
- [x] T-019 Snack slot in the plan: 1–2 snacks a day from snack recipes and My products (D-024)

## Later
- [ ] Visual design pass
- [ ] Body-weight tracking (weekly)
- [ ] Gamification
- [ ] Claude API integration (purpose TBD)
