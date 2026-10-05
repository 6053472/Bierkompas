-- BierKompas: maakt de laatste badges die nog nooit konden ontgrendelen
-- daadwerkelijk behaalbaar. Uitvoeren via het Supabase-dashboard: SQL Editor
-- -> New query -> plak dit bestand -> Run.
-- Vereist: add_stats_and_badges.sql, add_new_badges.sql, add_badge_categories.sql,
-- add_scan_achievements.sql, add_bieren_tabel.sql, add_cheers.sql,
-- add_tasting_notes.sql, add_feed.sql (eerder uitgevoerd).
--
-- Sommige badge-omschrijvingen (bv. "deel een fles", "craft collaboration",
-- "eigen brouwsels") matchen geen bestaande functie 1-op-1. Die zijn gekoppeld
-- aan de dichtstbijzijnde bestaande sociale actie (proost sturen, delen,
-- een eigen post plaatsen) in plaats van nieuwe functionaliteit te verzinnen.

-- 1. Vijf stijl-badges die nog geen enkel bier in de catalogus hadden om aan
-- te koppelen. Nieuwe catalogusbieren toegevoegd zodat ze echt te proeven/
-- scannen zijn (zelfde opzet als de bestaande placeholder-bieren zonder
-- specifieke brouwerij in add_bieren_tabel.sql).
-- (Defensief hier ook toegevoegd, voor het geval add_scan_achievements.sql
-- nog niet is uitgevoerd.)
alter table public.badges add column if not exists target_style text;

update public.badges set target_style = 'Vlaams Roodbruin' where id = 'flanders_red_ale';
update public.badges set target_style = 'NEIPA' where id = 'haze_for_days';
update public.badges set target_style = 'Kölsch' where id = 'respect_the_kolsch';
update public.badges set target_style = 'Lambic' where id = 'silence_of_the_lambics';
update public.badges set target_style = 'Altbier' where id = 'to_the_alt';

insert into public.bieren (id, naam, stijl, brouwerij, barcode) values
    (15, 'IIPA', 'IPA', E'Brouwerij \'t IJ, Amsterdam', '8710400000150'),
    (16, 'Roodbruin van de Leie', 'Vlaams Roodbruin', null, '8710400000167'),
    (17, 'Wolkendek Hazy IPA', 'NEIPA', null, '8710400000174'),
    (18, 'Nachtwacht Kölsch', 'Kölsch', null, '8710400000181'),
    (19, 'Stille Geuze', 'Lambic', null, '8710400000198'),
    (20, 'Keizerstad Altbier', 'Altbier', null, '8710400000204')
on conflict (id) do nothing;

-- 2. Locatie-badges: welke brouwerij/horeca (hardcoded in de app, dus hier
-- gekoppeld via item_type+item_id in plaats van een foreign key) een
-- "boerderijbrouwerij" of "beer garden" is, weet alleen een beheerder met
-- kennis van de echte locaties. Deze tabel staat bewust leeg tot een
-- beheerder er via de admin-pagina iets aan toevoegt -- er wordt niets
-- verzonnen over welke brouwerij wat is.
create table if not exists public.location_badge_tags (
    id bigint generated always as identity primary key,
    item_type text not null check (item_type in ('brewery', 'horeca')),
    item_id integer not null,
    tag text not null check (tag in ('farm', 'beer_garden')),
    created_at timestamptz not null default now(),
    constraint unique_location_tag unique (item_type, item_id, tag)
);

alter table public.location_badge_tags enable row level security;

drop policy if exists "Location badge tags: iedereen mag lezen" on public.location_badge_tags;
create policy "Location badge tags: iedereen mag lezen" on public.location_badge_tags
    for select using (true);

