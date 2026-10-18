# Hums Web Platform — Design System & Visual Guidelines

## 1. Aesthetic Direction

The Hums design system is tailored for an immersive audio and music streaming platform:
- **Palette:** Obsidian / deep slate base (`#07090e`, `#090a0f`), dark glass cards (`#12141e`), rich purple/indigo accents (`#8b5cf6`, `#6366f1`).
- **Typography:** High-legibility system sans font stack, high-contrast text (`#f8fafc` primary, `#94a3b8` secondary, `#64748b` muted).
- **Surfaces:** Subtle 1px borders (`#1e2235`, `#232738`), soft frosted backdrops (`backdrop-blur-md`), dark mode scrollbars.

---

## 2. Core UI Component Library

All shared components reside in `web/src/components/ui/`:

### 2.1 Buttons (`button.tsx`)
- Variants: `primary` (purple gradient/glow), `secondary` (slate-800 border), `outline` (subtle border), `danger` (rose-600), `ghost`.
- Sizes: `sm` (h-8), `md` (h-9.5), `lg` (h-11), `icon` (h-9 w-9).
- Built-in `isLoading` state displaying an animated spinner and preventing double submissions.

### 2.2 Inputs (`input.tsx`)
- Standardized text, password, and file inputs with icon slots (`icon?: ReactNode`) and error message integration.

### 2.3 Badges (`badge.tsx`)
- Variants: `default`, `success` (emerald), `warning` (amber), `danger` (rose), `info` (sky), `purple`, `outline`.
- `<StatusBadge status={...} />` automatically maps statuses (`READY`, `PENDING`, `FAILED`, `MODERATED`, `SUSPENDED`) to appropriate semantic colors.

### 2.4 Stat Cards (`stat-card.tsx`)
- Structured KPI metric cards with title, formatted count (`formatNumber`), subtitle, icon container, and percentage trend pill.

### 2.5 Data Table (`data-table.tsx`)
- TanStack Table integration featuring column definitions, loading skeletons, responsive horizontal scroll, empty states, and pagination controls.

### 2.6 Modal Dialog (`dialog.tsx`)
- Keyboard-accessible (`Escape` dismiss), backdrop blur overlay, animated entry, customizable header, body, and action footer.
