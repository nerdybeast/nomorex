-- Fix advisor findings: function_search_path_mutable, anon/authenticated_security_definer_function_executable

-- set_updated_at() has no search_path set, making it vulnerable to search_path hijacking.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
begin new.updated_at = now(); return new; end;
$function$;

-- handle_new_user() is SECURITY DEFINER and only ever invoked by the on_auth_user_created
-- trigger; triggers don't require EXECUTE grants to fire, so it never needs to be callable
-- directly via /rest/v1/rpc/handle_new_user. Two separate grants make it callable today:
-- the original remote_schema.sql migration's explicit `GRANT ALL ... TO anon, authenticated`,
-- and Postgres's own default EXECUTE-to-PUBLIC grant on function creation (which every role
-- implicitly inherits) -- both must be revoked.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
