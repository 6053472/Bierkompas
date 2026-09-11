-- Account verwijderen: ingelogde gebruiker kan zijn eigen account verwijderen.
-- Verwijdert de rij in auth.users; profiles, user_consents, favorites en events
-- worden automatisch verwijderd via "on delete cascade" in schema.sql.
create or replace function public.delete_account()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_account() to authenticated;
