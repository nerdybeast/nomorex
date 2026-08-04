# Program Support — Future Considerations

**Status:** Living backlog, not a build plan. These are ideas and known gaps that came up while writing `docs/research/program-plan.md` but were deliberately kept out of the initial scope — either because they're genuinely separate features, or because the MVP design choice in the plan explicitly trades away this capability for simplicity. Nothing here is scheduled; this exists so the tradeoffs aren't forgotten or silently re-litigated later.

Each entry cross-references the plan section/decision it came out of.

---

## F1 — Propagating program edits into in-progress instances

**Came from:** `program-plan.md` §12.5 (decided: Option A, no propagation).

Today's decision: editing a program template after it's been started has zero effect on any already-materialized `program_instances` — the copy made at "Start" time is permanent and independent. This is simple and predictable, but has a real gap: if you spot a mistake in Week 4 while actively running the program, there's no way to fix it in your current run without manually editing the affected `workouts` by hand.

Possible future shapes for this, roughly in order of complexity:
- **Warn only.** When editing a program that has active instances, show a non-blocking notice: "N people are currently running this — changes won't affect their in-progress workouts." Cheap, no data model changes, just an informed-consent UI.
- **Propagate to not-yet-reached days only.** If an instance hasn't reached a given `program_day` yet (its materialized `workouts.date` is still in the future relative to today), offer to re-sync just that day's exercises/sets from the current template state. Sidesteps the hard problem of a workout the user has already started customizing or logging against.
- **Full diff/merge.** Track template version per instance, diff old vs. new, offer a merge UI for already-touched workouts. Meaningfully bigger — real versioning system, real conflict resolution. Probably not worth it unless usage shows people editing programs mid-run often.

**Dependency:** requires deciding what "not yet reached" means precisely (workout date vs. workout completion status), and whether a partially-logged workout (some sets completed) should ever be touched by a re-sync. Recommend starting with "warn only" if this gets picked up.

---

## F2 — RPE-based sets and "% of a previous logged session" sets

**Came from:** `program-plan.md` §12.7.

The four research programs (`docs/research/zt-*.md`) use these constructs repeatedly and neither fits today's `weight_mode` (`percentage` | `absolute`), nor the Phase 1 `basis_exercise_id` addition:

- **RPE-based** (e.g. `ZT 6 Week Program` Week 5 Monday: "Front Squat: build to RPE 8," or `ZT 8 Week` Day 6: "Front Squat (RPE 8/2)x4"). There's no stored max to resolve against at all — the lifter picks the weight live, based on how the bar feels. The set's "prescription" is really just target reps + an RPE target, with the actual weight only known after the fact (this already has a natural home: it's exactly what `actual_weight_kg`/`actual_reps` on `workout_sets` capture today, just with no `absolute_weight_kg`/`percentage`/1RM target to show beforehand).
- **"% of last logged session"** (e.g. `ZT - 6 Week Positional` Week 4 Day 1: "Tempo Snatch Deadlift: 90% of last week's 5RM," or `ZT 6 Week Program` Week 2 Monday: "Hang Power Snatch: 3x3 at last week's heavy triple"). This is a percentage of a *specific previous workout's logged result*, not a stored personal best at all — closer to "reference the last time I did this movement" than "reference my all-time max."

Rough shape if this gets built: a third `weight_mode` value (e.g. `'rpe'`) with a new nullable `target_rpe` column; and for the session-relative case, either a `reference_workout_set_id` self-referential-ish column, or a resolver that looks up "the most recent completed set of this same exercise+rep-scheme, most recent workout first." Both are bigger changes than they first look, since `resolveSetWeightKg()` currently assumes every set is resolvable to a number at *plan-authoring* time (percentage × stored 1RM) — RPE and session-relative sets are only resolvable to a number after the fact, or by querying workout history at display time rather than at set-creation time. Needs its own design pass, not a bolt-on.

**Not urgent:** every program can still be transcribed and run without these — they just require the user to manually estimate/type a weight for those specific sets rather than having the app compute one, which is exactly what "absolute" mode already lets them do.

---

## F3 — Community/sharing parity for programs

**Came from:** `program-plan.md` §12.8.

The schema (`programs.is_public` + matching RLS) is already in place in the MVP plan since it's essentially free to include at table-creation time. What's *not* in the MVP plan is any UI for browsing other users' public programs — no `community_programs_provider.dart`, no programs tab in the Community screen, no "start someone else's program" flow.

When this gets picked up, it's a fairly direct mirror of the existing `community_workouts_provider.dart` / `CommunityScreen` pattern: query `programs` where `is_public = true` and `user_id != currentUser`, list them, and let a viewer either browse read-only or (see F4) fork a copy into their own account to actually run it — note a public *program* isn't very useful to "Start" directly unless forking is also built, since starting materializes workouts under `program_instances.user_id`, which should presumably be the runner, not the original author.

---

## F4 — Program versioning / duplication ("fork" a program)

**Came from:** `program-plan.md` §12.9.

No "take a copy of this program (mine or someone else's) and customize it" flow exists in the MVP plan. Two distinct use cases worth separating if this gets built:

- **Forking a public program** (depends on F3 shipping first, or at least being scoped together) — copy someone else's public program into your own `programs` row so you can tweak percentages/exercises without affecting their original.
- **Duplicating your own program** — e.g. you like "ZT 6 Week Program" as a base and want a second copy to build a heavier variant, without touching the original. Doesn't depend on F3 at all — pure convenience feature, and probably the simpler of the two to ship first (no cross-user RLS/attribution questions).

Implementation-wise this is a deep-copy operation across all 5 program tables (`programs` → `program_weeks` → `program_days` → `program_exercises` → `program_sets`), conceptually similar in shape to the "Start Program" materializer in `program-plan.md` §8.3 (walk the tree, insert copies, remap parent ids as you go). Smaller scope than it might sound, though: `WorkoutsNotifier.duplicateWorkout()` (`lib/features/workouts/providers/workouts_provider.dart`) already does exactly this operation, client-side, for a single workout today — a program-level duplicate is the same pattern one level deeper (weeks/days on top of exercises/sets), not a new pattern. §8.3 decided `start_program` will be a Postgres RPC (Option B) rather than a client-side loop, for atomicity and round-trip-count reasons that apply just as much here — follow the same shape for a `duplicate_program(p_program_id uuid)` RPC when this gets built, for consistency between the two "deep copy a program tree" operations.

---

## F5 — Dashboard "current program" surfacing

**Came from:** `program-plan.md` §10.

Once a user has an active `program_instances` row, a dashboard card like "Week 3 of 6 — next up: Thursday" would be a nice orientation aid, especially for longer programs (the `ZT 8 Week` block is 48 sessions — easy to lose your place). This is pure read/derive from `workouts.program_instance_id` + `date`, no new writes, no new tables — genuinely just a dashboard widget once the core feature exists. Lowest-risk, lowest-effort item on this whole list; mainly deferred just to keep the initial build focused on authoring + starting programs rather than dashboard polish.

---

## Adding to this list

When a new "not now, but don't lose this" idea comes up while implementing or using the program feature, add it here as a new `F<n>` entry with: where it came from, what the gap actually is, and a rough shape/size if one's obvious. Doesn't need to be fully designed — the point is capture, not commitment.
