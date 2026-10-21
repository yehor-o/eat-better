# Data formats

All files are JSON arrays. Texts are `{"en": "...", "uk": "..."}`.

## Ingredients

Shared: `Packages/EatBetterCore/Sources/EatBetterCore/Resources/ingredients.json`.
Extra private ones (optional): `Private/ingredients.json`, same format, appended at load time.

```json
{
  "id": "egg",
  "name": {"en": "Egg", "uk": "Яйце"},
  "category": "dairyEggs",
  "per100g": {"kcal": 143, "protein": 12.6, "fat": 9.5, "carbs": 0.7},
  "packGrams": 500,
  "packPriceUAH": 60,
  "units": [{"name": {"en": "egg", "uk": "яйце"}, "grams": 50}]
}
```

- `category`: `meatFish`, `dairyEggs`, `grains`, `vegetables`, `fruits`, `bakery`, `oilsSpices`,
  `canned`, `other`.
- `per100g`: as weighed in recipes (dry pasta/grains, raw meat).
- `packGrams` / `packPriceUAH`: a typical store pack and its approximate price.
- `units`: household measures shown next to grams; may be empty.

## Recipes

Demo: `Packages/EatBetterCore/Sources/EatBetterCore/Resources/demo-recipes.json`.
Owner's own: `Private/recipes.json` — when present it **replaces** the demo set.

```json
{
  "id": "chicken_buckwheat",
  "name": {"en": "Baked chicken with buckwheat", "uk": "Запечене філе з гречкою"},
  "mealTypes": ["lunch", "dinner"],
  "servings": 3,
  "totalMinutes": 45,
  "storageDays": 4,
  "ingredients": [
    {"ingredient": "chicken_breast", "grams": 600},
    {"ingredient": "salt", "grams": 6, "optional": true}
  ],
  "steps": [
    {"text": {"en": "Bake the chicken.", "uk": "Запікай філе."}, "timerMinutes": 25}
  ]
}
```

- `mealTypes`: any of `breakfast`, `lunch`, `dinner`, `snack`.
- `grams`: for the whole recipe (all servings).
- `optional`: never blocks "can cook now" and is never put on a shopping list.
- `storageDays`: optional; defaults to the app setting (7 days).
- `occasional`: optional, default `false`. A special dish the plan never picks by itself (D-020).
- Every `ingredient` id must exist in the catalog, otherwise loading fails with an error shown
  on the Recipes tab.

## Typical dishes

Shared: `Packages/EatBetterCore/Sources/EatBetterCore/Resources/dishes.json`.
Extra private ones (optional): `Private/dishes.json`, same format, appended at load time — e.g.
dishes the family often brings. Used only for logging food (D-016), never for planning.

```json
{
  "id": "cutlet",
  "name": {"en": "Meat cutlet, fried", "uk": "Котлета м'ясна смажена"},
  "per100g": {"kcal": 230, "protein": 15, "fat": 15, "carbs": 9},
  "units": [{"name": {"en": "cutlet", "uk": "котлета"}, "grams": 90}]
}
```

- `units`: the first one is the default portion (small / medium / large = ×0.7 / ×1 / ×1.4);
  the last one is offered as a counter ("2 × cutlet").
- Values are approximate home-cooking averages.

## Food code from Claude

One food per line; text around it is ignored. Numbers are per portion, decimal comma or dot.

```
EB1|name|kcal|protein g|fat g|carbs g|portions
EB1|Котлети з пюре|650|35|30|55|3
```

`portions` is optional (default 1); more than 1 means a container: one can be eaten now, the
rest go to "Ready in the fridge". The prompt the app copies for Claude is the `claude.prompt`
string in `App/Resources/*.lproj/Localizable.strings`.


## Store prices (private)

Optional: `Private/prices.json`, copied into the app at build time. It replaces the pack size
and price of catalog ingredients (D-025); unknown ids and prices ≤ 0 are ignored. Extra fields
(notes, date checked) are allowed and ignored by the app.

```json
{"ingredient": "buckwheat", "packGrams": 1000, "packPriceUAH": 114, "note": "kernel, 1 kg", "checked": "2026-10-21"}
```

- `packGrams`: optional; `0` or missing keeps the catalog pack.
- Prices the owner enters on the phone (ingredient card in Fridge) override this file.

## Backup file

Settings → Export backup writes one JSON object (not an array). Every section is optional on
import, so a partial file works. Dates are Foundation's default encoding (seconds since
2001-01-01), so they round-trip exactly.

```json
{
  "version": 1,
  "exportedAt": 800000000,
  "profile": {"weightKg": 70, "heightCm": 180, "ageYears": 25, "sex": "male", "activity": "moderate", "goal": "gain", "defaultStorageDays": 7},
  "settings": {"shoppingWeekdays": "2,5", "language": "uk"},
  "fridge": ["egg", "milk"],
  "prices": [{"ingredientID": "egg", "packPriceUAH": 82, "packGrams": 0}],
  "products": [{"id": "my-1", "name": "Yogurt", "per100g": {"kcal": 90, "protein": 5, "fat": 3, "carbs": 10}, "packGrams": 300, "packPriceUAH": 45, "createdAt": 800000000}],
  "readyPortions": [{"recipeID": "r", "title": "Dish", "nutrition": {"kcal": 600, "protein": 40, "fat": 20, "carbs": 60}, "cookedAt": 800000000, "expiresAt": 800600000}],
  "log": [{"date": 800000000, "title": "Toast", "nutrition": {"kcal": 300, "protein": 10, "fat": 10, "carbs": 40}}],
  "plan": [{"day": 800000000, "meal": "snack", "number": 1, "productID": "my-1", "isOutside": false, "isManual": true}],
  "bought": ["milk"]
}
```

- Import asks: **Replace everything** (the app becomes exactly like the file) or **Add to what
  is here** (nothing is removed; the phone's version wins on conflicts; identical log entries and
  portions are not doubled) — D-026.
- A file with a higher `version` than the app knows is refused.
