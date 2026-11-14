-- The official exercise catalog: stable slugs, aliases, retiring, and one
-- name-matching rule for every server-side path.
--
-- * slug: the official exercise's permanent identity, e.g. clean_and_jerk.
--   UUIDs change whenever the database is rebuilt; the slug doesn't, so the
--   catalog file (supabase/catalog/official_exercises.sql) upserts on it and
--   can be replayed after a wipe. Official rows only, and it can't change.
-- * aliases: other names an official exercise is known by ("C&J"). Every
--   name match also checks them, so free text (AI import, copying a workout
--   that uses someone's custom "C&J") lands on the official row instead of
--   creating a duplicate custom exercise.
-- * retired_at: how an official exercise is removed. It leaves the pickers
--   but keeps working everywhere it's already used: PRs, logged workouts,
--   programs and percentage bases all still point at it.
-- * normalize_exercise_name(): the one definition of "the same name"
--   (whitespace collapsed, trimmed, lowercased). The Dart and TypeScript
--   copies (normalizeExerciseName in Dart, normalizeExerciseName in
--   ai_import/normalize.ts) must match it; each one's tests run the same
--   cases as exercise_catalog.test.sql.
-- * find_exercise_for_user(): the one lookup map_exercise_for_viewer and
--   ai_import_resolve_exercise share. Active official (name or alias), then
--   retired official, then the caller's oldest custom row with that name.
-- * The basis_exercise_id foreign keys stop being ON DELETE SET NULL. Deleting
--   an exercise used as a percentage basis silently re-pointed every such set
--   at its own exercise ("75% of Clean & Jerk" became 75% of Front Squat).
--   Now the delete is refused, like every other reference to an exercise.

-- ---------------------------------------------------------------------------
-- Normalization
-- ---------------------------------------------------------------------------

create or replace function public.normalize_exercise_name(p_name text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(btrim(regexp_replace(p_name, '\s+', ' ', 'g')));
$$;

-- Every normalized name an exercise answers to: its name plus its aliases.
create or replace function public.exercise_match_keys(p_name text, p_aliases text[])
returns text[]
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(array_agg(distinct k order by k), '{}')
  from (
    select public.normalize_exercise_name(v) as k
    from unnest(array[p_name] || coalesce(p_aliases, '{}')) as u(v)
  ) keys
  where k is not null and k <> '';
$$;

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.exercises
  add column slug text,
  add column aliases text[] not null default '{}',
  add column retired_at timestamptz;

-- Backfill slugs for official rows that already exist (hosted projects; a
-- fresh local stack has none until the catalog seed runs), by the same rule
-- the catalog file's slugs were made with, so replaying the file updates
-- these rows instead of adding second copies. A second official row with the
-- same name is retired rather than deleted, because user data may point at it.
with ranked as (
  select id,
         coalesce(nullif(btrim(regexp_replace(replace(lower(name), '&', ' and '), '[^a-z0-9]+', '_', 'g'), '_'), ''),
                  'exercise') as base,
         row_number() over (
           partition by public.normalize_exercise_name(name) order by created_at, id
         ) as name_rank
  from public.exercises
  where is_predefined
), slugged as (
  select id, name_rank,
         base || case when n > 1 then '_' || n else '' end as slug
  from (
    select id, base, name_rank, row_number() over (partition by base order by name_rank, id) as n
    from ranked
  ) s
)
update public.exercises e
set slug = s.slug,
    retired_at = case when s.name_rank > 1 then now() end
from slugged s
where e.id = s.id;

alter table public.exercises
  add column match_keys text[] generated always as (public.exercise_match_keys(name, aliases)) stored;

alter table public.exercises drop constraint exercises_predefined_check;

alter table public.exercises
  add constraint exercises_official_shape check (
    (is_predefined and user_id is null
      and slug is not null and slug ~ '^[a-z0-9]+(_[a-z0-9]+)*$')
    or
    (not is_predefined and user_id is not null
      and slug is null and cardinality(aliases) = 0 and retired_at is null)
  );

-- Not validated against existing rows: a hosted project may hold old data,
-- and a failed migration would block every later one.
alter table public.exercises
  add constraint exercises_name_not_blank check (public.normalize_exercise_name(name) <> '') not valid;

create unique index exercises_slug_key on public.exercises (slug);
create index exercises_match_keys_idx on public.exercises using gin (match_keys);

-- ---------------------------------------------------------------------------
-- Write rules
-- ---------------------------------------------------------------------------

-- Tidies the name and aliases, keeps the slug permanent, and refuses an
-- official name or alias that another active official exercise already
-- answers to. A unique index can't compare one row's name against another
-- row's aliases, so this is a trigger, serialized by an advisory lock so two
-- concurrent writes can't both pass the check.
create or replace function public.exercises_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_keys text[];
  v_clash text;
begin
  new.name := btrim(regexp_replace(new.name, '\s+', ' ', 'g'));

  -- Aliases: trimmed, blanks and repeats dropped, and any alias that is just
  -- the name dropped (so renaming back to an old name doesn't leave it twice).
  select coalesce(array_agg(a order by ord), '{}') into new.aliases
  from (
    select distinct on (public.normalize_exercise_name(v))
           btrim(regexp_replace(v, '\s+', ' ', 'g')) as a, ord
    from unnest(new.aliases) with ordinality as u(v, ord)
    where public.normalize_exercise_name(v) <> ''
      and public.normalize_exercise_name(v) <> public.normalize_exercise_name(new.name)
    order by public.normalize_exercise_name(v), ord
  ) cleaned;

  if tg_op = 'UPDATE' and old.slug is not null and new.slug is distinct from old.slug then
    raise exception 'invalid_input: an exercise''s slug can''t be changed' using errcode = 'P0001';
  end if;

  if new.is_predefined and new.retired_at is null then
    perform pg_advisory_xact_lock(hashtextextended('public.exercises official names', 0));
    v_keys := public.exercise_match_keys(new.name, new.aliases);

    select e.name into v_clash
    from public.exercises e
    where e.is_predefined
      and e.retired_at is null
      and e.id <> new.id
      -- The catalog file's upsert fires this BEFORE INSERT trigger even when
      -- ON CONFLICT (slug) then turns it into an update of the row with the
      -- same slug. That row is the one being replaced, not a clash.
      and e.slug is distinct from new.slug
      and e.match_keys && v_keys
    limit 1;

    if found then
      raise exception 'duplicate: "%" already uses one of these names or aliases', v_clash
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

create trigger exercises_before_write
  before insert or update on public.exercises
  for each row execute function public.exercises_before_write();

-- ---------------------------------------------------------------------------
-- Basis foreign keys: refuse the delete instead of silently re-pointing sets.
-- NO ACTION rather than RESTRICT so deleting an account, which cascades to the
-- sets and the exercises in one statement, still works.
-- ---------------------------------------------------------------------------

alter table public.workout_sets drop constraint workout_sets_basis_exercise_id_fkey;
alter table public.workout_sets
  add constraint workout_sets_basis_exercise_id_fkey
  foreign key (basis_exercise_id) references public.exercises (id);

alter table public.program_sets drop constraint program_sets_basis_exercise_id_fkey;
alter table public.program_sets
  add constraint program_sets_basis_exercise_id_fkey
  foreign key (basis_exercise_id) references public.exercises (id);

-- ---------------------------------------------------------------------------
-- Matching
-- ---------------------------------------------------------------------------

-- The caller's exercise for a name: an active official exercise whose name or
-- alias matches, then a retired one, then the caller's oldest custom row with
-- that name. Null when there's none. The app's ensureExerciseByName and the AI
-- import's Catalog follow the same order.
create or replace function public.find_exercise_for_user(p_name text)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select e.id
  from public.exercises e
  where e.match_keys @> array[public.normalize_exercise_name(p_name)]
    and (e.is_predefined or e.user_id = (select auth.uid()))
  order by e.is_predefined desc, (e.retired_at is null) desc, e.created_at asc, e.id
  limit 1;
$$;

-- Unchanged contract (see 20261013023308): an official source is returned as
-- is; another user's custom exercise is matched into the caller's catalog by
-- name (now alias-aware), and created only when nothing matches.
create or replace function public.map_exercise_for_viewer(p_source_exercise_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_source record;
  v_match uuid;
begin
  if p_source_exercise_id is null then
    return null;
  end if;

  select e.id, e.name, e.is_predefined into v_source
  from public.exercises e
  where e.id = p_source_exercise_id;

  if not found then
    raise exception 'not_found: exercise % is not readable', p_source_exercise_id
      using errcode = 'P0001';
  end if;

  if v_source.is_predefined then
    return v_source.id;
  end if;

  v_match := public.find_exercise_for_user(v_source.name);
  if v_match is not null then
    return v_match;
  end if;

  insert into public.exercises (name, is_predefined, user_id)
  values (v_source.name, false, v_user_id)
  returning id into v_match;

  return v_match;
end;
$$;

-- Unchanged contract (see 20261110001658), with the name lookup shared.
create or replace function public.ai_import_resolve_exercise(
  p_name text,
  p_match jsonb default null
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_name text := nullif(btrim(regexp_replace(p_name, '\s+', ' ', 'g')), '');
  v_exercise_id uuid;
begin
  -- The Read exercises policy also shows exercises used in other users' public
  -- content, so RLS alone doesn't make an id one this user may build on.
  select e.id into v_exercise_id
  from public.exercises e
  where e.id = (p_match ->> 'exerciseId')::uuid
    and (e.is_predefined or e.user_id = v_user_id);
  if found then
    return v_exercise_id;
  end if;

  if v_name is null then
    raise exception 'invalid_input: an exercise needs a name' using errcode = 'P0001';
  end if;

  v_exercise_id := public.find_exercise_for_user(v_name);
  if v_exercise_id is not null then
    return v_exercise_id;
  end if;

  insert into public.exercises (name, is_predefined, user_id)
  values (v_name, false, v_user_id)
  returning id into v_exercise_id;
  return v_exercise_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. Default privileges grant every routine to anon and public.
-- The generated column and trigger run the helpers as the writing user, so
-- authenticated needs them.
-- ---------------------------------------------------------------------------

revoke all on function public.normalize_exercise_name(text) from public, anon;
revoke all on function public.exercise_match_keys(text, text[]) from public, anon;
revoke all on function public.exercises_before_write() from public, anon, authenticated;
revoke all on function public.find_exercise_for_user(text) from public, anon;

grant execute on function public.normalize_exercise_name(text) to authenticated, service_role;
grant execute on function public.exercise_match_keys(text, text[]) to authenticated, service_role;
grant execute on function public.find_exercise_for_user(text) to authenticated, service_role;
