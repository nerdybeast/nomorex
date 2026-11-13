# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(One Flutter codebase ships to iOS, Android and the web with a single shared design language, the Sleek Orange system, rather than Cupertino on iOS and Material on Android. Phone and desktop/web are equally important: logging happens on a phone in the gym, and authoring programs often happens on a larger screen. Below 600px navigation is a bottom bar; from 600px up a sidebar sits beside every page, collapsible to a rail.)

## Users

Anyone involved in a strength sport or strength training. No single persona is primary; the product has to serve all of these:

- **Self-coached athletes** who build their own workouts and multi-week programs, then run and log them.
- **Athletes looking for something to follow**, who find workouts and programs in Community and save or start a private copy.
- **Coaches** who build workouts and programs for athletes to do.
- **Athletes on a coach's program** that arrives as a PDF, sheet or photo, who bring it in through AI import.

Typical sessions: logging sets, reps, RPE and loads on a phone between sets; authoring or reviewing a multi-week program at a desk.

## Product Purpose

A strength-training log and programming tool. Users record personal bests, build workouts and multi-week programs whose sets are an absolute load, a percentage of a 1RM, or an open load, then run them as scheduled, logged sessions. Success is a lifter being able to take any program, from themselves, a coach, a file or the community, and run it day to day without doing the arithmetic or the scheduling by hand.

## Positioning

What a generic gym logger can't truthfully claim:

- **Import any program.** A photo or PDF of a program becomes a reviewable, editable, runnable program or workout through AI import.
- **Programs become scheduled runs.** Starting a multi-week template lays out every session on the calendar as an ordinary workout, and the run is tracked (today's day, upcoming, in progress).
- **Community copies.** Other people's public workouts and programs can be saved or started as private copies with attribution, and are previewed against the viewer's own maxes before committing.

## Operating Context

- Gym floor, mid-session: one hand, short attention, quick logging of what was actually lifted (reps, weight, RPE) against what was prescribed.
- Desk or tablet: authoring programs week by week, day by day; reviewing AI-import results before accepting them.
- Coach-written programs commonly arrive as PDFs, spreadsheets or photos, with notation such as "3×7–9 @ 67–72.5%", "% of Clean & Jerk", "RPE 6–7", "%1RM NA". Reference programs live in `docs/research/`.
- Units: weights stored in kg; each user chooses kg or lb for display.

## Capabilities and Constraints

- Personal bests per lift; 1RM derived from the latest PR (single as-is, 2–10 reps estimated with the user's chosen formula, Brzycki/Epley/Lander) and flagged as estimated wherever it's used.
- Sets: absolute load, %1RM (optionally a range, optionally of a different "basis" lift), or open load ("choose load"). Reps and RPE can be single values or ranges. Logged results (actual reps, weight, RPE) are separate from the prescription.
- Workouts archive (reversible) and hard delete only from the archive. Programs archive, never hard delete.
- Programs: weeks → days → exercises → sets; starting one materializes ordinary workouts.
- Community: public workouts and programs; copies are permanently private and attributed.
- AI import (Anthropic via a Supabase edge function), per-user caps, one-time consent notice, admin off switch.
- Admin area for roles, the AI-import switch and an audit log.
- Tempo/pause modifiers are notes on the base lift, not separate exercises, so PRs stay coherent.
- **Undecided:** whether coaches get a direct coach→athlete relationship (assigning, monitoring). Today a coach shares through Community or by the athlete importing; don't design as if assignment exists.

## Brand Commitments

- Name: **NoMoreX**. Landing tagline in the app: "Track your strength. Own your PRs."
- An existing design system, "Sleek Orange" (v3, light and dark), is implemented in `lib/core/theme/` and documented in the "Sleek Orange Design System" artifact. It is the incumbent visual authority; see CLAUDE.md for its rules.
- Fonts are bundled (Inter, JetBrains Mono); no runtime font fetching.
- Privacy policy at `web/privacy.html`, whose URL is registered with the app stores and must not move.

## Evidence on Hand

- Real reference programs: `docs/research/zt-*.md`.
- Seeded local accounts for demos and testing (`a@a.com`, `b@b.com`).
- No testimonials, user counts, reviews, press or pricing exist. Don't invent them.

## Product Principles

1. **Tap, don't type.** Mid-session the lifter has chalky hands and a minute between sets. Common actions (adjusting reps, load or RPE, logging a set, starting or finishing a session) are a tap or a stepper, never a text field or a shorthand to type out. Typing is the fallback, not the path.
2. **Serve every role in strength training without a mode switch.** Building, finding, importing and running programs are the same objects for a self-coached lifter, a follower and a coach.
3. **Never make the lifter do arithmetic.** Resolve percentages to loads from their own PRs, and say plainly when a number is estimated or can't be resolved, rather than showing zero.
4. **Prescription and result are different things.** What was programmed and what was lifted stay separate and are both visible.
5. **Borrowing is copying.** Anything taken from someone else becomes the user's own private, attributed copy; nothing is shared live.
6. **The user's data stays theirs.** Private by default, explicit consent before AI sees a file, no location data in uploads.

## Accessibility & Inclusion

- Every interactive control needs an accessible name (tooltip or semantics label); buttons aren't nested inside list tiles, so screen readers can reach them.
- Light and dark themes follow the device setting.
