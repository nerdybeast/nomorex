-- Materializes a program into ordinary logged workouts, in one transaction.
-- Runs server-side (rather than as a client-side loop, cf. duplicateWorkout
-- in workouts_provider.dart) because a full program is large enough
-- (~48 workouts / hundreds of exercises+sets for an 8-week program) that
-- hundreds of sequential client round trips would make "Start Program" a
-- slow, fragile button with no rollback on partial failure.
--
-- SECURITY INVOKER (not DEFINER): this does normal user-scoped writes, so it
-- must stay gated by the same RLS policies a direct client insert would hit,
-- not run with elevated function-owner privileges.
create or replace function public.start_program(
  p_program_id uuid,
  p_start_date date
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_instance_id uuid;
  v_day record;
  v_workout_id uuid;
  v_exercise record;
  v_workout_exercise_id uuid;
  v_set record;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from public.programs p
    where p.id = p_program_id and p.user_id = v_user_id
  ) then
    raise exception 'Program % not found for the current user', p_program_id;
  end if;

  insert into public.program_instances (program_id, user_id, started_at)
  values (p_program_id, v_user_id, p_start_date)
  returning id into v_instance_id;

  -- Every program_day gets a workouts row, including empty rest days — see
  -- program-plan.md Section 12.3. `position` is the day's global,
  -- 0-based order across the whole program and is used as-is for date
  -- math (startDate + position), matching programDayDate() client-side.
  for v_day in
    select pd.*
    from public.program_days pd
    where pd.program_id = p_program_id
    order by pd.position
  loop
    insert into public.workouts (user_id, title, date, program_instance_id, program_day_id)
    values (
      v_user_id,
      v_day.title,
      p_start_date + v_day.position,
      v_instance_id,
      v_day.id
    )
    returning id into v_workout_id;

    if not v_day.is_rest_day then
      for v_exercise in
        select pe.*
        from public.program_exercises pe
        where pe.program_day_id = v_day.id
        order by pe.position
      loop
        insert into public.workout_exercises (workout_id, user_id, exercise_id, position, notes)
        values (v_workout_id, v_user_id, v_exercise.exercise_id, v_exercise.position, v_exercise.notes)
        returning id into v_workout_exercise_id;

        for v_set in
          select ps.*
          from public.program_sets ps
          where ps.program_exercise_id = v_exercise.id
          order by ps.position
        loop
          insert into public.workout_sets (
            workout_exercise_id, user_id, position, target_reps, weight_mode,
            percentage, absolute_weight_kg, basis_exercise_id, note
          ) values (
            v_workout_exercise_id, v_user_id, v_set.position, v_set.target_reps,
            v_set.weight_mode, v_set.percentage, v_set.absolute_weight_kg,
            v_set.basis_exercise_id, v_set.note
          );
        end loop;
      end loop;
    end if;
  end loop;

  return v_instance_id;
end;
$$;
