# CLAUDE.md

Guidance for Claude (and humans) working in this repository.

## What this is

**Eat Better** — a personal, offline iPhone app that removes the daily "what do I eat?" decision.
It suggests simple recipes from what is at home, helps cook ahead for 2–3 days, builds shopping
lists with approximate prices, and tracks calories / protein / fat / carbs against a daily target
(goal: gain weight and rebuild strength).

Full scope and acceptance tests: [docs/SPEC.md](docs/SPEC.md).

## Read first, every session

1. `docs/PROJECT_STATE.md` — where things are right now.
2. `docs/TASKS.md` — what to do next.
3. `docs/DECISIONS.md` — why things are the way they are. Do not silently contradict a decision;
   propose a new one instead.
4. `Private/CONTEXT.md` — **if it exists locally**: the owner's personal context (body data,
   tastes, notes). Use it, but never copy its contents into tracked files.

At the end of a session update `PROJECT_STATE.md` and `TASKS.md`, and add to `DECISIONS.md`
when something was decided.

## Hard rules

- **No personal data in git.** The repo is public. Body data, private recipes, prices the owner
  entered, food log, signing team ID — all of it stays on the device or in `Private/` (git-ignored).
  Examples in code, tests and docs use neutral numbers (e.g. 70 kg / 180 cm / 25 y).
- **No network.** The app makes no network requests of any kind. No analytics, no CDN, no APIs.
- **Never shame.** UI text never scolds for over- or under-eating.
- **The fridge changes only by user action.** Cooking or logging never untick ingredients.
- **Merge to `main` only when it works.** Each session works on its own branch.

## Layout

```
App/                      SwiftUI app (iOS 18+)
  EatBetterApp.swift      entry point + tab bar
  Features/<Tab>/         one folder per tab: Today, Recipes, Fridge, Plan, Settings
  Persistence/            SwiftData models (personal data) and CatalogStore (recipes/ingredients)
  Shared/                 small view helpers, localized titles
  Resources/*.lproj/      Localizable.strings (en, uk)
Packages/EatBetterCore/   pure-Swift logic, no UI, builds and tests on Linux and macOS
  Sources/EatBetterCore/  models, DailyTargets, RecipeMath, PantryMatcher, ShoppingPlanner
  Sources/.../Resources/  ingredients.json (shared), demo-recipes.json
  Tests/                  Swift Testing suites
Config/                   xcconfig; signing comes from Private/Signing.xcconfig
scripts/                  copy-private-data.sh (Xcode build phase)
docs/                     SPEC, PROJECT_STATE, DECISIONS, TASKS, DATA_FORMAT
Private/                  git-ignored: recipes.json, ingredients.json, Signing.xcconfig, CONTEXT.md
project.yml               XcodeGen definition (the .xcodeproj is generated, not committed)
```

## Commands

```sh
# Logic tests (works on macOS and Linux)
swift test --package-path Packages/EatBetterCore

# Generate the Xcode project (macOS, needs `brew install xcodegen`)
xcodegen generate
open EatBetter.xcodeproj

# Command-line simulator build, same as CI
xcodebuild build -project EatBetter.xcodeproj -scheme EatBetter \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Re-run `xcodegen generate` after adding, moving or deleting files.

## Conventions

- Logic goes in `EatBetterCore` with tests; views stay thin. If a view computes something
  non-trivial, move it to the package.
- Core is Swift 6 language mode; the app target is Swift 5 mode (see DECISIONS D-014).
- All user-facing strings are English keys in code with a Ukrainian translation in
  `App/Resources/uk.lproj/Localizable.strings`. Add the translation in the same change.
  Recipe and ingredient texts use `LocalizedText { en, uk }` in JSON.
- Amounts are grams internally; show household measures (`units`) next to grams.
- Prices are UAH per store pack, approximate (Ukrainian supermarkets). Per-device overrides live in SwiftData.
- Data file formats: [docs/DATA_FORMAT.md](docs/DATA_FORMAT.md).
