---
name: NoMoreX
description: Sleek Orange v3, a quiet, tap-first strength-training log in light and dark.
colors:
  bg-0-dark: "#121212"
  bg-1-dark: "#171717"
  bg-2-dark: "#1C1C1C"
  bg-3-dark: "#262626"
  border-subtle-dark: "#262626"
  border-default-dark: "#333333"
  border-control-dark: "#6B6B6B"
  fg-1-dark: "#EDEDED"
  fg-2-dark: "#A1A1A1"
  fg-3-dark: "#8F8F8F"
  primary-dark: "#C8470F"
  primary-hover-dark: "#B8420F"
  primary-border-dark: "#DD6A35"
  primary-text-dark: "#F5814A"
  primary-subtle-dark: "rgba(200, 71, 15, 0.16)"
  info-dark: "#6AA6F8"
  danger-dark: "#C93434"
  danger-hover-dark: "#B52E2E"
  danger-text-dark: "#FF7B72"
  danger-subtle-dark: "rgba(255, 123, 114, 0.10)"
  bg-0-light: "#FAFAFA"
  bg-1-light: "#FFFFFF"
  bg-2-light: "#FFFFFF"
  bg-3-light: "#F0F0F0"
  border-subtle-light: "#EBEBEB"
  border-default-light: "#DEDEDE"
  border-control-light: "#8F8F8F"
  fg-1-light: "#171717"
  fg-2-light: "#525252"
  fg-3-light: "#6B6B6B"
  primary-light: "#C2410C"
  primary-hover-light: "#AD3A0B"
  primary-border-light: "#9A3412"
  primary-text-light: "#C2410C"
  primary-subtle-light: "rgba(194, 65, 12, 0.08)"
  info-light: "#1F63D6"
  danger-light: "#C62828"
  danger-hover-light: "#AD2121"
  danger-text-light: "#C62828"
  danger-subtle-light: "rgba(198, 40, 40, 0.06)"
  on-primary: "#FFFFFF"
  on-danger: "#FFFFFF"
typography:
  display:
    fontFamily: "Inter"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: "38px"
    letterSpacing: "-0.64px"
  title-1:
    fontFamily: "Inter"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: "30px"
    letterSpacing: "-0.36px"
  title-2:
    fontFamily: "Inter"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: "24px"
    letterSpacing: "-0.18px"
  title-3:
    fontFamily: "Inter"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: "22px"
    letterSpacing: "-0.07px"
  body:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: "20px"
  body-small:
    fontFamily: "Inter"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: "18px"
  button:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: "20px"
  button-sm:
    fontFamily: "Inter"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: "18px"
  caption:
    fontFamily: "Inter"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: "16px"
  nav:
    fontFamily: "Inter"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: "14px"
  stepper-value:
    fontFamily: "Inter"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: "30px"
    letterSpacing: "-0.24px"
    fontFeature: "tnum"
  stat:
    fontFamily: "Inter"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: "26px"
    letterSpacing: "-0.2px"
    fontFeature: "tnum"
  timer:
    fontFamily: "Inter"
    fontSize: "40px"
    fontWeight: 600
    lineHeight: "48px"
    letterSpacing: "-0.8px"
    fontFeature: "tnum"
  weight:
    fontFamily: "JetBrains Mono"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: "20px"
    fontFeature: "tnum"
  weight-md:
    fontFamily: "JetBrains Mono"
    fontSize: "16px"
    fontWeight: 500
    lineHeight: "22px"
    letterSpacing: "-0.16px"
    fontFeature: "tnum"
  weight-lg:
    fontFamily: "JetBrains Mono"
    fontSize: "20px"
    fontWeight: 500
    lineHeight: "26px"
    letterSpacing: "-0.2px"
    fontFeature: "tnum"
  weight-sm:
    fontFamily: "JetBrains Mono"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: "16px"
    fontFeature: "tnum"
  weight-xs:
    fontFamily: "JetBrains Mono"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: "16px"
    fontFeature: "tnum"
  eyebrow:
    fontFamily: "JetBrains Mono"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: "16px"
    letterSpacing: "0.66px"
