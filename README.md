# Eat Better

A personal, offline iPhone app that decides what to eat: simple recipes from what's in the fridge,
cook-ahead plans, shopping lists with approximate prices, and a calorie / protein tracker.

Pet project. No accounts, no network, no App Store — built and installed from a Mac with Xcode.
Personal data stays on the device; see [CLAUDE.md](CLAUDE.md) and [docs/](docs).

## Run it

Requirements: a Mac with Xcode, an iPhone, a (free) Apple ID.

```sh
brew install xcodegen
mkdir -p Private
cp Config/Signing.example.xcconfig Private/Signing.xcconfig   # fill in your team id and bundle id
xcodegen generate
open EatBetter.xcodeproj
```

Pick your iPhone as the run destination and press Run. With a free Apple ID, enable Developer Mode
on the phone and trust the developer certificate (Settings → General → VPN & Device Management).
The install expires after 7 days; run again from Xcode to renew (data is kept).

Own recipes: put them in `Private/recipes.json` ([format](docs/DATA_FORMAT.md)) and rebuild.

## Tests

```sh
swift test --package-path Packages/EatBetterCore
```
