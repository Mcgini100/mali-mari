# Mari — development knowledge base

Compressed record of everything decided and built for Mari, as of 11 Nov 2026 (v3 revamp, PR #1). Read this first; details live in the repo docs it points to.

## 1. What Mari is

- **Mari** (Shona for "money"): an offline-first personal budgeting app for tech-literate Zimbabweans. Tagline: *Money, made clear.*
- **Money reality it's built for:** a dual-currency life (US$ and ZiG, which has traded at about 25–29 ZiG per US$ officially, with a parallel premium of roughly 20%). EcoCash is the main money rail (alongside OneMoney and bank cards), USD cash is still common, and data is expensive or patchy.
- **Design brief:** Jony Ive's principles, made concrete: deference (one hero number), clarity (tabular figures, one brand colour), depth (sheets over a scaled-back screen), inevitability (keypad-first add), honest materials, saying no, and care over the boring details.
- **Retention brief (v2):** keep people coming back without the app feeling like a job or a game, and use colours that are interesting but not polarising.

## 2. Key product decisions

| Decision | Choice | Why |
|---|---|---|
| Data model | Every transaction stores the amount as it happened, plus US$ and ZiG equivalents **frozen at that day's rate** and the rate itself | Past months never shift when the rate moves; budgets convert at today's rate |
| Money type | Integer minor units (cents), never doubles | Correctness |
| Cash-out | A `transfer` category, excluded from spend and income | Moving EcoCash to your pocket isn't spending |
| Storage | Local SQLite only. No account, no server, no analytics | Privacy, offline use, data cost |
| Network | Only the daily official ZiG rate (open.er-api.com, ISO code ZWG), at most every 6 h, plus a manual "use my own rate" override for people who pay the street rate | Offline-first |
| Captured transactions | Always **pending until the person taps Confirm** | Parsing is imperfect; keeps the person in control |
| Languages | English, chiShona, isiNdebele | Audience. sn/nd are a first pass, not yet reviewed by native speakers |
| Retention mechanic | **The month tree** (below). No streaks, points, badges or guilt | Attachment without gamification |

## 3. Reading EcoCash and bank messages (the hard constraint)

- **iOS:** no app can read SMS, iMessage or other apps' notifications, ever. Mari offers paste-in-Review, plus an optional **Shortcuts "Message" automation** that opens `mari://capture?text=…` (guide inside the app).
- **Android:** Google Play reserves `READ_SMS`/`RECEIVE_SMS` for SMS apps, so **Mari never requests them**. It uses an opt-in **NotificationListenerService**. The person ticks which apps (EcoCash `com.ecocash.superapp`/`com.ecocash`, Google Messages, Samsung Messages) and which SMS senders (EcoCash, CBZ, Stanbic, Steward, FBC, NMB, InnBucks, OneMoney, ZB Bank, CABS) to accept. Native Kotlin filters on the spot (capture on → app allowed → sender allowed → text has a currency and a number) and queues matches on-device. Flutter drains the queue on launch, on resume and every 5 s while the app is open.
- **Also on Android:** the share sheet ("Share → Mari") and the deep link.
- **One pipeline:** every route ends in `CaptureService.ingest(text, source)` → parser → de-duplicate (by transaction reference if it has digits, otherwise an FNV-1a fingerprint of the text, within ±3 days) → pending entry. Low-confidence notification results (promotions) are dropped.
- **Play Protect:** sideloaded apps that request notification access are blocked ("app blocked to protect your device"). So CI builds two APKs:
  - **mari-sideload**: a profile build whose manifest overlay (`android/app/src/profile/AndroidManifest.xml`) removes the listener. It installs from a download, and Settings shows "Not in this test build".
  - **mari-full**: everything. Install it with `adb install`, or through a Play Console testing track.
- **For the Play Store:** a notification-listener policy declaration (suggested wording is in `docs/CAPTURE.md`); the Data Safety form says nothing is collected, because everything is processed on-device. Verify the EcoCash package names before launch.

## 4. Parser

- **Templates are data:** `assets/parser/templates.json`, with ordered regex templates using the placeholders `{CUR}` (ZiG/ZWG/USD/US$/$) and `{AMT}`. When no template matches, a generic heuristic runs.
- **Extracts:** amount, currency, direction, counterparty, category (by keyword: ZESA, OK/Spar/Pick n Pay, Chicken Inn, Mukuru, church…), fees (including the 2% IMTT tax, which can be logged as its own line), reference, and a confidence level (high = template matched, medium = heuristic with direction, low = no direction).
- **Two implementations, one set of tests:** `tool/parser_reference.js` (runs in Node and in the prototype) and `lib/capture/message_parser.dart`. Both pass the same 15 cases in `test/fixtures/messages.json`.
- ⚠️ The fixtures are **synthetic**. Real anonymised messages are the biggest open risk.

## 5. Design system v3

- **Palette:** Kariba teal accent (`#11756B` light / `#4FC3B0` dark), msasa amber as the warm second voice (`#D9822B` / `#F0A54C`), mist backgrounds (`#F3F5F2` / `#0C1514`, "Kariba at night"). Money in is teal and over-limit is copper (`#A94032`), which colour-blind people tell apart more easily than green and red. Amber means near the limit (85%+), copper means over.
- **Category tints:** sage, sky, amber, clay, plum, sand, moss and teal, each with ink and wash colours per theme.
- **Type:** system faces (SF Pro / Roboto), with tabular figures everywhere money appears. Scale: display 44, title1 28, title2 22, headline/body 17, callout 15, footnote 13, caption 12 in uppercase.
- **Spacing and shape:** 8pt grid with 20pt gutters. Radii: controls 12, cards 20, sheets 28.
- **Motion:** balance roll 520 ms; sheet rise 380 ms with the screen behind scaled to 0.94; currency swap 260 ms; press scale 0.97; reduced motion respected.
- **Source of truth:** `design/tokens.json`, mirrored in `lib/core/theme/tokens.dart`.
- **v3 accessibility floor (enforced by tests):** every text ink meets WCAG AA (4.5:1) on every ground it sits on. Secondary/tertiary inks are now `#4C5C58` / `#63726D` light and `#A6B8B3` / `#84968F` dark (tertiary was 2.4:1). `warning` fills bars; `warningInk` (`#96600F`) is for text. Anything tappable is at least 48 high (`Space.tapTarget`). System text scaling is honoured up to 1.35×. The month card uses a 28 radius (`Radii.hero`).

## 6. The month tree (v2's core idea)

- **One msasa tree per month,** with its shape seeded only by year and month (a Park–Miller generator): 22 branches, 12 tips, 31 leaf slots.
- **One leaf per day** that has anything logged; a day with nothing logged is a **bud**. Leaf colour shows how the day went against the daily pace (budget ÷ days, or the average spending day if there's no budget):
  - **light** (green, up to 0.5× pace)
  - **steady** (olive, up to 1×)
  - **full** (amber, up to 1.6×)
  - **heavy** (copper, above that)
  - **gold** (more money came in than went out)

  All are real msasa colours, and none of them means failure.
- **Tap a leaf** to open its day sheet: one kind sentence, that day's records, and "Add to this day". When a bud becomes a leaf, the leaf grows in (0 → 1.25 at 0.35 s → 1 at 0.6 s) and a snackbar says "A new leaf for today".
- **Home (v3, number first):** a greeting, then one **month card** read top to bottom: "Left to spend in October" with the US$/ZiG switch, the hero figure, a **pace track** (bar = budget used, tick = where the calendar is; teal on track, amber when more than 8 points ahead of the calendar or at 85%, copper when over), "About US$X a day for the N days left", the rate line, the tree, then "24 leaves · day 27" and a **leaf key** (five leaves; opens a sheet explaining each colour). Everything in the card fits the first screen of a 390 × 844 phone. Below it: today in one line with today's leaf (opens the day), the review queue, the top 3 budgets and the 4 most recent records. This replaces v2's tree-first Home, where the figure and the pace card sat below the fold and a six-item legend was always on screen.
- **Insights:** the month in one sentence, then the **Seasons shelf** (one tree per month, up to 12, newest first; tap one to open that month), then spending against budget, the comparison with the same days last month, and "Where it went".
- **History:** each day's header shows its leaf colour.
- **Rendering:**
  - The prototype draws it in **three.js r186** (Timer loop, an AnimationMixer clip per leaf on `leafN.scale`, damped wind sway of 0.07 rad over 11.4 s, per-leaf flutter, billboarded leaves, raycast taps).
  - The app uses a **Dart port** (`lib/domain/month_tree.dart`), parity-tested against the JS output to 1e-9 (`test/fixtures/tree_2026_10.json`), and drawn with a `CustomPainter` (`lib/features/tree/month_tree_view.dart`). There's no web view, so it's fast and works offline.
  - The ticker is muted on hidden tabs, and with reduced motion the tree is drawn still.

## 7. Architecture (Flutter, about 9k lines of Dart)

- **Stack:** Flutter stable (CI resolved 3.47.8), Riverpod, Drift (SQLite via drift_flutter), http, app_links, share_plus.
- **Layers** (one-way, enforced by `test/architecture_test.dart`): `core` ← `domain` ← `data` / `capture` ← `app` ← `widgets` ← `features`.
  - `lib/core`: tokens and theme, money, dates, the `Clock` type, strings
  - `lib/domain`: pure models, plus `budget_math.dart` (incl. `Pace` / `paceOf`), `month_tree.dart` and `tree_tones.dart`; no packages at all
  - `lib/data`: the Drift database (**schema v2**: categories, entries, budgets, rates, settings; indexes on `entries (status, occurred_at)` and `entries (source_ref)`) and repositories behind interfaces. The only layer that imports Drift
  - `lib/capture`
  - `lib/app`: the composition root. `providers.dart` is one import that re-exports `providers/{time,data,settings,rate,ledger,tree}_providers.dart`; `lifecycle.dart` (`AppLifecycle`) owns capture draining, rate refresh and day rollover
  - `lib/features/*`: home (with its view-model `home_state.dart`), history, budgets, insights, review, entry, onboarding, settings, consent, shell (navigation only), tree
- **Time is injected:** `clockProvider` is the only source of "now"; `todayProvider` rolls over at midnight and on resume. `DateTime.now()` is banned in `lib/` (architecture test), with one marked exception for id generation.
- **Settings** are stored in the same SQLite file, so "Delete all my data" erases everything and re-seeds the default categories. Edits save only the keys that changed, in one batch.
- **Seasons shelf** queries only the 12 months it shows.
- **Startup:** if the database or parser fails to load, `StartupFailure` shows a message and a retry.
- **Strings:** `lib/core/l10n/strings.dart` uses `enum K` with `_en`/`_sn`/`_nd` maps; missing translations fall back to English. v3 added `leftToSpendIn` (all three languages) and eight `leafKey*` keys (English only so far).
- **Tests (88):** domain maths, parser parity, capture pipeline, DB schema and v1→v2 upgrade, layer rules, colour contrast, the Home view-model, day rollover, and `screens_test.dart`, which runs the whole app on a sample month (the same October as the prototype) in light and dark, three languages, and a 360 × 640 phone at the largest text size, saving each screen to `build/screens/`.

## 8. Repo, build, CI

- **Repo:** **github.com/Mcgini100/mali-mari** (public, branch `main`). Commits are authored by Mcgini100 only, with **no AI co-author lines** (the owner's rule).
- **Setup:** `tool/setup.sh` runs `flutter create` for the Android/iOS scaffolding (keeping Mari's files), registers the iOS `mari://` scheme, then runs `pub get` and the Drift `build_runner`.
- **CI** (`.github/workflows/ci.yml`), in order:
  1. JS parser fixtures
  2. setup
  3. `flutter analyze --no-fatal-infos` (warnings fail the build)
  4. `flutter test`
  5. profile and release APKs uploaded as the two artifacts

  When analyze or tests fail, the errors are posted as annotations.
- **Status (27 Oct 2026):** CI is green on `b03eac5`. The owner installed the sideload build on a phone. That first test found a bug: the tab bar filled the whole screen and hid every page (a `Center` in the bar grew to full height). It's fixed, and `test/app_smoke_test.dart` now runs the whole app and checks Home renders with the bar at the bottom.
- **Status (11 Nov 2026):** v3 is on branch `claude/v3-revamp` as **PR #1** (not merged). CI is green on it: analyze clean, 88 tests, both APKs built. CI now also uploads a `mari-screens` artifact with every rendered screen. The v3 work was compiled and checked only through CI (the authoring environment still cannot download the Flutter SDK), so it has **not been run on a phone yet**; installing the sideload build over the existing one is the next real check, and it also exercises the v1 → v2 database upgrade.
- **App icon:** the month tree in mist on Kariba teal, with one amber leaf for today's. `tool/make_icon.js` draws `assets/icon/` (full icon, adaptive foreground, Android 13 themed layer, 512 px Play listing icon), and `flutter_launcher_icons` generates every size during setup.
- **Prototype:** `design/prototype.html` (built by `node tool/build_prototype.js`), published as a private Claude artifact ("Mari Prototype", now v3: number-first Home, leaf key sheet, v3 tokens).

## 9. Open decisions (grilling round 1, not yet answered)

| # | Question | Recommended answer |
|---|---|---|
| Q1 | What v1 is for | Closed beta of about 30 people through a Play Console testing track, then a public Play Store launch |
| Q2 | Platforms | Android only for v1; iPhone later |
| Q3 | Is the tree central? | Yes. v3 removes the need for a "numbers first" switch: Home now shows the figure first and the tree directly under it, in one card. Ask testers whether that is enough |
| Q4 | Parser data | Owner collects 20–30 real anonymised EcoCash and bank messages |
| Q5 | Translations | One Shona and one Ndebele reviewer before the beta; if no Ndebele reviewer is available in time, hide Ndebele |
| Q6 | Default rate | Official rate by default, plus a prompt the first time someone logs ZiG cash |
| Q7 | Name | App is "Mari"; use "malimari" for the package, domain and social handles |

**Questions that depend on these:** the Play declaration and privacy policy, backup and sync, pricing, the testing path for capture, and the evening reminder.

## 10. Backlog

1. Real message fixtures → new templates (blocked on Q4).
2. Native-speaker review of the sn/nd strings and category names (`docs/LOCALISATION.md`).
3. Evening check-in: an optional notification at 19:30, only on days with nothing logged ("Today's leaf is still a bud"). Needs `flutter_local_notifications` and the Android 13 notification permission. It's in the prototype only.
4. Play Console setup: an internal testing track, the listener declaration, a privacy policy and the Data Safety form.
5. ~~A "numbers first" Home option~~ Done differently in v3: the month card puts the figure above the tree for everyone.
6. Season prints: share a finished month's tree as an image.
7. Later: iOS build, optional encrypted backup.

## 11. v3 review scores (11 Nov 2026)

Scored by the same reviewer before and after, against the same criteria. Evidence for "after" is CI (analyze, 88 tests, rendered screens), not a phone.

| Area | v2 | v3 | What moved it | What still holds it back |
|---|---|---|---|---|
| Architecture | 7.4 | 9.0 | Enforced layers, injected clock, split providers, view-model, lifecycle out of the shell, indexed schema with a tested upgrade | Other screens still compute their numbers in `build`; navigation is still ad hoc `Navigator.push`; History loads all records |
| UI / UX | 7.6 | 8.9 | Number-first month card, pace track, leaf key, AA contrast, 48 tap targets, text scaling, labels that fit in all three languages | Only Home, the tab bar and the Budgets header were redesigned; not yet seen on a phone; `leafKey*` strings are English only |
| Overall | 7.5 | 9.0 | | Real EcoCash fixtures and native-speaker review (unchanged risks, section 9) |

## 12. Repo docs to read for detail


`README.md` (setup, test builds) · `docs/ARCHITECTURE.md` · `docs/CAPTURE.md` · `docs/DESIGN.md` · `docs/LOCALISATION.md` · `design/tokens.json`
