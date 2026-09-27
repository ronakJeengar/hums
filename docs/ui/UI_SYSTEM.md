# Hums Design System Tokens & Specifications

## 1. Color Palette

The Hums color palette is anchored in true deep obsidian black and warm graphite tones with rich sunset amber-tangerine accents and crisp white pill CTAs, directly replicating the reference design language.

### Base / Background
- `background`: `#0A0B0E` — True deep obsidian black canvas (zero blue cast, optimal OLED contrast).
- `surface`: `#14161D` — Warm graphite card and container surface.
- `surfaceElevated`: `#1C1F28` — Secondary elevated layer (modals, bottom sheets, secondary pill buttons).
- `surfaceHighlight`: `#262B37` — Hovered / active surface (chips, active item rows).
- `surfaceSubtle`: `#101217` — Inset containers, recessed text fields, and subtle backdrops.

### Accent & Highlights
- `primary`: `#FF6633` — Vibrant sunset amber-tangerine for active states, play highlights, scrubbers, and badges.
- `primaryLight`: `#FF8555` — Softer sunset glow for ambient highlights.
- `whitePill`: `#FFFFFF` — Crisp high-contrast pure white for primary CTA pill buttons.
- `accentMint`: `#10B981` — Emerald/mint for verified creator tags and success states.
- `accentBlue`: `#38BDF8` — Sky blue for badges and metadata.
- `accentPurple`: `#A855F7` — Soft violet for genres and ambient glows.
- `accentAmber`: `#F59E0B` — Golden amber for featured accents.

### Text & Icons
- `textPrimary`: `#FFFFFF` — Crisp pure white for headings and primary titles.
- `textSecondary`: `#94A3B8` — Slate neutral for subtitles, artists, duration, and secondary metadata.
- `textTertiary`: `#64748B` — Muted hints, disabled states, and timestamps.

### Borders & Dividers
- `border`: `#222631` — Warm graphite border for cards and inputs.
- `borderSubtle`: `rgba(255, 255, 255, 0.10)` — Translucent 1px borders for cards and inputs.
- `borderFocus`: `rgba(255, 102, 51, 0.5)` — Sunset amber focus border for inputs and active selections.
- `divider`: `#1A1D26` — Ultra-thin divider between list items.

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
