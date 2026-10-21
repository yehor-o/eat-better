# Tasks

Status: `[ ]` todo · `[~]` in progress · `[x]` done. Numbers refer to [SPEC.md](SPEC.md) must-haves.

## Done
- [x] T-001 Project docs: CLAUDE.md, SPEC, PROJECT_STATE, DECISIONS, TASKS, DATA_FORMAT
- [x] T-002 Core package: models, `DailyTargets`, recipe nutrition + scaling + household amounts,
      `PantryMatcher`, `ShoppingPlanner` — with tests
- [x] T-003 Shared ingredient catalog (16 items) and 6 demo recipes
- [x] T-004 App skeleton: tabs Today / Recipes / Fridge / Plan / Settings, SwiftData models,
      private-data build phase, EN/UK strings
- [x] T-005 CI: core tests on Linux, simulator build on macOS
-## Next
- [~] T-006 **Run on the iPhone** — signing is set up and a signed device build succeeds. Left:
      connect the iPhone, install, trust the developer profile (steps in PROJECT_STATE.md).
- [ ] T-015 Backup export / import (JSON via share sheet / file importer) — spec #12. Do this
      before relying on the data on the phone.
- [ ] T-008 Private recipe set: agree on 15–20 dishes with the owner, write `Private/recipes.json`.
      Bigger portions matter: with the demo recipes a planned day is ~1600 kcal.
- [ ] T-019 Plan: count calories too — add a snack slot or scale portions so a planned day
      reaches the kcal target, not only protein.
- [ ] T-007 Verify and refresh ingredient prices (stores the owner uses — see Private/CONTEXT.md)
      and extend the catalog.
- [ ] T-011 Ingredient detail screen with price editing (`PriceOverride`) — spec #2.
- [ ] T-012 Cooking mode: step-by-step, timers, scaling — spec #8.
- [ ] T-016 Localization pass: every screen in EN and UK — spec #13.

glish / Українська) — D-015.
- [ ] T-009 Log any food (D-016): typical dishes with portion sizes, "My products" for packaged
      foods and snacks, "Paste from Claude" code + saved prompt, outside food as ready portions
      (ReadyPortion without a recipe), manual kcal/P/F/C fallback — spec #11.
- [ ] T-010 "What should I eat now?" engine in core + button on Today — spec #7.
- [ ] T-011 Ingredient detail screen with price editing (`PriceOverride`) — spec #2.
- [ ] T-012 Cooking mode: step-by-step, timers, scaling — spec #8.
- [ ] T-013 Plan until the next shopping trip (D-017): shopping days in Settings, days × meals
      grid, swap / lock / "outside food" slots — spec #9.
- [ ] T-014 Plan auto-fill in core (D-017): greedy pick that maximises reuse of ticked and
      shared ingredients, covers slots with cook-ahead batches, hits the protein target,
      minimises cost; shopping list with packs, total and "check at home"; "cooked" creates
      ready portions; "put bought items in the fridge" on explicit tap — spec #9, #10.
- [ ] T-015 Backup export / import (JSON via share sheet / file importer) — spec #12.
- [ ] T-016 Localization pass: every screen in EN and UK — spec #13.
- [x] T-017 UI nits from the first simulator run: servings/days plurals (`inflect`), no double
      brackets in household measures, log confirmation shown in the button, "Can cook now" text
      when the fridge is ticked, timer row layout. Checked in the simulator in EN and UK.

## Later
- [ ] Visual design pass
- [ ] Body-weight tracking (weekly)
- [ ] Gamification
- [ ] Claude API integration (purpose TBD)
