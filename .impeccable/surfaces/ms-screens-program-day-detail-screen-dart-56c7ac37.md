---
version: 1
slug: "ms-screens-program-day-detail-screen-dart-56c7ac37"
primary_target: "lib/features/programs/screens/program_day_detail_screen.dart"
related_targets: []
---

# Program day screen

Scope: the read-only view of one program day (`ProgramDayDetailScreen`), reached from a day row on the program screen or a Community program. Visitor mode: Operate.

Audience and job: a lifter (self-coached, following a coach, or browsing Community) who opens a day to judge it and to prep it: what is trained, how hard, and what they will actually lift. Both jobs weigh equally (user confirmed).

Constraints: stays inside Sleek Orange (user chose "push the system", no new accent). Loads resolve from the viewer's own 1RM and render in `info` blue mono; an estimate carries " (est.)"; a percentage with no 1RM offers the Set PR shortcut; open sets read "choose load". Same screen serves another user's public program.

## Direction contract

THESIS: The day opens with its shape and leads with its main lift at full size; it refuses the flat card-per-exercise list of identical text lines.

OWN-WORLD: Sleek Orange dark and light: gray surfaces, hairlines, Inter with JetBrains Mono loads in info blue, one orange-edged hero block with a primary-subtle wash, orange reserved for the main lift's index and the peak-intensity number.

STORY: The lifter sees how big the day is and how heavy it peaks, sees exactly what the main lift asks of them in kilos, then scans the rest in order and taps nothing to get a load.

FIRST VIEWPORT: Title and week line; three stat tiles (lifts, sets, peak %); the first lift as a hero block (index, name, note, load range large in blue mono, set groups as rows: "3 × 3 · 70% · 56 kg"); the remaining lifts as a numbered list with a one-line summary and a right-hand load.

FORM: Session brief, position 4 of 7 on the ordered list; seed:6f8d1a5755604228

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

Unresolved: none.
