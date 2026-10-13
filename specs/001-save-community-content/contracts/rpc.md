# RPC Contracts

Both functions: `language plpgsql`, `security invoker`, `set search_path = public`, single
transaction (any raised exception rolls back every write). Called from Dart via
`Supabase.instance.client.rpc(...)`.

## `copy_workout`

```sql
public.copy_workout(
  p_source_workout_id uuid,
  p_today date,                -- caller's local date; the copy's `date`
  p_start boolean default false
) returns uuid  -- id of the new workout owned by auth.uid()
```

**Behavior**
1. Pre-checks (raise, no writes) — see Errors.
2. Insert the copy (`is_public = false`, `is_copy = true`, attribution snapshot, `date = p_today`,
   `status = 'not_started'`).
3. Copy exercises and sets with exercise-name mapping (research R4).
4. If `p_start`, call `start_workout_session(new_id)`; the row is then `in_progress`.
5. Return the new workout id.

## `copy_program`

```sql
public.copy_program(
  p_source_program_id uuid,
  p_start_date date default null
) returns jsonb  -- {"program_id": uuid, "instance_id": uuid | null}
```

**Behavior**
1. Pre-checks (raise, no writes).
2. Insert the program copy (`is_public = false`, `is_copy = true`, attribution snapshot), then weeks,
   days, exercises, sets — preserving `week_number`, `position`, `day_number`, `is_rest_day`.
3. If `p_start_date` is non-null, call `start_program(new_program_id, p_start_date)` and capture
   the instance id.
4. Return `{program_id, instance_id}`.

## `start_program` (replaced, signature unchanged)

`start_program(p_program_id uuid, p_start_date date) returns uuid` — unchanged contract; each
materialized `workouts` row additionally receives the program's `is_copy`,
`copied_from_user_id`, `copied_from_display_name`, `copied_from_program_id`.

## Errors

Raised with `raise exception ... using errcode = 'P0001', message = '<code>: <detail>'`; the client
matches on the `<code>:` prefix of `PostgrestException.message`.

| Code | When | User-facing message |
|---|---|---|
| `not_authenticated` | `auth.uid()` is null | "Sign in to save this." |
| `not_found` | source missing, private, or deleted (RLS-hidden) | "This is no longer available." |
| `own_content` | source `user_id = auth.uid()` | (not reachable from UI — buttons hidden) |
| `archived` | program source has `is_archived = true` | "This is no longer available." |
| `source_is_copy` | source `is_copy = true` (defensive) | "This is no longer available." |
| any other | unexpected DB error | "Couldn't save. Try again." (with retry) |

## Supporting schema objects

- `CHECK workouts_copy_not_public (not (is_copy and is_public))`, same on `programs`.
- Trigger function `prevent_uncopy()` (`security invoker`), `BEFORE UPDATE` on both tables:
  raises `copy_is_permanent` if `old.is_copy and not new.is_copy`.
- Client maps a `23514` check violation or `copy_is_permanent` on a visibility update to
  "Copies of other people's content can't be shared."
