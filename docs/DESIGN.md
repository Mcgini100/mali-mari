# Design (v3)

Open `design/prototype.html` in a browser for the clickable prototype: every screen, light and dark, the three.js month tree, and the real parser in the Review paste box. Tokens live in `design/tokens.json` and are mirrored in `lib/core/theme/tokens.dart`.

## Home in v3: the number first, then the tree it grew

v2 put the tree at the top and the figure under it, so on a phone the answer to "how much can I spend?" sat below the fold, the daily pace was cut off by the tab bar, and a six-item legend was on screen every day. v3 makes them one object, the **month card**, read top to bottom:

1. **What is left** ("Left to spend in October"), with the US$ / ZiG switch beside it.
2. **The pace track.** The bar is the budget used; the tick is where the calendar is. Bar short of the tick means spending is behind the month. Teal on track, amber when it runs more than 8 points ahead of the calendar or reaches 85%, copper when the budget is spent.
3. **One sentence**: "About US$29.76 a day for the 5 days left in October", then the rate in use.
4. **The tree**, the same size as before and still tappable leaf by leaf.
5. **The leaf key**: five leaves in the corner. Tap for a sheet that explains each colour once.

Below the card: today in one line with today's leaf (opens the day), the review queue, three budgets, four recent records. Everything in the card is on the first screen of a 390 × 844 phone; `test/screens_test.dart` asserts it.

The same pace track heads the Budgets tab, so the two screens say the same thing the same way.

### Accessibility floor (enforced, not aspired to)

- **Contrast.** Every text ink meets WCAG AA (4.5:1) on every ground it is used on. v2's tertiary ink was 2.4:1 on the background; it carried hints, footnotes and the tab labels. `test/contrast_test.dart` fails the build if a token regresses.
- **Tap targets.** Tabs, header buttons and the leaf key are at least 48 high (`Space.tapTarget`).
- **Text size.** System text scaling is honoured up to 1.35×; the hero figure and tab labels shrink to fit instead of clipping. Tested on a 360 × 640 screen in all three languages.
- **Motion.** Unchanged: reduced motion draws the tree still.

## The idea: your month grows a tree

People keep coming back to things that grow and that are theirs. Mari gives every month a msasa tree.

- **One leaf a day.** Log or confirm anything and that day gets a leaf. A day with nothing logged stays a small bud.
- **Every colour is a good colour.** Leaves take real msasa colours: green for a light day, olive for steady, amber for full, copper for heavy, gold when more came in than went out. Nothing on the tree means "failure", so opening the app never stings.
- **Tap a leaf** to open that day: what was spent, one kind sentence ("Big days happen; the month absorbs them"), and a way to add something forgotten. Adding to a bud turns it into a leaf with the same grow animation.
- **Seasons.** Finished months stay on a shelf in Insights exactly as they grew. Twelve trees later, you can see your year. That shelf is the long-term reason to stay.
- **A number worth checking daily.** "About US$29.76 a day for the 5 days left in October" changes every day, so it's worth a glance each morning. In v3 it sits directly under the hero figure.

### Deliberately left out

Streaks, points, badges, levels, leaderboards, "you missed 3 days" messages, red alarm colours. Those turn a budget into a job or a game. Mari's tree only records; it never scores.

## Palette

| Role | Light | Dark | Why |
|---|---|---|---|
| Kariba teal (brand, every action) | `#11756B` | `#4FC3B0` | A calm lake blue-green that very few people dislike. Trustworthy for money without corporate-bank blue. |
| Msasa amber (the warm second voice) | `#D9822B` | `#F0A54C` | Kept for moments worth a smile: the wordmark dot, a full day's leaf. A fill colour, never a text colour. |
| Mist grounds | `#F3F5F2` | `#0C1514` | A soft green-grey instead of stark white or cream. Dark mode is "Kariba at night". |
| Money in / over limit | teal `#0B7460` / copper `#A94032` | `#57C9A0` / `#F08A6E` | Easier to tell apart for colour-blind people than green and red. Both darkened slightly in v3 to reach AA on their soft grounds. |
| Text inks (secondary / tertiary) | `#4C5C58` / `#63726D` | `#A6B8B3` / `#84968F` | v3: 6.4:1 and 4.6:1 on the mist background (were 5.1 and 2.4). |
| Near a limit | fill `#B7791F`, text `#96600F` | `#E9B44C` | The amber that fills a bar is too light to read as text, so text gets its own darker ink. |
| Category tints | sage, sky, amber, clay, plum, sand, moss, teal | lifted versions | Lists feel lively without fighting the brand colour. |

## The tree, technically

- **One generator, two renderers.** `tool/month_tree.js` builds the tree from the year and month with a seeded Park–Miller generator. The prototype renders it in **three.js** (r186): an orthographic camera, Lambert-shaded branches, flat leaves that always face the viewer, an `AnimationMixer` clip per leaf (`leafN.scale`: 0 → 1.25 at 0.35 s → 1 at 0.6 s, `LoopOnce`, clamped), a `THREE.Timer` loop via `renderer.setAnimationLoop`, procedural wind sway and per-leaf flutter, and raycast taps.
- **In the app**, `lib/domain/month_tree.dart` is a line-for-line Dart port, held to the JS output by `test/month_tree_test.dart` (to 1e-9). `lib/features/tree/month_tree_view.dart` draws the same projection with a `CustomPainter`. That gives the same tree, the same wind and the same grow curve, with no web view, so it starts instantly, works offline, and is light on battery on budget phones.
- **Motion respects the person.** With "reduce motion" on, the tree is drawn once, still and fully grown. On hidden tabs the tree's ticker is muted.

## Principles, and where they show up

| Principle | In Mari |
|---|---|
| **Deference** | One card leads Home: the number, then the tree. Everything else sits below, quieter. |
| **Clarity** | System faces, tabular money figures, one brand colour; semantic colours carry state and nothing else. |
| **Depth** | Sheets rise over the screen while it scales back; the tree turns gently in 3D. |
| **Inevitability** | Add is a keypad; saving lands you on a leaf growing in. |
| **Honest materials** | Native transitions and switches; dark mode is its own palette. |
| **Saying no** | No gamification, no chart wall: three numbers, one ranked list, the shelf. |
| **Boring details** | Leaf overshoot of 1.25, sway of 0.07 rad over 11.4 s, flutter on each leaf's own phase, budget bars amber at 85% and copper when over. |

## Next

- **Evening check-in** (shown in the prototype's Settings): one optional local notification at 19:30, only on days with nothing logged, worded as an invitation ("Today's leaf is still a bud"). It needs `flutter_local_notifications` and the Android 13 notification permission, so it's a separate step.
- **Season prints**: export a finished month's tree as an image to share.
