# Hums Core Reusable UI Components Catalog

All components reside in `mobile/lib/core/widgets/` and strictly adhere to the Hums design tokens.

---

## 1. `HumsButton`
Configurable button supporting multiple variants:
- **`primaryPill`**: White background (`#FFFFFF`), black text (`#0D111A`), pill border radius (`999`), bold typography. Used for major CTAs ("Get Started", "Login", "Play Now").
- **`accentPill`**: Coral background (`#FF7A59`), white text, pill radius. Used for active media playback actions.
- **`secondaryPill`**: Elevated slate background (`#1E2638`), white text, subtle border (`borderSubtle`), pill radius.
- **`outlinePill`**: Transparent background, white or coral 1.5px border, pill radius.
- **`iconCircle`**: Circular action button with surface background and centered icon (used for player controls, header actions).

---

## 2. `HumsCard`
- Elevated container with `AppColors.surface` (`#151B26`), rounded corners (`AppRadii.lg` / `xl`), and a subtle border (`borderSubtle`).
- Supports optional gradient backgrounds (used for Hero featured cards and playlist highlights).
- Includes tap animation feedback (scale or opacity on tap).

---

## 3. `HumsArtwork`
- Clean image container with standardized radii (`AppRadii.md` for tiles, `AppRadii.lg` for cards, `AppRadii.xxl` for full player).
- Subtle drop shadow (`BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 4))`).
- Built-in placeholder fallback with music icon and slate gradient when image URL is null or fails to load.

---

## 4. `HumsCreatorBadgeCard`
- The signature component from the reference home screen: horizontal card with artwork, uppercase category chip below, bold title, and an **overlapping circular creator avatar badge** positioned at the top-left of the artwork with a clean outline.

---

## 5. `HumsSectionHeader`
- Standardized header row: Bold title on the left (`TitleLarge`), optional "View All" or "See more" text button on the right with a subtle arrow.

---

## 6. `HumsChip`
- Compact pill chip with rounded radius (`AppRadii.pill`), subtle border, and optional icon. Used for genres (`ACOUSTIC`, `INDIE`, `POP`), filter categories, and audio tags.

---

## 7. `HumsTrackTile`
- Universal list row for tracks across Home, Search, Liked Songs, History, Downloads, and Playlists.
- Displays:
  - Artwork thumbnail (`48x48` with `AppRadii.sm`).
  - Track title (semi-bold white) + artist name (slate secondary).
  - Explicit / HQ badges where applicable.
  - Duration or status.
  - Action buttons: Quick-like heart toggle, download indicator, and options menu.
  - Active playing indicator: Animated equalizer bar or coral tint when currently playing in `PlayerNotifier`.

---

## 8. `HumsBottomSheet`
- Modal bottom sheet with curved top corners (`AppRadii.xxl` = 24px), centered drag handle pill (`40x4` muted grey), dark surface background (`#151B26`), and structured header/body.

---

## 9. `HumsEmptyState` & `HumsErrorState`
- Polished empty state with thematic illustration/icon, clear heading, supportive description, and primary pill action button.
- Polished error state with retry button and error details.
