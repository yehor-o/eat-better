# Spec — v1

## Goal
Remove the "what do I eat?" decision: the app suggests simple dishes from what is at home, helps
cook ahead, and shows whether the daily calorie and protein targets for weight gain are met.

## Success
Over 3 weeks of use, the owner picks food through the app in under a minute every day, does at
least one cook-ahead session per week, eats better and feels hungry less often.

## User
One person (the owner), on their own iPhone, offline, several times a day. Installed from a Mac
with Xcode and a free Apple ID (re-signed every 7 days).

## Must have (v1)

| # | Feature | Acceptance test |
|---|---|---|
| 1 | Profile and daily targets, on device only: weight, height, age, sex, activity → kcal (Mifflin–St Jeor × activity + ~400 kcal surplus), protein 1.8 g/kg, fat 1.0 g/kg, carbs the rest | Enter 70 kg / 180 cm / 25 y / male / moderate: targets show ≈3043 kcal and 126 g protein; change weight → targets update |
| 2 | Shared ingredient catalog: nutrition per 100 g, approximate pack price (UAH), household measures | Open an ingredient: nutrition, price and measure are shown; edit the price → the new price is used and stored only on device |
| 3 | Recipes from `Private/recipes.json` (git-ignored), demo set (5–8) as fallback; meal type, grams + household measures, steps, servings, storage days | Build without `Private/` → demo recipes; add `Private/recipes.json`, rebuild → own recipes; `git status` never lists `Private/` |
| 4 | Recipe nutrition computed from ingredient amounts | Per-serving numbers equal a manual sum from the catalog (±1%) |
| 5 | Fridge: have / don't have checkboxes, never changed automatically | Tick eggs, cook an egg dish → eggs stay ticked |
| 6 | Match recipes to the fridge: "can cook now" and "missing 1–2" with what to buy and cost | Tick all but one ingredient of a recipe → it shows under "missing 1" with that ingredient and its price |
| 7 | "What should I eat now?": one suggestion using time of day, fridge, ready portions and remaining protein | At 08:00 with an empty log it suggests breakfast or a ready portion, not dinner; tapping again gives another option |
| 8 | Cooking mode: one step at a time, large text, step timers, portion scaling | Open a recipe ×3 → grams tripled; run a timer → it counts down and alerts |
| 9 | Cook-ahead plan: pick dishes for 2–3 days → one shopping list (only what's missing, with total) → "cooked" adds portions to "Ready" with an eat-by date | 2 dishes × 3 servings → list excludes ticked items and shows a total; after "cooked", 6 portions appear in "Ready" |
| 10 | "What to buy for N days": when the fridge is nearly empty, one tap proposes a shopping list (3 or 7 days) that lets the owner cook dishes from their own recipe base, with approximate total | Empty fridge, tap "Buy for 3 days" → list of ingredients with packs and total ₴, plus the dishes it enables, covering 3 days of meals |
| 11 | Food log: from a recipe, from a ready portion, or quick manual entry (kcal/P/F/C); day total vs target | Log a portion + a manual 300 kcal / 10 g protein snack → day total grows by both; one portion leaves "Ready" |
| 12 | Backup: export / import all personal data as a JSON file | Export, delete app, reinstall, import → profile, fridge, prices, log and ready portions are back |
| 13 | UI in English and Ukrainian | Switch iPhone language → every screen translated, no raw keys |
| 14 | Logic in a Swift package with tests; CI builds the app on macOS | `swift test` passes locally and in CI; CI app build is green on `main` |

## Later (not v1)
Polished visual design (separate stage after logic is validated), body-weight tracking,
gamification, Claude API integration.

## Out of scope for v1
App Store distribution; any network request or iCloud sync; push notifications and reminders;
automatic removal of fridge items; store-product / barcode database; detailed visual design.

## Constraints
- Swift, SwiftUI, SwiftData; iPhone; fully offline.
- Free Apple ID: re-sign through Xcode every 7 days.
- Public repo: no personal data in commits; code and docs in English.
- Simple dishes: up to 1 h per meal, up to 2 h per cook-ahead session; stove, oven, microwave, toaster.

## Reject if
- The app makes any network request.
- Personal data (profile, private recipes, log, prices) ends up in a commit.
- Any text scolds or shames about eating too much or too little.
- Fridge ticks change without a user action.
- Choosing what to eat takes more than two taps from the main screen.

## Open risks
- Deleting the app without a fresh backup erases all data.
- If not re-signed in time, the app won't launch until the phone is connected to the Mac.
- Prices go stale (no auto-update by design).
