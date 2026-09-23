-- BierKompas: bier scannen (barcode) -> loggen in het Bier-paspoort.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

-- Welke bieren een gebruiker al gescand/gelogd heeft. Bier-data zelf staat nog
-- hardcoded in de app (lib/features/favorites/beers.dart), dus we bewaren hier
-- alleen het bier-id (uit die lijst) en de brouwerijnaam op het moment van loggen.
create table if not exists public.user_beer_logs (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    beer_id integer not null,
    brewery text,
    logged_at timestamptz not null default now(),
    constraint unique_user_beer unique (user_id, beer_id)
);

alter table public.user_beer_logs enable row level security;

drop policy if exists "User beer logs: select own" on public.user_beer_logs;
create policy "User beer logs: select own" on public.user_beer_logs
    for select using (auth.uid() = user_id);

-- Geen insert-policy voor gebruikers: loggen gaat alleen via de functie hieronder
-- (security definer), zodat beers_tasted/breweries_explored niet los aan te passen zijn.

-- Logt een gescand bier. Idempotent: opnieuw scannen van hetzelfde bier telt niet
-- dubbel mee. Werkt beers_tasted/breweries_explored bij en kent nieuwe
-- 'checkins'-badges toe zodra de drempel gehaald is.
create or replace function public.log_beer_scan(p_user_id uuid, p_beer_id integer, p_brewery text)
returns table(beers_tasted integer, breweries_explored integer, newly_earned_badges text[])
language plpgsql
security definer set search_path = public
as $$
declare
    v_already_logged boolean;
    v_beers_tasted integer;
    v_breweries_explored integer;
    v_newly_earned text[];
begin
    select exists(
        select 1 from public.user_beer_logs
        where user_id = p_user_id and beer_id = p_beer_id
    ) into v_already_logged;

    if not v_already_logged then
        insert into public.user_beer_logs (user_id, beer_id, brewery)
        values (p_user_id, p_beer_id, p_brewery);
    end if;

    select count(*) into v_beers_tasted
        from public.user_beer_logs where user_id = p_user_id;

    select count(distinct brewery) into v_breweries_explored
        from public.user_beer_logs
        where user_id = p_user_id and brewery is not null;

    update public.profiles
        set beers_tasted = v_beers_tasted,
            breweries_explored = v_breweries_explored
        where id = p_user_id;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'checkins'
            and b.requirement_value <= v_beers_tasted
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_newly_earned from inserted;

    return query select v_beers_tasted, v_breweries_explored, v_newly_earned;
end;
$$;

grant execute on function public.log_beer_scan(uuid, integer, text) to authenticated;
