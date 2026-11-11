-- Saves sets with no prescribed load from an AI import as open sets (#109).
--
-- The extraction flow now marks a set such as "3x8 light by feel" with
-- "openLoad": true instead of moving it to the import's notes. This replaces
-- ai_import_exercise_sets from 20261110001658_add_ai_import_accept.sql with one
-- new branch for that marker; everything else is unchanged.
--
-- The marker is explicit on purpose. A set with neither a percentage nor a
-- weightKg is still saved as absolute, so the weight_mode_value constraint
-- refuses an absolute load the client failed to convert, rather than it being
-- saved as "choose load".
--
-- Additive: until the flow deploys, no stored result carries openLoad, and an
-- app that predates this passes the key through untouched.

create or replace function public.ai_import_exercise_sets(p_exercise jsonb)
returns table (
  set_position integer,
  target_reps integer,
  target_reps_max integer,
  weight_mode text,
  percentage numeric,
  percentage_max numeric,
  absolute_weight_kg numeric,
  rpe_min numeric,
  rpe_max numeric,
  basis_exercise_id uuid,
  note text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_set jsonb;
  v_count integer;
  v_next integer := 0;
  v_unreadable text;
begin
  for v_set in
    select s.value
    from jsonb_array_elements(coalesce(p_exercise -> 'sets', '[]'::jsonb))
      with ordinality s(value, n)
    order by s.n
  loop
    v_count := coalesce((v_set ->> 'sets')::integer, 1);
    -- The same bound the extraction flow applies.
    if v_count not between 1 and 50 then
      raise exception 'invalid_input: a set count must be between 1 and 50'
        using errcode = 'P0001';
    end if;

    target_reps := (v_set ->> 'reps')::integer;
    target_reps_max := (v_set ->> 'repsMax')::integer;
    percentage := (v_set ->> 'percent')::numeric;
    percentage_max := (v_set ->> 'percentMax')::numeric;
    rpe_min := (v_set ->> 'rpeMin')::numeric;
    rpe_max := (v_set ->> 'rpeMax')::numeric;
    basis_exercise_id := null;

    if percentage is not null then
      weight_mode := 'percentage';
      absolute_weight_kg := null;
      if jsonb_typeof(v_set -> 'basisExercise') = 'object' then
        basis_exercise_id := public.ai_import_resolve_exercise(
          v_set -> 'basisExercise' ->> 'name',
          v_set -> 'basisExercise' -> 'match'
        );
      end if;
    elsif (v_set ->> 'openLoad')::boolean is true then
      -- No load prescribed: the lifter picks the weight on the day (#66).
      weight_mode := 'open';
      absolute_weight_kg := null;
    else
      -- Left null when absent, for the weight_mode_value constraint to refuse.
      weight_mode := 'absolute';
      absolute_weight_kg := (v_set ->> 'weightKg')::numeric;
    end if;

    select string_agg(u.value, ', ') into v_unreadable
    from jsonb_array_elements_text(coalesce(v_set -> 'unreadable', '[]'::jsonb)) u(value);
    note := nullif(concat_ws(
      '. ',
      nullif(trim(v_set ->> 'note'), ''),
      'Could not read: ' || v_unreadable
    ), '');

    for i in 1..v_count loop
      set_position := v_next;
      v_next := v_next + 1;
      return next;
    end loop;
  end loop;
end;
$$;
