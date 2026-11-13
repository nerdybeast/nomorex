-- reorder_program_weeks (#126): moving a week has to move its days too.
--
-- program_days.position is the day's global order and also its schedule
-- offset (start_program dates each day start_date + position). Renumbering
-- only the weeks, as the client used to, left every day where it was, so a
-- week moved first still ran on its old dates. This reassigns the weeks'
-- numbers and positions in the new order and then hands the days the same
-- set of positions in the new week order, all in one transaction.
--
-- SECURITY INVOKER like the other editor RPCs; the caller must own the
-- program, and p_week_ids must be exactly its weeks.
create or replace function public.reorder_program_weeks(p_program_id uuid, p_week_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.programs p where p.id = p_program_id and p.user_id = v_user_id
  ) then
    raise exception 'not_found: program % is not available', p_program_id using errcode = 'P0001';
  end if;
  if p_week_ids is null
     or cardinality(p_week_ids) <> (select count(distinct x) from unnest(p_week_ids) as x)
     or (select count(*) from public.program_weeks w where w.program_id = p_program_id)
        <> cardinality(p_week_ids)
     or exists (
       select 1 from unnest(p_week_ids) as x
       where not exists (select 1 from public.program_weeks w where w.id = x and w.program_id = p_program_id)
     ) then
    raise exception 'invalid_argument: list every week of the program once' using errcode = 'P0001';
  end if;

  -- Weeks: the k-th week in the new order takes the k-th smallest week
  -- number and position. Negatives first, for unique(program_id, week_number).
  with ord as (
    select x.id, x.ord from unnest(p_week_ids) with ordinality as x(id, ord)
  ), nums as (
    select w.week_number, row_number() over (order by w.week_number) as rn
    from public.program_weeks w where w.program_id = p_program_id
  ), poss as (
    select w.position, row_number() over (order by w.position) as rn
    from public.program_weeks w where w.program_id = p_program_id
  )
  update public.program_weeks w
  set week_number = -n.week_number - 1, position = p.position
  from ord
  join nums n on n.rn = ord.ord
  join poss p on p.rn = ord.ord
  where w.id = ord.id;
  update public.program_weeks
  set week_number = -week_number - 1
  where program_id = p_program_id and week_number < 0;

  -- Days: walk them in the new week order (keeping each week's own order) and
  -- give the k-th the k-th smallest of the positions they already hold, so
  -- the schedule stays the same length with no gaps added.
  with ord as (
    select x.id, x.ord from unnest(p_week_ids) with ordinality as x(id, ord)
  ), walk as (
    select d.id, row_number() over (order by ord.ord, d.position) as rn
    from public.program_days d join ord on ord.id = d.program_week_id
  ), slots as (
    select d.position, row_number() over (order by d.position) as rn
    from public.program_days d where d.program_id = p_program_id
  )
  update public.program_days d
  set position = -s.position - 1
  from walk
  join slots s on s.rn = walk.rn
  where d.id = walk.id;
  update public.program_days
  set position = -position - 1
  where program_id = p_program_id and position < 0;
end;
$$;
revoke execute on function public.reorder_program_weeks(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_program_weeks(uuid, uuid[]) to authenticated;
