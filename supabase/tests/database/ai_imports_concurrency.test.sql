-- Two real connections race to start an import (#81). A single test
-- transaction can't overlap with itself, so this uses dblink, which means its
-- rows really commit. It clears them at both ends, and relies on seed.sql
-- having switched imports on.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select plan(5);

create temp table t on commit drop as
select (select id from auth.users where email = 'b@b.com') as user_id;

-- The address this session came in on, not loopback: the database trusts
-- loopback without a password, and dblink refuses non-superusers that way.
create function pg_temp.conn_string() returns text language sql as $$
  select format('host=%s port=%s dbname=postgres user=postgres password=postgres',
                host(inet_server_addr()), inet_server_port());
$$;

create function pg_temp.act_as_sql(p_user uuid) returns text language sql as $$
  select format(
    $q$ select set_config('request.jwt.claims', %L, true), set_config('role', 'authenticated', true) $q$,
    json_build_object('sub', p_user, 'role', 'authenticated')::text);
$$;

create function pg_temp.clear() returns void language plpgsql as $$
begin
  perform dblink_exec('setup', format(
    'delete from public.ai_import_jobs where user_id = %L', (select user_id from t)));
  perform dblink_exec('setup', format(
    'delete from public.ai_import_consents where user_id = %L', (select user_id from t)));
end;
$$;

select dblink_connect('setup', pg_temp.conn_string());
select dblink_connect('first', pg_temp.conn_string());
select dblink_connect('second', pg_temp.conn_string());

select pg_temp.clear();
select dblink_exec('setup', format(
  'insert into public.ai_import_consents (user_id) values (%L)', (select user_id from t)));

select ok((select enabled from public.ai_import_limits), 'imports are switched on in the local seed');

-- The first start takes the lock and hasn't committed.
select dblink_exec('first', 'begin');
select * from dblink('first', pg_temp.act_as_sql((select user_id from t))) as r(a text, b text);
select isnt(
  (select id from dblink('first',
    'select public.ai_import_start(gen_random_uuid())') as r(id uuid)),
  null, 'the first start succeeds');

-- The second has to wait for it.
select dblink_exec('second', 'begin');
select * from dblink('second', pg_temp.act_as_sql((select user_id from t))) as r(a text, b text);
select dblink_send_query('second', 'select public.ai_import_start(gen_random_uuid())');
select pg_sleep(0.3);
select is(dblink_is_busy('second'), 1, 'the second start waits for the first');

select dblink_exec('first', 'commit');

-- fail => false turns the remote error into an empty result.
select * from dblink_get_result('second', false) as r(id uuid);
select matches(dblink_error_message('second'), 'active_import', 'the second start is refused');
select * from dblink_get_result('second', false) as r(id uuid);
select dblink_exec('second', 'rollback');

select is(
  (select count(*)::int from public.ai_import_jobs
   where user_id = (select user_id from t) and status = 'processing'),
  1, 'exactly one job is running');

select pg_temp.clear();
select dblink_disconnect('setup');
select dblink_disconnect('first');
select dblink_disconnect('second');

select * from finish();
rollback;
