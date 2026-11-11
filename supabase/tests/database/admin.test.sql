-- Admin roles and the admin_* functions (#112). a@a.com is the seeded admin,
-- b@b.com and c@c.com are ordinary users. Only the functions can change roles,
-- the audit log or the AI import switch; nobody can write those tables
-- directly, admins included.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(56);

-- ---------------------------------------------------------------------------
-- Helpers and fixtures
-- ---------------------------------------------------------------------------

create temp table u on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from auth.users where email = 'c@c.com') as c,
       (select count(*) from auth.users) as user_count,
       (select id from auth.users order by created_at desc, id limit 1 offset 1) as second_newest;
grant select on u to authenticated, anon;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Audit rows written by this test: now() is the transaction's start time, so
-- rows left by earlier manual testing on the stack don't count.
create function pg_temp.audit_count(p_action text, p_target uuid) returns integer
language sql as $$
  select count(*)::int from public.admin_audit_log
  where action = p_action and target_user_id is not distinct from p_target and created_at = now()
$$;

update public.profiles set display_name = 'Bravo Lifter' where id = (select b from u);
update public.ai_import_limits set enabled = true;

-- ---------------------------------------------------------------------------
-- Seed and schema
-- ---------------------------------------------------------------------------

select is((select array_agg(name) from public.roles), array['admin'], 'admin is the only role so far');
select is(
  (select array_agg(u2.email order by u2.email) from public.user_roles r join auth.users u2 on u2.id = r.user_id),
  array['a@a.com']::varchar[], 'seed makes only a@a.com an admin');

-- ---------------------------------------------------------------------------
-- An ordinary user (b) is refused everything.
-- ---------------------------------------------------------------------------

select pg_temp.act_as((select b from u));

select ok(not public.has_role('admin'), 'b is not an admin');
select throws_like($$ select * from public.admin_list_users() $$,
  'forbidden:%', 'b cannot list users');
select throws_like($$ select public.admin_grant_role((select b from u), 'admin') $$,
  'forbidden:%', 'b cannot make themselves an admin');
select throws_like($$ select public.admin_revoke_role((select a from u), 'admin') $$,
  'forbidden:%', 'b cannot remove a''s admin role');
select throws_like($$ select public.admin_set_ai_imports_enabled(false) $$,
  'forbidden:%', 'b cannot switch AI imports off');
select throws_like($$ select * from public.admin_list_audit_log() $$,
  'forbidden:%', 'b cannot read the audit log through the function');
select is((select count(*)::int from public.user_roles), 0, 'b cannot see a''s role');
select is((select count(*)::int from public.roles), 1, 'b can read the role names');
select throws_ok($$ insert into public.user_roles (user_id, role) select b, 'admin' from u $$,
  '42501', null, 'b cannot insert a role row directly');
select throws_ok($$ select public.require_role('admin') $$,
  '42501', null, 'require_role is not callable by clients');
select throws_ok($$ select public.lock_user_roles() $$,
  '42501', null, 'lock_user_roles is not callable by clients');

-- ---------------------------------------------------------------------------
-- anon can't call anything.
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
set local role anon;

select throws_ok($$ select public.has_role('admin') $$, '42501', null, 'anon cannot call has_role');
select throws_ok($$ select * from public.admin_list_users() $$, '42501', null, 'anon cannot list users');
select throws_ok($$ select public.admin_grant_role((select b from u), 'admin') $$,
  '42501', null, 'anon cannot grant a role');
select throws_ok($$ select public.admin_set_ai_imports_enabled(false) $$,
  '42501', null, 'anon cannot switch AI imports off');
select throws_ok($$ select count(*) from public.user_roles $$, '42501', null, 'anon cannot read user_roles');

-- ---------------------------------------------------------------------------
-- The admin (a) can't write the tables directly either.
-- ---------------------------------------------------------------------------

reset role;
select pg_temp.act_as((select a from u));

select ok(public.has_role('admin'), 'a is an admin');
select throws_ok($$ insert into public.user_roles (user_id, role) select b, 'admin' from u $$,
  '42501', null, 'a cannot insert a role row directly');
select throws_ok($$ update public.user_roles set granted_at = now() $$,
  '42501', null, 'a cannot update role rows directly');
select throws_ok($$ delete from public.user_roles $$,
  '42501', null, 'a cannot delete role rows directly');
select throws_ok($$ insert into public.roles (name, description) values ('owner', 'x') $$,
  '42501', null, 'a cannot add a role directly');
select throws_ok($$ insert into public.admin_audit_log (action) values ('forged') $$,
  '42501', null, 'a cannot write the audit log directly');
select throws_ok($$ delete from public.admin_audit_log $$,
  '42501', null, 'a cannot delete audit entries');