rounded:
  sm: "4px"
  md: "6px"
  lg: "10px"
  xl: "14px"
  full: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  2xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "44px"
  button-primary-hover:
    backgroundColor: "{colors.primary-hover-dark}"
  button-secondary:
    backgroundColor: "{colors.bg-2-dark}"
    textColor: "{colors.fg-1-dark}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "44px"
  button-secondary-hover:
    backgroundColor: "{colors.bg-3-dark}"
  button-danger:
    backgroundColor: "{colors.danger-dark}"
    textColor: "{colors.on-danger}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "44px"
  button-outlined:
    backgroundColor: "{colors.bg-2-dark}"
    textColor: "{colors.fg-1-dark}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 12px"
    height: "36px"
  stepper-increment:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    size: "40px"
  stepper-decrement:
    backgroundColor: "{colors.bg-2-dark}"
    textColor: "{colors.fg-1-dark}"
    rounded: "{rounded.md}"
    size: "40px"
  text-field:
    backgroundColor: "{colors.bg-2-dark}"
    textColor: "{colors.fg-1-dark}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px"
  list-group:
    backgroundColor: "{colors.bg-1-dark}"
    rounded: "{rounded.lg}"
  list-row:
    textColor: "{colors.fg-1-dark}"
    padding: "12px 16px"
  list-row-hover:
    backgroundColor: "{colors.bg-3-dark}"
  list-header:
    backgroundColor: "{colors.bg-0-dark}"
    textColor: "{colors.fg-3-dark}"
    typography: "{typography.eyebrow}"
    padding: "8px 12px 8px 16px"
  card:
    backgroundColor: "{colors.bg-1-dark}"
    rounded: "{rounded.lg}"
    padding: "12px 16px"
  dialog:
    backgroundColor: "{colors.bg-2-dark}"
    rounded: "{rounded.xl}"
    padding: "20px"
  badge:
    textColor: "{colors.fg-2-dark}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: "2px 8px"
  fab:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.full}"
    size: "52px"
  app-bar:
    backgroundColor: "{colors.bg-0-dark}"
    textColor: "{colors.fg-1-dark}"
    typography: "{typography.title-3}"
    height: "52px"
  sidebar:
    backgroundColor: "{colors.bg-1-dark}"
    width: "232px"
  sidebar-rail:
    backgroundColor: "{colors.bg-1-dark}"
    width: "76px"
  nav-item-selected:
    backgroundColor: "{colors.bg-3-dark}"
    textColor: "{colors.primary-text-dark}"
    rounded: "{rounded.md}"
---

# Design System: NoMoreX

## Overview

**Creative North Star: "The Chalk Line"**

NoMoreX is used on the gym floor: chalky hands, a minute between sets, the phone propped on a bench, read at arm's length. The Chalk Line is that floor made into an interface. It's plain and sturdy. Gray surfaces separated by hairlines stay out of the way, and one orange mark says what to do next. Every common action is a tap: steppers instead of text fields, a "Log RPE" button instead of a form, one obvious primary button per screen. The same system has to hold up at a desk, where coaches and athletes author multi-week programs on a wider screen, so it scales by layout (bottom bar below 600px, a sidebar above) rather than by changing character.

Inside that, the rule is **quiet chrome, loud data**. Loads, reps, percentages and PRs are what you see first: weights are set in mono so they line up down a list, counts and timers use tabular figures so digits don't jump. Precision shows up in alignment and exact numbers, never in density: when a bigger tap target and one more row on screen compete, the tap target wins.

The world is literal and functional. The gym is in how the app is used, not in how it's decorated: no chalk textures, plates, grit, gradients, glows or glass.

