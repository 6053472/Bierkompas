-- BierKompas: statistieken-overzicht voor de admin-pagina.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- De admin-pagina gebruikt alleen de publieke anon key, en RLS op `profiles`
-- staat geen "select alle rijen" toe voor een gewone gebruiker. Deze functie
-- draait met de rechten van de eigenaar (security definer) en telt daarom
-- zelf de aggregaten op, maar geeft nooit individuele rij-data terug -- en
-- controleert eerst of de aanroeper zelf beheerder is.

create or replace function public.admin_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    result json;
begin
    if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin) then
        raise exception 'Alleen beheerders mogen statistieken opvragen.';
    end if;

    select json_build_object(
        'total_users', (select count(*) from public.profiles),
        'active_7d', (select count(*) from public.profiles where last_activity_date >= (current_date - interval '7 days')),
        'active_30d', (select count(*) from public.profiles where last_activity_date >= (current_date - interval '30 days')),
        'total_beers_tasted', (select coalesce(sum(beers_tasted), 0) from public.profiles),
        'total_breweries_explored', (select coalesce(sum(breweries_explored), 0) from public.profiles),
        'longest_streak', (select coalesce(max(longest_streak), 0) from public.profiles),
        'pending_events', (select count(*) from public.events where status = 'pending'),
        'pending_breweries', (select count(*) from public.brewery_submissions where status = 'pending'),
        'pending_horeca', (select count(*) from public.horeca_submissions where status = 'pending'),
        'pending_posts', (select count(*) from public.feed_items where status = 'pending'),
        'total_badges_earned', (select count(*) from public.user_badges)
    ) into result;

    return result;
end;
$$;

grant execute on function public.admin_stats() to authenticated;

NOTIFY pgrst, 'reload schema';