select throws_ok($$ update public.ai_import_limits set enabled = false $$,
  '42501', null, 'a cannot switch AI imports directly');

-- ---------------------------------------------------------------------------
-- Listing users
-- ---------------------------------------------------------------------------

select ok(
  (select array_agg(email) from public.admin_list_users(null, 100, 0))
    @> array['a@a.com', 'b@b.com', 'c@c.com'],
  'the list includes every seeded user');
select is(
  (select roles from public.admin_list_users('a@a.com') where email = 'a@a.com'),
  array['admin'], 'a is listed with the admin role');
select is(
  (select roles from public.admin_list_users('c@c.com') where email = 'c@c.com'),
  '{}'::text[], 'c is listed with no roles');
select results_eq(
  $$ select email, display_name, total_count from public.admin_list_users('B@B.') $$,
  $$ values ('b@b.com'::text, 'Bravo Lifter'::text, 1::bigint) $$,
  'search matches part of an email, ignoring case');
select results_eq(
  $$ select email from public.admin_list_users('bravo') $$,
  $$ values ('b@b.com'::text) $$,
  'search matches the display name');
select is((select count(*)::int from public.admin_list_users('no such user')), 0, 'no match lists nobody');
select is(
  (select total_count from public.admin_list_users(null, 1, 0)),
  (select user_count from u),
  'total_count counts every match, not just the page');
select is(
  (select id from public.admin_list_users(null, 1, 1)),
  (select second_newest from u),
  'pages are newest first and offset by p_offset');
select is((select count(*)::int from public.admin_list_users(null, 0, 0)), 1, 'the page size is at least 1');

-- ---------------------------------------------------------------------------
-- Granting and revoking
-- ---------------------------------------------------------------------------

select lives_ok($$ select public.admin_grant_role((select b from u), 'admin') $$, 'a can make b an admin');
select is(
  (select granted_by from public.user_roles where user_id = (select b from u) and role = 'admin'),
  (select a from u), 'the role records who granted it');
select is(pg_temp.audit_count('role_granted', (select b from u)), 1, 'granting is logged');
select lives_ok($$ select public.admin_grant_role((select b from u), 'admin') $$, 'granting again is harmless');
select is(pg_temp.audit_count('role_granted', (select b from u)), 1, 'granting again is not logged');
select throws_like($$ select public.admin_grant_role((select c from u), 'owner') $$,
  'not_found:%', 'an unknown role is refused');
select throws_like($$ select public.admin_grant_role(gen_random_uuid(), 'admin') $$,
  'not_found:%', 'an unknown user is refused');
select throws_like($$ select public.admin_revoke_role((select a from u), 'admin') $$,
  'self:%', 'a cannot remove their own admin role');

-- Another admin can see every role row.
reset role;
select pg_temp.act_as((select b from u));
select is((select count(*)::int from public.user_roles), 2, 'an admin sees everyone''s roles');

reset role;
select pg_temp.act_as((select a from u));
select lives_ok($$ select public.admin_revoke_role((select b from u), 'admin') $$, 'a can remove b''s admin role');
select ok(not exists (select 1 from public.user_roles where user_id = (select b from u)), 'b is no longer an admin');
select is(pg_temp.audit_count('role_revoked', (select b from u)), 1, 'revoking is logged');
select lives_ok($$ select public.admin_revoke_role((select b from u), 'admin') $$, 'revoking again is harmless');
select is(pg_temp.audit_count('role_revoked', (select b from u)), 1, 'revoking again is not logged');

-- ---------------------------------------------------------------------------
-- AI import switch
-- ---------------------------------------------------------------------------

select lives_ok($$ select public.admin_set_ai_imports_enabled(false) $$, 'a can switch AI imports off');
select ok(not (select enabled from public.ai_import_limits), 'AI imports are off');
select public.admin_set_ai_imports_enabled(false);
select is(pg_temp.audit_count('ai_imports_disabled', null), 1, 'switching off is logged once, not again when already off');
select public.admin_set_ai_imports_enabled(true);
select is(pg_temp.audit_count('ai_imports_enabled', null), 1, 'switching on is logged');
select throws_like($$ select public.admin_set_ai_imports_enabled(null) $$,
  'invalid_input:%', 'null is refused');

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------

select results_eq(
  $$ select actor_email, target_email, details from public.admin_list_audit_log(100, 0)
     where action = 'role_granted' and created_at = now() $$,
  $$ values ('a@a.com'::text, 'b@b.com'::text, '{"role": "admin"}'::jsonb) $$,
  'audit entries show the actor''s and target''s emails');

-- b, no longer an admin, sees none of it.
reset role;
select pg_temp.act_as((select b from u));
select is((select count(*)::int from public.admin_audit_log), 0, 'a non-admin sees no audit entries');

select * from finish();
rollback;