**Key Characteristics:**
- Tap-first: steppers, switches and single-purpose buttons for anything done mid-session; 44px controls, 48px hit areas.
- Neutral gray surfaces in four close steps; 1px hairlines do the separating.
- One accent (orange), on one main action per screen and the current place in the app.
- Small, even Inter type scale; weights in JetBrains Mono; tabular figures on every changing number.
- Flat in flow; only overlays cast a shadow.
- Light and dark themes, following the device.

## Colors

Near-neutral grays with a single toned-down orange and two information hues that are never used as fills except red for destructive actions. Every color comes in a dark and a light value (suffix `-dark` / `-light`); both themes are built from one set of component rules in `lib/core/theme/app_theme.dart` (`NomorexPalette`).

### Primary
- **Chalk-line Orange** (`primary`): fills the one main button on a screen, the FAB, the stepper's + and the switch's on track, always edged in `primary-border`. Labels on it are `on-primary` white in both themes.
- **Pressed Orange** (`primary-hover`): a shade *darker* than the fill, never lighter, so the white label keeps its contrast on hover and press.
- **Orange Ink** (`primary-text`): orange as text: links, snackbar actions, the selected nav icon, today's date in the picker.
- **Orange Wash** (`primary-subtle`): a faint translucent wash behind `primary-text`: the selected unit, a selected segment, today's program day, the header band of a program day's main lift or an editor's exercise card. A band or row tint, never a whole-card fill.

### Secondary
- **Resolved Blue** (`info`): text only. It marks a weight resolved from the viewer's own or an estimated 1RM, e.g. a percentage set on someone else's public workout. The one other use is the plan label on the sidebar's account card ("Free"); a paid plan there will take `primary-text` instead. Never a button, never a fill.

### Tertiary
- **Warning Red** (`danger` / `danger-hover`): destructive button fills only ("Discard", "Delete permanently"); hover darkens.
- **Error Ink** (`danger-text`, with `danger-subtle` wash): validation messages, invalid field outlines, destructive menu items. This is what `ColorScheme.error` carries.

### Neutral
- **Floor** (`bg-0`): page, app bar, bottom nav, and recessed strips inside a container (list headers, dialog footers).
- **Mat** (`bg-1`): cards, list containers, the sidebar.
- **Bench** (`bg-2`): overlays, text-field fills, secondary buttons, icon tiles, the stepper's − button.
- **Raised** (`bg-3`): hover and pressed rows, the selected nav item, snackbars, the switch's off track, disabled fills.
- **Hairline** (`border-subtle`): lines between areas and around cards.
- **Edge** (`border-default`): edges of pressable things and overlays, badges.
- **Control Edge** (`border-control`): field outlines, checkbox and stepper − outlines; 3:1 or better on `bg-0`…`bg-2`.
- **Ink 1 / 2 / 3** (`fg-1`, `fg-2`, `fg-3`): titles and values / body and descriptions / dates, captions, chevrons, inactive nav. All three pass 4.5:1 on every surface, `bg-3` included.

### Named Rules
**The One Mark Rule.** Orange fills appear on one main action per screen plus the current-place indicators (FAB, selected nav icon). Everything else is neutral. If two orange buttons are visible, one of them is the secondary style.

**The Secondary Is Orange Trap Rule.** `ColorScheme.secondary`, `tertiary` and every `*Container` role are pinned to orange so stock Material widgets never fall back to purple or teal. Reaching for `colorScheme.secondary` to get "another color" gets orange. Anything without a stock slot is read from `NomorexTokens.of(context)`.

**The White-on-White Rule.** In light mode `bg-1` and `bg-2` are both white. Never rely on one against the other to separate anything; use a border.

## Typography

**Body Font:** Inter (bundled in `assets/fonts/`, never fetched at runtime)
**Numeric/Label Font:** JetBrains Mono (bundled)

**Character:** Inter carries every word at a small, even scale, with headings set apart by weight and tight tracking rather than size or capitals. JetBrains Mono is reserved for loads and the caps eyebrow labels, so a column of weights reads like a ruled ledger.

