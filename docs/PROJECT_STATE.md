# Project state

_Last updated: 2026-10-21_

## Where we are
Skeleton is in place (branch `claude/meal-planning-app-4jzc5n`, not yet merged — `main` does
not exist yet; the first merge creates it).

- **Core logic** (`Packages/EatBetterCore`): models, daily targets, recipe nutrition, scaling,
  household measures, fridge matching ("can cook now" / "missing 1–2" with cost), shopping list
  aggregation. 16 tests passing on Linux (Swift 6.2).
- **Data**: 16 shared ingredients with approximate prices (estimates — to verify, T-007),
  6 demo recipes.
- **App** (`App/`): tab bar; Recipes list grouped by fridge match + detail with nutrition,
  household measures and "log 1 serving"; Fridge checklist; Today with day totals vs targets,
  ready portions and today's log; Settings with profile and targets; Plan is a placeholder.
- **Not yet compiled on a Mac.** The app was written in a Linux cloud session; CI (macOS) is the
  first compile. Expect small fixes in T-006.

## Next step
T-006: owner switches to a local Claude Code session on the Mac, builds and runs on the iPhone.

## Known gaps
- "What should I eat now?" button is a disabled placeholder (T-010).
- No backup yet (T-015) — don't rely on the app's data until it exists.
