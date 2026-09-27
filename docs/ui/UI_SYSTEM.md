# Hums Design System Tokens & Specifications

## 1. Color Palette

The Hums color palette is anchored in deep obsidian and slate tones with warm coral and mint accents, directly derived from the reference images.

### Base / Background
- `background`: `#0D111A` — Primary deep obsidian canvas.
- `surface`: `#151B26` — Elevated card and container background.
- `surfaceLight`: `#1E2638` — Hovered / elevated layer surface (chips, secondary buttons).
- `surfaceSubtle`: `#101520` — Inset containers, text fields, and subtle backdrops.

### Accent & Highlights
- `primary`: `#FFFFFF` — Crisp high-contrast white used for primary action pill buttons.
- `accentCoral`: `#FF7A59` — Warm coral used for play icons, active playback states, hero badges, and primary media actions.
- `accentMint`: `#2DD4BF` — Refreshing mint/teal for creator tags, success indicators, and secondary categories.
- `accentBlue`: `#60A5FA` — Sky blue for badges and metadata.
- `accentPurple`: `#A78BFA` — Lavender for genres, ambient glows, and mood playlists.

### Text & Icons
- `textPrimary`: `#FFFFFF` — Pure white for headings and primary titles.
- `textSecondary`: `#94A3B8` — Slate grey for subtitles, artists, duration, and secondary metadata.
- `textTertiary`: `#64748B` — Muted slate for hints, disabled states, and timestamps.

### Borders & Dividers
- `borderSubtle`: `rgba(255, 255, 255, 0.08)` — Subtle 1px borders for cards and inputs.
- `borderFocus`: `rgba(255, 122, 89, 0.5)` — Coral focus border for inputs and active selections.
- `divider`: `rgba(255, 255, 255, 0.05)` — Ultra-thin divider between list items.

---

## 2. Corner Radii (`AppRadii`)

- `xs`: `4.0` — Small tags, indicators.
- `sm`: `8.0` — Text fields, small chips, dropdown items.
- `md`: `12.0` — Medium chips, list item hover targets.
- `lg`: `16.0` — Mini Player, standard cards, dialogs.
- `xl`: `20.0` — Hero cards, large content containers.
- `xxl`: `24.0` — Full Player artwork, modal bottom sheets.
- `pill`: `999.0` — Buttons, action chips, search bars, "Up Next" drawers.

---

## 3. Spacing Tokens (`AppSpacing`)

- `xxs`: `4.0`
- `xs`: `8.0`
- `sm`: `12.0`
- `md`: `16.0` (Standard page horizontal padding)
- `lg`: `20.0`
- `xl`: `24.0` (Section vertical spacing)
- `xxl`: `32.0`
- `xxxl`: `40.0`

---

## 4. Typography Scale

- **Display Large**: 32px, Bold (w700), letter-spacing: -0.5px (Hero titles, splash heading).
- **Display Medium**: 26px, Bold (w700), letter-spacing: -0.3px (Screen headings, player track title).
- **Title Large**: 20px, Semi-Bold (w600), letter-spacing: -0.2px (Section titles, modal headers).
- **Title Medium**: 16px, Semi-Bold (w600), letter-spacing: 0.0px (Track card titles, item headers).
- **Body Large**: 15px, Regular (w400) / Medium (w500) (Input fields, descriptions).
- **Body Medium**: 13px, Regular (w400) (Artist names, metadata, secondary rows).
- **Label Small**: 11px, Semi-Bold (w600), uppercase, letter-spacing: 0.5px (Genre chips, category tags).