### Hierarchy
- **Display** (600, 32/38, −0.64px): rare; the largest heading.
- **Title 1** (600, 24/30, −0.36px): screen-level headings.
- **Title 2** (600, 18/24, −0.18px): dialog titles, section headings.
- **Title 3** (600, 15/22, −0.07px): app-bar titles, card titles.
- **Body** (400, 14/20): all UI text; `body-strong` is 14/500 (list-row titles). **Body small** (400, 13/18, `fg-2`; `NomorexTokens.bodySmall`) for row details, card bodies, empty-state messages and snackbars. It is not `TextTheme.bodySmall`, which is the 12px caption.
- **Button** (500, 14/20); **Button small** (500, 13/18; `NomorexTokens.buttonSmall`) for small in-card buttons and segments.
- **Caption** (400, 12/16): dates, helper text, badges.
- **Nav** (500, 11/14): collapsed-sidebar and bottom-bar labels. Nothing is smaller than 11px.
- **Weight / Weight md / Weight lg** (JetBrains Mono 500, 14 / 16 / 20, tabular): a load inline, in a PR row, on its own. **Weight sm** (12) for a secondary number beside a weight ("e1RM 112.5"); **Weight xs** (11) for unit tags and chart axis labels.
- **Eyebrow** (JetBrains Mono 500, 11/16, 0.66px tracking, upper-cased by the caller): list-group headers ("RECENT PRS"), the ARCHIVED pill.
- **Stepper value / Stat / Timer** (Inter 600, 24 / 20 / 40, tabular): the number in every stepper, counts and durations in summaries, the running workout clock.

### Named Rules
**The Theme Styles Only Rule.** Text takes a `TextTheme` or `NomorexTokens` style, optionally with `copyWith(color: …)`. No `TextStyle(fontSize: …)` at a call site: a new size is a new token.

**The Mono Load Rule.** Every weight renders in a `weight*` mono style, with its unit ("140 kg"), so loads line up down a list. Estimated values end in " (est.)".

**The Steady Digits Rule.** Any number that changes while you look at it (steppers, stats, timers) uses tabular figures, so it never shifts or re-fits.

**The Sentence Case Rule.** Titles, buttons, tabs and app bars are sentence case. Capitals appear only in mono eyebrows, which are a label style, not shouting.

## Layout

A 4px grid with a 2px half-step. List rows pad 12px × 16px; cards pad 16px; dialogs pad 20px (actions 20px sides, 16px bottom). Mobile screens use 16px side gutters and 24px between sections.

Sizes are touch-first: primary, secondary and danger buttons are full width by default at 44px (`control-height-lg`), every control keeps a 48px hit area, stepper buttons are 40px squares beside an 80px value. Outlined and text buttons use 36px (`control-height`). App bar 52px, nav bar 56px, FAB 52px.

Below 600px (`kMobileBreakpoint`) the shell is a bottom app bar with a centered FAB; at 600px and above every signed-in page sits beside a sidebar on `bg-1`, which collapses to a rail. Both carry Home, Programs, Workouts, My PRs and Community, in that order. Phone and desktop are equal citizens: the desktop layout gets more room, not more density. List and detail screens cap their content at 840px (`kContentMaxWidth`), centered, via `contentPadding()` / `shellListPadding()` in `responsive_layout.dart`. The cap is scroll-view padding, not a `ConstrainedBox`, so scrolling still works across the whole window. Forms cap at 520px.

### Named Rules
**The Arm's-Length Rule.** Anything done mid-session must be operable with one thumb at arm's length: 44px controls, 48px hit areas, no target packed tighter to fit another row.

## Elevation & Depth

Flat by default. Depth comes from the four surface steps and hairline borders, not shadows. Every in-flow surface (cards, app bar, buttons, FAB) has elevation 0 and a transparent surface tint. Only overlays (dialogs, bottom sheets, menus, snackbars) cast a shadow, in `overlayShadow`: strong in dark (`rgba(0,0,0,0.55)`), soft in light (`rgba(0,0,0,0.08)`), at Material elevation 8 (menus, snackbars) or 12 (dialogs, sheets).

