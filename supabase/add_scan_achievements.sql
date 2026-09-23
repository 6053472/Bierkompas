-- BierKompas: bier scannen telt nu ook mee voor de Bier Streak, en badges op
-- basis van bierstijl ('style') en meerdere stijlen op één dag
-- ('taster_flight') worden echt toegekend in plaats van voor altijd
-- vergrendeld te blijven.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_beer_scan.sql en add_bieren_tabel.sql (eerder uitgevoerd).

-- 1. Welke bierstijl een 'style'-badge vereist. Alleen ingevuld voor stijlen
-- die daadwerkelijk in de bieren-catalogus voorkomen; badges voor stijlen
-- die er nog niet in zitten (Lambic, Kölsch, Vlaams Roodbruin, ...) blijven
-- bewust vergrendeld totdat zulke bieren zijn toegevoegd via de admin-pagina.
alter table public.badges add column if not exists target_style text;

update public.badges set target_style = 'Bock' where id = 'ill_be_bock';
update public.badges set target_style = 'Witbier' where id = 'keep_your_wits';
update public.badges set target_style = 'Kriek' where id = 'pucker_up';
update public.badges set target_style = 'IPA' where id = 'land_of_the_free';

-- 2. log_beer_scan: doet nu ook de streak-update (hetzelfde effect als het
-- openen van de app) en kent style-/taster-flight-badges toe.
create or replace function public.log_beer_scan(p_user_id uuid, p_beer_id integer, p_brewery text)
returns table(
    beers_tasted integer,
    breweries_explored integer,
    current_streak integer,
    longest_streak integer,
    newly_earned_badges text[]
)
language plpgsql
security definer set search_path = public
as $$
declare
    v_already_logged boolean;
    v_beers_tasted integer;
    v_breweries_explored integer;
    v_style text;
    v_styles_today integer;
    v_streak_row record;
    v_newly_earned text[] := array[]::text[];
    v_checkin_earned text[];
    v_style_earned text[];
    v_taster_earned text[];
begin
    select exists(
        select 1 from public.user_beer_logs
        where user_id = p_user_id and beer_id = p_beer_id
    ) into v_already_logged;

    if not v_already_logged then
        insert into public.user_beer_logs (user_id, beer_id, brewery)
        values (p_user_id, p_beer_id, p_brewery);
    end if;

    -- Bier scannen telt als activiteit voor de Bier Streak.
    select * into v_streak_row from public.record_daily_activity(p_user_id);
    v_newly_earned := v_newly_earned || v_streak_row.newly_earned_badges;

    select count(*) into v_beers_tasted
        from public.user_beer_logs where user_id = p_user_id;

    select count(distinct brewery) into v_breweries_explored
        from public.user_beer_logs
        where user_id = p_user_id and brewery is not null;

    update public.profiles
        set beers_tasted = v_beers_tasted,
            breweries_explored = v_breweries_explored
        where id = p_user_id;

    -- Badges op basis van totaal aantal gescande/gelogde bieren ('checkins').
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
    select coalesce(array_agg(badge_id), array[]::text[]) into v_checkin_earned from inserted;
    v_newly_earned := v_newly_earned || v_checkin_earned;

    -- Badge voor het proeven van een specifieke bierstijl.
    select stijl into v_style from public.bieren where id = p_beer_id;
    if v_style is not null then
        with inserted as (
            insert into public.user_badges (user_id, badge_id)
            select p_user_id, b.id
            from public.badges b
            where b.requirement_type = 'style'
                and b.target_style = v_style
                and not exists (
                    select 1 from public.user_badges ub
                    where ub.user_id = p_user_id and ub.badge_id = b.id
                )
            on conflict (user_id, badge_id) do nothing
            returning badge_id
        )
        select coalesce(array_agg(badge_id), array[]::text[]) into v_style_earned from inserted;
        v_newly_earned := v_newly_earned || v_style_earned;
    end if;

    -- Badge voor 4 verschillende bierstijlen op één dag ('Taster, Please').
    select count(distinct bi.stijl) into v_styles_today
        from public.user_beer_logs ubl
        join public.bieren bi on bi.id = ubl.beer_id
        where ubl.user_id = p_user_id
            and ubl.logged_at::date = current_date
            and bi.stijl is not null;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'taster_flight'
            and b.requirement_value <= v_styles_today
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_taster_earned from inserted;
    v_newly_earned := v_newly_earned || v_taster_earned;

    return query select v_beers_tasted, v_breweries_explored, v_streak_row.current_streak, v_streak_row.longest_streak, v_newly_earned;
end;
$$;

grant execute on function public.log_beer_scan(uuid, integer, text) to authenticated;

NOTIFY pgrst, 'reload schema';
