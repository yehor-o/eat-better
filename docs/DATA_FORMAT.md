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
- Every `ingredient` id must exist in the catalog, otherwise loading fails with an error shown
  on the Recipes tab.