### Named Rules
**The Floor Stays Flat Rule.** If it scrolls with the page, it has no shadow. Shadows mean "this is above the page."

## Shapes

Gently squared. Small radii keep the hairline look crisp.
- **Small** (4px): checkboxes, the unit toggle, segments.
- **Medium** (6px): buttons, fields, stepper buttons, icon tiles, snackbars, list tiles, tooltips, the selected nav indicator.
- **Large** (10px): cards and list containers.
- **Extra large** (14px): dialogs and bottom-sheet tops.
- **Full**: badges and pills, the switch, the FAB (a true circle with a `primary-border` edge).

Borders are always 1px, except focused fields (1.5px) and checkbox edges (1.5px).

## Components

The stock Material widgets are themed rather than wrapped; custom shared widgets live in `lib/shared/widgets/`.

### Buttons
Sturdy and plain: solid fills with a 1px edge in the fill's own family, no ripple (overlay transparent).
- **Shape:** medium radius (6px), 44px tall, full width unless placed in a `Row`/`Expanded`.
- **Primary** (`FilledButton`): `primary` fill, `primary-border` edge, white 14/500 label. Hover/press: `primary-hover`.
- **Secondary** (`NomorexTokens.secondaryButtonStyle`): same size, `bg-2` fill, `border-default` edge, `fg-1` label; hover `bg-3`. The equal-weight alternate beside a primary ("Pause" beside "Finish", "Cancel").
- **Danger** (`dangerButtonStyle`): same shape in `danger`, for an irreversible action.
- **Outlined / Text:** 36px, `fg-1` label, `bg-3` on hover; outlined adds a `bg-2` fill and `border-default` edge.
- **Disabled:** `bg-3` fill, `fg-3` label, `border-subtle` edge. Prefer an enabled control that explains what's missing.
- **Keyboard focus:** filled buttons and segmented buttons get a 2px `fg-1` edge, which stands out on orange, neutral and red fills in both themes. Rows, tiles, nav items, text, outlined and icon buttons fill with `bg-3`. Checkboxes and switches show a `primary-subtle` halo.

### Number Stepper (signature)
The heart of tap-first logging (`NumberStepperField`). A 40px − button (`bg-2` fill, `border-control` edge), an 80px borderless value in `stepper-value` (24/600 tabular, still typeable), and a 40px + button (`primary` fill, `primary-border` edge), 8px apart. Floored at a sensible minimum; buttons are named "Decrease <label>" / "Increase <label>" for screen readers. Reps, %1RM, weight, sets and RPE all use it; ranges reveal a second "Max" stepper behind a switch.

### List Groups and Rows
Related rows go in one bordered `ListGroup` (`bg-1`, 10px radius, `border-subtle`) with hairline dividers, not a card each. An optional header strip sits on `bg-0` with a mono eyebrow. Rows (`GroupableTile`) pad 12×16 and fill `bg-3` on hover/press; outside a group the same row renders as its own card. Today's row can take a `primary-subtle` fill.

### Summary Card
The row for a workout or program, read top to bottom in priority order:
- a 32px icon tile (`bg-2`, `border-default`, 6px radius, 18px `fg-2` icon);
- the name in title-3 (15/600), the thing the row is scanned for;
- the run state right under it (a running program shows the 8px status dot, orange with a `primary-subtle` halo while in progress and `fg-3` while upcoming, then "In progress · started Nov 1" in caption, state word in `fg-1`);
- an optional `fg-3` caption and badge;
- a 13px `fg-2` description, clamped to two lines;
- the facts chips (weeks, days, workouts) 8px below;
- a `fg-3` chevron or the overflow menu.

The Programs list leaves out the created date: the program screen shows it, and the list is sorted by it. Archived rows mute the title to `fg-2` and swap in the archive icon.

