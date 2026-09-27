# Hums Reference Image Mapping

This document maps each visual reference image provided in `mobile/images/` directly to its corresponding screens, components, and UX patterns in Hums.

---

## 1. Reference Artifacts Catalog

| Image File Name | Screen / Domain | Key Visual Features to Replicate |
|---|---|---|
| `WhatsApp Image 2026-09-27 at 17.41.09.jpeg` | **Home, App Preview, Full Player** | - Welcome screen preview with pill action CTAs.<br>- Home header: Notification bell + orange unread dot (left), brand title `hums` (center), circular profile avatar (right).<br>- Hero featured gradient card ("FEATURED", bold headline, subtitle, Play CTA).<br>- "From creators you follow" horizontal carousel with **overlapping circular creator avatar badge in top-left corner of artwork**.<br>- Full player: Ambient glow backdrop, centered artist badge, 24px rounded artwork with depth shadow, title + artist with inline heart, sleek scrubber, 64px circular play/pause button, bottom docked "Up Next: [Track] >" pill drawer. |
| `WhatsApp Image 2026-09-27 at 17.41.09 (1).jpeg` | **Reader / Synchronized Lyrics & Content Detail** | - Curved ambient backdrop header matching content palette.<br>- Hero artwork centered with subtle drop shadow.<br>- Title with category pill chip (e.g. `ACOUSTIC`, `INDIE`).<br>- Expandable narrative description with "...see more" toggle.<br>- Dual action CTAs: Large coral pill ("PLAY NOW" with play icon) + secondary circular action button.<br>- Standardized content list (chapters / tracklist) with index numbers, title, duration, and download indicators.<br>- Synchronized lyrics / reader display with active high-contrast highlight and dimmed preceding/subsequent text. |
| `WhatsApp Image 2026-09-27 at 17.41.09 (2).jpeg` | **Auth & Onboarding Gateway Flow** | - Welcome Gateway: Deep obsidian background, centered branding and product pitch, large white pill CTA ("Get Started"), secondary dark slate pill CTA ("Login").<br>- Onboarding Success Modal: Celebratory badge ("Woo-Hoo!"), clean subtitle, primary action button to enter main experience.<br>- Login Screen: Clean back navigation, high-contrast headline ("Welcome back"), elevated input fields with subtle borders and icon prefixes, password visibility toggle, forgot password link, primary white pill button. |
| `WhatsApp Image 2026-09-27 at 17.41.09 (3).jpeg` | **Signup, Audio Player & Creator Selection Sheet** | - Signup screen with progressive input fields (name, email, password) and clear validation feedback.<br>- Audio Player variant with chapter scrubber and speed toggles.<br>- Reusable Bottom Sheet Modal: Curved top corners (24px radius), centered drag handle indicator, search input, segmented list items with checkmark selection and primary confirm CTA. |
| `WhatsApp Image 2026-09-27 at 17.41.10.jpeg` | **Lyrics / Ebook Reader & Typography Controls** | - Immersive synchronized lyrics viewer with custom font size options, ambient glow, and high-legibility dark mode contrast. |

---

## 2. Component Design Implementations

### A. Overlapping Creator Avatar Badge
- **Location:** Used on creator-recommended cards (e.g., "From creators you follow").
- **Pattern:** The track artwork card has a circular 32px creator avatar positioned at `top: 10, left: 10` with a 2px white/slate border for visual separation.

### B. "Up Next" Bottom Pill Drawer
- **Location:** Full Player bottom bar.
- **Pattern:** A horizontal pill container `Container(height: 48, decoration: BoxDecoration(color: slateColor, borderRadius: BorderRadius.circular(24)))` displaying "Up Next: [Track Title]" with a right chevron icon. Tapping opens the interactive queue bottom sheet.

### C. Hero Featured Card
- **Location:** Top of `HomeScreen`.
- **Pattern:** Gradient background from dark slate to deep coral or violet accent, rounded 20px corners, bold white headline, subtitle, and an embedded white pill "Play Now" button.

### D. Ambient Curved Glow Header
- **Location:** Top of `PlaylistDetailScreen`, `TrackDetailScreen`, and `CreatorProfileScreen`.
- **Pattern:** Custom painter or radial gradient container in the background giving a warm, colored aura behind the hero artwork.
