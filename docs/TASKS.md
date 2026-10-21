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

## Next
- [ ] T-006 **First run on the Mac and iPhone** (owner, local session): `brew install xcodegen`,
      create `Private/Signing.xcconfig`, `xcodegen generate`, run on the phone. Fix any compile
      errors the cloud session could not see.
- [ ] T-007 Verify and refresh ingredient prices (stores the owner uses — see Private/CONTEXT.md) and extend the catalog.
- [ ] T-008 Private recipe set: agree on 15–20 dishes with the owner, write `Private/recipes.json`.
- [ ] T-009 Quick manual log entry (kcal/P/F/C) on Today — spec #11.
- [ ] T-010 "What should I eat now?" engine in core + button on Today — spec #7.
- [ ] T-011 Ingredient detail screen with price editing (`PriceOverride`) — spec #2.
- [ ] T-012 Cooking mode: step-by-step, timers, scaling — spec #8.
- [ ] T-013 Cook-ahead plan → shopping list → "cooked" creates ready portions — spec #9.
- [ ] T-014 "What to buy for N days" planner (3 / 7 days) in core + Plan tab — spec #10.
      Idea: greedy pick of recipes that maximise reuse of already-ticked and shared ingredients,
      cover breakfast/lunch/dinner/snack slots with cook-ahead batches, hit the protein target,
      minimise total cost.
- [ ] T-015 Backup export / import (JSON via share sheet / file importer) — spec #12.
- [ ] T-016 Localization pass: every screen in EN and UK — spec #13.

## Later
- [ ] Visual design pass
- [ ] Body-weight tracking (weekly)
- [ ] Gamification
- [ ] Claude API integration (purpose TBD)
