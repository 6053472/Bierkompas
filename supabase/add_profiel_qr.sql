-- BierKompas: persoonlijke QR-code op het profiel. Wie de code scant ziet
-- het profiel van de ander en kan hem als Bier-vriend toevoegen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_friends.sql (eerder uitgevoerd).

-- `profiles` heeft RLS "select own"; deze functie geeft net als
-- search_profiles alleen naam en avatar van één gebruiker terug.
create or replace function public.get_profile_by_id(p_user_id uuid)
returns table(id uuid, name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
    select p.id, p.name, p.avatar_url
    from public.profiles p
    where p.id = p_user_id;
$$;

grant execute on function public.get_profile_by_id(uuid) to authenticated;

NOTIFY pgrst, 'reload schema';
