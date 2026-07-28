# AskEva — App Color Theme (memory)

Mobile CRM app (Leads / Companies / Dashboard / Profile / Team). Green-forward,
clean, card-based. Light mode default; a dark-mode toggle exists in the nav drawer.
Use ONLY this palette for AskEva work unless told otherwise.

## Brand green (primary)
| Token | Hex | oklch | Use |
|---|---|---|---|
| brand-300 (lime highlight) | `#85D653` | oklch(0.82 0.18 132) | gradient highlight, glows |
| brand-400 | `#5BCC4A` | oklch(0.78 0.19 138) | hero gradient light end |
| brand-500 (PRIMARY) | `#3CC23F` | oklch(0.74 0.20 142) | buttons, toggles, badges, active states |
| brand-600 | `#2BA84A` | oklch(0.66 0.18 145) | solid avatars, pressed, hero gradient deep end |
| brand-700 (deep) | `#177A36` | oklch(0.52 0.15 147) | headings, links, icon strokes on light |

### Hero / banner gradient
Diagonal grass→lime green (`#2BA84A` → `#5BCC4A` → `#85D653`) overlaid with the
faint angular "circuit/topographic" line texture. Asset: `assets/bg-green.jpg`.
Used on dashboard hero banner, profile header card, and as full-screen background.

## Green tints (surfaces, pills, badges)
| Token | Hex | Use |
|---|---|---|
| tint-50 | `#EAF9E6` | active nav bg, status pills, chat badge, chips |
| tint-100 | `#DCF3D6` | hover/secondary chip bg |
| tint border | `#CDEAC4` | optional pill border |

## Neutrals
| Token | Hex | Use |
|---|---|---|
| canvas / page bg | `#F6F8F5` | app background (faint warm-green-tinted off-white) |
| surface | `#FFFFFF` | cards |
| line / border | `#EEF1EC` | hairline borders, dividers |
| ink (text) | `#15231A` | primary text (near-black, green-tinted) |
| ink-2 | `#4D5D52` | secondary text / body |
| ink-3 | `#8A978D` | muted labels, placeholders, inactive tab icons |

## Accents / semantic (lead status & roles — use sparingly, only where the app does)
| Meaning | Hex |
|---|---|
| New Lead (info) | `#3B82F6` blue |
| Hot | `#F2542D` red-orange |
| Warm | `#F5B829` amber |
| Converted | brand-500 `#3CC23F` |
| Cold | `#5AB6E8` light blue |
| Invalid | `#9AA39C` grey |
| Destructive / Logout | `#EF5350` coral red |

## Type
Clean geometric/grotesque sans (app uses a system-ish sans; we use **Plus Jakarta Sans**).
Headings 700–800 weight, tight tracking. UPPERCASE micro-labels in ink-3 with wide tracking.

## Conventions
- Cards: white, ~20px radius, soft low shadow, 1px `#EEF1EC` border.
- Primary CTA: brand-500→brand-600 gradient, white text, pill/rounded.
- Status/role badges: tint-50 bg + brand-700 text.
- Icons on light: brand-600/700 strokes; on green: white.
- Keep one green accent dominant; avoid rainbow except true semantic statuses.
