-- Admin roles and an audit log (#112, stage 1 of #111).
--
-- Roles live in their own table rather than on profiles: profiles has an
-- "update own profile" policy, so a role column there would let anyone make
-- themselves admin, and other users can sometimes read profiles rows. Roles are
-- rows in public.roles, not an enum, so a future role is an insert.
--
-- Nothing here is writable by a client. user_roles, admin_audit_log and
-- ai_import_limits change only through the admin_* functions below, which are
-- SECURITY DEFINER and check the caller's role themselves; the app's route
-- guard is only UX. The first admin is created by hand with SQL (docs/build.md).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.roles (
  name text primary key,
  description text not null
);

insert into public.roles (name, description)
values ('admin', 'Manages users, their roles and app settings.');

-- References auth.users, not profiles: a second FK to profiles from a table
-- the app embeds would make PostgREST embeds ambiguous (PGRST201).
create table public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null references public.roles (name),
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create index user_roles_role_idx on public.user_roles (role);
create index user_roles_granted_by_idx on public.user_roles (granted_by);

create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  target_user_id uuid references auth.users (id) on delete set null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index admin_audit_log_created_at_idx on public.admin_audit_log (created_at desc);
create index admin_audit_log_actor_id_idx on public.admin_audit_log (actor_id);
create index admin_audit_log_target_user_id_idx on public.admin_audit_log (target_user_id);

alter table public.roles enable row level security;
alter table public.user_roles enable row level security;
alter table public.admin_audit_log enable row level security;

-- ---------------------------------------------------------------------------
-- Role checks
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so the user_roles policy can call it without recursing
-- into itself. It only ever answers for the caller.
create or replace function public.has_role(p_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = (select auth.uid()) and role = p_role
  );
$$;

-- Every admin function calls this first. Not callable by clients.
create or replace function public.require_role(p_role text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if not public.has_role(p_role) then
    raise exception 'forbidden: the % role is required', p_role using errcode = 'P0001';
  end if;
end;
$$;

-- Role changes take this lock before checking the caller's role, so they run
-- one at a time and each sees the others' results. Two admins revoking each
-- other at once can't both succeed: the second finds it is no longer an admin.
-- Together with the self-revoke refusal, that means at least one admin is
-- always left.
create or replace function public.lock_user_roles()
returns void
language sql
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtext('public.user_roles'));
$$;

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

-- The project's default privileges grant everything to anon and authenticated.
revoke all on public.roles, public.user_roles, public.admin_audit_log from anon, authenticated;
grant select on public.roles, public.user_roles, public.admin_audit_log to authenticated;

create policy roles_select on public.roles
  for select to authenticated
  using (true);

create policy user_roles_select on public.user_roles
  for select to authenticated
  using ((select auth.uid()) = user_id or (select public.has_role('admin')));

create policy admin_audit_log_select on public.admin_audit_log
  for select to authenticated
  using ((select public.has_role('admin')));

-- ---------------------------------------------------------------------------
-- Admin functions
-- ---------------------------------------------------------------------------

-- Every user, newest first. p_search matches part of the email or display
-- name, case-insensitively. total_count is the number of matches, repeated on
-- each row (no rows past the last page, so no total either).
create or replace function public.admin_list_users(
  p_search text default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  id uuid,
  email text,
  display_name text,
  roles text[],
  created_at timestamptz,
  last_sign_in_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_search text := nullif(lower(btrim(p_search)), '');
begin
  perform public.require_role('admin');

  return query
  select u.id,
         u.email::text,
         p.display_name,
         coalesce(
           (select array_agg(r.role order by r.role) from public.user_roles r where r.user_id = u.id),
           '{}'::text[]),
         u.created_at,
         u.last_sign_in_at,
         count(*) over ()
  from auth.users u
  left join public.profiles p on p.id = u.id
  where v_search is null
     or strpos(lower(coalesce(u.email, '')), v_search) > 0
     or strpos(lower(coalesce(p.display_name, '')), v_search) > 0
  order by u.created_at desc, u.id
  limit greatest(1, least(coalesce(p_limit, 25), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

-- Idempotent: granting a role the user already has changes nothing and is not
-- logged.
create or replace function public.admin_grant_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted integer;
begin
  perform public.lock_user_roles();
  perform public.require_role('admin');

  if not exists (select 1 from public.roles where name = p_role) then
    raise exception 'not_found: unknown role %', p_role using errcode = 'P0001';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'not_found: user % does not exist', p_user_id using errcode = 'P0001';
  end if;

  insert into public.user_roles (user_id, role, granted_by)
  values (p_user_id, p_role, (select auth.uid()))
  on conflict (user_id, role) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    insert into public.admin_audit_log (actor_id, action, target_user_id, details)
    values ((select auth.uid()), 'role_granted', p_user_id, jsonb_build_object('role', p_role));
  end if;
end;
$$;

-- Removing a role the user doesn't have changes nothing and is not logged.
-- An admin can't remove their own roles, which (with lock_user_roles) keeps at
-- least one admin.
create or replace function public.admin_revoke_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  perform public.lock_user_roles();
  perform public.require_role('admin');

  if p_user_id = (select auth.uid()) then
    raise exception 'self: you can''t remove your own % role', p_role using errcode = 'P0001';
  end if;

  delete from public.user_roles where user_id = p_user_id and role = p_role;
  get diagnostics v_deleted = row_count;

  if v_deleted > 0 then
    insert into public.admin_audit_log (actor_id, action, target_user_id, details)
    values ((select auth.uid()), 'role_revoked', p_user_id, jsonb_build_object('role', p_role));
  end if;
end;
$$;

-- The AI import off switch. An import already running still finishes.
-- Setting the value it already has changes nothing and is not logged.
create or replace function public.admin_set_ai_imports_enabled(p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  perform public.require_role('admin');

  if p_enabled is null then
    raise exception 'invalid_input: enabled must be true or false' using errcode = 'P0001';
  end if;

  update public.ai_import_limits set enabled = p_enabled where enabled is distinct from p_enabled;
  get diagnostics v_updated = row_count;

  if v_updated > 0 then
    insert into public.admin_audit_log (actor_id, action, details)
    values ((select auth.uid()),
            case when p_enabled then 'ai_imports_enabled' else 'ai_imports_disabled' end,
            '{}');
  end if;
end;
$$;

-- Newest first, with the emails the app shows in place of ids.
create or replace function public.admin_list_audit_log(
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  id uuid,
  actor_id uuid,
  actor_email text,
  action text,
  target_user_id uuid,
  target_email text,
  details jsonb,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.require_role('admin');

  return query
  select l.id,
         l.actor_id,
         actor.email::text,
         l.action,
         l.target_user_id,
         target.email::text,
         l.details,
         l.created_at,
         count(*) over ()
  from public.admin_audit_log l
  left join auth.users actor on actor.id = l.actor_id
  left join auth.users target on target.id = l.target_user_id
  order by l.created_at desc, l.id
  limit greatest(1, least(coalesce(p_limit, 25), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

-- Default privileges grant every routine to anon (and public).
revoke all on function public.has_role(text) from public, anon;
revoke all on function public.require_role(text) from public, anon, authenticated;
revoke all on function public.lock_user_roles() from public, anon, authenticated;
revoke all on function public.admin_list_users(text, integer, integer) from public, anon;
revoke all on function public.admin_grant_role(uuid, text) from public, anon;
revoke all on function public.admin_revoke_role(uuid, text) from public, anon;
revoke all on function public.admin_set_ai_imports_enabled(boolean) from public, anon;
revoke all on function public.admin_list_audit_log(integer, integer) from public, anon;

grant execute on function public.has_role(text) to authenticated;
grant execute on function public.admin_list_users(text, integer, integer) to authenticated;
grant execute on function public.admin_grant_role(uuid, text) to authenticated;
grant execute on function public.admin_revoke_role(uuid, text) to authenticated;
grant execute on function public.admin_set_ai_imports_enabled(boolean) to authenticated;
grant execute on function public.admin_list_audit_log(integer, integer) to authenticated;
