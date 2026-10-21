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