### Program Weeks
A program's screen lists its weeks as collapsible sections. Each heading is "Week 1 · <label>" in title-3 (15/600), so the open week's days carry the weight. Under it sits a caption summary ("6 days · 5 workouts") and an `expand_more` chevron that turns to open. Only the week that matters opens: the week holding today for a running program, otherwise week 1. An "Expand all" / "Collapse all" text button sits above the first week. Each day row names its lifts ("Back squat · Clean · Bench  +3 more", `exercisePreview()`), clamped to two lines, and a live run marks today's day with the `primary-subtle` wash and TODAY pill. A live run also leads with that day as its own row above "View progress", tapping straight into the scheduled workout. An unstarted program says what Start does underneath it ("Schedules 30 workouts from the date you pick."). The description above is `fg-2` and clamps at four lines, with a `primary-text` "Show more".

### Program Day (session brief)
The read-only view of one program day, laid out as a session brief, capped at 640px so reps read straight across to load.
- **Shape first:** three stat tiles (`bg-1`, hairline, 10px radius): lifts, sets and peak intensity, values in `stat` (20/600 tabular). Only the peak is orange (`primary-text`); with no percentage sets it shows the top fixed load instead.
- **Main lift:** a card with a `primary-border` edge. A `primary-subtle` header band holds an orange index, the name in title-2 and the note. The body is `bg-1`.
  - **Headline:** the load range in 28px blue mono, with the unit at 14px `fg-2` beside it. To the right sits "6 × 3 / 70–75% of 80 kg PR".
  - **Set-group ledger:** below, identical consecutive sets collapse to "3 × 3 · 70% · 56 kg", with loads right-aligned on one edge.
  - **No 1RM:** the headline becomes the prescription ("70–75%" in `fg-1`), with "No 1RM yet · set PR" under it.
- **The rest:** a numbered `ListGroup`, with indices in Inter tabular (`fg-3`).
  - **Each row:** a one-line summary ("4 × 3 · 50–70% of Snatch") and the note, clamped to 2 lines, with the load range on the right. Percentage-resolved loads are `info` blue; fixed loads are `fg-1`; open sets read "choose load".
  - **Missing 1RM:** a row links "set <lift> PR", naming the basis lift when it isn't the row's own. When the main lift already offers that link, the row reads "needs <lift> PR" in `fg-3` instead of linking twice.

### Exercise Picker
Adding an exercise to a workout or program day opens one shared picker (`showExercisePickerSheet`): a 92%-height bottom sheet on a phone, a 560px centered panel on wider screens. The search field is pinned under the title and focused on open; results fill the rest, so the keyboard only covers the end of the list.
- **Empty search:** a "RECENT" section (the last 8 distinct lifts used in any workout or program), then "ALL EXERCISES" A–Z, under mono eyebrows. Custom lifts carry a "CUSTOM" pill; lifts already in this workout or day read "Added" in `fg-3` and stay pickable.
- **Typing:** names that start with the query first, then those containing it, with the matched part in `primary-text` 600. Without an exact match, a `primary-subtle` row offers **Create "<name>"** below the matches, which finds or creates the lift by name.
- **Saving:** one tap saves. The row spins until the insert lands, then the sheet closes; a failure keeps it open with a `danger-text` line.

### Add Sets Sheet
"Add sets (%)" and "Add sets (weight)" open one sheet (a bottom sheet on a phone, a 440px panel wider), titled "Add sets · <lift>".
- **Preview first:** a `bg-1` card reads the batch back as a coach writes it, "3 × 8–10 @ 70–75% · RPE 7": count and reps in `fg-1` 20/600, the load in `primary-text` (mono for a fixed weight), RPE in `fg-2`. A percentage batch adds the resolved load in blue mono ("98–105 kg each set") or "No 1RM recorded for this lift".
- **Fields as rows:** "Based on" is a pill picker with the basis 1RM on the right; Sets, Reps, %1RM (or weight with its unit toggle under the label) and RPE are hairline-divided rows with a compact stepper on the right. Reps, %1RM and RPE carry a small mono ONE | RANGE toggle beside the label; a range drops to a second line of two steppers joined by "to". Target RPE starts as an "Add target RPE" link.
- **Footer:** Cancel (secondary) and "Add 3 sets" (primary, twice as wide) on `bg-0`, pinned below the scrolling fields.

