-- Admin management of the official exercise catalog (Profile -> Admin ->
-- Exercises), on top of 20261114202746_official_exercise_catalog.sql.
--
-- Same shape as the other admin_* functions: SECURITY DEFINER (clients can't
-- write official rows), require_role('admin') first, search_path = '', anon
-- revoked, and one admin_audit_log row for every change (none for a no-op).
-- The exercises_before_write trigger still applies, so name/alias clashes and
-- slug changes are refused here exactly as anywhere else.
--
-- Errors are raised as `code: detail`. invalid_input, duplicate and in_use
-- details are written for the admin and shown as-is by adminErrorMessage().

-- ---------------------------------------------------------------------------
-- Helpers (not callable by clients)
-- ---------------------------------------------------------------------------

-- How many lifters use an exercise anywhere: PRs, workouts, programs, or as a
-- percentage basis. Each counts once.
create or replace function public.exercise_usage_count(p_exercise_id uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select count(distinct user_id) from (
    select user_id from public.personal_bests where exercise_id = p_exercise_id
    union all
    select user_id from public.workout_exercises where exercise_id = p_exercise_id
    union all
    select user_id from public.program_exercises where exercise_id = p_exercise_id
    union all
    select user_id from public.workout_sets where basis_exercise_id = p_exercise_id
    union all
    select user_id from public.program_sets where basis_exercise_id = p_exercise_id
  ) uses;
$$;

-- The official exercise row, locked, or not_found.
create or replace function public.lock_official_exercise(p_exercise_id uuid)
returns public.exercises
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.exercises;
begin
  select * into v_row from public.exercises
  where id = p_exercise_id and is_predefined
  for update;
  if not found then
    raise exception 'not_found: that exercise no longer exists' using errcode = 'P0001';
  end if;
  return v_row;
end;
$$;

create or replace function public.check_exercise_name(p_name text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if coalesce(public.normalize_exercise_name(p_name), '') = '' then
    raise exception 'invalid_input: an exercise needs a name' using errcode = 'P0001';
  end if;
  if length(btrim(p_name)) > 100 then
    raise exception 'invalid_input: keep the name under 100 characters' using errcode = 'P0001';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reads
-- ---------------------------------------------------------------------------

-- Official exercises A–Z, active or retired. p_search matches part of the
-- name, an alias or the slug. total_count repeats on each row, as in
-- admin_list_users.
create or replace function public.admin_list_exercises(
  p_search text default null,
  p_retired boolean default false,
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  id uuid,
  slug text,
  name text,
  aliases text[],
  retired_at timestamptz,
  created_at timestamptz,
  usage_count bigint,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_search text := nullif(public.normalize_exercise_name(p_search), '');
begin
  perform public.require_role('admin');

  return query
  select e.id, e.slug, e.name, e.aliases, e.retired_at, e.created_at,
         public.exercise_usage_count(e.id),
         count(*) over ()
  from public.exercises e
  where e.is_predefined
    and (e.retired_at is not null) = coalesce(p_retired, false)
    and (v_search is null
         or strpos(e.slug, v_search) > 0
         or exists (select 1 from unnest(e.match_keys) k where strpos(k, v_search) > 0))
  order by lower(e.name), e.id
  limit greatest(1, least(coalesce(p_limit, 25), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

-- The catalog as supabase/catalog/official_exercises.sql: commit what this
-- returns over that file. Rows sorted by slug, so a diff shows only changes.
create or replace function public.admin_export_exercises()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rows text;
begin
  perform public.require_role('admin');

  select string_agg(
           format('  (%L, %L, %s, %s)',
                  e.slug,
                  e.name,
                  case when cardinality(e.aliases) = 0 then '''{}'''
                       else 'array[' || (select string_agg(format('%L', a), ', ' order by o)
                                         from unnest(e.aliases) with ordinality as x(a, o)) || ']'
                  end,
                  case when e.retired_at is null then 'null'
                       else format('%L', to_char(e.retired_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
                  end),
           E',\n' order by e.slug)
  into v_rows
  from public.exercises e
  where e.is_predefined;

  return
'-- The official exercise catalog: every exercise with is_predefined = true.
--
-- This file is how the catalog survives a database wipe. The live catalog is
-- edited in the app (Profile -> Admin -> Exercises); export it from there and
-- commit the result here, replacing this file. Hand edits are fine too.
--
-- It''s an upsert keyed on slug, so it can be run any number of times, against
-- an empty database or a live one:
--   * local and CI stacks load it on `supabase db reset` (supabase/config.toml
--     [db.seed], before seed.sql, which refers to these exercises by name);
--   * after wiping a hosted project, paste it into the SQL editor once.
-- A row here updates the official exercise with the same slug (name, aliases,
-- retired) or creates it. Official exercises missing from the file are left
-- alone, never deleted.
--
-- A slug is permanent: never change one here, or the row becomes a second
-- exercise instead of a rename. retired_at null means active.
insert into public.exercises (slug, name, aliases, retired_at, is_predefined)
select slug, name, aliases, retired_at::timestamptz, true
from (values
' || coalesce(v_rows, '') || '
) as catalog (slug, name, aliases, retired_at)
on conflict (slug) do update
set name = excluded.name,
    aliases = excluded.aliases,
    retired_at = excluded.retired_at;
';
end;
$$;

-- ---------------------------------------------------------------------------
-- Changes
-- ---------------------------------------------------------------------------

-- Creates an official exercise. custom_name_count is how many lifters already
-- have a custom exercise answering to one of its names: they'll see both
-- until a merge feature exists, so the app warns about it.
create or replace function public.admin_create_exercise(
  p_slug text,
  p_name text,
  p_aliases text[] default '{}'
)
returns table (id uuid, custom_name_count bigint)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_slug text := btrim(coalesce(p_slug, ''));
  v_row public.exercises;
begin
  perform public.require_role('admin');
  perform public.check_exercise_name(p_name);

  if v_slug !~ '^[a-z0-9]+(_[a-z0-9]+)*$' then
    raise exception 'invalid_input: a slug is lowercase letters and numbers joined by underscores, like clean_and_jerk'
      using errcode = 'P0001';
  end if;
  if exists (select 1 from public.exercises e where e.slug = v_slug) then
    raise exception 'duplicate: the slug % is already taken (slugs are never reused, even when retired)', v_slug
      using errcode = 'P0001';
  end if;

  insert into public.exercises (slug, name, aliases, is_predefined)
  values (v_slug, p_name, coalesce(p_aliases, '{}'), true)
  returning * into v_row;

  insert into public.admin_audit_log (actor_id, action, details)
  values ((select auth.uid()), 'exercise_created',
          jsonb_build_object('exercise_id', v_row.id, 'slug', v_row.slug, 'name', v_row.name,
                             'aliases', to_jsonb(v_row.aliases)));

  return query
  select v_row.id,
         (select count(distinct e.user_id)
          from public.exercises e
          where not e.is_predefined and e.match_keys && v_row.match_keys);
end;
$$;

-- Renames an official exercise and/or replaces its aliases. The slug never
-- changes. The app adds the old name as an alias when renaming, visibly, so
-- the admin can drop it (a typo fix shouldn't keep the typo).
create or replace function public.admin_update_exercise(
  p_exercise_id uuid,
  p_name text,
  p_aliases text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.exercises;
  v_new public.exercises;
begin
  perform public.require_role('admin');
  perform public.check_exercise_name(p_name);
  v_old := public.lock_official_exercise(p_exercise_id);

  update public.exercises
  set name = p_name, aliases = coalesce(p_aliases, '{}')
  where id = p_exercise_id
  returning * into v_new;

  if v_new.name is distinct from v_old.name or v_new.aliases is distinct from v_old.aliases then
    insert into public.admin_audit_log (actor_id, action, details)
    values ((select auth.uid()), 'exercise_updated',
            jsonb_build_object('exercise_id', v_new.id, 'slug', v_new.slug,
                               'old_name', v_old.name, 'name', v_new.name,
                               'old_aliases', to_jsonb(v_old.aliases), 'aliases', to_jsonb(v_new.aliases)));
  end if;
end;
$$;

-- Retires (p_retired) or restores an official exercise. Restoring is refused
-- by the trigger while an active exercise has one of its names.
create or replace function public.admin_set_exercise_retired(p_exercise_id uuid, p_retired boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.exercises;
begin
  perform public.require_role('admin');
  if p_retired is null then
    raise exception 'invalid_input: retired must be true or false' using errcode = 'P0001';
  end if;
  v_row := public.lock_official_exercise(p_exercise_id);
  if (v_row.retired_at is not null) = p_retired then
    return;
  end if;

  update public.exercises
  set retired_at = case when p_retired then now() end
  where id = p_exercise_id;

  insert into public.admin_audit_log (actor_id, action, details)
  values ((select auth.uid()),
          case when p_retired then 'exercise_retired' else 'exercise_restored' end,
          jsonb_build_object('exercise_id', v_row.id, 'slug', v_row.slug, 'name', v_row.name));
end;
$$;

-- Deletes an official exercise nobody uses: for a mistake caught straight
-- away. Anything in use is retired instead; the foreign keys would refuse the
-- delete anyway, this just says why.
create or replace function public.admin_delete_exercise(p_exercise_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.exercises;
  v_uses bigint;
begin
  perform public.require_role('admin');
  v_row := public.lock_official_exercise(p_exercise_id);

  v_uses := public.exercise_usage_count(p_exercise_id);
  if v_uses > 0 then
    raise exception 'in_use: % is used by % lifter(s). Retire it instead.', v_row.name, v_uses
      using errcode = 'P0001';
  end if;

  delete from public.exercises where id = p_exercise_id;

  insert into public.admin_audit_log (actor_id, action, details)
  values ((select auth.uid()), 'exercise_deleted',
          jsonb_build_object('exercise_id', v_row.id, 'slug', v_row.slug, 'name', v_row.name));
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. Default privileges grant every routine to anon and public.
-- ---------------------------------------------------------------------------

revoke all on function public.exercise_usage_count(uuid) from public, anon, authenticated;
revoke all on function public.lock_official_exercise(uuid) from public, anon, authenticated;
revoke all on function public.check_exercise_name(text) from public, anon, authenticated;
revoke all on function public.admin_list_exercises(text, boolean, integer, integer) from public, anon;
revoke all on function public.admin_export_exercises() from public, anon;
revoke all on function public.admin_create_exercise(text, text, text[]) from public, anon;
revoke all on function public.admin_update_exercise(uuid, text, text[]) from public, anon;
revoke all on function public.admin_set_exercise_retired(uuid, boolean) from public, anon;
revoke all on function public.admin_delete_exercise(uuid) from public, anon;

grant execute on function public.admin_list_exercises(text, boolean, integer, integer) to authenticated;
grant execute on function public.admin_export_exercises() to authenticated;
grant execute on function public.admin_create_exercise(text, text, text[]) to authenticated;
grant execute on function public.admin_update_exercise(uuid, text, text[]) to authenticated;
grant execute on function public.admin_set_exercise_retired(uuid, boolean) to authenticated;
grant execute on function public.admin_delete_exercise(uuid) to authenticated;