drop policy if exists "Location badge tags: alleen beheerders mogen wijzigen" on public.location_badge_tags;
create policy "Location badge tags: alleen beheerders mogen wijzigen" on public.location_badge_tags
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- 3. Gedeelde helper: kent 'la_creme_de_la_creme' (meta-badge) toe zodra
-- iemand 10 andere badges heeft verdiend. Wordt aan het eind van elke
-- badge-functie hieronder aangeroepen.
create or replace function public.check_meta_badges(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_count integer;
begin
    select count(*) into v_count from public.user_badges where user_id = p_user_id and badge_id <> 'la_creme_de_la_creme';
    if v_count >= 10 then
        insert into public.user_badges (user_id, badge_id)
        values (p_user_id, 'la_creme_de_la_creme')
        on conflict (user_id, badge_id) do nothing;
    end if;
end;
$$;

-- 4. send_cheer kent nu ook 'better_together' toe aan de afzender (een
-- proost sturen is de bestaande manier om "samen te proosten" met een
-- andere bierliefhebber).
drop function if exists public.send_cheer(uuid, bigint);
create or replace function public.send_cheer(p_receiver_id uuid, p_reply_to_id bigint default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_receiver_id = auth.uid() then
        raise exception 'Je kunt jezelf geen proost sturen';
    end if;

    if not exists (
        select 1 from public.friend_requests
        where status = 'accepted'
          and ((requester_id = auth.uid() and addressee_id = p_receiver_id)
            or (requester_id = p_receiver_id and addressee_id = auth.uid()))
    ) then
        raise exception 'Je kunt alleen vrienden een proost sturen';
    end if;

    if p_reply_to_id is not null and not exists (
        select 1 from public.cheers
        where id = p_reply_to_id
          and sender_id = p_receiver_id
          and receiver_id = auth.uid()
    ) then
        p_reply_to_id := null;
    end if;

    insert into public.cheers (sender_id, receiver_id, reply_to_id)
    values (auth.uid(), p_receiver_id, p_reply_to_id);

    insert into public.user_badges (user_id, badge_id)
    values (auth.uid(), 'better_together')
    on conflict (user_id, badge_id) do nothing;
    perform public.check_meta_badges(auth.uid());
end;
$$;

grant execute on function public.send_cheer(uuid, bigint) to authenticated;

-- 5. Delen (het systeem-deelvenster, WhatsApp, Facebook/Instagram/TikTok in
-- de app) kent 'bottle_share' toe -- je deelt een bier/post met iemand
-- anders, net als "een fles delen".
create or replace function public.record_share_action(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_user_id <> auth.uid() then
        raise exception 'Niet toegestaan.';
    end if;
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'bottle_share')
    on conflict (user_id, badge_id) do nothing;
    perform public.check_meta_badges(p_user_id);
end;
$$;

grant execute on function public.record_share_action(uuid) to authenticated;

-- 6. Een eigen post plaatsen in de Ontdek-feed (zelf iets maken om te delen)
-- kent 'home_brewed_goodness' toe -- de app heeft geen homebrew-functie,
-- dit is de dichtstbijzijnde bestaande "eigen gemaakte content"-actie.
create or replace function public.record_own_post(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_user_id <> auth.uid() then
        raise exception 'Niet toegestaan.';
    end if;
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'home_brewed_goodness')
    on conflict (user_id, badge_id) do nothing;
    perform public.check_meta_badges(p_user_id);
end;
$$;

grant execute on function public.record_own_post(uuid) to authenticated;

-- 7. Een proefnotitie opslaan kent 'super_model' toe zodra je gemiddelde
-- beoordeling (bij minstens 3 notities) 4.5 of hoger is.
create or replace function public.record_tasting_note_created(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_count integer;
    v_avg numeric;
begin
    if p_user_id <> auth.uid() then
        raise exception 'Niet toegestaan.';
    end if;

    select count(*), avg(rating) into v_count, v_avg
        from public.tasting_notes where user_id = p_user_id;

    if v_count >= 3 and v_avg >= 4.5 then
        insert into public.user_badges (user_id, badge_id)
        values (p_user_id, 'super_model')
        on conflict (user_id, badge_id) do nothing;
    end if;
    perform public.check_meta_badges(p_user_id);
end;
$$;

grant execute on function public.record_tasting_note_created(uuid) to authenticated;

-- 8. Een brouwerij/horeca favorieten kent locatie-badges toe als die plek
-- door een beheerder getagd is als boerderijbrouwerij of beer garden.
-- Blijft vergrendeld zolang er geen tags zijn ingesteld.
create or replace function public.record_item_favorited(p_user_id uuid, p_item_type text, p_item_id integer)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_user_id <> auth.uid() then
        raise exception 'Niet toegestaan.';
    end if;

    if p_item_type not in ('brewery', 'horeca') then
        return;
    end if;

    if exists (select 1 from public.location_badge_tags where item_type = p_item_type and item_id = p_item_id and tag = 'farm') then
        insert into public.user_badges (user_id, badge_id)
        values (p_user_id, 'trip_to_the_farm')
        on conflict (user_id, badge_id) do nothing;
    end if;

    if exists (select 1 from public.location_badge_tags where item_type = p_item_type and item_id = p_item_id and tag = 'beer_garden') then
        insert into public.user_badges (user_id, badge_id)
        values (p_user_id, 'visit_the_beer_garden')
        on conflict (user_id, badge_id) do nothing;
    end if;

    perform public.check_meta_badges(p_user_id);
end;
$$;

grant execute on function public.record_item_favorited(uuid, text, integer) to authenticated;

-- 9. log_beer_scan: nu ook 'draft_city' (5 verschillende bieren van dezelfde
-- brouwerij gelogd) en 'style_count'-badges (century_club / wheel_of_styles).
-- Drop eerst: Postgres staat geen wijziging van het returntype toe via
-- create or replace.
drop function if exists public.log_beer_scan(uuid, integer, text);
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
    v_distinct_styles integer;
    v_max_per_style integer;
    v_max_per_brewery integer;
    v_streak_row record;
    v_newly_earned text[] := array[]::text[];
    v_checkin_earned text[];
    v_style_earned text[];
    v_taster_earned text[];
    v_taps_earned text[];
    v_stylecount_earned text[];
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

    -- Badge voor 5 verschillende bieren van dezelfde brouwerij ('Draft City').
    select max(cnt) into v_max_per_brewery from (
        select count(distinct beer_id) as cnt
        from public.user_beer_logs
        where user_id = p_user_id and brewery is not null
        group by brewery
    ) sub;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'taps'
            and b.requirement_value <= coalesce(v_max_per_brewery, 0)
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_taps_earned from inserted;
    v_newly_earned := v_newly_earned || v_taps_earned;

    -- Badges op basis van stijl-diversiteit/aantal ('Wheel of Styles',
    -- 'The Century Club'): respectievelijk aantal verschillende stijlen
    -- geproefd, en het hoogste aantal unieke bieren binnen één stijl.
    select count(distinct bi.stijl) into v_distinct_styles
        from public.user_beer_logs ubl
        join public.bieren bi on bi.id = ubl.beer_id
        where ubl.user_id = p_user_id and bi.stijl is not null;

    select max(cnt) into v_max_per_style from (
        select count(distinct ubl.beer_id) as cnt
        from public.user_beer_logs ubl
        join public.bieren bi on bi.id = ubl.beer_id
        where ubl.user_id = p_user_id and bi.stijl is not null
        group by bi.stijl
    ) sub;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'style_count'
            and (
                (b.id = 'wheel_of_styles' and b.requirement_value <= coalesce(v_distinct_styles, 0))
                or (b.id = 'century_club' and b.requirement_value <= coalesce(v_max_per_style, 0))
            )
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_stylecount_earned from inserted;
    v_newly_earned := v_newly_earned || v_stylecount_earned;

    perform public.check_meta_badges(p_user_id);

    return query select v_beers_tasted, v_breweries_explored, v_streak_row.current_streak, v_streak_row.longest_streak, v_newly_earned;
end;
$$;

grant execute on function public.log_beer_scan(uuid, integer, text) to authenticated;

NOTIFY pgrst, 'reload schema';
