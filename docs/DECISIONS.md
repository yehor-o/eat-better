# Decisions

Newest at the bottom. To change a decision, add a new one that supersedes it.

### D-001 Native SwiftUI app, sideloaded with a free Apple ID
Swift/SwiftUI on iPhone, installed from a Mac with Xcode. No App Store. The free account means
the app must be re-signed every 7 days; accepted. Alternatives considered: $99/yr developer
account, PWA (no expiry, but not native).

### D-002 Personal data never enters git
Body data, food log, fridge, price overrides: SwiftData on the device only. Data the owner
prepares on the Mac (own recipes, extra ingredients, signing settings, personal context notes)
lives in `Private/`, which is git-ignored and copied into the app bundle at build time by
`scripts/copy-private-data.sh`. The repo ships only a small neutral demo recipe set.
("Hybrid" option C: even a recipe list reveals what the owner eats.)

### D-003 Logic in a separate Swift package
`Packages/EatBetterCore` is pure Swift (Foundation only), so it builds and tests on Linux
(cloud sessions) and in CI. The app is a thin SwiftUI layer over it.

### D-004 XcodeGen instead of a committed .xcodeproj
`project.yml` is the source of truth; `EatBetter.xcodeproj` is generated and git-ignored.
Readable diffs, no pbxproj merge conflicts, and the project can be authored without Xcode.

### D-005 SwiftData, iOS 18 minimum
SwiftData for on-device storage. Deployment target iOS 18 (owner's phone runs a newer iOS; 18
gives the `Tab` API and a mature SwiftData).

### D-006 Fridge is have / don't have, never auto-modified
Checkboxes only, no quantities. Cooking or logging never unticks anything — having eggs and using
three doesn't mean they're gone. The owner unticks manually when something runs out.

### D-007 Daily targets formula
BMR by Mifflin–St Jeor × activity multiplier (1.2 / 1.375 / 1.55 / 1.725) + 400 kcal for "gain".
Protein 1.8 g/kg, fat 1.0 g/kg, carbs fill the remaining calories. A sensible starting point,
not medical advice.

### D-008 Nutrition computed from ingredients
Each ingredient has nutrition per 100 g; recipe amounts are grams for the whole recipe; per-serving
values are computed. Household measures (egg, tbsp, cup, pack) are shown next to grams.

### D-009 Prices are approximate pack prices, no auto-update
UAH per typical store pack, Ukrainian supermarkets, refreshed manually from time to time. The owner can
override a price on the device. Shopping lists round up to whole packs.

### D-010 Cooked portions keep 7 days by default
The owner's choice; editable in Settings. A recipe may set a shorter `storageDays` (demo recipes
with meat/fish use 3–4 days, the common food-safety guidance for cooked meat in the fridge).

### D-011 No network, no notifications, no shaming
Hard rules from the spec's "reject if" list.

### D-012 Languages
UI in English and Ukrainian. Code, comments, docs and commit messages in English.

### D-013 Branch workflow
Each working session uses its own branch; merge into `main` only when the app builds and works.

### D-014 Swift language modes
Core package: Swift 6 language mode (strict concurrency, verified on Linux). App target: Swift 5
mode, to avoid fighting strict concurrency in SwiftUI/SwiftData code that can only be compiled on
macOS. Revisit once the app is stable.

### D-015 In-app language switch
Settings gets a language picker: Automatic (iPhone language) / English / Українська. The choice
is stored on the device and applies after the app restarts. Extends spec #13, which only
covered switching the iPhone language. iOS's own per-app language setting stays available.

### D-016 Logging food the owner did not cook
Not everything eaten comes from the app's recipes (food from family, cafés, packaged snacks).
Ways to log it, all offline:
- **Typical dishes**: a built-in list of common dishes (borscht, cutlet, varenyky…) with
  nutrition per 100 g and small / medium / large portion sizes.
- **My products**: packaged foods and snacks (yogurt, kefir, bars…) entered once from the label
  (per 100 g + pack weight), then logged in one tap by pack or grams. Stored on device.
- **Paste from Claude**: the owner asks the Claude app on the phone (chat, no API key) to
  estimate a dish from a photo using a saved prompt; Claude answers with a one-line code that the
  app reads from the clipboard. The app itself still makes no network requests (D-011).
- **Outside food into "Ready"**: a container for several days becomes N ready portions with
  estimated nutrition, eaten from Today like home-cooked portions.
- Plain manual kcal / P / F / C entry stays as the fallback.
Claude Code (on the Mac) is used for maintaining the catalogs, not for daily logging.

### D-017 Plan is built around shopping trips
The owner shops 1–2 times a week. The Plan tab covers the days until the next trip: a grid of
days × meals, "Fill" picks recipes (cook-ahead batches cover several slots, protein target,
ingredient reuse, low cost), and every slot can be swapped, locked or marked "outside food"
(nothing to buy). The shopping list holds only what is missing, rounded to packs, with a total,
plus a "check at home" section with needed amounts for ticked items (the fridge has no
quantities, D-006). After shopping, bought items go into the fridge only on the owner's
explicit tap. Supersedes the separate "N days" idea in spec #10; spec #9 cook-ahead stays.

### D-018 Repo lives outside iCloud-synced folders
iCloud Desktop sync adds extended attributes that break `codesign` for build products in the
repo. The local checkout lives in `~/Developer/eat-better`.

### D-019 Save important writes immediately
SwiftData autosave can lag; an app killed right after "Cooked" lost the new portions in testing.
Logging, cooking, plan edits and "put in the fridge" call `ModelContext.saveNow()`, and the app
saves when it leaves the foreground.

### D-020 Occasional dishes are planned only by hand
Recipes may set `"occasional": true` for special dishes (e.g. oven bakes). Auto-fill never
picks them, so the plan stays on the cheap everyday base; the owner picks them in a slot when
wanted ("Special dishes" in the picker). "What should I eat now?" may still offer them when
everything is at home.

### D-021 New recipes go through Claude Code for now
The owner asks in a Claude Code session; the recipe is added to `Private/recipes.json` and the
app is rebuilt (it has to be re-signed weekly anyway). Pasting a recipe from the Claude app on the
phone is a later task (T-020).

