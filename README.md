# Mari

**Money, made clear.** An offline-first budgeting app for Zimbabwe: US dollars and ZiG side by side, EcoCash and bank alerts turned into transactions you confirm, and a msasa tree that grows a leaf for every day you check in. Finished months stay on a Seasons shelf.

Flutter (Android + iOS) · Drift/SQLite · Riverpod · English, chiShona, isiNdebele

---

## Run it

You need Flutter (stable, 3.27 or newer) and, for Android, a JDK 17.

```bash
./tool/setup.sh          # Android + iOS (iOS needs macOS)
./tool/setup.sh android  # Android only
flutter run
```

`setup.sh` does four things, once:

1. `flutter create .` fills in what Flutter owns (Gradle files, the Xcode project, launcher icons). Mari's own files, including `AndroidManifest.xml` and the Kotlin capture code, are kept.
2. On macOS it registers the `mari://` URL scheme in `ios/Runner/Info.plist` and turns off Flutter's built-in deep-link routing (the `app_links` package handles links).
3. `flutter pub get` and `dart run build_runner build` to generate `lib/data/db/database.g.dart`.
4. `dart run flutter_launcher_icons` to replace Flutter's logo with Mari's icon (`assets/icon/`, drawn by `tool/make_icon.js`; `play-store-512.png` is the Play Console listing icon).

Commit the generated `android/` and `ios/` folders afterwards so the project builds without the script.

### Installing a test build on an Android phone

Every CI run attaches two APKs (Actions → the run → Artifacts):

| Build | What's in it | How to install |
|---|---|---|
| **mari-sideload-apk** | Everything except reading EcoCash/bank notifications | Download and open it on the phone. Play Protect lets it through. |
| **mari-full-apk** | Everything, including alert reading | `adb install mari-full.apk` from a computer, or a Play Console internal-testing track |

Why two: Google Play Protect blocks apps installed from a download if they ask for notification access ("app blocked to protect your device… sensitive data"), because scam apps use that access to read banking OTPs. Mari only asks for it to read money alerts the person chooses, but Play Protect can't tell the difference for a sideloaded app. Apps from the Play Store with an approved declaration (see docs/CAPTURE.md) aren't blocked. The sideload build leaves the alert reader out via `android/app/src/profile/AndroidManifest.xml`, and Settings explains that the feature isn't in this build.

### Checks

```bash
flutter analyze --no-fatal-infos
flutter test                 # parser fixtures, money, budget maths, DB + capture pipeline, widgets
node tool/test_parser.js     # same fixtures against the JavaScript reference parser
node tool/month_tree.js --fixture   # regenerate the tree parity fixture after changing the generator
```

`.github/workflows/ci.yml` runs all of that on every push and attaches the two test APKs described above.

> **Build status.** This project was written in an environment that could not download the Flutter SDK, so the Dart code has been syntax-checked and the parser logic tested in Node, but it has **not** been compiled. The first CI run (or your first `flutter run`) is the real compile. Expect at most a small fix or two, most likely around a package API version.

---

## What's in the box

| Area | Where |
|---|---|
| Design tokens (single source of truth) | `design/tokens.json` → `lib/core/theme/tokens.dart` |
| Month tree generator (JS reference + Dart port, parity-tested) | `tool/month_tree.js`, `lib/domain/month_tree.dart` |
| Tree painter, day sheet, Seasons | `lib/features/tree/`, `lib/domain/tree_tones.dart`, `lib/features/insights/` |
| Clickable design prototype (three.js tree) | `design/prototype.html` (built from `prototype.src.html` by `node tool/build_prototype.js`) |
| Money in integer minor units, USD ⇄ ZiG | `lib/core/money/money.dart` |
| Database (Drift) and repositories | `lib/data/db/`, `lib/data/repositories/` |
| Budget maths (pure, tested) | `lib/domain/budget_math.dart` |
| Message parser + templates (data, not code) | `lib/capture/message_parser.dart`, `assets/parser/templates.json` |
| Capture pipeline (paste, share, deep link, Android notifications) | `lib/capture/capture_service.dart`, `android/app/src/main/kotlin/zw/mari/mari/` |
| Screens | `lib/features/*` |
| Strings in three languages | `lib/core/l10n/strings.dart` |

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/CAPTURE.md](docs/CAPTURE.md) · [docs/LOCALISATION.md](docs/LOCALISATION.md) · [docs/DESIGN.md](docs/DESIGN.md)

---

## How transactions get in

| | Android | iPhone |
|---|---|---|
| Type it (keypad sheet) | ✓ | ✓ |
| Paste a message in Review | ✓ | ✓ |
| Share a message to Mari | ✓ (share sheet) | — |
| Shortcut / automation deep link `mari://capture?text=…` | ✓ (e.g. Tasker, Automate) | ✓ (Shortcuts "Message" automation) |
| Read EcoCash/bank **notifications** (opt-in) | ✓ | not possible on iOS |

Every captured message becomes a **pending** entry. Nothing counts until the person taps Confirm in Review. Mari never asks for `READ_SMS`; see [docs/CAPTURE.md](docs/CAPTURE.md) for why.

## Adding a bank or a new message format

1. Add a real (anonymised) message to `test/fixtures/messages.json` with what should be extracted.
2. Run `node tool/test_parser.js` and watch it fail.
3. Add or adjust a template in `assets/parser/templates.json` until it passes.
4. `flutter test test/parser_test.dart` runs the same fixtures through the Dart parser.

The templates in this repo were written against synthetic messages modelled on common Zimbabwean alert wording. Replace them with real samples before launch.

## Privacy

All data lives in one SQLite file on the phone. No account, no server, no analytics. The only network call fetches the daily ZiG/USD rate (`open.er-api.com`, swappable in `lib/data/rates/rate_fetcher.dart`). Android backup is off (`allowBackup="false"`), so the CSV export is the way to move data to a new phone. "Delete all my data" in Settings wipes everything.