### Exercise Editor Card
Each exercise in the workout and program editors is a `bg-1` card whose header band is `primary-subtle`, holding the drag handle, the orange mono position number, the name in title-3 and delete. The body holds the notes field and the set ledger: reps in `fg-2`, the prescription (percentages and "Choose load" in Inter, fixed loads in mono), and, for a percentage set with a 1RM, the resolved load right-aligned in `info` blue mono. "Add sets (%)" and "Add sets (weight)" are compact secondary buttons. A just-added card is scrolled to and edged in `primary-border` for 1.6s before fading back. This is the one place every card carries the band: in an editor, each card is where the work happens.

### Cards / Containers
- **Corner Style:** 10px.
- **Background:** `bg-1`.
- **Shadow Strategy:** none (see Elevation).
- **Border:** 1px `border-subtle`.
- **Internal Padding:** 12px × 16px for rows, 16px for content cards.

### Inputs / Fields
- **Style:** `bg-2` fill, 1px `border-control` outline, 6px radius, 12px padding, 14px text, `fg-3` hint, `fg-2` label.
- **Focus:** outline turns `primary` at 1.5px.
- **Error:** `danger-text` outline and 12px message. **Disabled:** `border-subtle` outline.

### Badges and Toggles
- **Pills** (`CopiedFromBadge`, `ArchivedPill`): full radius, 1px `border-default`, no fill; 12px `fg-2` text with a 14px icon, or a mono eyebrow.
- **Unit toggle:** a 4px-radius bordered track; the selected unit takes `primary-subtle` with `primary-text`, in 11px mono. The track stays small, but each segment's tap area is a full 48px tall, and each segment is a button ("Kilograms" / "Pounds") with a selected state.
- **Segmented button:** `bg-3` track, selected segment `primary-subtle` with `primary-text`, 13/500.
- **Switch:** on = `primary` track with white thumb; off = `bg-3` track, `fg-3` thumb, `border-default` outline.

### Navigation
- **App bar:** `bg-0`, 52px, hairline bottom border, left-aligned 15/600 title, `fg-2` icons, no elevation.
- **Mobile:** bottom app bar on `bg-0` with a centered 52px orange FAB. Any FAB on a shell screen sets its own `heroTag`.
- **Desktop / tablet: the sidebar** (`AppSidebar`), on `bg-1` with a hairline right edge, beside every signed-in page, detail and edit screens included. 232px expanded; 76px collapsed to a rail. Tablets (600–1023px, `kSidebarExpandedBreakpoint`) open collapsed and wider windows open expanded. The toggle beside the wordmark (or `[`) switches it, the choice is saved on the device per side of 1024px, and expanding always pushes the page over rather than covering it. Top to bottom:
  - **Header**, 52px like the app bar: the "NoMoreX" wordmark (title-3, the X in `primary-text`) and the collapse toggle; collapsed, "NX" and the expand toggle.
  - **New**: a secondary-style button, not an orange fill, so each page's own main action stays the one orange fill. It opens a menu: new personal best, workout, program, then "Import from photos or PDFs" while imports are on. `N` opens it. On the rail it opens to the button's right.
  - **Destinations**: 44px rows, 20px icon and 14/500 label. Selected: `bg-3` fill (6px radius), filled `primary-text` icon, `fg-1` label; unselected: `fg-3` icon, `fg-2` label. On the rail the label sits under the icon in the nav style.
  - **Running**: a mono eyebrow, then a row per live session (title, "Session in progress" or "Paused", the clock in `weight-sm`) and per program run ("Today · Week 2", "Starts Nov 20"), each led by the 8px status dot. Empty, it says so in one `fg-3` caption line.
  - **Footer**: Admin (admins only), then the account card: a 36px avatar, the display name or email, and the role pill plus plan label ("Free" in `info`). It opens Profile.
