# Languages

Mari ships in **English**, **chiShona** and **isiNdebele**. All of Mari's own words live in `lib/core/l10n/strings.dart`:

- `enum K` lists every string key.
- `_en`, `_sn`, `_nd` map keys to text. A key missing from Shona or Ndebele falls back to English, so the app never shows a blank.
- Placeholders look like `{amount}` and are filled with `s.f(K.key, {'amount': …})`.
- Month and weekday names are in `_months` and `_weekdays`.
- Category names are stored per language in the database seed (`lib/data/seed/default_categories.dart`).

Date pickers and other built-in Flutter widgets stay in English, because Flutter has no Shona or Ndebele material localisations.

## Needs a native speaker

The Shona and Ndebele text is a careful first pass, **not** reviewed by native speakers. Before release:

1. Have one Shona and one Ndebele speaker read every value in `_sn` and `_nd`, plus the category names. Pay most attention to the consent screen (`consent*` keys), which must be unambiguous.
2. Check the greetings (Mangwanani / Masikati / Manheru; Livukile / Litshonile), the tree words (leaf, bud, Seasons) and the day sentences, which are new in v2.
3. Fill in the keys still falling back to English (Shortcut steps, rate messages, a few short labels). Find them by comparing the three maps.
4. Check that money words sound natural: "of" in "US$120 of US$180" (`K.of`), "Left to spend", "Money in / out".
5. Run the app in each language and look for text that clips in buttons and segmented controls.
