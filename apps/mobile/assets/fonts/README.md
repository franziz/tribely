# Fonts

Tribely uses two type families. **Both are free and open-source**, but they need to be downloaded and placed in this directory before the app builds for the first time.

If the font files are missing the app still runs — Flutter falls back to the system font and surfaces a one-time warning at launch. The aesthetic suffers but nothing breaks.

## Fraunces (display)

A variable serif by Undercase Type. We use the SOFT axis for a friendly hand-cut feel.

- **Source:** https://github.com/undercasetype/Fraunces/raw/main/fonts/variable/
- **Files needed:**
  - `Fraunces-VariableFont_SOFT,WONK,opsz,wght.ttf`
  - `Fraunces-Italic-VariableFont_SOFT,WONK,opsz,wght.ttf`
- **License:** SIL Open Font License 1.1

Download both `.ttf` files and drop them into this directory. Filenames must match the pubspec exactly.

## General Sans (body)

A humanist sans by Indian Type Foundry. Variable weight 400–700.

- **Source:** https://www.fontshare.com/fonts/general-sans
- **Files needed:**
  - `GeneralSans-Variable.ttf`
  - `GeneralSans-VariableItalic.ttf`
- **License:** Fontshare Free License (commercial use allowed)

Click "Download" on Fontshare, accept the license, extract, and copy the two variable files into this directory.

## Why we don't bundle the font files in the repo

- License compliance: redistributing fonts in third-party repos can be ambiguous even when the license technically allows it. Easier to point at the canonical source.
- Smaller git repo: variable fonts are 200–800 KB each. Better to fetch them once at clone time.
- Designers often want to swap them as the brand evolves; keeping them out of git makes that low-friction.

If you'd rather have CI fetch the fonts automatically, a one-line script in `scripts/fetch-fonts.sh` would be the cleanest place — open a PR if you want it.
