# Design

Open `design/prototype.html` in a browser for the clickable prototype (every screen, light and dark, the real parser in the Review paste box). Tokens: `design/tokens.json`.

## Principles, and where they show up

| Principle | In Mari |
|---|---|
| **Deference** | Home has one hero number, *Left to spend*. The currency switch is small and sits beside the rate it depends on. No ripples; pressed things scale to 0.97. |
| **Clarity** | System faces (SF Pro, Roboto): no download, native feel. Every money figure uses tabular figures, so digits never shift. One accent (jacaranda violet); semantic green, amber and terracotta carry state and nothing else. |
| **Depth** | Sheets rise over the screen while the screen behind scales to 0.94 and rounds its corners (`DepthScaler`), so people always know where they are. |
| **Inevitability** | Add is a keypad, not a form. Review shows the original message with the amount highlighted, so the person checks Mari's reading against the source in one glance. |
| **Honest materials** | Native page transitions, Cupertino switches, the platform's own date pickers. Dark mode is its own palette (warm blacks, lifted accent), not an inversion. |
| **Saying no** | Insights is three numbers and one ranked list, not a chart wall. No accounts, no bank linking, no gamification. |
| **The boring details** | Balance roll 520 ms ease-out; currency swap 260 ms, old figure up and out, new one up from below; budget bars amber at 85%, terracotta over 100%, legible at 0%. |

## Why jacaranda

Harare's streets turn violet with jacaranda every October. It is local without leaning on flag colours, and it stays clear of the green and red that already mean income and spending.

## Zimbabwe-specific details

- US$ and ZiG on every screen, each record frozen at its own day's rate.
- Categories people actually use: ZESA tokens, Mukando & savings, Family support, Church & tithe, Mobile money fees (including the 2% IMTT tax), Cash out (a transfer, not spending).
- Fees and IMTT tax found in EcoCash messages can be logged as their own line in one tap.
- Works with no data; the only network call is a daily rate check, and people who pay the street rate can set their own.