- **Breadcrumbs:** beside the sidebar, detail screens lead their app-bar title with the section in `fg-2` ("Programs › ZT 6 Week Program"), which goes back to the section's list. The back arrow stays, because it returns to wherever the page was opened from. Phones keep the plain title.
- **Phone program editor:** below 600px, editing a program goes one level per screen: the program (a details row, then a card per week listing each day's first two lifts with a "+N" that never truncates), a week (a card per day listing every exercise as "4 × 3 · 20 kg"), then a day (a drag-to-reorder list; tapping an exercise opens it in a bottom sheet with Done pinned under its list). The week and day screens title themselves with the level above in 12px `fg-3` over the name, and a **selector strip** under the app bar switches weeks (W1 W2 …) or days (Day 1 with "6 ex" under it) in place: 36px-tall bordered buttons, the selected one `bg-3` with a `border-control` edge, and a + at the end. Each card and row is announced as a button; ⋯ menus are bottom sheets of actions, the destructive one in `danger-text`.
- **Tabs:** sentence-case 14/500 labels, `fg-1` selected / `fg-2` unselected, a 2px `fg-2` underline (not orange). `ActiveArchivedTabs` uses them on Workouts and Programs.

### Overlays
Dialogs and sheets on `bg-2` with a `border-default` edge and 14px radius (sheets round the top only, with a 36×4 drag handle); menus `bg-2` at 10px; snackbars floating, `bg-3`, 6px radius, `primary-text` action. Tooltips invert: `fg-1` fill, `bg-0` text.

## Do's and Don'ts

### Do:
- **Do** make every mid-session action a tap: a stepper, switch or single-purpose button ("Log reps", "Log RPE", "Log weight"). Typing is the fallback.
- **Do** keep small controls' hit areas at 48px even when they look smaller (the unit toggle, the inline "set PR" link's padded target).
- **Do** keep controls 44px tall with a 48px hit area, and give every icon-only control a tooltip or semantics label.
- **Do** read colors from `NomorexTokens.of(context)` / the theme; add a new token to `NomorexPalette` rather than hardcoding a `Color`.
- **Do** put related rows in one `ListGroup` rather than a card each.
- **Do** render weights in the mono `weight*` styles with their unit, and estimated values with " (est.)".
- **Do** use tabular figures for every number that changes on screen.
- **Do** darken on hover and press (`primary-hover`, `danger-hover`, `bg-3`), never lighten.
- **Do** use Material Icons, outlined at rest (`Icons.*_outlined`), 18–20px, `fg-2` beside text and `fg-3` for chevrons.

### Don't:
- **Don't** put a second orange fill on a screen; use the secondary button.
- **Don't** use `colorScheme.secondary` expecting a second color: it's orange.
- **Don't** use `info` blue for a button or fill, or `primary-subtle` as a whole-card background (a header band or a row tint is fine).
- **Don't** add a shadow to anything in the page flow, or use gradients, glows, glassmorphism or gym-themed textures.
- **Don't** fetch fonts at runtime (`google_fonts`); Inter and JetBrains Mono are bundled.
- **Don't** pack controls tighter on desktop to fit more; wider screens get more room, not more density.
- **Don't** put a separate button inside a `ListTile`'s `trailing`; place it beside the tile in a `Row`.
- **Don't** set text below 11px or use capitals outside mono eyebrows.

### Not yet implemented
The Sleek Orange Design System artifact also specifies the following, which the code doesn't do yet. The code is the source of truth until they ship:
- Material Symbols Outlined at weight 300 (the app uses stock Material Icons).
- The artifact's 2px `primary` focus ring with a 2px `bg-0` gap, and a 3px `primary-subtle` halo on focused fields. The app uses the focus treatment under Buttons instead: Flutter has no ring-with-gap, and a `primary` ring is invisible on a `primary` fill.
- 120–200ms ease-out motion tokens for hover, press and sheets (the app uses Flutter defaults).
