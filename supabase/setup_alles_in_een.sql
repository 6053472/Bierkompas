-- BierKompas: ALLES-IN-ÉÉN database-setup.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- hele bestand -> Run. Dit vervangt alle losse supabase/add_*.sql-bestanden.
--
-- * Veilig om opnieuw te draaien: alles is "if not exists" / "or replace", en
--   voorbeeldgegevens worden alleen toegevoegd als ze er nog niet staan.
-- * Werkt op een lege database en op een bestaande (al deels ingerichte).
-- * Bevat bewust NIET: reset_test_data.sql, wipe_events.sql,
--   remove_fake_feed_data.sql (verwijderen gegevens) en de oude debug-fix.
-- * Na het draaien: admin-paneel -> Data-imports -> Importeren (bierdatabase,
--   agenda, nieuws). Die gegevens zitten niet in dit bestand.
--
-- Gegenereerd uit de losse bestanden; wijzigingen horen in de losse
-- bestanden en daarna opnieuw genereren.

-- ============================================================
-- schema.sql
-- ============================================================
-- =========================================================
-- BierKompas Supabase schema
-- Herstelde versie zonder events RLS-recursie
-- =========================================================


-- =========================================================
-- 1. PROFILES
-- =========================================================

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null default '',
    email text not null default '',
    avatar_url text,
    is_admin boolean not null default false,
    created_at timestamptz not null default now()
);

alter table public.profiles
add column if not exists avatar_url text;

alter table public.profiles
add column if not exists is_admin boolean not null default false;

alter table public.profiles enable row level security;


-- =========================================================
-- ADMIN FUNCTIE
-- =========================================================

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
    select coalesce(
        (
            select p.is_admin
            from public.profiles p
            where p.id = auth.uid()
        ),
        false
    );
$$;


-- =========================================================
-- PROFILE POLICIES
-- =========================================================

drop policy if exists "Profiles: select own"
on public.profiles;

drop policy if exists "Profiles: update own"
on public.profiles;

drop policy if exists "Profiles: event owners can view participants"
on public.profiles;

drop policy if exists "Profiles: event owners and admins can view participants"
on public.profiles;


create policy "Profiles: select own"
on public.profiles
for select
to authenticated
using (
    auth.uid() = id
);


create policy "Profiles: update own"
on public.profiles
for update
to authenticated
using (
    auth.uid() = id
)
with check (
    auth.uid() = id
);


-- =========================================================
-- NIEUWE GEBRUIKER -> PROFILE
-- =========================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.profiles (
        id,
        name,
        email,
        avatar_url
    )
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'name', ''),
        coalesce(new.email, ''),
        new.raw_user_meta_data->>'avatar_url'
    )
    on conflict (id)
    do update set
        name = excluded.name,
        email = excluded.email,
        avatar_url = coalesce(
            excluded.avatar_url,
            public.profiles.avatar_url
        );

    return new;

end;
$$;


drop trigger if exists on_auth_user_created
on auth.users;


create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();


-- =========================================================
-- 2. USER CONSENTS
-- =========================================================

create table if not exists public.user_consents (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    terms_version text not null,
    privacy_version text not null,
    accepted_at timestamptz not null default now(),
    age_confirmed boolean not null default false,
    lawful_alcohol_use boolean not null default false,
    accurate_account_data boolean not null default false,
    personal_account boolean not null default false,
    credentials_secure boolean not null default false,
    no_impersonation boolean not null default false,

    constraint unique_user_consent_version
        unique (user_id, terms_version, privacy_version)
);

alter table public.user_consents enable row level security;


drop policy if exists "Consents: select own"
on public.user_consents;

drop policy if exists "Consents: insert own"
on public.user_consents;

drop policy if exists "Consents: update own"
on public.user_consents;


create policy "Consents: select own"
on public.user_consents
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "Consents: insert own"
on public.user_consents
for insert
to authenticated
with check (
    auth.uid() = user_id
);


create policy "Consents: update own"
on public.user_consents
for update
to authenticated
using (
    auth.uid() = user_id
)
with check (
    auth.uid() = user_id
);


-- =========================================================
-- 3. FAVORITES
-- =========================================================

create table if not exists public.favorites (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    item_type text not null,
    item_id bigint not null,
    created_at timestamptz not null default now(),

    constraint unique_favorite
        unique (user_id, item_type, item_id)
);

alter table public.favorites enable row level security;


drop policy if exists "Favorites: select own"
on public.favorites;

drop policy if exists "Favorites: insert own"
on public.favorites;

drop policy if exists "Favorites: delete own"
on public.favorites;


create policy "Favorites: select own"
on public.favorites
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "Favorites: insert own"
on public.favorites
for insert
to authenticated
with check (
    auth.uid() = user_id
);


create policy "Favorites: delete own"
on public.favorites
for delete
to authenticated
using (
    auth.uid() = user_id
);


-- =========================================================
-- 4. EVENTS
-- =========================================================

create table if not exists public.events (
    id bigint generated always as identity primary key,

    user_id uuid
        references auth.users(id)
        on delete cascade,

    name text not null,
    event_type text not null,

    start_date timestamptz not null,
    end_date timestamptz not null,

    opening_hours text,

    street text not null,
    house_number text not null,
    postal_code text not null,
    city text not null,
    location_name text not null,

    description text not null,

    ticket_regular boolean not null default false,
    ticket_beer boolean not null default false,
    ticket_vip boolean not null default false,

    price numeric(10,2),

    price_incl_btw boolean not null default false,
    price_excl_btw boolean not null default false,

    status text not null default 'pending',

    image_asset text,

    created_at timestamptz not null default now()
);


alter table public.events
add column if not exists image_asset text;

alter table public.events
add column if not exists status text not null default 'pending';

alter table public.events enable row level security;


-- =========================================================
-- ALLE OUDE EVENTS POLICIES OPRUIMEN
-- =========================================================

drop policy if exists "Approved events are public"
on public.events;

drop policy if exists "Events: everyone can view"
on public.events;

drop policy if exists "Events: everyone can view approved"
on public.events;

drop policy if exists "Events: view approved, own, or admin"
on public.events;

drop policy if exists "Users can view their own events"
on public.events;

drop policy if exists "Events: authenticated users can create"
on public.events;

drop policy if exists "Events: authenticated users can insert"
on public.events;

drop policy if exists "Events: owner can update"
on public.events;

drop policy if exists "Events: owners can update"
on public.events;

drop policy if exists "Events: owner or admin can update"
on public.events;

drop policy if exists "Events: admins can update"
on public.events;

drop policy if exists "Events: owner can delete"
on public.events;

drop policy if exists "Events: owners can delete"
on public.events;

drop policy if exists "Events: admins can delete"
on public.events;


-- =========================================================
-- EVENTS SELECT
-- Geen verwijzing naar profiles/events/andere policies.
-- Hierdoor geen RLS-recursie.
-- =========================================================

create policy "Events: everyone can view"
on public.events
for select
to anon, authenticated
using (
    true
);


-- =========================================================
-- EVENTS INSERT
-- =========================================================

create policy "Events: authenticated users can insert"
on public.events
for insert
to authenticated
with check (
    auth.uid() = user_id
);


-- =========================================================
-- EVENTS UPDATE - EIGENAAR
-- =========================================================

create policy "Events: owner can update"
on public.events
for update
to authenticated
using (
    auth.uid() = user_id
)
with check (
    auth.uid() = user_id
);


-- =========================================================
-- EVENTS UPDATE - ADMIN
-- =========================================================

create policy "Events: admins can update"
on public.events
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);


-- =========================================================
-- EVENTS DELETE - EIGENAAR
-- =========================================================

create policy "Events: owner can delete"
on public.events
for delete
to authenticated
using (
    auth.uid() = user_id
);


-- =========================================================
-- EVENTS DELETE - ADMIN
-- =========================================================

create policy "Events: admins can delete"
on public.events
for delete
to authenticated
using (
    public.is_admin()
);


grant select
on public.events
to anon;

grant select, insert, update, delete
on public.events
to authenticated;


-- =========================================================
-- 5. EVENT REGISTRATIONS
-- =========================================================

create table if not exists public.event_registrations (
    id bigint generated always as identity primary key,

    event_id bigint not null
        references public.events(id)
        on delete cascade,

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    status text not null default 'pending',

    created_at timestamptz not null default now(),

    constraint unique_event_registration
        unique (event_id, user_id),

    constraint event_registration_status_check
        check (
            status in (
                'pending',
                'approved',
                'rejected'
            )
        )
);


alter table public.event_registrations
add column if not exists status text not null default 'pending';


update public.event_registrations
set status = 'pending'
where status is null;


do $$
begin

    if not exists (
        select 1
        from pg_constraint
        where conname = 'event_registration_status_check'
    ) then

        alter table public.event_registrations
        add constraint event_registration_status_check
        check (
            status in (
                'pending',
                'approved',
                'rejected'
            )
        );

    end if;

end $$;


alter table public.event_registrations
enable row level security;


-- =========================================================
-- REGISTRATION POLICIES
-- =========================================================

drop policy if exists "Registrations: select own"
on public.event_registrations;

drop policy if exists "Registrations: event owner can view"
on public.event_registrations;

drop policy if exists "Registrations: admins can view"
on public.event_registrations;

drop policy if exists "Registrations: insert own"
on public.event_registrations;

drop policy if exists "Registrations: delete own"
on public.event_registrations;

drop policy if exists "Registrations: owner can update"
on public.event_registrations;

drop policy if exists "Registrations: admins can update"
on public.event_registrations;


create policy "Registrations: select own"
on public.event_registrations
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "Registrations: event owner can view"
on public.event_registrations
for select
to authenticated
using (
    exists (
        select 1
        from public.events e
        where e.id = event_registrations.event_id
        and e.user_id = auth.uid()
    )
);


create policy "Registrations: admins can view"
on public.event_registrations
for select
to authenticated
using (
    public.is_admin()
);


create policy "Registrations: insert own"
on public.event_registrations
for insert
to authenticated
with check (
    auth.uid() = user_id
);


create policy "Registrations: delete own"
on public.event_registrations
for delete
to authenticated
using (
    auth.uid() = user_id
);


create policy "Registrations: owner can update"
on public.event_registrations
for update
to authenticated
using (
    exists (
        select 1
        from public.events e
        where e.id = event_registrations.event_id
        and e.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.events e
        where e.id = event_registrations.event_id
        and e.user_id = auth.uid()
    )
);


create policy "Registrations: admins can update"
on public.event_registrations
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);


grant select, insert, update, delete
on public.event_registrations
to authenticated;


-- =========================================================
-- 6. PARTICIPANT PROFILE ACCESS
-- =========================================================

drop policy if exists "Profiles: event owners can view participants"
on public.profiles;

drop policy if exists "Profiles: event owners and admins can view participants"
on public.profiles;


create policy "Profiles: event owners and admins can view participants"
on public.profiles
for select
to authenticated
using (
    exists (
        select 1
        from public.event_registrations er
        join public.events e
            on e.id = er.event_id
        where er.user_id = public.profiles.id
        and e.user_id = auth.uid()
    )
    or public.is_admin()
);


-- =========================================================
-- 7. GRANTS
-- =========================================================

grant select, update
on public.profiles
to authenticated;

grant select, insert, update
on public.user_consents
to authenticated;

grant select, insert, delete
on public.favorites
to authenticated;

grant select, insert, update, delete
on public.events
to authenticated;

grant select, insert, update, delete
on public.event_registrations
to authenticated;


-- =========================================================
-- 8. SUPABASE SCHEMA CACHE
-- =========================================================

notify pgrst, 'reload schema';

-- ============================================================
-- add_avatar.sql
-- ============================================================
-- BierKompas: profielfoto ondersteuning.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

alter table public.profiles add column if not exists avatar_url text;

-- Storage-bucket voor profielfoto's (publiek leesbaar, alleen eigenaar mag schrijven).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Avatars: public read" on storage.objects;
create policy "Avatars: public read" on storage.objects
    for select using (bucket_id = 'avatars');

drop policy if exists "Avatars: insert own" on storage.objects;
create policy "Avatars: insert own" on storage.objects
    for insert with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Avatars: update own" on storage.objects;
create policy "Avatars: update own" on storage.objects
    for update using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Avatars: delete own" on storage.objects;
create policy "Avatars: delete own" on storage.objects
    for delete using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- add_stats_and_badges.sql
-- ============================================================
-- BierKompas: per-profiel stats, badges en Bier Streaks.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

-- 1. Stats + streak-velden op het profiel.
alter table public.profiles add column if not exists beers_tasted integer not null default 0;
alter table public.profiles add column if not exists breweries_explored integer not null default 0;
alter table public.profiles add column if not exists current_streak integer not null default 0;
alter table public.profiles add column if not exists longest_streak integer not null default 0;
alter table public.profiles add column if not exists last_activity_date date;

-- 2. Badge-definities (algemeen, niet per gebruiker).
create table if not exists public.badges (
    id text primary key,
    title text not null,
    description text not null,
    icon_name text not null,
    requirement_type text not null,
    requirement_value integer not null
);

alter table public.badges enable row level security;

drop policy if exists "Badges: public read" on public.badges;
create policy "Badges: public read" on public.badges
    for select using (true);

insert into public.badges (id, title, description, icon_name, requirement_type, requirement_value) values
    ('streak_7', 'Week Streak', '7 dagen op rij actief in Bierkompas.', 'local_fire_department', 'streak', 7),
    ('streak_30', 'Maand Streak', '30 dagen op rij actief in Bierkompas.', 'whatshot', 'streak', 30),
    ('streak_100', 'Streak Legende', '100 dagen op rij actief in Bierkompas.', 'military_tech', 'streak', 100)
on conflict (id) do nothing;

-- 3. Welke badges een gebruiker heeft verdiend.
create table if not exists public.user_badges (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    badge_id text not null references public.badges(id) on delete cascade,
    earned_at timestamptz not null default now(),
    constraint unique_user_badge unique (user_id, badge_id)
);

alter table public.user_badges enable row level security;

drop policy if exists "User badges: select own" on public.user_badges;
create policy "User badges: select own" on public.user_badges
    for select using (auth.uid() = user_id);

-- Geen insert/update/delete-policy voor gebruikers: badges worden alleen
-- toegekend via de onderstaande functie (security definer), niet rechtstreeks
-- vanuit de app, zodat gebruikers zichzelf geen badges kunnen geven.

-- 4. Streak-logica: 1x per dag aanroepen bij een relevante actie in de app.
-- Vandaag al actief geweest -> streak blijft gelijk.
-- Gisteren actief geweest -> streak +1.
-- Langer geleden (of nog nooit) -> streak reset naar 1.
-- Kent automatisch nieuwe streak-badges toe zodra de drempel gehaald is.
drop function if exists public.record_daily_activity(uuid);
create or replace function public.record_daily_activity(p_user_id uuid)
returns table(current_streak integer, longest_streak integer, newly_earned_badges text[])
language plpgsql
security definer set search_path = public
as $$
declare
    v_last_date date;
    v_current_streak integer;
    v_longest_streak integer;
    v_new_streak integer;
    v_today date := current_date;
    v_newly_earned text[];
begin
    select p.last_activity_date, p.current_streak, p.longest_streak
        into v_last_date, v_current_streak, v_longest_streak
        from public.profiles p
        where p.id = p_user_id
        for update;

    if v_last_date = v_today then
        v_new_streak := v_current_streak;
    elsif v_last_date = v_today - 1 then
        v_new_streak := v_current_streak + 1;
    else
        v_new_streak := 1;
    end if;

    update public.profiles
        set current_streak = v_new_streak,
            longest_streak = greatest(v_longest_streak, v_new_streak),
            last_activity_date = v_today
        where id = p_user_id;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'streak'
            and b.requirement_value <= v_new_streak
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_newly_earned from inserted;

    return query select v_new_streak, greatest(v_longest_streak, v_new_streak), v_newly_earned;
end;
$$;

grant execute on function public.record_daily_activity(uuid) to authenticated;

-- ============================================================
-- delete_account.sql
-- ============================================================
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

-- ============================================================
-- add_badge_categories.sql
-- ============================================================
-- BierKompas: categorie per badge, zodat "Bekijk alles" badges kan groeperen
-- zoals in het Mijn Prestaties-ontwerp (Evenement Badges / Culturele Verkenning
-- / Algemene Prestaties).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

alter table public.badges add column if not exists category text not null default 'algemeen';

update public.badges set category = 'evenement' where id in (
    'bottle_share', 'better_together', 'draft_city', 'home_brewed_goodness',
    'taster_please', 'trip_to_the_farm', 'visit_the_beer_garden'
);

update public.badges set category = 'cultureel' where id in (
    'flanders_red_ale', 'haze_for_days', 'ill_be_bock', 'keep_your_wits',
    'land_of_the_free', 'pucker_up', 'respect_the_kolsch',
    'silence_of_the_lambics', 'to_the_alt'
);

update public.badges set category = 'algemeen' where id in (
    'epic_milestone', 'la_creme_de_la_creme', 'super_model', 'century_club',
    'wheel_of_styles', 'streak_7', 'streak_30', 'streak_100'
);

-- Streak-badges tonen allemaal het vuurtje-icoon.
update public.badges set icon_name = 'local_fire_department'
    where id in ('streak_7', 'streak_30', 'streak_100');

-- ============================================================
-- add_feed.sql
-- ============================================================
-- BierKompas: Infinite Scroll Feed voor de Ontdek-pagina.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Kan veilig opnieuw worden uitgevoerd.
--
-- - feed_items: losse feed-content (mini-reviews, biertips, weetjes en brouwerij-posts).
--   beer_id / brewery_id verwijzen naar de vaste bieren en brouwerijen in de app
--   (lib/features/favorites/beers.dart en lib/features/map/breweries.dart). Liken van zo'n
--   post slaat het bier of de brouwerij op als favoriet; andere posts worden zelf bewaard.
-- - feed (view): voegt feed_items samen met de bestaande tabel events, zodat
--   evenementen uit de Agenda automatisch ook in de feed verschijnen.
-- De app leest alleen de view, in batches van 15 via range (limit/offset),
-- gesorteerd op created_at en daarna feed_key.

create table if not exists public.feed_items (
    id bigint generated always as identity primary key,
    item_type text not null,
    title text not null,
    body text not null,
    image_url text,
    author text,
    rating numeric(2,1) check (rating between 0 and 5),
    beer_id bigint,
    brewery_id bigint,
    created_at timestamptz not null default now()
);

-- Voor het geval de tabel al bestond zonder deze kolommen of met een oudere controle.
alter table public.feed_items add column if not exists beer_id bigint;
alter table public.feed_items add column if not exists brewery_id bigint;
alter table public.feed_items drop constraint if exists feed_items_item_type_check;
alter table public.feed_items add constraint feed_items_item_type_check
    check (item_type in ('review', 'tip', 'weetje', 'brouwerij'));

create index if not exists feed_items_created_at_idx on public.feed_items (created_at desc);

alter table public.feed_items enable row level security;

drop policy if exists "Feed items: everyone can view" on public.feed_items;
create policy "Feed items: everyone can view"
on public.feed_items for select using (true);

grant select on public.feed_items to anon, authenticated;

-- Eén gemengde stroom. feed_key is uniek over beide tabellen en dient als
-- tiebreaker, zodat paginering met offset geen items overslaat of dubbel toont.
-- security_invoker zorgt dat de RLS-regels van de onderliggende tabellen gelden.
drop view if exists public.feed;
create view public.feed
with (security_invoker = on) as
select
    'item-' || id as feed_key,
    item_type,
    title,
    body,
    image_url,
    author,
    rating,
    beer_id,
    brewery_id,
    null::timestamptz as event_start,
    null::text as event_location,
    created_at
from public.feed_items
union all
select
    'event-' || id,
    'evenement',
    name,
    description,
    null,
    null,
    null,
    null,
    null,
    start_date,
    location_name || ', ' || city,
    created_at
from public.events;

grant select on public.feed to anon, authenticated;

-- ============================================================
-- add_new_badges.sql
-- ============================================================
-- BierKompas: 21 nieuwe "Artisanal Draught"-badges uit de Stitch-badge-galerij.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Let op: dit voegt alleen de badge-definities toe (zichtbaar als "Vergrendeld" voor iedereen).
-- De progressie-/unlock-logica voor deze requirement_types moet nog gebouwd worden
-- (in tegenstelling tot 'streak', die al automatisch wordt toegekend via record_daily_activity).

alter table public.badges add column if not exists image_asset text;

insert into public.badges (id, title, description, icon_name, image_asset, requirement_type, requirement_value) values
    ('bottle_share', 'Bottle Share', 'Deel een fles met een medebierliefhebber.', 'sports_bar', 'bottle_share', 'social', 1),
    ('better_together', 'Better Together', 'Werk samen met andere bierliefhebbers aan een craft collaboration.', 'sports_bar', 'better_together', 'social', 1),
    ('draft_city', 'Draft City', 'Proef bier van 5 verschillende tapkranen op één locatie.', 'sports_bar', 'draft_city', 'taps', 5),
    ('epic_milestone', 'Epic Milestone', 'Meer dan 5000 check-ins in BierKompas. Legendarische status.', 'military_tech', 'epic_milestone', 'checkins', 5000),
    ('flanders_red_ale', 'Flan-Didly-Anders', 'Proef en waardeer een Vlaams Roodbruin bier.', 'sports_bar', 'flanders_red_ale', 'style', 1),
    ('haze_for_days', 'Haze for Days', 'Word een meester in NEIPA''s (New England IPA).', 'sports_bar', 'haze_for_days', 'style', 1),
    ('home_brewed_goodness', 'Home Brewed Goodness', 'Voor de hobbybrouw-community: gecrafte en gebottelde eigen brouwsels.', 'sports_bar', 'home_brewed_goodness', 'social', 1),
    ('ill_be_bock', 'I''ll Be Bock', 'Proef je eerste Bockbier.', 'sports_bar', 'ill_be_bock', 'style', 1),
    ('keep_your_wits', 'Keep Your Wits About You', 'Word meester in Tarwebier (Witbier).', 'sports_bar', 'keep_your_wits', 'style', 1),
    ('land_of_the_free', 'Land of the Free', 'Proef een Amerikaanse craft beer klassieker.', 'sports_bar', 'land_of_the_free', 'style', 1),
    ('la_creme_de_la_creme', 'La Crème de la Crème', 'Behaal een premium prestatie in BierKompas.', 'military_tech', 'la_creme_de_la_creme', 'milestone', 1),
    ('pucker_up', 'Pucker Up!', 'Proef een zuur bier (Sour).', 'sports_bar', 'pucker_up', 'style', 1),
    ('respect_the_kolsch', 'Respect the Kölsch', 'Eer de traditie en het erfgoed van de Kölsch.', 'sports_bar', 'respect_the_kolsch', 'style', 1),
    ('silence_of_the_lambics', 'Silence of the Lambics', 'Verken de wereld van Lambic en Geuze.', 'sports_bar', 'silence_of_the_lambics', 'style', 1),
    ('super_model', 'Super Model', 'Behaal een hoge gemiddelde beoordeling op je proeverijen.', 'military_tech', 'super_model', 'avg_rating', 1),
    ('taster_please', 'Taster, Please', 'Proef vier verschillende bierstijlen in één sessie.', 'sports_bar', 'taster_please', 'taster_flight', 4),
    ('century_club', 'The Century Club', 'Proef 100 unieke bieren van dezelfde stijl.', 'military_tech', 'century_club', 'style_count', 100),
    ('to_the_alt', 'To the Alt', 'Word meester in Düsseldorf Altbier.', 'sports_bar', 'to_the_alt', 'style', 1),
    ('trip_to_the_farm', 'Trip to the Farm', 'Bezoek een boerderijbrouwerij.', 'local_florist', 'trip_to_the_farm', 'location', 1),
    ('visit_the_beer_garden', 'Visit the Beer Garden', 'Bezoek een Beer Garden.', 'local_florist', 'visit_the_beer_garden', 'location', 1),
    ('wheel_of_styles', 'Wheel of Styles', 'Proef bier uit alle hoofdcategorieën van het Wheel of Styles.', 'military_tech', 'wheel_of_styles', 'style_count', 12)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    icon_name = excluded.icon_name,
    image_asset = excluded.image_asset,
    requirement_type = excluded.requirement_type,
    requirement_value = excluded.requirement_value;

-- ============================================================
-- add_friends.sql
-- ============================================================
-- Bier-vrienden: vriendschapsverzoeken met accepteren/weigeren.
-- Eén rij per verzoek (requester -> addressee). Bij versturen staat status op
-- 'pending'; de ontvanger ziet 'm en kan accepteren (-> 'accepted') of weigeren
-- (rij wordt verwijderd). Verstuurt iemand een verzoek terwijl de ander al een
-- verzoek naar hem/haar had staan, dan wordt dat bestaande verzoek meteen
-- geaccepteerd (wederzijdse match), zodat er nooit twee losse rijen ontstaan.

create table if not exists public.friend_requests (
    id bigint generated always as identity primary key,
    requester_id uuid not null references public.profiles(id) on delete cascade,
    addressee_id uuid not null references public.profiles(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted')),
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    constraint unique_friend_request unique (requester_id, addressee_id),
    constraint no_self_request check (requester_id <> addressee_id)
);

alter table public.friend_requests enable row level security;

drop policy if exists "Friend requests: select involved" on public.friend_requests;
create policy "Friend requests: select involved" on public.friend_requests
    for select using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "Friend requests: insert own" on public.friend_requests;
create policy "Friend requests: insert own" on public.friend_requests
    for insert with check (auth.uid() = requester_id);

drop policy if exists "Friend requests: addressee can update" on public.friend_requests;
create policy "Friend requests: addressee can update" on public.friend_requests
    for update using (auth.uid() = addressee_id);

drop policy if exists "Friend requests: involved can delete" on public.friend_requests;
create policy "Friend requests: involved can delete" on public.friend_requests
    for delete using (auth.uid() = requester_id or auth.uid() = addressee_id);

grant select, insert, update, delete on public.friend_requests to authenticated;

-- Iedereen die is ingelogd mag naam/avatar van andere profielen opzoeken om
-- vrienden te kunnen vinden en toevoegen. E-mailadressen blijven privé
-- (die worden hier niet teruggegeven).
drop function if exists public.search_profiles(text);
create or replace function public.search_profiles(p_query text)
returns table(id uuid, name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
    select p.id, p.name, p.avatar_url
    from public.profiles p
    where p.id <> auth.uid()
      and p.name ilike '%' || p_query || '%'
    order by p.name
    limit 20;
$$;

grant execute on function public.search_profiles(text) to authenticated;

-- Verstuurt een vriendschapsverzoek. Had de ander al een verzoek naar mij
-- openstaan, dan accepteert dit dat verzoek meteen in plaats van een tweede
-- (tegenovergestelde) rij aan te maken.
create or replace function public.send_friend_request(p_addressee_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_addressee_id = auth.uid() then
        raise exception 'Je kunt jezelf niet toevoegen als vriend';
    end if;

    update public.friend_requests
        set status = 'accepted', responded_at = now()
        where requester_id = p_addressee_id
          and addressee_id = auth.uid()
          and status = 'pending';

    if found then
        return;
    end if;

    insert into public.friend_requests (requester_id, addressee_id, status)
    values (auth.uid(), p_addressee_id, 'pending')
    on conflict (requester_id, addressee_id) do nothing;
end;
$$;

grant execute on function public.send_friend_request(uuid) to authenticated;

-- Accepteert of weigert een binnengekomen vriendschapsverzoek.
create or replace function public.respond_friend_request(p_requester_id uuid, p_accept boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_accept then
        update public.friend_requests
            set status = 'accepted', responded_at = now()
            where requester_id = p_requester_id
              and addressee_id = auth.uid()
              and status = 'pending';
    else
        delete from public.friend_requests
            where requester_id = p_requester_id
              and addressee_id = auth.uid()
              and status = 'pending';
    end if;
end;
$$;

grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;

-- Let op: `profiles` heeft RLS "select own" (iedereen ziet alleen zijn eigen
-- rij). Een gewone join/embed vanuit de app (bv. friend_requests -> profiles)
-- levert dus geen naam/avatar van de ánder op en toont "Onbekend". Deze twee
-- functies zijn security definer en mogen daarom wél de naam/avatar van de
-- vriend/aanvrager opzoeken, zonder de RLS van `profiles` verder open te zetten.
drop function if exists public.list_friends();
create or replace function public.list_friends()
returns table(friend_id uuid, name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
    select
        case when fr.requester_id = auth.uid() then fr.addressee_id else fr.requester_id end as friend_id,
        p.name,
        p.avatar_url
    from public.friend_requests fr
    join public.profiles p
      on p.id = case when fr.requester_id = auth.uid() then fr.addressee_id else fr.requester_id end
    where fr.status = 'accepted'
      and (fr.requester_id = auth.uid() or fr.addressee_id = auth.uid());
$$;

grant execute on function public.list_friends() to authenticated;

drop function if exists public.list_incoming_friend_requests();
create or replace function public.list_incoming_friend_requests()
returns table(requester_id uuid, name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
    select fr.requester_id, p.name, p.avatar_url
    from public.friend_requests fr
    join public.profiles p on p.id = fr.requester_id
    where fr.addressee_id = auth.uid()
      and fr.status = 'pending';
$$;

grant execute on function public.list_incoming_friend_requests() to authenticated;

-- Realtime aanzetten voor deze tabel, zodat een nieuw/geaccepteerd verzoek
-- meteen doorkomt bij de andere gebruiker, zonder dat die hoeft te verversen.
do $$
begin
    alter publication supabase_realtime add table public.friend_requests;
exception
    when duplicate_object then null;
    when undefined_object then null;
end;
$$;

-- ============================================================
-- add_cheers.sql
-- ============================================================
-- Digitale Proost: een vriend kan je vanaf zijn/haar profiel een "Proost!"
-- sturen. Bij ontvangst verschijnt er een kaart in de app (zie het Proost!-
-- scherm) met de mogelijkheid om meteen "Proost terug" te sturen.

create table if not exists public.cheers (
    id bigint generated always as identity primary key,
    sender_id uuid not null references public.profiles(id) on delete cascade,
    receiver_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    seen boolean not null default false,
    constraint no_self_cheer check (sender_id <> receiver_id)
);

-- Koppelt een "Proost terug" aan de proost waarop hij reageert. Zo kan de app
-- een reactie herkennen en daarvoor het rustige bevestigingsscherm tonen
-- (i.p.v. wéér een "Proost terug"-knop, wat een oneindige heen-en-weer keten
-- van meldingen veroorzaakte).
alter table public.cheers add column if not exists reply_to_id bigint references public.cheers(id) on delete set null;

alter table public.cheers enable row level security;

drop policy if exists "Cheers: select involved" on public.cheers;
create policy "Cheers: select involved" on public.cheers
    for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Cheers: insert own" on public.cheers;
create policy "Cheers: insert own" on public.cheers
    for insert with check (auth.uid() = sender_id);

drop policy if exists "Cheers: receiver can update" on public.cheers;
create policy "Cheers: receiver can update" on public.cheers
    for update using (auth.uid() = receiver_id);

grant select, insert, update on public.cheers to authenticated;

-- Verstuurt een proost. Beide gebruikers moeten al vrienden zijn.
-- p_reply_to_id: het id van de proost waarop dit een reactie is (optioneel).
-- Alleen geldig als díe proost ook echt door p_receiver_id aan mij is
-- gestuurd, anders zou je een willekeurige proost als "beantwoord" kunnen
-- markeren.
drop function if exists public.send_cheer(uuid);
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
end;
$$;

grant execute on function public.send_cheer(uuid, bigint) to authenticated;

-- Ongeziene proosts voor de ingelogde gebruiker, met naam/avatar van de
-- afzender (security definer omvat de RLS "select own" op `profiles`).
-- is_reply: true als dit een "Proost terug" is op een proost die ík stuurde.
drop function if exists public.list_unseen_cheers();
drop function if exists public.list_unseen_cheers();
create or replace function public.list_unseen_cheers()
returns table(id bigint, sender_id uuid, name text, avatar_url text, created_at timestamptz, is_reply boolean)
language sql
security definer set search_path = public
stable
as $$
    select c.id, c.sender_id, p.name, p.avatar_url, c.created_at, (c.reply_to_id is not null)
    from public.cheers c
    join public.profiles p on p.id = c.sender_id
    where c.receiver_id = auth.uid()
      and c.seen = false
    order by c.created_at desc;
$$;

grant execute on function public.list_unseen_cheers() to authenticated;

create or replace function public.mark_cheer_seen(p_cheer_id bigint)
returns void
language sql
security definer set search_path = public
as $$
    update public.cheers set seen = true where id = p_cheer_id and receiver_id = auth.uid();
$$;

grant execute on function public.mark_cheer_seen(bigint) to authenticated;

-- Realtime aanzetten zodat een proost meteen als pop-up verschijnt bij de
-- ontvanger, zonder te hoeven verversen.
do $$
begin
    alter publication supabase_realtime add table public.cheers;
exception
    when duplicate_object then null;
    when undefined_object then null;
end;
$$;

-- ============================================================
-- add_presence.sql
-- ============================================================
-- Online-status voor Bier-vrienden: een groene stip op de avatar als iemand
-- de app recent open had. Geen aparte presence-service nodig; de app "tikt"
-- gewoon elke X seconden een tijdstempel bij terwijl hij open is.

alter table public.profiles add column if not exists last_active_at timestamptz;

create or replace function public.touch_presence()
returns void
language sql
security definer set search_path = public
as $$
    update public.profiles set last_active_at = now() where id = auth.uid();
$$;

grant execute on function public.touch_presence() to authenticated;

-- `list_friends` (uit add_friends.sql) opnieuw gedefinieerd met een extra
-- `online`-kolom: recent (binnen 2 minuten) actief geweest. Het returntype
-- verandert, dus `create or replace` is niet genoeg: eerst droppen.
drop function if exists public.list_friends();
drop function if exists public.list_friends();
create or replace function public.list_friends()
returns table(friend_id uuid, name text, avatar_url text, online boolean)
language sql
security definer set search_path = public
stable
as $$
    select
        case when fr.requester_id = auth.uid() then fr.addressee_id else fr.requester_id end as friend_id,
        p.name,
        p.avatar_url,
        (p.last_active_at is not null and p.last_active_at > now() - interval '2 minutes') as online
    from public.friend_requests fr
    join public.profiles p
      on p.id = case when fr.requester_id = auth.uid() then fr.addressee_id else fr.requester_id end
    where fr.status = 'accepted'
      and (fr.requester_id = auth.uid() or fr.addressee_id = auth.uid());
$$;

grant execute on function public.list_friends() to authenticated;

-- ============================================================
-- add_chat.sql
-- ============================================================
-- 1-op-1 chat tussen Bier-vrienden. Geen aparte "conversations"-tabel nodig:
-- een gesprek is simpelweg alle berichten tussen twee gebruikers-id's.
-- message_type onderscheidt gewone tekst van een gedeeld bier of een
-- evenement-uitnodiging; metadata bevat de bijbehorende gegevens (jsonb).

create table if not exists public.messages (
    id bigint generated always as identity primary key,
    sender_id uuid not null references public.profiles(id) on delete cascade,
    receiver_id uuid not null references public.profiles(id) on delete cascade,
    body text not null default '',
    message_type text not null default 'text' check (message_type in ('text', 'beer_share', 'event_invite')),
    metadata jsonb,
    created_at timestamptz not null default now(),
    read_at timestamptz,
    constraint no_self_message check (sender_id <> receiver_id)
);

create index if not exists messages_conversation_idx
    on public.messages (least(sender_id, receiver_id), greatest(sender_id, receiver_id), created_at);

alter table public.messages enable row level security;

drop policy if exists "Messages: select involved" on public.messages;
create policy "Messages: select involved" on public.messages
    for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Messages: insert own" on public.messages;
create policy "Messages: insert own" on public.messages
    for insert with check (auth.uid() = sender_id);

drop policy if exists "Messages: receiver can update" on public.messages;
create policy "Messages: receiver can update" on public.messages
    for update using (auth.uid() = receiver_id);

grant select, insert, update on public.messages to authenticated;

-- Verstuurt een bericht. Beide gebruikers moeten al vrienden zijn (zelfde
-- regel als bij een proost).
create or replace function public.send_message(
    p_receiver_id uuid,
    p_body text,
    p_message_type text default 'text',
    p_metadata jsonb default null
)
returns bigint
language plpgsql
security definer set search_path = public
as $$
declare
    v_id bigint;
begin
    if p_receiver_id = auth.uid() then
        raise exception 'Je kunt jezelf geen bericht sturen';
    end if;

    if not exists (
        select 1 from public.friend_requests
        where status = 'accepted'
          and ((requester_id = auth.uid() and addressee_id = p_receiver_id)
            or (requester_id = p_receiver_id and addressee_id = auth.uid()))
    ) then
        raise exception 'Je kunt alleen vrienden een bericht sturen';
    end if;

    insert into public.messages (sender_id, receiver_id, body, message_type, metadata)
    values (auth.uid(), p_receiver_id, coalesce(p_body, ''), coalesce(p_message_type, 'text'), p_metadata)
    returning id into v_id;

    return v_id;
end;
$$;

grant execute on function public.send_message(uuid, text, text, jsonb) to authenticated;

-- Markeert alle berichten van p_other_id aan mij als gelezen.
create or replace function public.mark_messages_read(p_other_id uuid)
returns void
language sql
security definer set search_path = public
as $$
    update public.messages
        set read_at = now()
        where receiver_id = auth.uid()
          and sender_id = p_other_id
          and read_at is null;
$$;

grant execute on function public.mark_messages_read(uuid) to authenticated;

do $$
begin
    alter publication supabase_realtime add table public.messages;
exception
    when duplicate_object then null;
    when undefined_object then null;
end;
$$;

-- ============================================================
-- add_chat_photos.sql
-- ============================================================
-- Foto's versturen in de chat: nieuw message_type 'image' + een
-- Storage-bucket voor chatfoto's (zelfde opzet als de profielfoto's in
-- add_avatar.sql, maar dan per conversatie-map).

alter table public.messages drop constraint if exists messages_message_type_check;
alter table public.messages add constraint messages_message_type_check
    check (message_type in ('text', 'beer_share', 'event_invite', 'image'));

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

-- Bestandspad is "<mijn user id>/<bestandsnaam>", zodat de map-naam altijd
-- overeenkomt met de uploader. Lezen mag iedereen (publieke bucket), net als
-- bij avatars; alleen de eigenaar mag in zijn eigen map schrijven/verwijderen.
drop policy if exists "Chat images: public read" on storage.objects;
create policy "Chat images: public read" on storage.objects
    for select using (bucket_id = 'chat-images');

drop policy if exists "Chat images: insert own" on storage.objects;
create policy "Chat images: insert own" on storage.objects
    for insert with check (
        bucket_id = 'chat-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Chat images: delete own" on storage.objects;
create policy "Chat images: delete own" on storage.objects
    for delete using (
        bucket_id = 'chat-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- add_event_status.sql
-- ============================================================
-- Evenementen: goedkeuringsflow voor beheerders + "vervallen" i.p.v.
-- verwijderen, en een eenvoudige beheerder-rol.
--
-- Een beheerder is gewoon een normale gebruiker (logt in met zijn eigen
-- account) waarvan `is_admin` op true staat. Er is bewust geen los
-- "beheerder-wachtwoord" systeem gebouwd: dat zou een tweede, zwakkere
-- authenticatielaag naast Supabase Auth betekenen. Maak iemand beheerder met:
--
--   update public.profiles set is_admin = true where email = 'naam@voorbeeld.nl';

alter table public.profiles add column if not exists is_admin boolean not null default false;

alter table public.events add column if not exists status text not null default 'pending';
alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check
    check (status in ('pending', 'approved', 'cancelled'));
alter table public.events add column if not exists approved_at timestamptz;
alter table public.events add column if not exists approved_by uuid references public.profiles(id);
alter table public.events add column if not exists cancelled_at timestamptz;

-- Bestaande evenementen (vóór deze migratie) meteen als goedgekeurd
-- behandelen, anders verdwijnen ze allemaal uit de agenda.
-- (eenmalige 'pending -> approved'-update weggelaten: zou bij opnieuw draaien wachtende evenementen goedkeuren)

-- Iedereen ziet goedgekeurde en vervallen evenementen; de eigenaar ziet ook
-- zijn eigen nog-niet-goedgekeurde evenementen; beheerders zien alles.
drop policy if exists "Events: everyone can view" on public.events;
drop policy if exists "Events: view approved, own, or admin" on public.events;
create policy "Events: view approved, own, or admin" on public.events
    for select using (
        status in ('approved', 'cancelled')
        or user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Events: owner can update" on public.events;
drop policy if exists "Events: owner or admin can update" on public.events;
create policy "Events: owner or admin can update" on public.events
    for update using (
        user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- Eigenaar laat zijn eigen (goedgekeurde) evenement vervallen i.p.v. het te
-- verwijderen: blijft zichtbaar in de agenda met een "Vervallen"-stempel.
create or replace function public.cancel_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    update public.events
        set status = 'cancelled', cancelled_at = now()
        where id = p_event_id and user_id = auth.uid() and status = 'approved';
end;
$$;

grant execute on function public.cancel_event(bigint) to authenticated;

-- Beheerder keurt een nieuw evenement goed, waarna het publiek zichtbaar wordt.
create or replace function public.approve_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen evenementen goedkeuren';
    end if;

    update public.events
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_event_id and status = 'pending';
end;
$$;

grant execute on function public.approve_event(bigint) to authenticated;

-- Beheerder wijst een nieuw evenement af (nooit gepubliceerd geweest, dus
-- gewoon verwijderen in plaats van als "vervallen" te tonen).
create or replace function public.reject_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen evenementen afwijzen';
    end if;

    delete from public.events where id = p_event_id and status = 'pending';
end;
$$;

grant execute on function public.reject_event(bigint) to authenticated;

-- ============================================================
-- add_friend_suggestions.sql
-- ============================================================
-- Vriendschap-suggesties voor het "Vrienden"-tabblad op Ontdek (zoals
-- Snapchat's "Snel toevoegen"): willekeurige andere gebruikers die nog geen
-- vriend zijn en met wie nog geen verzoek open staat (in beide richtingen).

drop function if exists public.suggest_friends(int);
create or replace function public.suggest_friends(p_limit int default 12)
returns table(id uuid, name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
    select p.id, p.name, p.avatar_url
    from public.profiles p
    where p.id <> auth.uid()
      and not exists (
          select 1 from public.friend_requests fr
          where (fr.requester_id = auth.uid() and fr.addressee_id = p.id)
             or (fr.requester_id = p.id and fr.addressee_id = auth.uid())
      )
    order by random()
    limit p_limit;
$$;

grant execute on function public.suggest_friends(int) to authenticated;

-- ============================================================
-- add_user_posts.sql
-- ============================================================
-- Zelf een post plaatsen in de Ontdek-feed (naast de vaste content uit
-- add_feed.sql). Een post is een nieuw item_type 'post' in feed_items,
-- gekoppeld aan de gebruiker die 'm plaatste zodat hij/zij 'm ook weer kan
-- verwijderen. Kan veilig opnieuw worden uitgevoerd.

alter table public.feed_items add column if not exists user_id uuid references public.profiles(id) on delete cascade;
alter table public.feed_items add column if not exists avatar_url text;

alter table public.feed_items drop constraint if exists feed_items_item_type_check;
alter table public.feed_items add constraint feed_items_item_type_check
    check (item_type in ('review', 'tip', 'weetje', 'brouwerij', 'post'));

-- Iedereen mag al lezen (zie add_feed.sql). Plaatsen mag alleen als eigen
-- 'post'; de vaste content-types (review/tip/weetje/brouwerij) blijven
-- beheerd via losse SQL, niet vanuit de app.
drop policy if exists "Feed items: insert own post" on public.feed_items;
create policy "Feed items: insert own post" on public.feed_items
    for insert with check (
        auth.uid() = user_id
        and item_type = 'post'
    );

drop policy if exists "Feed items: delete own post" on public.feed_items;
create policy "Feed items: delete own post" on public.feed_items
    for delete using (auth.uid() = user_id);

grant insert, delete on public.feed_items to authenticated;

-- View opnieuw aanmaken zodat user_id/avatar_url ook meekomen (nodig om
-- "verwijderen" alleen bij je eigen posts te tonen).
drop view if exists public.feed;
create view public.feed
with (security_invoker = on) as
select
    'item-' || id as feed_key,
    item_type,
    title,
    body,
    image_url,
    author,
    rating,
    beer_id,
    brewery_id,
    null::timestamptz as event_start,
    null::text as event_location,
    user_id,
    avatar_url,
    created_at
from public.feed_items
union all
select
    'event-' || id,
    'evenement',
    name,
    description,
    null,
    null,
    null,
    null,
    null,
    start_date,
    location_name || ', ' || city,
    null::uuid as user_id,
    null::text as avatar_url,
    created_at
from public.events;

grant select on public.feed to anon, authenticated;

-- Storage-bucket voor foto's bij een post (zelfde opzet als chat-images).
insert into storage.buckets (id, name, public)
values ('feed-images', 'feed-images', true)
on conflict (id) do nothing;

drop policy if exists "Feed images: public read" on storage.objects;
create policy "Feed images: public read" on storage.objects
    for select using (bucket_id = 'feed-images');

drop policy if exists "Feed images: insert own" on storage.objects;
create policy "Feed images: insert own" on storage.objects
    for insert with check (
        bucket_id = 'feed-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Feed images: delete own" on storage.objects;
create policy "Feed images: delete own" on storage.objects
    for delete using (
        bucket_id = 'feed-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- add_tasting_notes.sql
-- ============================================================
-- BierKompas: Proefnotities ("Mijn Proefnotities" op het profiel).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Kan veilig opnieuw worden uitgevoerd.
--
-- tasting_notes: eigen aantekeningen van een gebruiker bij een bier (naam komt
-- uit lib/features/favorites/beers.dart; beer_id is optioneel omdat gebruikers
-- ook een bier kunnen noteren dat niet in die vaste lijst staat).

create table if not exists public.tasting_notes (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    beer_id bigint,
    beer_name text not null,
    note text not null,
    rating smallint not null check (rating between 1 and 5),
    created_at timestamptz not null default now()
);

create index if not exists tasting_notes_user_id_created_at_idx
    on public.tasting_notes (user_id, created_at desc);

alter table public.tasting_notes enable row level security;

drop policy if exists "Tasting notes: select own" on public.tasting_notes;
create policy "Tasting notes: select own" on public.tasting_notes
    for select using (auth.uid() = user_id);

drop policy if exists "Tasting notes: insert own" on public.tasting_notes;
create policy "Tasting notes: insert own" on public.tasting_notes
    for insert with check (auth.uid() = user_id);

drop policy if exists "Tasting notes: update own" on public.tasting_notes;
create policy "Tasting notes: update own" on public.tasting_notes
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Tasting notes: delete own" on public.tasting_notes;
create policy "Tasting notes: delete own" on public.tasting_notes
    for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.tasting_notes to authenticated;
grant usage, select on sequence public.tasting_notes_id_seq to authenticated;

-- ============================================================
-- fix_record_daily_activity_ambiguous_column.sql
-- ============================================================
-- BierKompas: echte fix voor de Bier Streak.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- record_daily_activity gaf altijd de fout "column reference current_streak
-- is ambiguous", omdat de functie een tabel met kolom current_streak/
-- longest_streak teruggeeft (RETURNS TABLE), en in de functie zelf ook
-- current_streak/longest_streak uit public.profiles las zonder tabel-alias.
-- Postgres kon dan niet weten of "current_streak" de returnwaarde of de
-- profielkolom bedoelde. Hierdoor werd de streak dus nog nooit bijgewerkt.
-- Fix: de select uit profiles krijgt een expliciete tabel-alias (p.*).

drop function if exists public.record_daily_activity(uuid);
create or replace function public.record_daily_activity(p_user_id uuid)
returns table(current_streak integer, longest_streak integer, newly_earned_badges text[])
language plpgsql
security definer set search_path = public
as $$
declare
    v_last_date date;
    v_current_streak integer;
    v_longest_streak integer;
    v_new_streak integer;
    v_today date := current_date;
    v_newly_earned text[];
begin
    select p.last_activity_date, p.current_streak, p.longest_streak
        into v_last_date, v_current_streak, v_longest_streak
        from public.profiles p
        where p.id = p_user_id
        for update;

    if not found then
        raise exception 'record_daily_activity: geen profiel gevonden voor gebruiker %', p_user_id;
    end if;

    if v_last_date = v_today then
        v_new_streak := v_current_streak;
    elsif v_last_date = v_today - 1 then
        v_new_streak := v_current_streak + 1;
    else
        v_new_streak := 1;
    end if;

    update public.profiles
        set current_streak = v_new_streak,
            longest_streak = greatest(v_longest_streak, v_new_streak),
            last_activity_date = v_today
        where id = p_user_id;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'streak'
            and b.requirement_value <= v_new_streak
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_newly_earned from inserted;

    return query select v_new_streak, greatest(v_longest_streak, v_new_streak), v_newly_earned;
end;
$$;

grant execute on function public.record_daily_activity(uuid) to authenticated;

-- ============================================================
-- add_beer_scan.sql
-- ============================================================
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
drop function if exists public.log_beer_scan(uuid, integer, text);
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

-- ============================================================
-- add_bieren_tabel.sql
-- ============================================================
-- BierKompas: bieren-tabel als bron van barcodes, beheerd door beheerders.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- De volledige bierinhoud (naam, stijl, beschrijving, ...) blijft voorlopig
-- hardcoded in de app (lib/features/favorites/beers.dart) -- deze tabel is
-- puur de koppeling bier-id <-> barcode, zodat een beheerder via de
-- admin-pagina barcodes kan instellen zonder dat de app opnieuw gebouwd
-- hoeft te worden. Naam/stijl staan er ook in, alleen zodat de beheerder
-- ziet welk bier hij aan het bewerken is.

create table if not exists public.bieren (
    id integer primary key,
    naam text not null,
    stijl text,
    brouwerij text,
    barcode text unique,
    updated_at timestamptz not null default now()
);

alter table public.bieren enable row level security;

drop policy if exists "Bieren: iedereen mag lezen" on public.bieren;
create policy "Bieren: iedereen mag lezen" on public.bieren
    for select using (true);

drop policy if exists "Bieren: alleen beheerders mogen wijzigen" on public.bieren;
create policy "Bieren: alleen beheerders mogen wijzigen" on public.bieren
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- De 14 bieren die nu al hardcoded in de app staan, met dezelfde ID's zodat
-- de koppeling klopt. Barcodes zijn de fictieve testcodes uit
-- lib/features/favorites/beers.dart -- een beheerder vervangt deze later
-- door de echte EAN-code van het bier.
insert into public.bieren (id, naam, stijl, brouwerij, barcode) values
    (1, 'Zatte', 'Tripel', E'Brouwerij \'t IJ, Amsterdam', '8710400000013'),
    (2, 'Natte', 'Dubbel', E'Brouwerij \'t IJ, Amsterdam', '8710400000020'),
    (3, 'IJwit', 'Witbier', E'Brouwerij \'t IJ, Amsterdam', '8710400000037'),
    (4, 'Columbus', 'Amber Ale', E'Brouwerij \'t IJ, Amsterdam', '8710400000044'),
    (5, 'Koperen Nacht Tripel', 'Tripel', null, '8710400000051'),
    (6, 'Amber Kompas IPA', 'IPA', null, '8710400000068'),
    (7, 'Donkere Molen Stout', 'Stout', null, '8710400000075'),
    (8, 'Zomerhaven Witbier', 'Witbier', null, '8710400000082'),
    (9, 'Oude Sluis Dubbel', 'Dubbel', null, '8710400000099'),
    (10, 'Veldkers Saison', 'Saison', null, '8710400000105'),
    (11, 'Koperen Nacht Blond', 'Blond', null, '8710400000112'),
    (12, 'Winterlicht Bock', 'Bock', null, '8710400000129'),
    (13, 'Havenmeester Pale Ale', 'Pale Ale', null, '8710400000136'),
    (14, 'Kelderzuur Kriek', 'Kriek', null, '8710400000143')
on conflict (id) do nothing;

-- user_beer_logs.beer_id verwijst nu aantoonbaar naar een bestaand bier.
alter table public.user_beer_logs drop constraint if exists user_beer_logs_beer_id_fkey;
alter table public.user_beer_logs
    add constraint user_beer_logs_beer_id_fkey
    foreign key (beer_id) references public.bieren(id)
    not valid;
alter table public.user_beer_logs validate constraint user_beer_logs_beer_id_fkey;

-- ============================================================
-- add_scan_achievements.sql
-- ============================================================
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

-- ============================================================
-- add_brewery_submissions.sql
-- ============================================================
-- BierKompas: eigen brouwerij aanmelden voor de kaart, met goedkeuring door
-- een beheerder (zelfde patroon als evenementen, zie add_event_status.sql).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

create table if not exists public.brewery_submissions (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,

    naam text not null,
    beschrijving text,

    street text not null,
    house_number text not null,
    postal_code text not null,
    city text not null,

    -- Automatisch bepaald bij het aanmelden (geocoding op het ingevulde
    -- adres). Kan null zijn als geocoding niet lukte; zo'n aanmelding kan een
    -- beheerder nog wel goedkeuren, maar verschijnt pas op de kaart zodra er
    -- coördinaten bekend zijn.
    latitude double precision,
    longitude double precision,

    photo_url text,

    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now(),
    approved_at timestamptz,
    approved_by uuid references public.profiles(id),
    rejection_reason text
);

alter table public.brewery_submissions enable row level security;

-- Iedereen ziet goedgekeurde aanmeldingen (die horen op de kaart); de
-- indiener ziet ook zijn eigen nog-niet-goedgekeurde aanmelding; beheerders
-- zien alles (voor de goedkeuringswachtrij).
drop policy if exists "Brewery submissions: view approved, own, or admin" on public.brewery_submissions;
create policy "Brewery submissions: view approved, own, or admin" on public.brewery_submissions
    for select using (
        status = 'approved'
        or user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Brewery submissions: insert own" on public.brewery_submissions;
create policy "Brewery submissions: insert own" on public.brewery_submissions
    for insert with check (user_id = auth.uid());

-- Geen update/delete-policy voor gewone gebruikers: goedkeuren/afwijzen gaat
-- uitsluitend via de onderstaande functies (security definer).

create or replace function public.approve_brewery_submission(p_submission_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen brouwerij-aanmeldingen goedkeuren';
    end if;

    update public.brewery_submissions
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.approve_brewery_submission(bigint) to authenticated;

create or replace function public.reject_brewery_submission(p_submission_id bigint, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen brouwerij-aanmeldingen afwijzen';
    end if;

    update public.brewery_submissions
        set status = 'rejected', rejection_reason = p_reason
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.reject_brewery_submission(bigint, text) to authenticated;

-- Storage-bucket voor brouwerij-foto's (publiek leesbaar, alleen de indiener
-- mag in zijn eigen map schrijven -- zelfde opzet als avatars, zie add_avatar.sql).
insert into storage.buckets (id, name, public)
values ('brewery-photos', 'brewery-photos', true)
on conflict (id) do nothing;

drop policy if exists "Brewery photos: public read" on storage.objects;
create policy "Brewery photos: public read" on storage.objects
    for select using (bucket_id = 'brewery-photos');

drop policy if exists "Brewery photos: insert own" on storage.objects;
create policy "Brewery photos: insert own" on storage.objects
    for insert with check (
        bucket_id = 'brewery-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- add_bier_toevoegen.sql
-- ============================================================
-- BierKompas: beheerders kunnen nu volledig nieuwe bieren aanmaken via de
-- admin-pagina, niet meer alleen barcodes bewerken van de 14 bieren die al
-- in de app-code stonden.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_bieren_tabel.sql (eerder uitgevoerd).

-- Volledige bierinhoud, zodat een door een beheerder aangemaakt bier er in
-- de app precies zo uitziet als de 14 bestaande (naam, stijl, brouwerij en
-- barcode stonden al in de tabel).
alter table public.bieren add column if not exists abv text;
alter table public.bieren add column if not exists beschrijving text;
alter table public.bieren add column if not exists hoe_gemaakt text;
alter table public.bieren add column if not exists stijl_info text;
alter table public.bieren add column if not exists foto_url text;

-- De 14 bestaande bieren hebben een handmatig, vast id (1 t/m 14). Nieuwe
-- bieren die een beheerder toevoegt krijgen voortaan automatisch een id
-- vanaf 1000, zodat er nooit een botsing kan ontstaan met die vaste 14.
do $mig$
begin
    if not exists (
        select 1 from pg_attribute
        where attrelid = 'public.bieren'::regclass and attname = 'id' and attidentity <> ''
    ) then
        alter table public.bieren alter column id add generated by default as identity;
        perform setval(pg_get_serial_sequence('public.bieren', 'id'), 1000, false);
    end if;
end;
$mig$;

-- ============================================================
-- add_event_registration_rpcs.sql
-- ============================================================
-- BierKompas: ontbrekende functies voor het "aanmelden voor een evenement"
-- -flow (event_registrations, zie schema.sql). De app (events_page.dart)
-- roept get_event_pending_registrations en get_event_approved_participants
-- al aan, maar deze functies stonden nog in geen enkel SQL-bestand -- zonder
-- deze migratie ziet een organisator dus nooit zijn wachtende of
-- goedgekeurde aanmeldingen (de query mislukt stil en toont een lege lijst).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist schema.sql (event_registrations-tabel + is_admin()-functie).

-- Bestaande versies (rechtstreeks in Supabase aangemaakt, niet in deze repo)
-- kunnen een ander retourtype hebben -- Postgres staat geen wijziging van het
-- retourtype toe via 'create or replace', dus eerst verwijderen.
drop function if exists public.get_event_pending_registrations(bigint);
drop function if exists public.get_event_approved_participants(bigint);

drop function if exists public.get_event_pending_registrations(bigint);
create or replace function public.get_event_pending_registrations(p_event_id bigint)
returns table(
    id bigint,
    user_id uuid,
    status text,
    created_at timestamptz,
    name text,
    avatar_url text
)
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (
        select 1 from public.events e
        where e.id = p_event_id and (e.user_id = auth.uid() or public.is_admin())
    ) then
        raise exception 'Alleen de organisator of een beheerder mag aanmeldingen bekijken';
    end if;

    return query
        select er.id, er.user_id, er.status, er.created_at, p.name, p.avatar_url
        from public.event_registrations er
        join public.profiles p on p.id = er.user_id
        where er.event_id = p_event_id and er.status = 'pending'
        order by er.created_at;
end;
$$;

grant execute on function public.get_event_pending_registrations(bigint) to authenticated;

drop function if exists public.get_event_approved_participants(bigint);
create or replace function public.get_event_approved_participants(p_event_id bigint)
returns table(
    id bigint,
    user_id uuid,
    name text,
    avatar_url text
)
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (
        select 1 from public.events e
        where e.id = p_event_id and (e.user_id = auth.uid() or public.is_admin())
    ) then
        raise exception 'Alleen de organisator of een beheerder mag deelnemers bekijken';
    end if;

    return query
        select er.id, er.user_id, p.name, p.avatar_url
        from public.event_registrations er
        join public.profiles p on p.id = er.user_id
        where er.event_id = p_event_id and er.status = 'approved'
        order by er.created_at;
end;
$$;

grant execute on function public.get_event_approved_participants(bigint) to authenticated;

-- ============================================================
-- add_friend_locations.sql
-- ============================================================
-- BierKompas: "Bierliefhebbers in de buurt" op de kaart -- een gebruiker
-- deelt zijn live locatie alleen met bevestigde vrienden, en alleen na
-- expliciete toestemming (sharing_enabled, aan te zetten in Instellingen).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_friends.sql (voor de friend_requests-tabel).

create table if not exists public.friend_locations (
    user_id uuid primary key references auth.users(id) on delete cascade,
    latitude double precision not null,
    longitude double precision not null,
    sharing_enabled boolean not null default false,
    updated_at timestamptz not null default now()
);

alter table public.friend_locations enable row level security;

-- Je eigen rij zie je altijd; een vriend zie je alleen als die zelf
-- sharing_enabled heeft aangezet.
drop policy if exists "Friend locations: select own or sharing friends" on public.friend_locations;
create policy "Friend locations: select own or sharing friends" on public.friend_locations
    for select using (
        auth.uid() = user_id
        or (
            sharing_enabled
            and exists (
                select 1 from public.friend_requests fr
                where fr.status = 'accepted'
                    and (
                        (fr.requester_id = auth.uid() and fr.addressee_id = user_id)
                        or (fr.addressee_id = auth.uid() and fr.requester_id = user_id)
                    )
            )
        )
    );

drop policy if exists "Friend locations: upsert own" on public.friend_locations;
create policy "Friend locations: upsert own" on public.friend_locations
    for insert with check (auth.uid() = user_id);

drop policy if exists "Friend locations: update own" on public.friend_locations;
create policy "Friend locations: update own" on public.friend_locations
    for update using (auth.uid() = user_id);

drop policy if exists "Friend locations: delete own" on public.friend_locations;
create policy "Friend locations: delete own" on public.friend_locations
    for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.friend_locations to authenticated;

-- Geeft de locaties van vrienden die momenteel delen, met naam/avatar erbij
-- (net als list_friends() in add_friends.sql: profiles-RLS staat een gewone
-- join niet toe, dus via een security-definer functie).
drop function if exists public.list_friend_locations();
create or replace function public.list_friend_locations()
returns table(
    friend_id uuid,
    name text,
    avatar_url text,
    latitude double precision,
    longitude double precision,
    updated_at timestamptz
)
language sql
security definer set search_path = public
stable
as $$
    select
        fl.user_id as friend_id,
        p.name,
        p.avatar_url,
        fl.latitude,
        fl.longitude,
        fl.updated_at
    from public.friend_locations fl
    join public.profiles p on p.id = fl.user_id
    join public.friend_requests fr
        on fr.status = 'accepted'
        and (
            (fr.requester_id = auth.uid() and fr.addressee_id = fl.user_id)
            or (fr.addressee_id = auth.uid() and fr.requester_id = fl.user_id)
        )
    where fl.sharing_enabled = true
        and fl.user_id <> auth.uid();
$$;

grant execute on function public.list_friend_locations() to authenticated;

-- ============================================================
-- add_horeca_submissions.sql
-- ============================================================
-- BierKompas: horeca/biergelegenheden aanmelden voor de kaart, met
-- goedkeuring door een beheerder. Exact dezelfde opzet als
-- add_brewery_submissions.sql, maar voor cafés/proeflokalen i.p.v. brouwerijen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

create table if not exists public.horeca_submissions (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,

    naam text not null,
    beschrijving text,

    street text not null,
    house_number text not null,
    postal_code text not null,
    city text not null,

    latitude double precision,
    longitude double precision,

    photo_url text,

    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now(),
    approved_at timestamptz,
    approved_by uuid references public.profiles(id),
    rejection_reason text
);

alter table public.horeca_submissions enable row level security;

drop policy if exists "Horeca submissions: view approved, own, or admin" on public.horeca_submissions;
create policy "Horeca submissions: view approved, own, or admin" on public.horeca_submissions
    for select using (
        status = 'approved'
        or user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Horeca submissions: insert own" on public.horeca_submissions;
create policy "Horeca submissions: insert own" on public.horeca_submissions
    for insert with check (user_id = auth.uid());

create or replace function public.approve_horeca_submission(p_submission_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen horeca-aanmeldingen goedkeuren';
    end if;

    update public.horeca_submissions
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.approve_horeca_submission(bigint) to authenticated;

create or replace function public.reject_horeca_submission(p_submission_id bigint, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen horeca-aanmeldingen afwijzen';
    end if;

    update public.horeca_submissions
        set status = 'rejected', rejection_reason = p_reason
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.reject_horeca_submission(bigint, text) to authenticated;

-- Zelfde storage-bucket-opzet als brouwerij-foto's.
insert into storage.buckets (id, name, public)
values ('horeca-photos', 'horeca-photos', true)
on conflict (id) do nothing;

drop policy if exists "Horeca photos: public read" on storage.objects;
create policy "Horeca photos: public read" on storage.objects
    for select using (bucket_id = 'horeca-photos');

drop policy if exists "Horeca photos: insert own" on storage.objects;
create policy "Horeca photos: insert own" on storage.objects
    for insert with check (
        bucket_id = 'horeca-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- add_beer_scan_photo.sql
-- ============================================================
-- BierKompas: naast het scannen van een barcode kan een gebruiker ook zelf
-- een foto van het bier/etiket maken en uploaden. Er is geen automatische
-- etiketherkenning -- de gebruiker kiest zelf welk bier het is uit de
-- bierlijst, en de foto wordt bewaard bij die log-regel.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_beer_scan.sql en add_scan_achievements.sql (eerder uitgevoerd).

alter table public.user_beer_logs add column if not exists photo_url text;

-- Zelfde functie als in add_scan_achievements.sql, met een extra optionele
-- p_photo_url. Moet eerst gedropt worden: anders blijft de oude 3-parameter
-- versie ernaast bestaan en wint die bij een aanroep met 3 argumenten.
drop function if exists public.log_beer_scan(uuid, integer, text);

drop function if exists public.log_beer_scan(uuid, integer, text, text);
create or replace function public.log_beer_scan(p_user_id uuid, p_beer_id integer, p_brewery text, p_photo_url text default null)
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
        insert into public.user_beer_logs (user_id, beer_id, brewery, photo_url)
        values (p_user_id, p_beer_id, p_brewery, p_photo_url);
    elsif p_photo_url is not null then
        -- Opnieuw scannen met een nieuwe foto: die foto bewaren bij de
        -- bestaande log-regel i.p.v. te negeren.
        update public.user_beer_logs
            set photo_url = p_photo_url
            where user_id = p_user_id and beer_id = p_beer_id;
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

grant execute on function public.log_beer_scan(uuid, integer, text, text) to authenticated;

-- Opslag voor de eigen bier/etiket-foto's.
insert into storage.buckets (id, name, public)
values ('beer-scan-photos', 'beer-scan-photos', true)
on conflict (id) do nothing;

drop policy if exists "Beer scan photos: public read" on storage.objects;
create policy "Beer scan photos: public read" on storage.objects
    for select using (bucket_id = 'beer-scan-photos');

drop policy if exists "Beer scan photos: insert own" on storage.objects;
create policy "Beer scan photos: insert own" on storage.objects
    for insert with check (
        bucket_id = 'beer-scan-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- add_feed_admin_management.sql
-- ============================================================
-- BierKompas: de Ontdek-feed (mini-reviews, biertips, weetjes, brouwerij-posts)
-- beheren vanuit het admin-paneel i.p.v. losse SQL-scripts.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_feed.sql en add_user_posts.sql (eerder uitgevoerd).

-- Alleen beheerders mogen de vaste content-types (review/tip/weetje/brouwerij)
-- toevoegen, bewerken of verwijderen. Gewone gebruikers blijven beperkt tot
-- hun eigen 'post' (zie add_user_posts.sql).
drop policy if exists "Feed items: admin manage curated content" on public.feed_items;
create policy "Feed items: admin manage curated content" on public.feed_items
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- add_user_posts.sql gaf alleen insert/delete; een admin moet ook kunnen bewerken.
grant update on public.feed_items to authenticated;

-- ============================================================
-- add_feed_hide_cancelled_events.sql
-- ============================================================
-- BierKompas: vervallen (en nog niet goedgekeurde) evenementen hoorden niet
-- thuis in de Ontdek-feed. De view `feed` haalde events zonder filter op
-- status op, dus stonden geannuleerde en zelfs nog niet goedgekeurde
-- evenementen daar ook tussen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_feed.sql, add_user_posts.sql en add_event_status.sql (eerder uitgevoerd).

drop view if exists public.feed;
create view public.feed
with (security_invoker = on) as
select
    'item-' || id as feed_key,
    item_type,
    title,
    body,
    image_url,
    author,
    rating,
    beer_id,
    brewery_id,
    null::timestamptz as event_start,
    null::text as event_location,
    user_id,
    avatar_url,
    created_at
from public.feed_items
union all
select
    'event-' || id,
    'evenement',
    name,
    description,
    null,
    null,
    null,
    null,
    null,
    start_date,
    location_name || ', ' || city,
    null::uuid as user_id,
    null::text as avatar_url,
    created_at
from public.events
where status = 'approved';

grant select on public.feed to anon, authenticated;

-- ============================================================
-- add_feed_post_moderation.sql
-- ============================================================
-- BierKompas: eigen posts in de Ontdek-feed krijgen nu (1) een soort-keuze
-- (Post / Mini-review / Biertip / Weetje, i.p.v. altijd alleen 'Post') en
-- (2) moeten eerst door een beheerder goedgekeurd worden voordat ze
-- zichtbaar worden, net als evenementen/brouwerijen/horeca.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_feed.sql, add_user_posts.sql en add_feed_admin_management.sql (eerder uitgevoerd).

alter table public.feed_items add column if not exists status text not null default 'approved';
alter table public.feed_items drop constraint if exists feed_items_status_check;
alter table public.feed_items add constraint feed_items_status_check
    check (status in ('pending', 'approved'));

-- Gebruikers mogen nu ook zelf 'review'/'tip'/'weetje' kiezen (naast 'post'),
-- maar niet 'brouwerij' (dat blijft redactioneel/beheerder-only). Elke eigen
-- post komt er als 'pending' in, ongeacht wat er verder wordt meegestuurd.
drop policy if exists "Feed items: insert own post" on public.feed_items;
create policy "Feed items: insert own post" on public.feed_items
    for insert with check (
        auth.uid() = user_id
        and item_type in ('post', 'review', 'tip', 'weetje')
        and status = 'pending'
    );

-- De Ontdek-feed toont voortaan alleen goedgekeurde content (en goedgekeurde
-- evenementen, zie add_feed_hide_cancelled_events.sql).
drop view if exists public.feed;
create view public.feed
with (security_invoker = on) as
select
    'item-' || id as feed_key,
    item_type,
    title,
    body,
    image_url,
    author,
    rating,
    beer_id,
    brewery_id,
    null::timestamptz as event_start,
    null::text as event_location,
    user_id,
    avatar_url,
    created_at
from public.feed_items
where status = 'approved'
union all
select
    'event-' || id,
    'evenement',
    name,
    description,
    null,
    null,
    null,
    null,
    null,
    start_date,
    location_name || ', ' || city,
    null::uuid as user_id,
    null::text as avatar_url,
    created_at
from public.events
where status = 'approved';

grant select on public.feed to anon, authenticated;

-- ============================================================
-- add_admin_stats_rpc.sql
-- ============================================================
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

-- ============================================================
-- add_beer_pairings.sql
-- ============================================================
-- BierKompas: bier-spijscombinaties ("Foodpairing Hub"), data aangeleverd door Huub.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- Smaak_Drie_Woorden, Tripadvisor_Rating en Proeflokaal_Sfeer staan in het
-- bronbestand van Huub maar waren in alle 162 rijen leeg -- de kolommen
-- blijven wel bestaan zodat een beheerder ze later per combinatie kan
-- aanvullen via de admin-pagina, zonder dat er iets verzonnen wordt.

create table if not exists public.beer_pairings (
    id bigint generated always as identity primary key,
    brouwerij text not null,
    biernaam text not null,
    link_website text,
    aanbevolen_gerecht text not null,
    aankoop_context text,
    prijs text,
    smaak_drie_woorden text,
    tripadvisor_rating numeric,
    proeflokaal_sfeer text,
    created_at timestamptz not null default now()
);

alter table public.beer_pairings enable row level security;

drop policy if exists "Pairings: iedereen mag lezen" on public.beer_pairings;
create policy "Pairings: iedereen mag lezen" on public.beer_pairings
    for select using (true);

drop policy if exists "Pairings: alleen beheerders mogen wijzigen" on public.beer_pairings;
create policy "Pairings: alleen beheerders mogen wijzigen" on public.beer_pairings
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- 162 combinaties uit "belgisch brouwerijen met spijs.xlsx" (aangeleverd door Huub).
do $mig$
begin
    if not exists (select 1 from public.beer_pairings) then
insert into public.beer_pairings
    (brouwerij, biernaam, link_website, aanbevolen_gerecht, aankoop_context, prijs, smaak_drie_woorden, tripadvisor_rating, proeflokaal_sfeer)
values
    ('Brouwerij Hoop', 'Koperen Hoogte', 'https://www.hoopbier.nl', 'Gestoofde runderwang met kruidkoek', 'Webshop / Slijterij', '€ 2', null, null, null),
    ('Brouwerij Hoop', 'Bleeke Nelis', 'https://www.hoopbier.nl', 'Gegrilde dorade met citroen en venkel', 'Webshop / Supermarkt', '€ 2', null, null, null),
    ('Brouwerij Hoop', 'Waterwolf', 'https://www.hoopbier.nl', 'Blauwaderkaas en donkere chocolade', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Brouwerij Hoop', 'Oude Zaan', 'https://www.hoopbier.nl', 'Oude Zaanse kaas met mosterd', 'Webshop / Proeflokaal', '€ 2', null, null, null),
    ('Brouwerij Hoop', 'Schotse Hooglander', 'https://www.hoopbier.nl', 'Gegrilde lamsracks met rozemarijn', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Nimf', 'https://www.naecktebrouwers.nl', 'Vegan burger met geitenkaas en vijg', 'Proeflokaal / Webshop', '€ 3', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Non', 'https://www.naecktebrouwers.nl', 'Geroosterd varkensbuikspek', 'Proeflokaal / Slijter', '€ 3', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Zonnegloed', 'https://www.naecktebrouwers.nl', 'Gebraden kip met citroenkruiden', 'Webshop / Slijterij', '€ 2', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Grand Cru', 'https://www.naecktebrouwers.nl', 'Rijpe boerenkaas met noten', 'Proeflokaal / Slijter', '€ 3', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Spits', 'https://www.naecktebrouwers.nl', 'Gestoofde mosselen met patat', 'Slijterij / Horeca', '€ 2', null, null, null),
    ('Wispe Brouwerij', 'Wispe Wit', 'https://www.wispe.nl', 'Gestoomde kabeljauw met citroen butter sauce', 'Webshop / Grand Café', '€ 2', null, null, null),
    ('Wispe Brouwerij', 'Wispe Blond', 'https://www.wispe.nl', 'Beef Teriyaki en pikante kip', 'Webshop / Grand Café', '€ 2', null, null, null),
    ('Wispe Brouwerij', 'Wispe IPA', 'https://www.wispe.nl', 'Black Angus burger met cheddar en bacon', 'Webshop / Grand Café', '€ 3', null, null, null),
    ('Wispe Brouwerij', 'Wispe Tripel', 'https://www.wispe.nl', 'Gegrilde lamskotelet met tijm', 'Webshop / Grand Café', '€ 3', null, null, null),
    ('Wispe Brouwerij', 'Wispe Quadrupel', 'https://www.wispe.nl', 'Biefstuk met champignons en boerenkaas', 'Webshop / Grand Café', '€ 3', null, null, null),
    ('Wispe Brouwerij', 'Wispe Porter', 'https://www.wispe.nl', 'Puur chocoladedessert of warme brownie', 'Webshop / Grand Café', '€ 3', null, null, null),
    ('Rock City Brewing', 'Shaky Bones DDH IPA', 'https://rockcitybrewing.nl', 'Low & slow smoked pulled pork', 'Webshop / Brewpub', '€ 3', null, null, null),
    ('Rock City Brewing', 'Koene Ridder Tripel', 'https://rockcitybrewing.nl', 'Gegrilde spareribs met barbecuesaus', 'Webshop / Brewpub', '€ 2', null, null, null),
    ('Rock City Brewing', 'Buried Treasure Double Stout', 'https://rockcitybrewing.nl', 'Smoked brisket en blauwe schimmelkaas', 'Webshop / Brewpub', '€ 4', null, null, null),
    ('Rock City Brewing', 'Tropical White', 'https://rockcitybrewing.nl', 'Mexicaanse taco''s met limoen en vis', 'Webshop / Brewpub', '€ 3', null, null, null),
    ('Rock City Brewing', 'Twisted Blond', 'https://rockcitybrewing.nl', 'Gegrilde kipsaté met pinda-kokossaus', 'Webshop / Brewpub', '€ 3', null, null, null),
    ('Jopen', 'Mooi Nel IPA', 'https://www.jopenkerk.nl', 'Indiaase curry of pittige kip', 'Supermarkt / Jopenkerk', '€ 2', null, null, null),
    ('Jopen', 'Koyt', 'https://www.jopenkerk.nl', 'Gestoofd wild met stoofperen', 'Webshop / Jopenkerk', '€ 3', null, null, null),
    ('Jopen', 'Hoppenbier', 'https://www.jopenkerk.nl', 'Jonge geitenkaas op geroosterd brood', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Jopen', 'Lentebier', 'https://www.jopenkerk.nl', 'Asperges op traditionele wijze', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Jopen', 'Jacobus RP Pale Ale', 'https://www.jopenkerk.nl', 'Gegrilde hamburgers en cheddarkaas', 'Webshop / Jopenkerk', '€ 2', null, null, null),
    ('Jopen', 'Ongelovige Thomas', 'https://www.jopenkerk.nl', 'Oude boerenkaas of zware wildstoof', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Hertog Jan', 'Grand Prestige', 'https://www.hertogjan.nl', 'Rijpe rijpingskaas of pure chocolademousse', 'Supermarkt / Slijter', '€ 3', null, null, null),
    ('Hertog Jan', 'Bockbier', 'https://www.hertogjan.nl', 'Klassiek draadjesvlees met rode kool', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Hertog Jan', 'Tripel', 'https://www.hertogjan.nl', 'Spaanse paella met gamba''s en kip', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('Hertog Jan', 'Karakter', 'https://www.hertogjan.nl', 'Gegrilde varkenshaas met champignonsaus', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('Brouwerij ''t IJ', 'Zatte Tripel', 'https://www.brouwerijij.nl', 'Oude Amsterdamse kaas en bitterballen', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Brouwerij ''t IJ', 'Natte Dubbel', 'https://www.brouwerijij.nl', 'Lamskoteletten of geroosterde groenten', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Brouwerij ''t IJ', 'IJwit', 'https://www.brouwerijij.nl', 'Thaise vissalade met koriander en limoen', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Brouwerij ''t IJ', 'IIPA', 'https://www.brouwerijij.nl', 'Pikante nacho''s met jalapeños', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Brouwerij ''t IJ', 'Vrij (0.5%)', 'https://www.brouwerijij.nl', 'Verse tonijnsalade of lichte pasta', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Stadsbrouwerij De Drie Ringen', 'Amersfoorts Blond', 'https://www.drie-ringen.nl', 'Klassiek plankje Hollandse kazen', 'Slijter / Proeflokaal', '€ 2', null, null, null),
    ('Stadsbrouwerij De Drie Ringen', 'Vuursteentje', 'https://www.drie-ringen.nl', 'Gegrild rood vlees met peperjus', 'Slijter / Proeflokaal', '€ 3', null, null, null),
    ('Stadsbrouwerij De Drie Ringen', 'Stadsbock', 'https://www.drie-ringen.nl', 'Herfststamppot met rookworst', 'Slijter / Proeflokaal', '€ 3', null, null, null),
    ('Uiltje Brewing Company', 'Bird of Prey IPA', 'https://www.uiltjebrewing.com', 'Pikante Indiaase vindaloo of taco''s', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Uiltje Brewing Company', 'Trackdown Pale Ale', 'https://www.uiltjebrewing.com', 'Gegrilde kipsalade of gegrilde vis', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Uiltje Brewing Company', 'Dr. Raptor Imperial IPA', 'https://www.uiltjebrewing.com', 'Rijke blauwschimmelkaas of gegrilde ribeye', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Uiltje Brewing Company', 'Prima Donna', 'https://www.uiltjebrewing.com', 'Citroen meringue taart of verse aardbeien', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Texelse Bierbrouwerij', 'Skuumkoppe', 'https://www.texels.nl', 'Texels lamsvlees of romige oude kaas', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Texelse Bierbrouwerij', 'Texels Tuunwal Tripel', 'https://www.texels.nl', 'Gegrilde varkenshaas met honing-mosterd', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Texelse Bierbrouwerij', 'Texels Overzee IPA', 'https://www.texels.nl', 'Garnalencroquetten of gebakken schol', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Texelse Bierbrouwerij', 'Texels Stormbock', 'https://www.texels.nl', 'Rijke hazengoulash met rode kool', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('vandeStreek bier', 'Playground IPA (0.5%)', 'https://www.vandestreekbier.nl', 'Lichte gegrilde groenten en geitenkaas', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('vandeStreek bier', 'Hazy Weekend', 'https://www.vandestreekbier.nl', 'Mexicaanse nacho''s met guacamole', 'Supermarkt / Webshop', '€ 3', null, null, null),
    ('vandeStreek bier', 'Turf & Jenever', 'https://www.vandestreekbier.nl', 'Gerookte zalm en rijke eend', 'Webshop / Slijterij', '€ 4', null, null, null),
    ('vandeStreek bier', 'Broeders Blond', 'https://www.vandestreekbier.nl', 'Gegrilde kipsaté met satésaus', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Brouwerij Kompaan', 'Bondgenoot Pale Ale', 'https://www.kompaanbier.nl', 'Fish and chips met remouladesaus', 'Webshop / Craft Bar', '€ 2', null, null, null),
    ('Brouwerij Kompaan', 'Bloedbroeder', 'https://www.kompaanbier.nl', 'Blackened steak met pepersaus', 'Webshop / Craft Bar', '€ 3', null, null, null),
    ('Brouwerij Kompaan', 'Handlanger Double IPA', 'https://www.kompaanbier.nl', 'Pikante chorizo of gerookte ribs', 'Webshop / Craft Bar', '€ 3', null, null, null),
    ('Brouwerij Kompaan', 'Levensgenieter', 'https://www.kompaanbier.nl', 'Verse caesar salade met kip', 'Webshop / Craft Bar', '€ 2', null, null, null),
    ('Brouwerij De Hemel', 'Nieuw Liefde', 'https://www.brouwerijdeemmer.nl', 'Lichte zomersalades en jonge kaas', 'Proeflokaal / Slijterij', '€ 2', null, null, null),
    ('Brouwerij De Hemel', 'Helse Engel', 'https://www.brouwerijdeemmer.nl', 'Gegrilde ribeye met kruidenboter', 'Proeflokaal / Slijterij', '€ 3', null, null, null),
    ('Brouwerij De Hemel', 'Serafijn', 'https://www.brouwerijdeemmer.nl', 'Wildzwijnstoofschotel met cranberry', 'Proeflokaal / Slijterij', '€ 3', null, null, null),
    ('Maximus Brouwerij', 'Pandora Pale Ale', 'https://www.maximusbrouwerij.nl', 'Gegrilde kip en milde curry''s', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Maximus Brouwerij', 'Brutus', 'https://www.maximusbrouwerij.nl', 'Smoked brisket en gerookte amandelen', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Maximus Brouwerij', 'Little Session IPA', 'https://www.maximusbrouwerij.nl', 'Lichte garnalencocktail', 'Webshop / Slijterij', '€ 2', null, null, null),
    ('Kaapse Brouwerij', 'Kaapse Karel', 'https://www.kaapsebrouwers.nl', 'Pikante streetfood en Koreaanse fried chicken', 'Webshop / Fenix Food', '€ 3', null, null, null),
    ('Kaapse Brouwerij', 'Kaapse Harrie', 'https://www.kaapsebrouwers.nl', 'Verse oesters of ceviche', 'Webshop / Fenix Food', '€ 3', null, null, null),
    ('Kaapse Brouwerij', 'Kaapse Carrie', 'https://www.kaapsebrouwers.nl', 'Affogato dessert of tiramisu', 'Webshop / Slijterij', '€ 4', null, null, null),
    ('Oproer Brouwerij', '24/7 Session IPA', 'https://www.Oproer.nl', 'Vegan shoarma met knoflooksaus', 'Webshop / Restobar', '€ 2', null, null, null),
    ('Oproer Brouwerij', 'Imperial Stout', 'https://www.Oproer.nl', 'Vegan chocoladetaart met framboos', 'Webshop / Restobar', '€ 4', null, null, null),
    ('Oproer Brouwerij', 'Cosmic IPA', 'https://www.Oproer.nl', 'Pikante curry''s met kokosmelk', 'Webshop / Restobar', '€ 3', null, null, null),
    ('Frontaal Brewing Co.', 'Juice Punch', 'https://www.frontaalbrewingcompany.com', 'Gegrilde zalm met mango salsa', 'Webshop / Craft Bar', '€ 3', null, null, null),
    ('Frontaal Brewing Co.', 'Bulldog', 'https://www.frontaalbrewingcompany.com', 'Rijke stoofschotel met ontbijtkoek', 'Webshop / Craft Bar', '€ 3', null, null, null),
    ('Frontaal Brewing Co.', 'Deer Hunter', 'https://www.frontaalbrewingcompany.com', 'Puur chocolade soufflé', 'Webshop / Craft Bar', '€ 5', null, null, null),
    ('Frontaal Brewing Co.', 'Andreas', 'https://www.frontaalbrewingcompany.com', 'Rijpe camembert met toast', 'Webshop / Craft Bar', '€ 3', null, null, null),
    ('Brouwerij Kees', 'Export Porter 1750', 'https://www.brouwerijkees.nl', 'Blauwe schimmelkaas (Stilton)', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Brouwerij Kees', 'Haze & Kicks', 'https://www.brouwerijkees.nl', 'Crispy calamari met citroenmayonaise', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Brouwerij Kees', 'Caramel Fudge Stout', 'https://www.brouwerijkees.nl', 'Vanille-ijs met karamelsaus', 'Webshop / Slijterij', '€ 4', null, null, null),
    ('De Halve Maan (NL distribution)', 'Straffe Hendrik Tripel', 'https://www.brouwerijdehalvemaan.nl', 'Rijke vissoep met rouille', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('De Halve Maan (NL distribution)', 'Brugse Zot Blond', 'https://www.brouwerijdehalvemaan.nl', 'Gegrilde kalfskotelet', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Brouwerij De Molen', 'Hel & Verdoemenis', 'https://www.geitenbrei.nl', 'Rijke vacherin mont d''or of pure chocola', 'Webshop / Proeflokaal', '€ 4', null, null, null),
    ('Brouwerij De Molen', 'Bommen & Granaten', 'https://www.geitenbrei.nl', 'Rijpe blauwe kaas of gedroogde vijgen', 'Webshop / Proeflokaal', '€ 4', null, null, null),
    ('Brouwerij De Molen', 'Op & Top', 'https://www.geitenbrei.nl', 'Lichte barbecue gerechten en burgers', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Brouwerij De Molen', 'Dag & Nacht', 'https://www.geitenbrei.nl', 'Oude brokkelkaas en walnoten', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Brouwerij ''t IJ x Duvel', 'IJbok', 'https://www.brouwerijduvelmoortgat.nl', 'Gestoofde hertenbiefstuk met rode kool', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Uiltje Brewing Company', 'Sequence Series Stout', 'https://www.brouwerijhetuiltje.nl', 'Tiramisu of chocolade mousse', 'Webshop / Craft Bar', '€ 5', null, null, null),
    ('Brouwerij Leeuw', 'Valkenburgs Wit', 'https://www.brouwerijdeleeuw.nl', 'Lichte zomersalades met geitenkaas', 'Slijterij / Horeca', '€ 2', null, null, null),
    ('Grolsch Proefbrouwerij', 'Karakter', 'https://www.grolsch.nl', 'Stoofvlees met friet', 'Supermarkt / Horeca', '€ 1', null, null, null),
    ('Grolsch Proefbrouwerij', 'Weizen', 'https://www.grolsch.nl', 'Garnalen en verse vissalades', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Sint Christoffel', 'Christoffel Bier', 'https://www.brouwerijstchristoffel.nl', 'Duitse bratwurst met zuurkool', 'Slijterij / Webshop', '€ 2', null, null, null),
    ('Sint Christoffel', 'Christoffel Robertus', 'https://www.brouwerijstchristoffel.nl', 'Gegrild kalfsvlees met jus', 'Slijterij / Webshop', '€ 2', null, null, null),
    ('Brand Bierbrouwerij', 'Brand Imperator', 'https://www.brand.nl', 'Gestoofde konijnenbout met pruimen', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Brand Bierbrouwerij', 'Brand IPA', 'https://www.brand.nl', 'Aziatische roerbak met chili', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Brand Bierbrouwerij', 'Brand Dubbelbock', 'https://www.brand.nl', 'Klassieke hachee met aardappelpuree', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Lindeboom Brouwerij', 'Gouverneur Blond', 'https://www.brouwerijlindeboom.nl', 'Gegrilde tonijnsteak', 'Slijterij / Supermarkt', '€ 2', null, null, null),
    ('Lindeboom Brouwerij', 'Gouverneur Dubbel', 'https://www.brouwerijlindeboom.nl', 'Lamsrack met tijmjus', 'Slijterij / Supermarkt', '€ 2', null, null, null),
    ('Lindeboom Brouwerij', 'Gouverneur Stout', 'https://www.brouwerijlindeboom.nl', 'Oude Limburgse grottenkaas', 'Slijterij / Supermarkt', '€ 2', null, null, null),
    ('Gulpener Bierbrouwerij', 'Oer-Pilsner', 'https://www.brouwerijgulpener.nl', 'Verse oesters of gebakken mosselen', 'Supermarkt / Horeca', '€ 1', null, null, null),
    ('Gulpener Bierbrouwerij', 'Château Neercanne', 'https://www.brouwerijgulpener.nl', 'Gastronomisch kalfsvlees met truffel', 'Webshop / Horeca', '€ 6', null, null, null),
    ('Gulpener Bierbrouwerij', 'IJsbock', 'https://www.brouwerijgulpener.nl', 'Rijke appeltaart met vanille-ijs', 'Supermarkt / Webshop', '€ 3', null, null, null),
    ('Gulpener Bierbrouwerij', 'Limburgs Land Pils', 'https://www.brouwerijgulpener.nl', 'Frise salade met geitenkaas', 'Supermarkt / Horeca', '€ 1', null, null, null),
    ('Gulpener Bierbrouwerij', 'Gerardus Dubbel', 'https://www.brouwerijgulpener.nl', 'Klassieke Limburgse zuurvlees', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Brouwerij Eem', 'Eem Bitter', 'https://www.brouwerijceven.nl', 'Klassieke Engelse cheddar cheese', 'Webshop / Slijterij', '€ 2', null, null, null),
    ('Brouwerij Eem', 'Eem Stout', 'https://www.brouwerijceven.nl', 'Oesters of roodschimmelkaas', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('La Trappe Trappist', 'La Trappe Blond', 'https://www.brouwerijdekoningshoeven.nl', 'Gegrilde kip en milde visgerechten', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('La Trappe Trappist', 'La Trappe Dubbel', 'https://www.brouwerijdekoningshoeven.nl', 'Gestoofde kalfswang met gegrilde groenten', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('La Trappe Trappist', 'La Trappe Tripel', 'https://www.brouwerijdekoningshoeven.nl', 'Pikante Aziatische gerechten of eend', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('La Trappe Trappist', 'La Trappe Quadrupel', 'https://www.brouwerijdekoningshoeven.nl', 'Blauwe schimmelkaas of dadelcake', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('La Trappe Trappist', 'La Trappe ISID''OR', 'https://www.brouwerijdekoningshoeven.nl', 'Gegrilde varkenshaas met champignons', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('La Trappe Trappist', 'La Trappe White Trappist', 'https://www.brouwerijdekoningshoeven.nl', 'Lichte vissalades met citroendressing', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Trappistenbrouwerij De Kievit', 'Zundert 8', 'https://www.zunderttrappist.nl', 'Geroosterd wildschijn of gegrilde steak', 'Slijterij / Webshop', '€ 2', null, null, null),
    ('Trappistenbrouwerij De Kievit', 'Zundert 10', 'https://www.zunderttrappist.nl', 'Oude trappistenkaas of stoofschotel', 'Slijterij / Webshop', '€ 3', null, null, null),
    ('Het Anker (NL Horeca)', 'Gouden Carolus Classic', 'https://www.brouwerijhetanker.be', 'Gestoofde runderkonijn met pruimen', 'Slijterij / Horeca', '€ 2', null, null, null),
    ('Het Anker (NL Horeca)', 'Gouden Carolus Tripel', 'https://www.brouwerijhetanker.be', 'Garnalencroquetten of gegrilde kabeljauw', 'Slijterij / Horeca', '€ 2', null, null, null),
    ('Oirschots Bier', 'Oirschots Blond', 'https://www.brouwerijvandeoirschotse.nl', 'Boerenkaasplankje van lokale boerderij', 'Slijterij / Horeca', '€ 2', null, null, null),
    ('Oirschots Bier', 'Oirschots Dubbel', 'https://www.brouwerijvandeoirschotse.nl', 'Gegrilde speklappen met appelmoes', 'Slijterij / Horeca', '€ 2', null, null, null),
    ('St. Bernardus (NL distribution)', 'Abt 12', 'https://www.brouwerijstbernardus.be', 'Rijpe stilton en pure chocolade', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('St. Bernardus (NL distribution)', 'Prior 8', 'https://www.brouwerijstbernardus.be', 'Stoofvlees met frites en mayonaise', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('St. Bernardus (NL distribution)', 'Tripel', 'https://www.brouwerijstbernardus.be', 'Gegrild kalfsvlees met citroen', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('St. Bernardus (NL distribution)', 'Wit', 'https://www.brouwerijstbernardus.be', 'Thaise salades en gewokte garnalen', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('Oirschotse Brouwerij', 'Zomerblond', 'https://www.vandeoirschotse.nl', 'Lichte kipsalade met verse ananas', 'Slijterij / Lokaal', '€ 2', null, null, null),
    ('Brouwerij Hoop', 'Czaar Peter', 'https://www.brouwerijhoop.nl', 'Rijke choco-lava cake met bosvruchten', 'Webshop / Proeflokaal', '€ 3', null, null, null),
    ('Brouwerij Hoop', 'Oudt Zaan', 'https://www.brouwerijhoop.nl', 'Hollandse stamppot rauwe andijvie', 'Webshop / Proeflokaal', '€ 2', null, null, null),
    ('Wispe Brouwerij', 'Wispe Session IPA', 'https://www.wispe.nl', 'Mexicaanse nacho''s met guacamole', 'Webshop / Grand Café', '€ 2', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Elegast', 'https://www.naecktebrouwers.nl', 'Rijk wild zwijn rollade', 'Proeflokaal / Slijter', '€ 3', null, null, null),
    ('Rock City Brewing', 'Second Date DIPA', 'https://rockcitybrewing.nl', 'Pikante buffalo chicken wings', 'Webshop / Brewpub', '€ 3', null, null, null),
    ('Jopen', 'Heavy Cross', 'https://www.jopenkerk.nl', 'Blauwe schimmelkaas met vijgenbrood', 'Webshop / Jopenkerk', '€ 4', null, null, null),
    ('Brouwerij ''t IJ', 'Biri', 'https://www.brouwerijij.nl', 'Verse taco''s met lime en koriander', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Uiltje Brewing Company', 'Pineapple Weizen', 'https://www.uiltjebrewing.com', 'Pikante Surinaamse roti', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('vandeStreek bier', 'Grave Digger', 'https://www.vandestreekbier.nl', 'Rijke fudge brownie met noten', 'Webshop / Slijterij', '€ 4', null, null, null),
    ('Brouwerij Kompaan', 'Badgast', 'https://www.kompaanbier.nl', 'Gegrilde witvis met citroen', 'Webshop / Craft Bar', '€ 2', null, null, null),
    ('Maximus Brouwerij', 'Dakota', 'https://www.maximusbrouwerij.nl', 'Gegrilde lamskoteletten', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Frontaal Brewing Co.', 'Churchill', 'https://www.frontaalbrewingcompany.com', 'Boerenkaas met piccalilly', 'Webshop / Craft Bar', '€ 3', null, null, null),
    ('Brouwerij Kees', 'Peated Imperial Stout', 'https://www.brouwerijkees.nl', 'Gerookte zalm en droge worst', 'Webshop / Slijterij', '€ 4', null, null, null),
    ('Brouwerij De Molen', 'Vuur & Vlam', 'https://www.geitenbrei.nl', 'Indiase kip tikka masala', 'Webshop / Proeflokaal', '€ 3', null, null, null),
    ('Texelse Bierbrouwerij', 'Vrijbuiter', 'https://www.texels.nl', 'Geroosterde amandelen en oude kaas', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('La Trappe Trappist', 'La Trappe Nillis (0.0%)', 'https://www.brouwerijdekoningshoeven.nl', 'Verse caesar salade', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Trappistenbrouwerij De Kievit', 'Zundert 4', 'https://www.zunderttrappist.nl', 'Lichte quiche met prei en geitenkaas', 'Slijterij / Webshop', '€ 2', null, null, null),
    ('Kaapse Brouwerij', 'Kaapse Nelis', 'https://www.kaapsebrouwers.nl', 'Klassieke Engelse fish and chips', 'Webshop / Fenix Food', '€ 2', null, null, null),
    ('Oproer Brouwerij', 'Subculture', 'https://www.Oproer.nl', 'Vegan mushroom risotto', 'Webshop / Restobar', '€ 3', null, null, null),
    ('Stadsbrouwerij De Drie Ringen', 'Klassieker Blond', 'https://www.drie-ringen.nl', 'Kabeljauw uit de oven', 'Slijter / Proeflokaal', '€ 2', null, null, null),
    ('Brouwerij De Hemel', 'Lazarus', 'https://www.brouwerijdeemmer.nl', 'Panna cotta met rode vruchten', 'Proeflokaal / Slijterij', '€ 3', null, null, null),
    ('Gulpener Bierbrouwerij', 'Ur-Weizen', 'https://www.brouwerijgulpener.nl', 'Beierse pretzel met spundekäs', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Brand Bierbrouwerij', 'Brand Weizen', 'https://www.brand.nl', 'Gebakken sliptong met citroen', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Lindeboom Brouwerij', 'Kersenbier', 'https://www.brouwerijlindeboom.nl', 'Kersentaart of chocolademousse', 'Slijterij / Supermarkt', '€ 2', null, null, null),
    ('Brouwerij Hoop', 'Volendamer DBL', 'https://www.brouwerijhoop.nl', 'Gestoofde paling in groen', 'Webshop / Proeflokaal', '€ 3', null, null, null),
    ('Wispe Brouwerij', 'Wispe Weizen', 'https://www.wispe.nl', 'Bratwurst met zuurkool en mosterd', 'Webshop / Grand Café', '€ 2', null, null, null),
    ('De Naeckte Brouwers', 'Naeckte Koez', 'https://www.naecktebrouwers.nl', 'Duitse schnitzel met citroen', 'Proeflokaal / Slijter', '€ 2', null, null, null),
    ('Rock City Brewing', 'Buried Treasure Vanilla', 'https://rockcitybrewing.nl', 'Affogato vanille-ijs met espresso', 'Webshop / Brewpub', '€ 4', null, null, null),
    ('Jopen', 'Sin & Remorse', 'https://www.jopenkerk.nl', 'Rijke vacherin mont d''or', 'Webshop / Jopenkerk', '€ 4', null, null, null),
    ('Brouwerij ''t IJ', 'Columbus', 'https://www.brouwerijij.nl', 'Gegrild lamsvlees met knoflook', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Uiltje Brewing Company', 'SFC Session IPA', 'https://www.uiltjebrewing.com', 'Klassieke vette Smashburger', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('vandeStreek bier', 'Hop Art', 'https://www.vandestreekbier.nl', 'Pikante chorizo pizza', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Brouwerij Kompaan', 'Wout Imperial Stout', 'https://www.kompaanbier.nl', 'Puur chocolade truffels', 'Webshop / Craft Bar', '€ 4', null, null, null),
    ('Maximus Brouwerij', 'Sura', 'https://www.maximusbrouwerij.nl', 'Klassieke Thaise groene curry', 'Webshop / Slijterij', '€ 3', null, null, null),
    ('Frontaal Brewing Co.', 'Rhodesian', 'https://www.frontaalbrewingcompany.com', 'Gestoofde kalfswang met vijgen', 'Webshop / Craft Bar', '€ 4', null, null, null),
    ('Brouwerij Kees', 'Session IPA', 'https://www.brouwerijkees.nl', 'Verse caesar salade met garnalen', 'Webshop / Slijterij', '€ 2', null, null, null),
    ('Brouwerij De Molen', 'Mooi & Meedogenloos', 'https://www.geitenbrei.nl', 'Rijke boerenkaas met vijgencompote', 'Webshop / Proeflokaal', '€ 4', null, null, null),
    ('Texelse Bierbrouwerij', 'Springtij', 'https://www.texels.nl', 'Verse asperges met eiersalade', 'Supermarkt / Webshop', '€ 2', null, null, null),
    ('Kaapse Brouwerij', 'Kaapse Bea', 'https://www.kaapsebrouwers.nl', 'Zware runderstoofschotel', 'Webshop / Fenix Food', '€ 3', null, null, null),
    ('La Trappe Trappist', 'La Trappe Bockbier', 'https://www.brouwerijdekoningshoeven.nl', 'Wildzwijn biefstuk met vossenbessen', 'Supermarkt / Proeflokaal', '€ 2', null, null, null),
    ('Gulpener Bierbrouwerij', 'Sterk Rogge Tripel', 'https://www.gulpener.nl', 'Gegrild buikspek met ketjap', 'Supermarkt / Horeca', '€ 2', null, null, null),
    ('Hertog Jan', 'Enkel', 'https://www.hertogjan.nl', 'Lichte kipgerechten of gegrilde courgette', 'Supermarkt / Slijter', '€ 2', null, null, null),
    ('Brouwerij Hoop', 'Gooische Stout', 'https://www.brouwerijhoop.nl', 'Oesters met citroen en sjalot', 'Webshop / Proeflokaal', '€ 3', null, null, null),
    ('Wispe Brouwerij', 'Wispe Blonde Bock', 'https://www.wispe.nl', 'Gegrilde eendenborst met sinaasappelsaus', 'Webshop / Grand Café', '€ 2', null, null, null),
    ('Rock City Brewing', 'Hazy Pale Ale', 'https://rockcitybrewing.nl', 'Fish taco''s met koolsla', 'Webshop / Brewpub', '€ 2', null, null, null);
    end if;
end;
$mig$;

-- ============================================================
-- add_videos.sql
-- ============================================================
-- BierKompas: video-reel ("Brouwerij Highlights"), beheerd door beheerders.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- De app toont deze video's als een horizontale "reel" op de Ontdek-pagina
-- (zie bierkompas paginas/brouwerij_highlights_reels). Zolang een beheerder
-- hier niets heeft toegevoegd, toont de app een lege staat -- er wordt geen
-- nepcontent verzonnen.

create table if not exists public.videos (
    id bigint generated always as identity primary key,
    title text not null,
    category text not null default 'Tasting',
    thumbnail_url text not null,
    video_url text not null,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.videos enable row level security;

drop policy if exists "Videos: iedereen mag lezen" on public.videos;
create policy "Videos: iedereen mag lezen" on public.videos
    for select using (true);

drop policy if exists "Videos: alleen beheerders mogen wijzigen" on public.videos;
create policy "Videos: alleen beheerders mogen wijzigen" on public.videos
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- ============================================================
-- add_feed_seed_content.sql
-- ============================================================
-- BierKompas: 20 redactionele Ontdek-feed items (weetjes, biertips,
-- mini-reviews, brouwerijposts) aangeleverd door Mayson als testdata om de
-- Ontdek-pagina te vullen. Zelfde soort content als wat al via het
-- admin-paneel (tabblad "Ontdek-feed") handmatig toegevoegd kan worden.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_feed.sql (en idealiter add_feed_post_moderation.sql,
-- al werkt dit ook zonder -- deze rijen hebben sowieso geen 'status'-kolom nodig
-- omdat redactionele content altijd meteen zichtbaar is).

do $mig$
begin
    if not exists (select 1 from public.feed_items where title = 'Wist je dat bier duizenden jaren oud is?') then
insert into public.feed_items (item_type, title, body, author) values
    ('weetje', 'Wist je dat bier duizenden jaren oud is?', 'Bier behoort tot de oudste alcoholische dranken ter wereld. Er zijn aanwijzingen dat mensen al duizenden jaren geleden bier brouwden. In de oudheid was bier bovendien niet alleen een drankje, maar ook een belangrijk onderdeel van het dagelijkse voedingspatroon.', 'BierKompas'),
    ('tip', 'Proef eerst de geur', 'Ruik even aan je bier voordat je een slok neemt. Hop kan aroma''s geven die doen denken aan citrus, tropisch fruit, bloemen of dennen. Door eerst te ruiken herken je vaak meer smaken tijdens het drinken.', 'BierKompas'),
    ('review', 'Een frisse Blond voor een zonnige dag', 'Een blond bier is vaak een fijne keuze wanneer je iets fris en toegankelijk zoekt. Verwacht een lichte moutigheid, zachte bitterheid en een frisse afdronk. Vooral lekker goed gekoeld op een zonnige middag.', 'BierKompas'),
    ('weetje', 'Niet iedere IPA is super bitter', 'IPA staat bekend om zijn hopkarakter, maar dat betekent niet dat iedere IPA extreem bitter is. Moderne IPA''s kunnen juist veel aroma''s van citrus en tropisch fruit hebben met een relatief zachte bitterheid.', 'BierKompas'),
    ('tip', 'Drink je bier uit het juiste glas', 'Het glas kan invloed hebben op hoe je bier ruikt en proeft. Een tulpvormig glas houdt aroma''s beter vast en is daardoor interessant voor speciaalbier met veel geur.', 'BierKompas'),
    ('brouwerij', 'Brouwerij Homeland – bier met een maritiem tintje', 'Brouwerij Homeland is gevestigd op het historische Marineterrein in Amsterdam. De brouwerij heeft een duidelijke link met de maritieme geschiedenis van de locatie. Een mooi voorbeeld van hoe een brouwerij zijn omgeving kan verwerken in zijn identiteit en bier.', 'BierKompas'),
    ('review', 'Tijd voor een stevige Tripel', 'Zin in iets krachtigers? Een Belgische Tripel combineert vaak een stevige alcoholwarmte met fruitige en kruidige tonen. Neem rustig de tijd voor iedere slok: dit is een bier om te ontdekken, niet om snel achterover te slaan.', 'BierKompas'),
    ('weetje', 'Waar komt de graansmaak vandaan?', 'Gerst is voor veel bieren het belangrijkste graan. Tijdens het brouwen worden de suikers uit het graan vrijgemaakt. Die suikers worden vervolgens door gist omgezet in alcohol en koolzuur.', 'BierKompas'),
    ('tip', 'Proef bier niet ijskoud', 'Heel koud bier kan sommige aroma''s en smaken minder duidelijk laten overkomen. Laat een speciaalbier daarom eventueel een paar minuten op temperatuur komen. Je zult merken dat het karakter langzaam verandert.', 'BierKompas'),
    ('weetje', 'Waarom heeft bier schuim?', 'Het schuim ontstaat voornamelijk door koolzuur dat uit het bier ontsnapt. Eiwitten en andere stoffen uit het bier helpen het schuim stabiel te houden. Een goede schuimkraag kan daardoor veel langer blijven staan.', 'BierKompas'),
    ('brouwerij', 'De Amsterdamse biergeschiedenis van Heineken', 'Heineken heeft zijn oorsprong in Amsterdam. Gerard Heineken kocht in 1864 brouwerij De Hooiberg en richtte zich sterk op de ontwikkeling van lagerbier. In 1873 begon de brouwerij onder de naam Heineken''s Bierbrouwerij Maatschappij verder te groeien.', 'BierKompas'),
    ('review', 'Een IPA voor de hopliefhebber', 'Deze IPA-stijl draait om hop. Denk aan aroma''s van citrus, tropisch fruit en soms dennen. De bitterheid blijft aanwezig, maar de geur maakt het bier interessant en zorgt voor een lange afdronk.', 'BierKompas'),
    ('tip', 'Combineer bier met eten', 'Bier kan verrassend goed samengaan met eten. Een fris witbier past bijvoorbeeld mooi bij lichte gerechten, terwijl een donker en moutig bier juist goed kan werken naast stevige of geroosterde gerechten.', 'BierKompas'),
    ('weetje', 'Waarom heet het India Pale Ale?', 'Het verhaal dat IPA speciaal werd uitgevonden voor de zeereis naar India is minder simpel dan vaak wordt verteld. Sterk gehopte pale ales bestonden al en de stijl ontwikkelde zich geleidelijk. De moderne IPA is bovendien flink veranderd ten opzichte van zijn historische voorgangers.', 'BierKompas'),
    ('review', 'Donker bier, diepe smaken', 'Donkere bieren kunnen aroma''s hebben die doen denken aan koffie, chocolade, karamel en geroosterde mout. Ondanks de donkere kleur hoeft een donker bier niet automatisch zwaar of zoet te zijn. Zeker de moeite waard om eens rustig te ontdekken.', 'BierKompas'),
    ('tip', 'Kijk naar de kleur', 'De kleur van bier kan je alvast een kleine hint geven over wat je kunt verwachten. Een licht bier is vaak fris en subtiel, terwijl donkere bieren vaker geroosterde of karamelachtige tonen hebben. Maar let op: kleur zegt niet alles!', 'BierKompas'),
    ('brouwerij', 'Brouwerij De Prael in Amsterdam', 'Brouwerij De Prael is een Nederlandse brouwerij uit Amsterdam. De brouwerij werd opgericht in 2002 en heeft door de jaren heen verschillende bierstijlen gebrouwen, waaronder IPA, Weizen, Tripel en stout.', 'BierKompas'),
    ('weetje', 'Gist doet het belangrijkste werk', 'Zonder gist geen alcoholisch bier. Tijdens de vergisting zet gist suikers om in alcohol en koolzuur. Daarnaast produceert gist allerlei smaak- en geurstoffen die een grote invloed hebben op het uiteindelijke bier.', 'BierKompas'),
    ('tip', 'Proef eens buiten je comfortzone', 'Drink je normaal pils? Probeer dan eens een Weizen, Blond of Saison. Ben je vooral fan van IPA? Ga dan eens voor een stout of dubbel. Door verschillende stijlen te proberen ontdek je misschien een compleet nieuwe favoriet.', 'BierKompas'),
    ('weetje', 'Bier bestaat uit meer dan alleen water en hop', 'De vier bekende basisingrediënten van traditioneel bier zijn water, mout, hop en gist. Door te variëren met deze ingrediënten en het brouwproces kunnen brouwers enorm veel verschillende smaken en stijlen creëren.', 'BierKompas');
    end if;
end;
$mig$;

-- ============================================================
-- add_remaining_badges.sql
-- ============================================================
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

-- Defensief, voor het geval add_bier_toevoegen.sql nog niet is uitgevoerd:
-- zonder dit is bieren.id een gewone kolom zonder standaardwaarde, en zou de
-- insert hieronder (die bewust geen id meegeeft) mislukken.
do $$
begin
    if not exists (
        select 1 from pg_attribute
        where attrelid = 'public.bieren'::regclass and attname = 'id' and attidentity <> ''
    ) then
        alter table public.bieren alter column id add generated by default as identity;
        perform setval(pg_get_serial_sequence('public.bieren', 'id'), 1000, false);
    end if;
end $$;

-- Let op: GEEN expliciet id meegeven. De app laadt alleen "eigen" bieren uit
-- deze tabel met id >= 1000 (zie beers_service.dart, loadCustomBeers) -- een
-- vast laag id zoals 15 zou in de database bestaan maar in de app onzichtbaar
-- blijven. De identity-kolom (zie add_bier_toevoegen.sql) kent zelf automatisch
-- een id >= 1000 toe, precies zoals bij een via de admin-pagina aangemaakt bier.
-- Elke insert is beveiligd met "where not exists" zodat dit script veilig
-- opnieuw gedraaid kan worden zonder dubbele bieren aan te maken.
insert into public.bieren (naam, stijl, brouwerij, barcode)
    select 'IIPA', 'IPA', E'Brouwerij \'t IJ, Amsterdam', '8710400000150'
    where not exists (select 1 from public.bieren where naam = 'IIPA' and stijl = 'IPA');
insert into public.bieren (naam, stijl, brouwerij, barcode)
    select 'Roodbruin van de Leie', 'Vlaams Roodbruin', null, '8710400000167'
    where not exists (select 1 from public.bieren where naam = 'Roodbruin van de Leie');
insert into public.bieren (naam, stijl, brouwerij, barcode)
    select 'Wolkendek Hazy IPA', 'NEIPA', null, '8710400000174'
    where not exists (select 1 from public.bieren where naam = 'Wolkendek Hazy IPA');
insert into public.bieren (naam, stijl, brouwerij, barcode)
    select 'Nachtwacht Kölsch', 'Kölsch', null, '8710400000181'
    where not exists (select 1 from public.bieren where naam = 'Nachtwacht Kölsch');
insert into public.bieren (naam, stijl, brouwerij, barcode)
    select 'Stille Geuze', 'Lambic', null, '8710400000198'
    where not exists (select 1 from public.bieren where naam = 'Stille Geuze');
insert into public.bieren (naam, stijl, brouwerij, barcode)
    select 'Keizerstad Altbier', 'Altbier', null, '8710400000204'
    where not exists (select 1 from public.bieren where naam = 'Keizerstad Altbier');

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

-- ============================================================
-- add_feed_comments.sql
-- ============================================================
-- BierKompas: reacties op de Ontdek-feed, inclusief een optionele
-- beoordeling (proefnotitie) bij een mini-review ("proeverij"). Uitvoeren
-- via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand
-- -> Run. Vereist add_feed.sql, add_stats_and_badges.sql, add_new_badges.sql
-- en add_remaining_badges.sql (eerder uitgevoerd; die maakt o.a. de functie
-- check_meta_badges aan die hieronder wordt aangeroepen).
--
-- Dit verandert ook wanneer 'Super Model' wordt toegekend: niet meer bij een
-- hoog gemiddelde van je EIGEN proefnotities, maar bij een hoge gemiddelde
-- BEOORDELING DIE JE VAN ANDEREN KRIJGT op je proeverij-posts -- dat past
-- beter bij "behaal een hoge beoordeling", en vereist dat andere mensen ook
-- echt kunnen reageren/beoordelen (wat deze migratie toevoegt).

create table if not exists public.feed_comments (
    id bigint generated always as identity primary key,
    feed_item_id bigint not null references public.feed_items(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    author text not null,
    avatar_url text,
    body text not null,
    rating numeric(2,1) check (rating between 1 and 5),
    created_at timestamptz not null default now()
);

create index if not exists feed_comments_feed_item_idx on public.feed_comments (feed_item_id, created_at);

alter table public.feed_comments enable row level security;

drop policy if exists "Feed comments: iedereen mag lezen" on public.feed_comments;
create policy "Feed comments: iedereen mag lezen" on public.feed_comments
    for select using (true);

drop policy if exists "Feed comments: eigen reactie verwijderen" on public.feed_comments;
create policy "Feed comments: eigen reactie verwijderen" on public.feed_comments
    for delete using (auth.uid() = user_id);

-- Geen directe insert-policy: reacties gaan via post_feed_comment hieronder,
-- zodat author/avatar betrouwbaar uit het eigen profiel komen (niet door de
-- client zelf in te vullen) en de badge-logica er altijd bij hoort.
grant select, delete on public.feed_comments to authenticated;

-- Plaatst een reactie. Bij een meegegeven [p_rating] (alleen zinvol op een
-- mini-review) wordt voor de MAKER van die post herberekend of die een hoog
-- genoeg gemiddelde (>=4.5 bij minstens 3 ontvangen beoordelingen) heeft
-- gekregen van anderen voor de 'Super Model'-badge.
create or replace function public.post_feed_comment(p_feed_item_id bigint, p_body text, p_rating numeric default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_author text;
    v_avatar_url text;
    v_post_owner uuid;
    v_post_type text;
    v_count integer;
    v_avg numeric;
begin
    select name, avatar_url into v_author, v_avatar_url from public.profiles where id = auth.uid();

    insert into public.feed_comments (feed_item_id, user_id, author, avatar_url, body, rating)
    values (p_feed_item_id, auth.uid(), coalesce(v_author, 'Bierliefhebber'), v_avatar_url, p_body, p_rating);

    if p_rating is not null then
        select user_id, item_type into v_post_owner, v_post_type
            from public.feed_items where id = p_feed_item_id;

        if v_post_owner is not null and v_post_type = 'review' then
            select count(*), avg(fc.rating) into v_count, v_avg
                from public.feed_comments fc
                join public.feed_items fi on fi.id = fc.feed_item_id
                where fi.user_id = v_post_owner
                    and fi.item_type = 'review'
                    and fc.rating is not null;

            if v_count >= 3 and v_avg >= 4.5 then
                insert into public.user_badges (user_id, badge_id)
                values (v_post_owner, 'super_model')
                on conflict (user_id, badge_id) do nothing;
                perform public.check_meta_badges(v_post_owner);
            end if;
        end if;
    end if;
end;
$$;

grant execute on function public.post_feed_comment(bigint, text, numeric) to authenticated;

-- 'Super Model' komt nu van ontvangen beoordelingen (hierboven), niet meer
-- van je eigen proefnotitie-cijfer -- deze functie kent 'm dus niet meer toe,
-- maar blijft bestaan (en bijgewerkt via de app aangeroepen) voor de overige
-- meta-badge-check.
create or replace function public.record_tasting_note_created(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_user_id <> auth.uid() then
        raise exception 'Niet toegestaan.';
    end if;
    perform public.check_meta_badges(p_user_id);
end;
$$;

grant execute on function public.record_tasting_note_created(uuid) to authenticated;

-- ============================================================
-- add_news_articles.sql
-- ============================================================
-- BierKompas: nieuwsartikelen voor de nieuwsrubriek (door Kirubel gebouwd in
-- lib/features/news/news_article_page.dart en home_page.dart), beheerd door
-- beheerders. Uitvoeren via het Supabase-dashboard: SQL Editor -> New query
-- -> plak dit bestand -> Run.
--
-- Zonder deze tabel blijft de nieuwsrubriek altijd leeg (de app vangt de
-- ontbrekende tabel netjes af), maar is de functie dus onbruikbaar.

create table if not exists public.news_articles (
    id bigint generated always as identity primary key,
    titel text not null,
    samenvatting text not null,
    inhoud text not null,
    foto_url text,
    status text not null default 'concept' check (status in ('concept', 'gepubliceerd')),
    gepubliceerd_op timestamptz not null default now(),
    created_at timestamptz not null default now()
);

alter table public.news_articles enable row level security;

drop policy if exists "Nieuws: iedereen mag gepubliceerde artikelen lezen" on public.news_articles;
create policy "Nieuws: iedereen mag gepubliceerde artikelen lezen" on public.news_articles
    for select using (status = 'gepubliceerd');

drop policy if exists "Nieuws: beheerders mogen alles lezen" on public.news_articles;
create policy "Nieuws: beheerders mogen alles lezen" on public.news_articles
    for select using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Nieuws: alleen beheerders mogen wijzigen" on public.news_articles;
create policy "Nieuws: alleen beheerders mogen wijzigen" on public.news_articles
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- ============================================================
-- add_notifications.sql
-- ============================================================
-- BierKompas: in-app berichtencentrum + afwijsreden voor evenementen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_event_status.sql (eerder uitgevoerd).
--
-- Geen echte OS-pushmeldingen (die vereisen een Firebase-project, net als de
-- Outlook-SSO een Azure-project vereist) -- dit is een berichtjescentrum
-- binnen de app zelf: een belletje met ongelezen berichten, gevuld door
-- automatische meldingen (evenement goedgekeurd/afgewezen) en door
-- berichten die een beheerder verstuurt, eventueel gericht op een stad of
-- op favorieten van een specifieke brouwerij/horeca.

-- 1. Optioneel woonplaatsveld, zodat een beheerder op regio kan filteren.
-- Niemand hoeft dit in te vullen; zonder woonplaats krijg je geen
-- regiogerichte berichten (wel "Iedereen"-berichten).
alter table public.profiles add column if not exists city text;

-- 2. Berichten zelf.
create table if not exists public.notifications (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    body text not null,
    created_at timestamptz not null default now(),
    read_at timestamptz
);

create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "Notifications: select own" on public.notifications;
create policy "Notifications: select own" on public.notifications
    for select using (auth.uid() = user_id);

drop policy if exists "Notifications: mark own as read" on public.notifications;
create policy "Notifications: mark own as read" on public.notifications
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Geen insert-policy voor gebruikers: berichten ontstaan alleen via de
-- functies hieronder (security definer), nooit rechtstreeks vanuit de app.
grant select, update on public.notifications to authenticated;

-- 3. Evenementen: afwijsreden + status 'rejected' i.p.v. verwijderen, zodat
-- de indiener kan zien waarom (zowel in "Mijn evenementen" als via een
-- bericht in het berichtencentrum).
alter table public.events add column if not exists rejection_reason text;
alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check
    check (status in ('pending', 'approved', 'cancelled', 'rejected'));

create or replace function public.approve_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_owner uuid;
    v_name text;
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen evenementen goedkeuren';
    end if;

    update public.events
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_event_id and status = 'pending'
        returning user_id, name into v_owner, v_name;

    if v_owner is not null then
        insert into public.notifications (user_id, title, body)
        values (v_owner, 'Evenement goedgekeurd', 'Je evenement "' || coalesce(v_name, '') || '" is goedgekeurd en staat nu in de agenda.');
    end if;
end;
$$;

grant execute on function public.approve_event(bigint) to authenticated;

-- Afwijzen verwijdert het evenement niet meer (dat verborg de reden voor de
-- indiener) maar zet het op 'rejected', met een optionele reden.
drop function if exists public.reject_event(bigint);
create or replace function public.reject_event(p_event_id bigint, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_owner uuid;
    v_name text;
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen evenementen afwijzen';
    end if;

    update public.events
        set status = 'rejected', rejection_reason = nullif(trim(p_reason), '')
        where id = p_event_id and status = 'pending'
        returning user_id, name into v_owner, v_name;

    if v_owner is not null then
        insert into public.notifications (user_id, title, body)
        values (
            v_owner,
            'Evenement afgewezen',
            case
                when p_reason is not null and trim(p_reason) <> ''
                    then 'Je evenement "' || coalesce(v_name, '') || '" is helaas afgewezen: ' || trim(p_reason)
                else 'Je evenement "' || coalesce(v_name, '') || '" is helaas afgewezen.'
            end
        );
    end if;
end;
$$;

grant execute on function public.reject_event(bigint, text) to authenticated;

-- 4. Bericht versturen vanuit het admin-paneel, aan iedereen, aan iedereen
-- in een bepaalde woonplaats, of aan iedereen die een specifieke
-- brouwerij/horeca favoriet heeft gemaakt. Geeft het aantal ontvangers terug.
create or replace function public.send_admin_notification(
    p_title text,
    p_body text,
    p_target text default 'all',
    p_city text default null,
    p_item_type text default null,
    p_item_id integer default null
)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
    v_count integer;
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen berichten versturen.';
    end if;

    if p_target = 'city' then
        insert into public.notifications (user_id, title, body)
        select id, p_title, p_body from public.profiles
        where city is not null and lower(trim(city)) = lower(trim(coalesce(p_city, '')));
    elsif p_target = 'favorites' then
        insert into public.notifications (user_id, title, body)
        select distinct f.user_id, p_title, p_body from public.favorites f
        where f.item_type = p_item_type and f.item_id = p_item_id;
    else
        insert into public.notifications (user_id, title, body)
        select id, p_title, p_body from public.profiles;
    end if;

    get diagnostics v_count = row_count;
    return v_count;
end;
$$;

grant execute on function public.send_admin_notification(text, text, text, text, text, integer) to authenticated;

-- ============================================================
-- add_faq.sql
-- ============================================================
-- BierKompas: Support & FAQ (veelgestelde vragen), beheerd via de admin-pagina.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist profiles.is_admin (eerder aangemaakt).
--
-- Vaste rubrieken (volgens afspraak met Huub):
--   account   = Account- en profielinstellingen
--   inchecken = Inchecken
--   bieren    = Bieren en beoordelingen
--   badges    = Badges
--   vrienden  = Vrienden en interactie
--   bronnen   = Toevoegen van bronnen en content
--
-- De startvragen onderaan beschrijven alleen wat de app nu echt doet; een
-- beheerder kan ze via de admin-pagina aanpassen of aanvullen.

create table if not exists public.faq_items (
    id bigint generated always as identity primary key,
    category text not null check (category in ('account', 'inchecken', 'bieren', 'badges', 'vrienden', 'bronnen')),
    question text not null,
    answer text not null,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

create index if not exists faq_items_category_idx on public.faq_items (category, sort_order, id);

alter table public.faq_items enable row level security;

drop policy if exists "FAQ: iedereen mag lezen" on public.faq_items;
create policy "FAQ: iedereen mag lezen" on public.faq_items
    for select using (true);

drop policy if exists "FAQ: alleen beheerders mogen wijzigen" on public.faq_items;
create policy "FAQ: alleen beheerders mogen wijzigen" on public.faq_items
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- Startvragen: alleen invoegen als de tabel nog leeg is, zodat opnieuw
-- draaien van dit script nooit dubbele vragen of overschreven aanpassingen
-- van een beheerder oplevert.
insert into public.faq_items (category, question, answer, sort_order)
select v.category, v.question, v.answer, v.sort_order
from (values
    ('account', 'Hoe pas ik mijn profiel aan?', 'Ga naar het tabblad Profiel en tik op "Bewerk Profiel". Daar kun je onder meer je naam en profielfoto wijzigen.', 1),
    ('account', 'Wie ziet mijn locatie?', 'Alleen bevestigde vrienden, en alleen als je dat zelf aanzet. Ga naar Profiel > Instellingen en zet "Deel mijn locatie met vrienden" aan of uit. Je vrienden zien je dan op de kaart onder "Bierliefhebbers in de buurt".', 2),
    ('account', 'Waar vind ik de Algemene Voorwaarden en het Privacybeleid?', 'Onder Profiel > Instellingen staan de Algemene Voorwaarden en het Privacybeleid.', 3),
    ('account', 'Hoe log ik uit?', 'Ga naar het tabblad Profiel en tik onderaan het profielblok op "Uitloggen".', 4),
    ('account', 'Hoe kan ik mijn account verwijderen?', 'Ga naar Profiel > Instellingen en kies "Account verwijderen". Je krijgt eerst een bevestigingsvraag. Het verwijderen is definitief en kan niet worden teruggedraaid.', 5),

    ('inchecken', 'Hoe check ik een bier in?', 'Gebruik de scanknop op het Ontdek-scherm (bij "Vinden & Proeven") of in je Favorieten. Scan de barcode van het bier, of kies de fotooptie en geef zelf aan welk bier het is. Het bier komt daarna in je Bier-Paspoort.', 1),
    ('inchecken', 'Mijn barcode wordt niet herkend, wat nu?', 'Niet elk bier heeft al een barcode in Bierkompas. Gebruik dan de fotooptie en kies zelf het bier uit de lijst. Staat het bier er niet tussen, dan kan een beheerder het toevoegen.', 2),
    ('inchecken', 'Wat is de Bier Streak?', 'Je streak telt hoeveel dagen op rij je actief bent. Een bier scannen of loggen, een proefnotitie schrijven of een post plaatsen telt als activiteit. Je ziet je streak als 🔥 linksboven in de app. Sla je een dag over, dan begint hij weer bij 1.', 3),

    ('bieren', 'Hoe schrijf ik een proefnotitie?', 'Ga naar Profiel en open Mijn Proefnotities. Kies het bier, geef een beoordeling van 1 tot 5 sterren en schrijf je notitie. Met de schakelaar "Ook delen als bierpost" deel je je notitie ook in de Ontdek-feed.', 1),
    ('bieren', 'Waarom zie ik mijn post nog niet in de Ontdek-feed?', 'Eigen posts worden eerst beoordeeld door een beheerder voordat ze voor iedereen zichtbaar zijn. Na het versturen zie je een melding dat je post is verstuurd.', 2),
    ('bieren', 'Kan ik reageren op de proeverij van iemand anders?', 'Ja. Tik op het reactie-icoon bij een post in de Ontdek-feed. Bij een mini-review kun je er ook een beoordeling van 1 tot 5 sterren als proefnotitie bij achterlaten.', 3),
    ('bieren', 'Hoe bewaar ik een bier of brouwerij als favoriet?', 'Tik op het hartje bij een bier, brouwerij of post. Je favorieten vind je terug in het tabblad Favorieten.', 4),

    ('badges', 'Hoe verdien ik badges?', 'Je verdient badges door de app te gebruiken: een streak opbouwen, bieren van verschillende stijlen scannen en proeven, vrienden proosten, iets delen of een eigen post plaatsen. In je Bier-Paspoort staat per badge wat daarvoor nodig is.', 1),
    ('badges', 'Waar zie ik mijn badges en voortgang?', 'Op Profiel onder "Mijn Bier-Paspoort". Tik op "Bekijk alles" voor alle badges, ingedeeld per categorie, met een voortgangsbalk waar dat meetbaar is.', 2),
    ('badges', 'Waarom staat een badge nog op vergrendeld?', 'Dan heb je de vereiste actie nog niet gedaan, of de voortgang is nog niet hoog genoeg. Sommige badges, zoals "La Crème de la Crème", krijg je pas nadat je al meerdere andere badges hebt verdiend.', 3),

    ('vrienden', 'Hoe voeg ik een vriend toe?', 'Ga naar Profiel en kies "Vrienden toevoegen". Zoek op naam en stuur een vriendschapsverzoek. Zodra de ander accepteert, zijn jullie bier-vrienden.', 1),
    ('vrienden', 'Hoe stuur ik een Proost?', 'Je kunt een Proost sturen naar bevestigde vrienden, via je vriendenlijst op Profiel of via "Bierliefhebbers in de buurt" op de kaart. De ander ziet je Proost meteen als pop-up en kan terugproosten.', 2),
    ('vrienden', 'Kan ik met vrienden chatten?', 'Ja, vanuit je vriendenlijst op Profiel kun je een chat met een bier-vriend openen.', 3),

    ('bronnen', 'Hoe meld ik een brouwerij aan?', 'Open het tabblad Kaart, kies "Brouwerijen" en tik op "Brouwerij toevoegen". Na goedkeuring door een beheerder verschijnt de brouwerij op de kaart.', 1),
    ('bronnen', 'Hoe meld ik een café of proeflokaal aan?', 'Open het tabblad Kaart, kies "Horeca" en tik op "Horeca toevoegen". Na goedkeuring door een beheerder verschijnt de locatie op de kaart.', 2),
    ('bronnen', 'Hoe voeg ik een evenement toe?', 'Ga naar het tabblad Agenda en maak een evenement aan met de plusknop. Je evenement staat onder "Mijn evenementen" totdat een beheerder het goedkeurt, daarna verschijnt het in de agenda.', 3),
    ('bronnen', 'Mijn evenement is afgewezen, waarom?', 'Je krijgt een bericht (Profiel > Berichten) en onder "Mijn evenementen" zie je de reden, als de beheerder die heeft ingevuld. Je kunt het evenement verwijderen en met aangepaste gegevens opnieuw aanmelden.', 4)
) as v(category, question, answer, sort_order)
where not exists (select 1 from public.faq_items);

-- ============================================================
-- add_admin_content_management.sql
-- ============================================================
-- BierKompas: beheerders kunnen zelf muziek, boeken, evenementen,
-- brouwerijen en proeflokalen/horeca toevoegen en publiceren via de
-- admin-pagina. Uitvoeren via het Supabase-dashboard: SQL Editor -> New query
-- -> plak dit bestand -> Run. Vereist add_event_status.sql,
-- add_brewery_submissions.sql en add_horeca_submissions.sql (eerder uitgevoerd).

-- 1. Muziek ("Brouwers Beats"). De bestaande nummers staan hardcoded in de
-- app; nummers die hier worden toegevoegd komen er automatisch bij.
create table if not exists public.music_tracks (
    id bigint generated always as identity primary key,
    title text not null,
    artist text not null,
    cover_url text not null,
    listen_url text,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.music_tracks enable row level security;

drop policy if exists "Muziek: iedereen mag lezen" on public.music_tracks;
create policy "Muziek: iedereen mag lezen" on public.music_tracks
    for select using (true);

drop policy if exists "Muziek: alleen beheerders mogen wijzigen" on public.music_tracks;
create policy "Muziek: alleen beheerders mogen wijzigen" on public.music_tracks
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- 2. Boeken (bibliotheek). Zelfde opzet als muziek.
create table if not exists public.library_books (
    id bigint generated always as identity primary key,
    title text not null,
    author text not null,
    subtitle text,
    cover_url text not null,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.library_books enable row level security;

drop policy if exists "Boeken: iedereen mag lezen" on public.library_books;
create policy "Boeken: iedereen mag lezen" on public.library_books
    for select using (true);

drop policy if exists "Boeken: alleen beheerders mogen wijzigen" on public.library_books;
create policy "Boeken: alleen beheerders mogen wijzigen" on public.library_books
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- 3. Beheerders mogen aangemelde en zelf toegevoegde brouwerijen/horeca en
-- evenementen bijwerken en verwijderen (voorheen alleen goed-/afkeuren).
drop policy if exists "Brewery submissions: admin update" on public.brewery_submissions;
create policy "Brewery submissions: admin update" on public.brewery_submissions
    for update using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Brewery submissions: admin delete" on public.brewery_submissions;
create policy "Brewery submissions: admin delete" on public.brewery_submissions
    for delete using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Horeca submissions: admin update" on public.horeca_submissions;
create policy "Horeca submissions: admin update" on public.horeca_submissions
    for update using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Horeca submissions: admin delete" on public.horeca_submissions;
create policy "Horeca submissions: admin delete" on public.horeca_submissions
    for delete using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Events: admin delete" on public.events;
create policy "Events: admin delete" on public.events
    for delete using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- ============================================================
-- add_external_content_imports.sql
-- ============================================================
-- BierKompas: importeren van externe bronnen (bierdatabase, agenda, nieuws).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_event_status.sql, add_news_articles.sql en
-- add_admin_content_management.sql (eerder uitgevoerd).
--
-- De gegevens zelf worden niet via SQL geladen maar met de knoppen op het
-- admin-tabblad "Data-imports" (veilig opnieuw te draaien: bestaande
-- regels worden bijgewerkt in plaats van dubbel aangemaakt).

-- 1. Bierdatabase. Aparte tabel naast `bieren` (die alleen de koppeling
-- barcode <-> bier-id voor de scanfunctie bevat en in zijn geheel in het
-- geheugen van de app wordt geladen -- bij ~4.500 bieren zoeken en pagineren
-- we juist op de server).
-- untappd_score en untappd_aantal staan in de kolomlijst van Huub, maar de
-- bron (Nederlandse Biercultuur) heeft die gegevens niet; Untappd staat
-- scrapen niet toe. De kolommen blijven daarom leeg tot er een toegestane
-- bron voor is.
create table if not exists public.beer_catalog (
    id bigint primary key,
    naam text not null,
    brouwerij text,
    brouwerij_id bigint,
    stijl text,
    smaakcategorie text,
    verpakking text,
    land text,
    alcohol numeric(4,2),
    ibu integer,
    gisting text,
    smaaktonen text,
    untappd_score numeric(3,2),
    untappd_aantal integer,
    bron text not null default 'Stichting Erfgoed Nederlandse Biercultuur',
    bron_url text,
    created_at timestamptz not null default now()
);

create index if not exists beer_catalog_naam_idx on public.beer_catalog (lower(naam));
create index if not exists beer_catalog_brouwerij_idx on public.beer_catalog (lower(brouwerij));
create index if not exists beer_catalog_stijl_idx on public.beer_catalog (stijl);

-- Foto en kleur, gevuld door de import van Belgian Beer Factory en Mitra
-- (supabase/bierdatabase/bierdatabase_belgie_en_nederland.sql).
alter table public.beer_catalog add column if not exists image_url text;
alter table public.beer_catalog add column if not exists kleur text;

alter table public.beer_catalog enable row level security;

drop policy if exists "Bierdatabase: iedereen mag lezen" on public.beer_catalog;
create policy "Bierdatabase: iedereen mag lezen" on public.beer_catalog
    for select using (true);

drop policy if exists "Bierdatabase: alleen beheerders mogen wijzigen" on public.beer_catalog;
create policy "Bierdatabase: alleen beheerders mogen wijzigen" on public.beer_catalog
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- Lijst van alle bierstijlen met aantal bieren, voor het stijlfilter in de app
-- (een gewone select geeft maximaal 1000 rijen terug, dus dit doen we in de database).
drop function if exists public.beer_catalog_styles();
create or replace function public.beer_catalog_styles()
returns table(stijl text, aantal bigint)
language sql
stable
as $$
    select stijl, count(*) as aantal
    from public.beer_catalog
    where stijl is not null and stijl <> ''
    group by stijl
    order by count(*) desc, stijl;
$$;

grant execute on function public.beer_catalog_styles() to anon, authenticated;

-- 2. Evenementen: herkomst bijhouden zodat een import niet dubbel inlaadt.
-- Gewone, door gebruikers aangemaakte evenementen hebben bron = null en
-- botsen dus nooit met de unieke index.
alter table public.events add column if not exists bron text;
alter table public.events add column if not exists bron_id text;
alter table public.events add column if not exists bron_url text;
create unique index if not exists events_bron_unique on public.events (bron, bron_id, start_date);

-- 3. Nieuws: bron van een artikel (naam + link), zodat de app naar het
-- originele artikel kan verwijzen in plaats van de tekst over te nemen.
alter table public.news_articles add column if not exists bron_naam text;
alter table public.news_articles add column if not exists bron_url text;
create unique index if not exists news_articles_bron_url_unique on public.news_articles (bron_url);

-- ============================================================
-- add_video_reel.sql
-- ============================================================
-- BierKompas: video-reel met externe video's (YouTube, TikTok, Instagram) en
-- eigen video's. Uitvoeren via het Supabase-dashboard: SQL Editor -> New query
-- -> plak dit bestand -> Run. Vereist add_videos.sql (eerder uitgevoerd).
--
-- Externe video's: alleen de link en het video-ID komen in de database, nooit
-- de videobestanden zelf; de app toont ze met de officiële embed-speler van
-- het platform (YouTube IFrame Player API, TikTok/Instagram embed).
-- Eigen video's: een .mp4/.webm in de opslag hieronder, of een directe link
-- (bijvoorbeeld een HLS-stream .m3u8 via Cloudflare Stream of Mux).

alter table public.videos add column if not exists source text not null default 'hosted';
alter table public.videos drop constraint if exists videos_source_check;
alter table public.videos add constraint videos_source_check
    check (source in ('hosted', 'youtube', 'tiktok', 'instagram'));

-- YouTube: video-ID. TikTok: numeriek video-ID. Instagram: 'reel/CODE' of 'p/CODE'.
alter table public.videos add column if not exists external_id text;

-- Een thumbnail is optioneel: voor YouTube leidt de app die zelf af, bij
-- eigen video's is er een zwart beeld tot de video laadt.
alter table public.videos alter column thumbnail_url drop not null;

-- Opslag voor eigen video's. Een bestand mag maximaal 50 MB zijn (de limiet
-- van het gratis Supabase-abonnement); grotere video's kun je beter via een
-- streamingdienst aanbieden en als directe link toevoegen.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('videos', 'videos', true, 52428800, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update
    set public = true, file_size_limit = 52428800, allowed_mime_types = array['video/mp4', 'video/webm', 'video/quicktime'];

drop policy if exists "Videos storage: iedereen mag lezen" on storage.objects;
create policy "Videos storage: iedereen mag lezen" on storage.objects
    for select using (bucket_id = 'videos');

drop policy if exists "Videos storage: beheerders mogen uploaden" on storage.objects;
create policy "Videos storage: beheerders mogen uploaden" on storage.objects
    for insert with check (
        bucket_id = 'videos'
        and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Videos storage: beheerders mogen verwijderen" on storage.objects;
create policy "Videos storage: beheerders mogen verwijderen" on storage.objects
    for delete using (
        bucket_id = 'videos'
        and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- ============================================================
-- add_video_seed.sql
-- ============================================================
-- BierKompas: eerste video's voor de video-reel ("Brouwerij Highlights").
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_videos.sql en add_video_reel.sql (of
-- setup_alles_in_een.sql). Veilig om opnieuw te draaien: een video die er al
-- staat (zelfde YouTube-ID) wordt overgeslagen.
--
-- Het zijn bestaande, openbare YouTube-video's van de makers zelf (kanaal
-- tussen haakjes). Alleen de link en het ID worden opgeslagen; de app speelt
-- ze af met de officiële YouTube-speler. Alle video's zijn op 14-10-2026
-- gecontroleerd: ze bestaan en de maker staat insluiten toe.
-- Een beheerder kan ze via het admin-paneel (Video's) verwijderen of aanvullen.

insert into public.videos (title, category, video_url, source, external_id, sort_order)
select v.title, v.category, 'https://www.youtube.com/watch?v=' || v.external_id, 'youtube', v.external_id, v.sort_order
from (values
    -- Nederlandstalig
    ('Ambachtelijk bierbrouwen: 5 brouwers aan het woord (RTV Oost)', 'Brouwerij', 'GXPOAQKCqmQ', 1),
    ('Hertog Jan: passie voor het brouwen', 'Brouwerij', 'N3BdbrP26w0', 2),
    ('Het brouwproces van bier (Colruyt)', 'Brouwproces', 'Vo5dypGiFjM', 3),
    ('Cursus bierbrouwen bij Bierbrouwerij Bax (OOG Groningen)', 'Brouwerij', 'fF6mM-GBkhA', 4),
    ('Leren bier brouwen (Brouwland)', 'Thuisbrouwen', 'vGz6SPjuGNs', 5),
    ('Märzen-recept 1841 van Brouwerij Bierverbond (Brouwbeesten)', 'Thuisbrouwen', 'gAnHm6NKxpA', 6),
    ('Zelf bier brouwen met een starterspakket (Brouwbroeders)', 'Thuisbrouwen', 'yw92oCh416k', 7),
    -- Engelstalig
    ('How Beer Is Made: inside a real brewery (The Whisky Baron)', 'Brouwproces', 'KqdJtq8siH0', 8),
    ('Beer brewing process in 3D-animatie (Explanation Avenue)', 'Brouwproces', 'ZL_HGOgy_Zo', 9),
    ('Inside Tree House Brewing: brewhouse tour', 'Brouwerij', 'lyNzhHDcIqc', 10),
    ('BrewDog: brewery video tour', 'Brouwerij', '_B-FdT9nQRM', 11),
    ('How craft beer is made: Shipyard Brewing Co.', 'Brouwerij', 'd89OxwY1GUg', 12),
    ('Brewing process: the Brewery at the CIA', 'Brouwproces', 'ceXUKLlEZ-Y', 13),
    ('Inside a 7 BBL commercial brewery (Genus Brewing)', 'Brouwerij', 'JUv6lEUSUEw', 14)
) as v(title, category, external_id, sort_order)
where not exists (
    select 1 from public.videos x where x.source = 'youtube' and x.external_id = v.external_id
);

-- ============================================================
-- add_builtin_content.sql
-- ============================================================
-- BierKompas: de vaste brouwerijen (580), muzieknummers (8) en boeken
-- (3) die tot nu toe in de app-code stonden, naar de database, zodat
-- een beheerder ze in het admin-paneel kan bewerken en verwijderen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_admin_content_management.sql (of setup_alles_in_een.sql).
--
-- Veilig om opnieuw te draaien: de vaste items worden alleen de allereerste
-- keer toegevoegd. Daarna blijven aanpassingen en verwijderingen van een
-- beheerder bewaard, ook als dit bestand nog eens wordt gedraaid.
--
-- Zolang dit bestand niet is gedraaid, gebruikt de app de vaste lijsten uit
-- de code. Daarna komen brouwerijen, muziek en boeken uit de database.

-- 1. Brouwerijen op de kaart. De id's zijn dezelfde als in de app, zodat
-- favorieten en feed-posts die naar een brouwerij verwijzen blijven kloppen.
create table if not exists public.breweries (
    id integer primary key,
    title text not null,
    location text not null default '',
    about text not null default '',
    tags text[] not null default '{}',
    facts text[] not null default '{}',
    founded text,
    latitude double precision not null,
    longitude double precision not null,
    image_url text,
    created_at timestamptz not null default now()
);

alter table public.breweries enable row level security;

drop policy if exists "Brouwerijen: iedereen mag lezen" on public.breweries;
create policy "Brouwerijen: iedereen mag lezen" on public.breweries
    for select using (true);

drop policy if exists "Brouwerijen: alleen beheerders mogen wijzigen" on public.breweries;
create policy "Brouwerijen: alleen beheerders mogen wijzigen" on public.breweries
    for all using (public.is_admin()) with check (public.is_admin());

insert into public.breweries (id, title, location, about, tags, facts, latitude, longitude)
select x.id, x.title, x.location, x.about,
       array(select jsonb_array_elements_text(x.tags)),
       array(select jsonb_array_elements_text(x.facts)),
       x.latitude, x.longitude
from jsonb_to_recordset($data$[{"id": 1001, "title": "Brouwerij Hoop", "location": "Zaandijk", "about": "Proeflokaal/restaurant: Ja (Restaurant & Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lagedijk 71, Zaandijk", "Website: https://www.hoopbier.nl"], "latitude": 52.4722, "longitude": 4.8105}, {"id": 1002, "title": "De Naeckte Brouwers", "location": "Amstelveen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Annakerk)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Karel Doormanweg 3, Amstelveen", "Website: https://www.naecktebrouwers.nl"], "latitude": 52.3023, "longitude": 4.8624}, {"id": 1003, "title": "Wispe Brouwerij", "location": "Weesp", "about": "Proeflokaal/restaurant: Ja (Grand Café & Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Herengracht 16, Weesp", "Website: https://www.wispe.nl"], "latitude": 52.3082, "longitude": 5.0416}, {"id": 1004, "title": "Rock City Brewing", "location": "Amersfoort", "about": "Proeflokaal/restaurant: Ja (Brewpub & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Middelhoefseweg 88, Amersfoort", "Website: https://rockcitybrewing.nl"], "latitude": 52.1691, "longitude": 5.3942}, {"id": 1005, "title": "Jopenkerk Haarlem", "location": "Haarlem", "about": "Proeflokaal/restaurant: Ja (Grand Café & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Gedempte Voldersgracht 2, Haarlem", "Website: https://www.jopenkerk.nl"], "latitude": 52.3811, "longitude": 4.6297}, {"id": 1006, "title": "Brouwerij 't IJ", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Molen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Funenkade 7, Amsterdam", "Website: https://www.brouwerijij.nl"], "latitude": 52.3667, "longitude": 4.9263}, {"id": 1007, "title": "Stadsbrouwerij De Drie Ringen", "location": "Amersfoort", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kleine Spui 18, Amersfoort", "Website: https://www.drie-ringen.nl"], "latitude": 52.1581, "longitude": 5.3857}, {"id": 1008, "title": "Hertog Jan Brouwerij", "location": "Arcen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Brouwerijcafé)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kruisweg 44, Arcen", "Website: https://www.hertogjan.nl"], "latitude": 51.4697, "longitude": 6.1812}, {"id": 1009, "title": "Uiltje Brewing Company", "location": "Haarlem", "about": "Proeflokaal/restaurant: Ja (Uiltje Bar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Bakenessergracht 43, Haarlem", "Website: https://www.uiltjebrewing.com"], "latitude": 52.3817, "longitude": 4.6393}, {"id": 1010, "title": "Texelse Bierbrouwerij", "location": "Oudeschild", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Schilderweg 214, Oudeschild", "Website: https://www.texels.nl"], "latitude": 53.0456, "longitude": 4.8471}, {"id": 1011, "title": "vandeStreek bier", "location": "Utrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Europalaan 2B, Utrecht", "Website: https://www.vandestreekbier.nl"], "latitude": 52.0682, "longitude": 5.1073}, {"id": 1012, "title": "Brouwerij Kompaan", "location": "Den Haag", "about": "Proeflokaal/restaurant: Ja (Thuishaven Craft Bar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Saturnusstraat 55, Den Haag", "Website: https://www.kompaanbier.nl"], "latitude": 52.0664, "longitude": 4.3468}, {"id": 1013, "title": "Brouwerij De Hemel", "location": "Nijmegen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Franseplaats 1, Nijmegen", "Website: https://www.brouwerijdehemel.nl"], "latitude": 51.8483, "longitude": 5.8631}, {"id": 1014, "title": "Maximus Brouwerij", "location": "Utrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restobar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Prattenburg 101, Utrecht", "Website: https://www.maximusbrouwerij.nl"], "latitude": 52.0983, "longitude": 5.0381}, {"id": 1015, "title": "Kaapse Brouwers", "location": "Rotterdam", "about": "Proeflokaal/restaurant: Ja (Kaapse Maria / Fenix)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwe Binnenweg 255, Rotterdam", "Website: https://www.kaapsebrouwers.nl"], "latitude": 51.9135, "longitude": 4.4593}, {"id": 1016, "title": "Oproer Brouwerij", "location": "Utrecht", "about": "Proeflokaal/restaurant: Ja (Vegan Restobar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: CAB-Rondom 90A, Utrecht", "Website: https://www.oproer.nl"], "latitude": 52.0911, "longitude": 5.0872}, {"id": 1017, "title": "Frontaal Brewing Co.", "location": "Breda", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Brewpub)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Liniestraat 31, Breda", "Website: https://www.frontaalbrewingcompany.com"], "latitude": 51.5975, "longitude": 4.7831}, {"id": 1018, "title": "Brouwerij Kees", "location": "Middelburg", "about": "Proeflokaal/restaurant: Nee (Lokaal verkooppunt)", "tags": ["NEDERLAND"], "facts": ["Adres: Voltaweg 8, Middelburg", "Website: https://www.brouwerijkees.nl"], "latitude": 51.4921, "longitude": 3.6302}, {"id": 1019, "title": "Brouwerij De Molen", "location": "Bodegraven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Overtoom 43, Bodegraven", "Website: https://www.brouwerijdemolen.nl"], "latitude": 52.0831, "longitude": 4.7483}, {"id": 1020, "title": "La Trappe Trappist", "location": "Berkel-Enschot", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Eindhovenseweg 3, Berkel-Enschot", "Website: https://www.latrappetrappist.com"], "latitude": 51.5433, "longitude": 5.1293}, {"id": 1021, "title": "Trappistenbrouwerij De Kievit", "location": "Zundert", "about": "Proeflokaal/restaurant: Ja (Schenkerij)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rucphenseweg 149, Zundert", "Website: https://www.zunderttrappist.nl"], "latitude": 51.4682, "longitude": 4.6301}, {"id": 1022, "title": "Gulpener Bierbrouwerij", "location": "Gulpen", "about": "Proeflokaal/restaurant: Ja (Brouwlokaaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg 16, Gulpen", "Website: https://www.gulpener.nl"], "latitude": 50.8142, "longitude": 5.8903}, {"id": 1023, "title": "Brand Bierbrouwerij", "location": "Wijlre", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Brouwerijstraat 2, Wijlre", "Website: https://www.brand.nl"], "latitude": 50.8322, "longitude": 5.8961}, {"id": 1024, "title": "Lindeboom Brouwerij", "location": "Neer", "about": "Proeflokaal/restaurant: Ja (Brouwerijcafé)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg Noord 2, Neer", "Website: https://www.lindeboom.nl"], "latitude": 51.2612, "longitude": 5.9862}, {"id": 1025, "title": "Stadsbrouwerij Eindhoven", "location": "Eindhoven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal 100 Watt)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nachtegaallaan 15, Eindhoven", "Website: https://www.stadsbrouwerijeindhoven.com"], "latitude": 51.4361, "longitude": 5.4852}, {"id": 1026, "title": "Stadsbrouwerij Maastricht", "location": "Maastricht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Cafe)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Oeverwal 12, Maastrticht", "Website: https://www.stadsbrouwerijmaastricht.nl"], "latitude": 50.8492, "longitude": 5.6983}, {"id": 1027, "title": "Brouwerij De Prael", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Oudezijds Armsteeg 26, Amsterdam", "Website: https://www.deprael.nl"], "latitude": 52.3758, "longitude": 4.8988}, {"id": 1028, "title": "Oedipus Brewing", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Taproom)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Gedempt Hamerkanaal 85, Amsterdam", "Website: https://www.oedipus.com"], "latitude": 52.3853, "longitude": 4.9221}, {"id": 1029, "title": "Two Chefs Brewing", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Two Chefs Bar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Moezelhavenweg 6, Amsterdam", "Website: https://twochefsbrewing.com"], "latitude": 52.3992, "longitude": 4.8321}, {"id": 1030, "title": "Brouwerij Poesiat & Kater", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Polderweg 648, Amsterdam", "Website: https://poesiatenkater.nl"], "latitude": 52.3571, "longitude": 4.9312}, {"id": 1031, "title": "Brouwerij Troost", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Brewpub & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Pazzanistraat 27, Amsterdam", "Website: https://brouwerijtroost.nl"], "latitude": 52.3861, "longitude": 4.8722}, {"id": 1032, "title": "Butcher's Tears", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Karperweg 45, Amsterdam", "Website: https://butcherstears.com"], "latitude": 52.3512, "longitude": 4.8561}, {"id": 1033, "title": "Brouwerij Kleiburg", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rigakade 20, Amsterdam", "Website: https://www.brouwerijkleiburg.nl"], "latitude": 52.3951, "longitude": 4.8712}, {"id": 1034, "title": "Brouwerij Homeland", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Pension Homeland)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kattenburgerstraat 5, Amsterdam", "Website: https://brouwerijhomeland.nl"], "latitude": 52.3732, "longitude": 4.9182}, {"id": 1035, "title": "Walhalla Craft Beer", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spijkerkade 10, Amsterdam", "Website: https://www.walhallacraftbeer.nl"], "latitude": 52.3892, "longitude": 4.9121}, {"id": 1036, "title": "Friart Brouwerij", "location": "Oud-Beijerland", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Oostkade 12, Oud-Beijerland", "Website: https://www.friart.nl"], "latitude": 51.8231, "longitude": 4.4122}, {"id": 1037, "title": "Brouwerij Lion's Head", "location": "Hilversum", "about": "Proeflokaal/restaurant: Ja (Brewpub)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Groest 52, Hilversum", "Website: https://www.lionsheadbrewing.com"], "latitude": 52.2241, "longitude": 5.1782}, {"id": 1038, "title": "Gooische Bierbrouwerij", "location": "Hilversum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Geuzenweg 132, Hilversum", "Website: https://gooischebierbrouwerij.nl"], "latitude": 52.2291, "longitude": 5.1882}, {"id": 1039, "title": "Stadsbrouwerij Radboud", "location": "Medemblik", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Smidstraat 4, Medemblik", "Website: https://brouwerijradboud.nl"], "latitude": 52.7712, "longitude": 5.1051}, {"id": 1040, "title": "Brouwerij Eggert", "location": "Purmerend", "about": "Proeflokaal/restaurant: Ja (Grand Café Eggert)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spoorstraat 2, Purmerend", "Website: https://www.brouwerijeggert.nl"], "latitude": 52.5051, "longitude": 4.9582}, {"id": 1041, "title": "Brouwerij Leeghwater", "location": "De Rijp", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Verlaat 4, De Rijp", "Website: https://www.brouwerijleeghwater.nl"], "latitude": 52.5581, "longitude": 4.8482}, {"id": 1042, "title": "Damsegat Brouwerij", "location": "Almere", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Damsluisweg 12, Almere", "Website: https://www.damsegat.nl"], "latitude": 52.3812, "longitude": 5.2582}, {"id": 1043, "title": "Stadsbrouwerij Vos", "location": "Epe", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 14, Epe", "Website: https://www.brouwerijvos.nl"], "latitude": 52.3482, "longitude": 5.9182}, {"id": 1044, "title": "Brouwerij Martinus", "location": "Groningen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kostersgang 32, Groningen", "Website: https://brouwerijmartinus.nl"], "latitude": 53.2172, "longitude": 6.5712}, {"id": 1045, "title": "Baxbier Brewery", "location": "Groningen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Proefboerderij)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Friesestraatweg 201, Groningen", "Website: https://www.baxbier.com"], "latitude": 53.2281, "longitude": 6.5382}, {"id": 1046, "title": "Grconnected / Eggens", "location": "Groningen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Eemskanaal Noordzijde 48, Groningen", "Website: https://www.eggenscraftbeer.nl"], "latitude": 53.2192, "longitude": 6.5882}, {"id": 1047, "title": "Dockum Stadsbrouwerij", "location": "Dokkum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal ProefDokkum)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Pipenpoy 2, Dokkum", "Website: https://www.stadsbrouwerijdokkum.nl"], "latitude": 53.3281, "longitude": 5.9991}, {"id": 1048, "title": "Grutte Pier Brouwerij", "location": "Bartlehiem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Elingsloane 11, Bartlehiem", "Website: https://gruttepierbrouwerij.nl"], "latitude": 53.2801, "longitude": 5.8282}, {"id": 1049, "title": "Us Heit Sneeker Pijp", "location": "Bolsward", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Distilleerderij)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Stittenserlaan 1, Bolsward", "Website: https://www.usheit.com"], "latitude": 53.0612, "longitude": 5.5221}, {"id": 1050, "title": "Het Stadsbrouwhuis", "location": "Arnhem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Brewpub)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijnkade 45, Arnhem", "Website: https://stadsbrouwhuis.nl"], "latitude": 51.9781, "longitude": 5.9082}, {"id": 1051, "title": "Brouwerij De Snor", "location": "Arnhem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Koningsweg 28, Arnhem", "Website: https://www.brouwerijdesnor.nl"], "latitude": 52.0081, "longitude": 5.8821}, {"id": 1052, "title": "Oproer Craft Beer Bar", "location": "Utrecht", "about": "Proeflokaal/restaurant: Ja (Restobar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Marktstraat 10, Utrecht", "Website: https://www.oproer.nl"], "latitude": 52.0931, "longitude": 5.1182}, {"id": 1053, "title": "Stadsbrouwerij De Pelgrim", "location": "Rotterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Aelbrechtskolk 12, Rotterdam", "Website: https://pelgrimbier.nl"], "latitude": 51.9051, "longitude": 4.4482}, {"id": 1054, "title": "Stadshaven Brouwerij", "location": "Rotterdam", "about": "Proeflokaal/restaurant: Ja (Gastropub)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Mayke Swaensstraat 35, Rotterdam", "Website: https://stadshavenbrouwerij.nl"], "latitude": 51.9082, "longitude": 4.4382}, {"id": 1055, "title": "Vet-Gezond Brouwerij", "location": "Rotterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwe Binnenweg 110, Rotterdam", "Website: https://www.vetgezond.nl"], "latitude": 51.9161, "longitude": 4.4682}, {"id": 1056, "title": "Brouwerij Noordt", "location": "Rotterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Noordt)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Zaagmolenkade 46, Rotterdam", "Website: https://www.brouwerijnoordt.nl"], "latitude": 51.9322, "longitude": 4.4821}, {"id": 1057, "title": "Ramses Bier", "location": "Lage Zwaluwe", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoogeinde 18, Lage Zwaluwe", "Website: https://www.ramsesbier.nl"], "latitude": 51.7081, "longitude": 4.7082}, {"id": 1058, "title": "Brouwerij De 3 Horizonten", "location": "Megen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 45, Megen", "Website: https://www.3horizonten.nl"], "latitude": 51.8212, "longitude": 5.5682}, {"id": 1059, "title": "Stadsbrouwerij De Ring", "location": "Zierikzee", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstraat 12, Zierikzee", "Website: https://www.stadsbrouwerijdering.nl"], "latitude": 51.6492, "longitude": 3.9182}, {"id": 1060, "title": "Brouwerij Dutch Bargain", "location": "Groede", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Maritiem)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lagedijk 1, Groede", "Website: https://www.dutchbargain.com"], "latitude": 51.3781, "longitude": 3.5082}, {"id": 1061, "title": "Brouwerij De Halve Maan NL", "location": "Sluis", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstraat 4, Sluis", "Website: https://www.halvemaan.be"], "latitude": 51.3081, "longitude": 3.3882}, {"id": 1062, "title": "Stadsbrouwerij Middelburg", "location": "Middelburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vismarkt 6, Middelburg", "Website: https://www.stadsbrouwerijmiddelburg.nl"], "latitude": 51.4982, "longitude": 3.6121}, {"id": 1063, "title": "Brouwerij Slot Oostende", "location": "Goes", "about": "Proeflokaal/restaurant: Ja (Restaurant & Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Singelstraat 5, Goes", "Website: https://www.slotoostende.nl"], "latitude": 51.5042, "longitude": 3.8912}, {"id": 1064, "title": "Brouwerij Vermeersen", "location": "Oosterhout", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Volksabdij 1, Oosterhout", "Website: https://www.vermeersen.nl"], "latitude": 51.6421, "longitude": 4.8582}, {"id": 1065, "title": "Brouwerij Witte Anker", "location": "Breda", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: St. Josephstraat 10, Breda", "Website: https://www.witteanker.nl"], "latitude": 51.5861, "longitude": 4.7782}, {"id": 1066, "title": "Brouwerij Dorpszicht", "location": "Chaam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 12, Chaam", "Website: https://www.brouwerijdorpszicht.nl"], "latitude": 51.5081, "longitude": 4.8582}, {"id": 1067, "title": "Stadsbrouwerij Tilburg", "location": "Tilburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kraftsloth)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Heuvelstraat 120, Tilburg", "Website: https://www.stadsbrouwerijtilburg.nl"], "latitude": 51.5581, "longitude": 5.0882}, {"id": 1068, "title": "Loc Brewery", "location": "Tilburg", "about": "Proeflokaal/restaurant: Ja (Loc Taproom)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spoorlaan 350, Tilburg", "Website: https://www.locbrewery.com"], "latitude": 51.5601, "longitude": 5.0821}, {"id": 1069, "title": "Brouwerij De Roos", "location": "Hilvarenbeek", "about": "Proeflokaal/restaurant: Ja (Museum & Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Sint Leopoldstraat 9, Hilvarenbeek", "Website: https://www.brouwerijderoos.nl"], "latitude": 51.4851, "longitude": 5.1382}, {"id": 1070, "title": "Stadsbrouwerij Helmond", "location": "Helmond", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Deftige Aap)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kanaaldijk NW 22, Helmond", "Website: https://www.dedeftigeaap.nl"], "latitude": 51.4812, "longitude": 5.6582}, {"id": 1071, "title": "Brouwerij Muifel", "location": "Uden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vluchtoord 42, Uden", "Website: https://www.muifelbrouwerij.nl"], "latitude": 51.6612, "longitude": 5.6282}, {"id": 1072, "title": "Oijen Bierbrouwerij", "location": "Oijen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Biergarten)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Oijense Bovendijk 61, Oijen", "Website: https://www.oijenbier.nl"], "latitude": 51.8281, "longitude": 5.5082}, {"id": 1073, "title": "Brouwerij De Block", "location": "Elst", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Sint Maartenskerkstraat 8, Elst", "Website: https://www.brouwerijdeblock.nl"], "latitude": 51.9181, "longitude": 5.8482}, {"id": 1074, "title": "Stadsbrouwerij Wageningen", "location": "Wageningen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: 1e Kloostersteeg 4, Wageningen", "Website: https://www.stadsbrouwerijwageningen.nl"], "latitude": 51.9681, "longitude": 5.6682}, {"id": 1075, "title": "Heidebrouwerij", "location": "Ede", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwe Kazernelaan 2, Ede", "Website: https://www.deheidebrouwerij.nl"], "latitude": 52.0381, "longitude": 5.6782}, {"id": 1076, "title": "Burg Bieren", "location": "Ermelo", "about": "Proeflokaal/restaurant: Ja (Biercafé De Zaak)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Ermeloseweg 57, Ermelo", "Website: https://www.burgbieren.nl"], "latitude": 52.2981, "longitude": 5.6282}, {"id": 1077, "title": "Brouwerij Het Anker NL", "location": "Harderwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 20, Harderwijk", "Website: https://www.hetanker.nl"], "latitude": 52.3481, "longitude": 5.6182}, {"id": 1078, "title": "Stadsbrouwerij Kampen", "location": "Kampen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Bovennieuwstraat 112, Kampen", "Website: https://www.stadsbrouwerijkampen.nl"], "latitude": 52.5581, "longitude": 5.9182}, {"id": 1079, "title": "Brouwerij Het Tweekoppige Pheerd", "location": "Spakenburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Botterstraat 4, Spakenburg", "Website: https://www.tweekoppigpheerd.nl"], "latitude": 52.2481, "longitude": 5.3782}, {"id": 1080, "title": "Brouwerij De Unger", "location": "Spakenburg", "about": "Proeflokaal/restaurant: Nee (Winkel)", "tags": ["NEDERLAND"], "facts": ["Adres: Oude Schans 12, Spakenburg", "Website: https://www.brouwerijdeunger.nl"], "latitude": 52.2491, "longitude": 5.3792}, {"id": 1081, "title": "Stadsbrouwerij Vollenhove", "location": "Vollenhove", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 22, Vollenhove", "Website: https://www.brouwerijvollenhove.nl"], "latitude": 52.6812, "longitude": 5.9482}, {"id": 1082, "title": "Brouwerij Zwolle", "location": "Zwolle", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Het Engelse Werk)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Thomas a Kempisstraat 33, Zwolle", "Website: https://www.brouwerijzwolle.nl"], "latitude": 52.5181, "longitude": 6.0982}, {"id": 1083, "title": "Axel Bierbrouwerij", "location": "Axel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 10, Axel", "Website: https://www.axelbier.nl"], "latitude": 51.2681, "longitude": 3.9082}, {"id": 1084, "title": "Stadsbrouwerij De Koperen Kat", "location": "Delft", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Schieweg 15M, Delft", "Website: https://www.koperenkat.nl"], "latitude": 52.0012, "longitude": 4.3682}, {"id": 1085, "title": "Delftse Pauw Brouwerij", "location": "Delft", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Pauwstraat 12, Delft", "Website: https://www.delftsepauw.nl"], "latitude": 52.0112, "longitude": 4.3582}, {"id": 1086, "title": "Brouwerij Scheveningen", "location": "Den Haag", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Keizerstraat)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Keizerstraat 58, Den Haag", "Website: https://www.brouwerijscheveningen.nl"], "latitude": 52.1051, "longitude": 4.2782}, {"id": 1087, "title": "Haagse Broeder", "location": "Den Haag", "about": "Proeflokaal/restaurant: Ja (Kloosterproeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Westeinde 12A, Den Haag", "Website: https://www.haagsebroeder.nl"], "latitude": 52.0781, "longitude": 4.3012}, {"id": 1088, "title": "EemBier", "location": "Soest", "about": "Proeflokaal/restaurant: Nee (Proeflokaal op afspraak)", "tags": ["NEDERLAND"], "facts": ["Adres: Nieuweweg 14, Soest", "Website: https://www.eembier.nl"], "latitude": 52.1781, "longitude": 5.2982}, {"id": 1089, "title": "Brouwerij De Leckere", "location": "Utrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Leckere Werkspoor)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vreedenburg 12, Utrecht", "Website: https://www.deleckere.nl"], "latitude": 52.0912, "longitude": 5.0782}, {"id": 1090, "title": "Oude Rijn Brouwerij", "location": "Hazenwoude", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijndijk 42, Hazenwoude", "Website: https://www.ouderijnbrouwerij.nl"], "latitude": 52.1381, "longitude": 4.5882}, {"id": 1091, "title": "Leidsch Bier", "location": "Leiden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal op afspraak)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Fahrenheitstraat 14, Leiden", "Website: https://www.leidschbier.nl"], "latitude": 52.1581, "longitude": 4.4882}, {"id": 1092, "title": "Brouwerij Pronk", "location": "Leiden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Pronk)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lammermarkt 20, Leiden", "Website: https://www.brouwerijpronk.nl"], "latitude": 52.1631, "longitude": 4.4892}, {"id": 1093, "title": "Singel Brouwerij", "location": "Leiden", "about": "Proeflokaal/restaurant: Ja (Café De Vergulde Kruik)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lange Mare 42, Leiden", "Website: https://www.singelbrouwerij.nl"], "latitude": 52.1612, "longitude": 4.4912}, {"id": 1094, "title": "Brouwerij Klein Duimpje", "location": "Hillegom", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Streekwinkel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Leidsestraat 170, Hillegom", "Website: https://www.kleinduimpje.nl"], "latitude": 52.2912, "longitude": 4.5782}, {"id": 1095, "title": "Gooische Landbrouwerij", "location": "Loosdrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuw Loosdrechtseweg 21, Loosdrecht", "Website: https://www.gooischelandbrouwerij.nl"], "latitude": 52.1981, "longitude": 5.1482}, {"id": 1096, "title": "Naarden Vesting Brouwerij", "location": "Naarden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Vesting)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Marktstraat 22, Naarden", "Website: https://www.vestingbrouwerij.nl"], "latitude": 52.2981, "longitude": 5.1612}, {"id": 1097, "title": "Stadsbrouwerij Weesp", "location": "Weesp", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstad 34, Weesp", "Website: https://www.stadsbrouwerijweesp.nl"], "latitude": 52.3091, "longitude": 5.0432}, {"id": 1098, "title": "Brouwerij 't Smisje", "location": "Aalst", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 18, Aalst", "Website: https://www.smisje.nl"], "latitude": 51.8122, "longitude": 5.1282}, {"id": 1099, "title": "Brouwerij De Schrans", "location": "Leeuwarden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Schrans 42, Leeuwarden", "Website: https://www.deschrans.nl"], "latitude": 53.1981, "longitude": 5.7982}, {"id": 1100, "title": "Groninger Brouwerij", "location": "Groningen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Boterdiep 44, Groningen", "Website: https://www.groningerbrouwerij.nl"], "latitude": 53.2212, "longitude": 6.5682}, {"id": 1101, "title": "Stadsbrouwerij De Koning", "location": "Groningen", "about": "Proeflokaal/restaurant: Ja (Café De Koning)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Oosterstraat 12, Groningen", "Website: https://www.stadsbrouwerijdekoning.nl"], "latitude": 53.2181, "longitude": 6.5702}, {"id": 1102, "title": "Brouwerij Westerwolde", "location": "Wedde", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Tuin)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 8, Wedde", "Website: https://www.brouwerijwesterwolde.nl"], "latitude": 53.0681, "longitude": 7.0782}, {"id": 1103, "title": "Stadsbrouwerij Almelo", "location": "Almelo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 42, Almelo", "Website: https://www.stadsbrouwerijalmelo.nl"], "latitude": 52.3581, "longitude": 6.6682}, {"id": 1104, "title": "Brouwerij Rigters", "location": "Enschede", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Deurningerstraat 12, Enschede", "Website: https://www.rigtersbier.nl"], "latitude": 52.2281, "longitude": 6.8982}, {"id": 1105, "title": "Twentse Bierbrouwerij", "location": "Hengelo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Proeflokaal Restaurant)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Haaksbergerstraat 51, Hengelo", "Website: https://www.twentsebierbrouwerij.nl"], "latitude": 52.2612, "longitude": 6.7882}, {"id": 1106, "title": "Blackout Brewing", "location": "Almere", "about": "Proeflokaal/restaurant: Nee (Webshop)", "tags": ["NEDERLAND"], "facts": ["Adres: Kotterbosweg 12, Almere", "Website: https://www.blackoutbrewing.nl"], "latitude": 52.3912, "longitude": 5.2882}, {"id": 1107, "title": "Stadsbrouwerij Lelystad", "location": "Lelystad", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Neringpassage 14, Lelystad", "Website: https://www.stadsbrouwerijlelystad.nl"], "latitude": 52.5081, "longitude": 5.4782}, {"id": 1108, "title": "Brouwerij Stijl", "location": "Arnhem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Stijl)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwe Kade 18, Arnhem", "Website: https://www.brouwerijstijl.nl"], "latitude": 51.9812, "longitude": 5.9282}, {"id": 1109, "title": "Brouwerij D'n Draak", "location": "'s-Hertogenbosch", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hinthamerstraat 102, 's-Hertogenbosch", "Website: https://www.brouwerijdndraak.nl"], "latitude": 51.6881, "longitude": 5.3082}, {"id": 1110, "title": "Stadsbrouwerij 't Kollektief", "location": "'s-Hertogenbosch", "about": "Proeflokaal/restaurant: Ja (Café)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kolk 4, 's-Hertogenbosch", "Website: https://www.kollektief.nl"], "latitude": 51.6912, "longitude": 5.3012}, {"id": 1111, "title": "Brouwerij Boegbeeld", "location": "'s-Hertogenbosch", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kutbier)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Zandstraat 40, 's-Hertogenbosch", "Website: https://www.brouwerijboegbeeld.nl"], "latitude": 51.6931, "longitude": 5.3092}, {"id": 1112, "title": "Brouwerij De Pelgrim", "location": "Nieuwkuijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorp 12, Nieuwkuijk", "Website: https://www.brouwerijdepelgrim.nl"], "latitude": 51.6812, "longitude": 5.1782}, {"id": 1113, "title": "Stadsbrouwerij Breda", "location": "Breda", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Reigerstraat 14, Breda", "Website: https://www.stadsbrouwerijbreda.nl"], "latitude": 51.5891, "longitude": 4.7762}, {"id": 1114, "title": "Brouwerij Witte Trappist", "location": "Tilburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Koninghoeven 1, Tilburg", "Website: https://www.latrappetrappist.com"], "latitude": 51.5433, "longitude": 5.1293}, {"id": 1115, "title": "Brouwerij De Dochter van de Korenaar NL", "location": "Baarle-Nassau", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grens 2, Baarle-Nassau", "Website: https://www.dedochtervandekorenaar.be"], "latitude": 51.4481, "longitude": 4.9282}, {"id": 1116, "title": "Brouwerij Bliksem", "location": "Breda", "about": "Proeflokaal/restaurant: Ja (Bar Bliksem)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Liniestraat 12, Breda", "Website: https://www.brouwerijbliksem.nl"], "latitude": 51.5981, "longitude": 4.7852}, {"id": 1117, "title": "Brouwerij Vroegesteeg", "location": "Delft", "about": "Proeflokaal/restaurant: Ja (Restobar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Binnenwatersloot 8, Delft", "Website: https://www.vroegesteeg.nl"], "latitude": 52.0081, "longitude": 4.3521}, {"id": 1118, "title": "Brouwerij Egmond", "location": "Egmond aan den Hoef", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Sancti Adalberti)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Torenweg 12, Egmond aan den Hoef", "Website: https://www.brouwerijegmond.nl"], "latitude": 52.6212, "longitude": 4.6582}, {"id": 1119, "title": "Texelse Kwakkel", "location": "Den Burg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Schilderweg 10, Den Burg", "Website: https://www.texelsekwakkel.nl"], "latitude": 53.0512, "longitude": 4.7982}, {"id": 1120, "title": "Brouwerij Tesselaar", "location": "Oudeschild", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Tesselaar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spinnekop 2, Oudeschild", "Website: https://www.tesselaarfamiliebrouwers.nl"], "latitude": 53.0412, "longitude": 4.8421}, {"id": 1121, "title": "Stadsbrouwerij Sneek", "location": "Sneek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Marktstraat 4, Sneek", "Website: https://www.stadsbrouwerijsneek.nl"], "latitude": 53.0322, "longitude": 5.6582}, {"id": 1122, "title": "Brouwerij Vlieland", "location": "Vlieland", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Fort)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Fortweg 2, Vlieland", "Website: https://www.fortbrouwerijvlieland.nl"], "latitude": 53.2981, "longitude": 5.0682}, {"id": 1123, "title": "Brouwerij Terschelling", "location": "Oosterend", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Terschelling)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdweg 12, Oosterend", "Website: https://www.schoemrakker.nl"], "latitude": 53.4012, "longitude": 5.3782}, {"id": 1124, "title": "Brouwerij Ameland", "location": "Buren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ameland)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kiekduun 1, Buren", "Website: https://www.amelandbier.nl"], "latitude": 53.4481, "longitude": 5.8082}, {"id": 1125, "title": "Brouwerij Schiermonnikoog", "location": "Schiermonnikoog", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Middenstreek 10, Schiermonnikoog", "Website: https://www.brouwerijschiermonnikoog.nl"], "latitude": 53.4781, "longitude": 6.1582}, {"id": 1126, "title": "Brouwerij Breugem", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Breugem Meeting)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwe Hemweg 2, Amsterdam", "Website: https://www.breugembier.nl"], "latitude": 52.3981, "longitude": 4.8682}, {"id": 1127, "title": "Brouwerij De Eeuwige Jeugd", "location": "Amsterdam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Eeuwige Jeugd)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Linnaeusstraat 37A, Amsterdam", "Website: https://www.deeeuwigejeugd.nl"], "latitude": 52.3612, "longitude": 4.9212}, {"id": 1128, "title": "Brouwerij Bird Brewery", "location": "Diemen", "about": "Proeflokaal/restaurant: Ja (House of Bird)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Diemerbos 1, Diemen", "Website: https://birdbrewery.com"], "latitude": 52.3281, "longitude": 4.9882}, {"id": 1129, "title": "Brouwerij Borrelnoot", "location": "Zaandam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Havenstraat 12, Zaandam", "Website: https://www.brouwerijborrelnoot.nl"], "latitude": 52.4381, "longitude": 4.8182}, {"id": 1130, "title": "Brouwerij Brederode", "location": "Santpoort-Zuid", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Brederodestraat 10, Santpoort-Zuid", "Website: https://www.brederodebier.nl"], "latitude": 52.4281, "longitude": 4.6382}, {"id": 1131, "title": "Brouwerij Jopen Proeflokaal Waarderpolder", "location": "Haarlem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Taproom)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Emrikweg 21, Haarlem", "Website: https://www.jopenkerk.nl"], "latitude": 52.3891, "longitude": 4.6621}, {"id": 1132, "title": "Stadsbrouwerij Velsen", "location": "Beverwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Breedstraat 12, Beverwijk", "Website: https://www.stadsbrouwerijvelsen.nl"], "latitude": 52.4881, "longitude": 4.6582}, {"id": 1133, "title": "Brouwerij Rodenburg", "location": "Zwaanshoek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Rodenburg)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spieringweg 1000, Zwaanshoek", "Website: https://www.rodenburgbier.nl"], "latitude": 52.3281, "longitude": 4.5982}, {"id": 1134, "title": "Brouwerij Lionstone", "location": "Zoetermeer", "about": "Proeflokaal/restaurant: Nee (Webshop)", "tags": ["NEDERLAND"], "facts": ["Adres: Koraalrood 12, Zoetermeer", "Website: https://www.lionstone.nl"], "latitude": 52.0481, "longitude": 4.4982}, {"id": 1135, "title": "Brouwerij Groene Hart", "location": "Woerden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorp 42, Woerden", "Website: https://www.groenehartbier.nl"], "latitude": 52.0881, "longitude": 4.8882}, {"id": 1136, "title": "Stadsbrouwerij Gouda", "location": "Gouda", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gouda)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Oosthaven 12, Gouda", "Website: https://www.stadsbrouwerijgouda.nl"], "latitude": 52.0112, "longitude": 4.7121}, {"id": 1137, "title": "Brouwerij De Molen Taproom", "location": "Bodegraven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Eetcafé)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Overtoom 45, Bodegraven", "Website: https://www.brouwerijdemolen.nl"], "latitude": 52.0833, "longitude": 4.7485}, {"id": 1138, "title": "Brouwerij De Kade", "location": "Gorinchem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nijverheidsweg 10, Gorinchem", "Website: https://www.brouwerijdekade.nl"], "latitude": 51.8381, "longitude": 4.9782}, {"id": 1139, "title": "Stadsbrouwerij Dordrecht", "location": "Dordrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Dordrecht)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Budastraat 20, Dordrecht", "Website: https://www.stadsbrouwerijdordrecht.nl"], "latitude": 51.8151, "longitude": 4.6682}, {"id": 1140, "title": "Brouwerij Ebontree", "location": "Dordrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spuiboulevard 300, Dordrecht", "Website: https://www.ebontree.nl"], "latitude": 51.8122, "longitude": 4.6621}, {"id": 1141, "title": "Brouwerij De Snaterende Eend", "location": "Eethen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 88, Eethen", "Website: https://www.snaterendeeend.nl"], "latitude": 51.7381, "longitude": 5.0582}, {"id": 1142, "title": "Brouwerij Biesbosch", "location": "Werkendam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Biesbosch)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Haven 4, Werkendam", "Website: https://www.biesboschbier.nl"], "latitude": 51.8112, "longitude": 4.8912}, {"id": 1143, "title": "Brouwerij Dijkhaag", "location": "Nieuwendijk", "about": "Proeflokaal/restaurant: Nee (Webshop)", "tags": ["NEDERLAND"], "facts": ["Adres: Rijksweg 12, Nieuwendijk", "Website: https://www.dijkhaag.nl"], "latitude": 51.7781, "longitude": 4.9182}, {"id": 1144, "title": "Brouwerij Alphense Boys", "location": "Alphen aan den Rijn", "about": "Proeflokaal/restaurant: Ja (Clubhuis / Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Sportlaan 2, Alphen aan den Rijn", "Website: https://www.alphenseboysbier.nl"], "latitude": 52.1381, "longitude": 4.6582}, {"id": 1145, "title": "Brouwerij Schelde (NL Kantoor)", "location": "Willemstad", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vissersdijk 12, Willemstad", "Website: https://www.scheldebrouwerij.com"], "latitude": 51.6912, "longitude": 4.4382}, {"id": 1146, "title": "Brouwerij De Halve Tamme", "location": "Zevenbergen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 10, Zevenbergen", "Website: https://www.dehalvetamme.nl"], "latitude": 51.6481, "longitude": 4.6082}, {"id": 1147, "title": "Stadsbrouwerij Roosendaal", "location": "Roosendaal", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 22, Roosendaal", "Website: https://www.stadsbrouwerijroosendaal.nl"], "latitude": 51.5312, "longitude": 4.4582}, {"id": 1148, "title": "Brouwerij Bergen op Zoom", "location": "Bergen op Zoom", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lievevrouwestraat 12, Bergen op Zoom", "Website: https://www.brouwerijboz.nl"], "latitude": 51.4951, "longitude": 4.2882}, {"id": 1149, "title": "Brouwerij Sterkens NL", "location": "Meerle", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorp 1, Meerle", "Website: https://www.sterkens.nl"], "latitude": 51.4881, "longitude": 4.7882}, {"id": 1150, "title": "Brouwerij Het Wit Kasteel", "location": "Loon op Zand", "about": "Proeflokaal/restaurant: Ja (Kasteel Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kasteellaan 1, Loon op Zand", "Website: https://www.hetwitkasteel.nl"], "latitude": 51.6281, "longitude": 5.0782}, {"id": 1151, "title": "Brouwerij De Dorpsgenoot", "location": "Oisterwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 4, Oisterwijk", "Website: https://www.dedorpsgenoot.nl"], "latitude": 51.5812, "longitude": 5.1982}, {"id": 1152, "title": "Brouwerij Reusel", "location": "Reusel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Wilhelminalaan 10, Reusel", "Website: https://www.brouwerijreusel.nl"], "latitude": 51.3612, "longitude": 5.1682}, {"id": 1153, "title": "Brouwerij Veldhoven", "location": "Veldhoven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 50, Veldhoven", "Website: https://www.brouwerijveldhoven.nl"], "latitude": 51.4181, "longitude": 5.4082}, {"id": 1154, "title": "Brouwerij Van Moll", "location": "Eindhoven", "about": "Proeflokaal/restaurant: Ja (Craft Beer Bar Van Moll)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Keizersgracht 16A, Eindhoven", "Website: https://www.vanmollcraftbeer.com"], "latitude": 51.4371, "longitude": 5.4762}, {"id": 1155, "title": "Brouwerij Het Veem", "location": "Eindhoven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Het Veem)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Strijp-S Veemgebouw, Eindhoven", "Website: https://www.brouwerijhetveem.nl"], "latitude": 51.4481, "longitude": 5.4582}, {"id": 1156, "title": "Brouwerij De Kazerne", "location": "Waahlre", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: KazernePad 1, Waahlre", "Website: https://www.brouwerijdekazerne.nl"], "latitude": 51.3912, "longitude": 5.4482}, {"id": 1157, "title": "Brouwerij Valkenswaard", "location": "Valkenswaard", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Statiestraat 12, Valkenswaard", "Website: https://www.brouwerijvalkenswaard.nl"], "latitude": 51.3512, "longitude": 5.4582}, {"id": 1158, "title": "Brouwerij Cranendonck", "location": "Budel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 2, Budel", "Website: https://www.cranendonckbier.nl"], "latitude": 51.2781, "longitude": 5.5782}, {"id": 1159, "title": "Budelse Brouwerij", "location": "Budel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Brouwerij)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstraat 18, Budel", "Website: https://www.budels.nl"], "latitude": 51.2721, "longitude": 5.5721}, {"id": 1160, "title": "Brouwerij De Fontein", "location": "Stein", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Terras)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Onderstestraat 27, Stein", "Website: https://www.brouwerijdefontein.nl"], "latitude": 50.9681, "longitude": 5.7682}, {"id": 1161, "title": "Brouwerij De Koppelpoort", "location": "Sittard", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuweweg 4, Sittard", "Website: https://www.dekoppelpoort.nl"], "latitude": 50.9981, "longitude": 5.8682}, {"id": 1162, "title": "Stadsbrouwerij Sittard", "location": "Sittard", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Sittard)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Helstraat 12, Sittard", "Website: https://www.stadsbrouwerijsittard.nl"], "latitude": 50.9991, "longitude": 5.8712}, {"id": 1163, "title": "Brouwerij Amstelbeek", "location": "Susteren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg 44, Susteren", "Website: https://www.amstelbeek.nl"], "latitude": 51.0612, "longitude": 5.8582}, {"id": 1164, "title": "Brouwerij Rolduc", "location": "Kerkrade", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Abdij Rolduc)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Heyendallaan 82, Kerkrade", "Website: https://www.rolduc.org"], "latitude": 50.8681, "longitude": 6.0882}, {"id": 1165, "title": "Stadsbrouwerij Heerlen", "location": "Heerlen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Pancratiusplein 1, Heerlen", "Website: https://www.stadsbrouwerijheerlen.nl"], "latitude": 50.8881, "longitude": 5.9782}, {"id": 1166, "title": "Brouwerij Zwarte Ruiter", "location": "Gulpen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Zwarte Ruiter)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 12, Gulpen", "Website: https://www.zwarteruiter.nl"], "latitude": 50.8151, "longitude": 5.8921}, {"id": 1167, "title": "Brouwerij Bosch", "location": "Maastricht", "about": "Proeflokaal/restaurant: Ja (Museum & Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Muntstraat 17, Maastricht", "Website: https://www.brouwerijbosch.nl"], "latitude": 50.8522, "longitude": 5.6912}, {"id": 1168, "title": "Stadsbrouwerij Valkenburg", "location": "Valkenburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Berkelstraat 14, Valkenburg", "Website: https://www.stadsbrouwerijvalkenburg.nl"], "latitude": 50.8651, "longitude": 5.8321}, {"id": 1169, "title": "Brouwerij Meerssen", "location": "Meerssen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 4, Meerssen", "Website: https://www.brouwerijmeerssen.nl"], "latitude": 50.8851, "longitude": 5.7521}, {"id": 1170, "title": "Brouwerij Grensland", "location": "Kessel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kessel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg 1, Kessel", "Website: https://www.grenslandbier.nl"], "latitude": 51.2981, "longitude": 6.0582}, {"id": 1171, "title": "Brouwerij Venlo", "location": "Venlo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Venlo)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Parade 12, Venlo", "Website: https://www.brouwerijvenlo.nl"], "latitude": 51.3681, "longitude": 6.1682}, {"id": 1172, "title": "Brouwerij De Weerd", "location": "Roermond", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kasteelwerf 1, Roermond", "Website: https://www.brouwerijdeweerd.nl"], "latitude": 51.1981, "longitude": 5.9882}, {"id": 1173, "title": "Brouwerij De Fontein Venray", "location": "Venray", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 10, Venray", "Website: https://www.brouwerijvenray.nl"], "latitude": 51.5281, "longitude": 5.9782}, {"id": 1174, "title": "Brouwerij De Graaf van Heumen", "location": "Heumen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 12, Heumen", "Website: https://www.graafvanheumen.nl"], "latitude": 51.7681, "longitude": 5.8482}, {"id": 1175, "title": "Stadsbrouwerij Kronenburger", "location": "Nijmegen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kronenburgersingel 1, Nijmegen", "Website: https://www.kronenburger.nl"], "latitude": 51.8451, "longitude": 5.8582}, {"id": 1176, "title": "Brouwerij Katjelam", "location": "Nijmegen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Katjelam)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Waalkade 12, Nijmegen", "Website: https://www.katjelam.nl"], "latitude": 51.8501, "longitude": 5.8621}, {"id": 1177, "title": "Brouwerij Oefelt", "location": "Oeffelt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 2, Oeffelt", "Website: https://www.brouwerijoeffelt.nl"], "latitude": 51.6981, "longitude": 5.9382}, {"id": 1178, "title": "Stadsbrouwerij Cuijk", "location": "Cuijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 14, Cuijk", "Website: https://www.stadsbrouwerijcuijk.nl"], "latitude": 51.7281, "longitude": 5.8782}, {"id": 1179, "title": "Brouwerij Gennep", "location": "Gennep", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Zandstraat 22, Gennep", "Website: https://www.brouwerijgennep.nl"], "latitude": 51.6981, "longitude": 5.9782}, {"id": 1180, "title": "Brouwerij De Cleene Hooghe", "location": "Boxmeer", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoogstraat 4, Boxmeer", "Website: https://www.cleenehooghe.nl"], "latitude": 51.6481, "longitude": 5.9482}, {"id": 1181, "title": "Brouwerij Oss", "location": "Oss", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Oss)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Monsterstraat 8, Oss", "Website: https://www.brouwerijoss.nl"], "latitude": 51.7681, "longitude": 5.5282}, {"id": 1182, "title": "Stadsbrouwerij Zaltbommel", "location": "Zaltbommel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Boschstraat 12, Zaltbommel", "Website: https://www.stadsbrouwerijzaltbommel.nl"], "latitude": 51.8122, "longitude": 5.2521}, {"id": 1183, "title": "Brouwerij De Plukker NL", "location": "Geldermalsen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorp 10, Geldermalsen", "Website: https://www.brouwerijdeplukker.nl"], "latitude": 51.8812, "longitude": 5.2782}, {"id": 1184, "title": "Brouwerij Culemborg", "location": "Culemborg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Herenstraat 14, Culemborg", "Website: https://www.brouwerijculemborg.nl"], "latitude": 51.9581, "longitude": 5.2282}, {"id": 1185, "title": "Stadsbrouwerij Tiel", "location": "Tiel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Tiel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Waterstraat 10, Tiel", "Website: https://www.stadsbrouwerijtiel.nl"], "latitude": 51.8881, "longitude": 5.4382}, {"id": 1186, "title": "Brouwerij De Hemel Taproom", "location": "Nijmegen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Hemel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lange Hezelstraat 4, Nijmegen", "Website: https://www.brouwerijdehemel.nl"], "latitude": 51.8471, "longitude": 5.8612}, {"id": 1187, "title": "Stadsbrouwerij Doesburg", "location": "Doesburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Meepoortstraat 12, Doesburg", "Website: https://www.stadsbrouwerijdoesburg.nl"], "latitude": 52.0122, "longitude": 6.1382}, {"id": 1188, "title": "Brouwerij Bronckhorst", "location": "Brummen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Eetcafé)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rhienderensestraat 18, Brummen", "Website: https://www.bronckhorsterbieren.nl"], "latitude": 52.0881, "longitude": 6.1582}, {"id": 1189, "title": "Brouwerij De Hanze", "location": "Zutphen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hanze)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Zutphenseweg 12, Zutphen", "Website: https://www.brouwerjdehanze.nl"], "latitude": 52.1381, "longitude": 6.2082}, {"id": 1190, "title": "Stadsbrouwerij Zutphen", "location": "Zutphen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zutphen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Koolmarkt 4, Zutphen", "Website: https://www.stadsbrouwerijzutphen.nl"], "latitude": 52.1412, "longitude": 6.1982}, {"id": 1191, "title": "Brouwerij De Vlijt", "location": "Apeldoorn", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Vlijt)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vlijtseweg 114, Apeldoorn", "Website: https://www.brouwerijdevlijt.nl"], "latitude": 52.2281, "longitude": 5.9682}, {"id": 1192, "title": "Veluwse Schavuyt", "location": "Apeldoorn", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Schavuyt)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vlijtseweg 114B, Apeldoorn", "Website: https://www.veluwseschavuyt.nl"], "latitude": 52.2291, "longitude": 5.9692}, {"id": 1193, "title": "Brouwerij Uddel", "location": "Uddel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Uddel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Uddelermeerweg 2, Uddel", "Website: https://www.brouwerijuddel.nl"], "latitude": 52.2581, "longitude": 5.7882}, {"id": 1194, "title": "Brouwerij Nunspeet", "location": "Nunspeet", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 14, Nunspeet", "Website: https://www.brouwerijnunspeet.nl"], "latitude": 52.3381, "longitude": 5.7882}, {"id": 1195, "title": "Brouwerij Harderwijk", "location": "Harderwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Harderwijk)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Houtwal 2, Harderwijk", "Website: https://www.brouwerijharderwijk.nl"], "latitude": 52.3491, "longitude": 5.6212}, {"id": 1196, "title": "Stadsbrouwerij Elburg", "location": "Elburg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Elburg)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Vispoortstraat 12, Elburg", "Website: https://www.stadsbrouwerijelburg.nl"], "latitude": 52.4481, "longitude": 5.8382}, {"id": 1197, "title": "Brouwerij Hattem", "location": "Hattem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 8, Hattem", "Website: https://www.brouwerijhattem.nl"], "latitude": 52.4781, "longitude": 6.0682}, {"id": 1198, "title": "Stadsbrouwerij Zwolle Het Anker", "location": "Zwolle", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Sassenstraat)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Sassenstraat 12, Zwolle", "Website: https://www.hetankerzwolle.nl"], "latitude": 52.5122, "longitude": 6.0951}, {"id": 1199, "title": "Brouwerij Dalfsen", "location": "Dalfsen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkplein 4, Dalfsen", "Website: https://www.brouwerijdalfsen.nl"], "latitude": 52.5081, "longitude": 6.2582}, {"id": 1200, "title": "Brouwerij Ommen", "location": "Ommen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ommen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 8, Ommen", "Website: https://www.brouwerijommen.nl"], "latitude": 52.5181, "longitude": 6.4282}, {"id": 1201, "title": "Brouwerij Hardenberg", "location": "Hardenberg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Voorstraat 10, Hardenberg", "Website: https://www.brouwerijhardenberg.nl"], "latitude": 52.5781, "longitude": 6.6182}, {"id": 1202, "title": "Stadsbrouwerij Coevorden", "location": "Coevorden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Friesestraat 12, Coevorden", "Website: https://www.stadsbrouwerijcoevorden.nl"], "latitude": 52.6612, "longitude": 6.7412}, {"id": 1203, "title": "Brouwerij Hoogeveen", "location": "Hoogeveen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdstraat 22, Hoogeveen", "Website: https://www.brouwerijhoogeveen.nl"], "latitude": 52.7281, "longitude": 6.4782}, {"id": 1204, "title": "Brouwerij Meppel", "location": "Meppel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Meppel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdstraat 40, Meppel", "Website: https://www.brouwerijmeppel.nl"], "latitude": 52.6981, "longitude": 6.1982}, {"id": 1205, "title": "Brouwerij Steenwijk", "location": "Steenwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 12, Steenwijk", "Website: https://www.brouwerijsteenwijk.nl"], "latitude": 52.7881, "longitude": 6.1182}, {"id": 1206, "title": "Brouwerij Giethoorn", "location": "Giethoorn", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Eetcafé)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Binnenpad 42, Giethoorn", "Website: https://www.brouwerijgiethoorn.nl"], "latitude": 52.8381, "longitude": 6.0782}, {"id": 1207, "title": "Brouwerij Wolvega", "location": "Wolvega", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdstraat 10, Wolvega", "Website: https://www.brouwerijwolvega.nl"], "latitude": 52.8781, "longitude": 6.0082}, {"id": 1208, "title": "Brouwerij Heerenveen", "location": "Heerenveen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Lindegracht 12, Heerenveen", "Website: https://www.brouwerijheerenveen.nl"], "latitude": 52.9581, "longitude": 5.9182}, {"id": 1209, "title": "Stadsbrouwerij Joure", "location": "Joure", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Midstraat 14, Joure", "Website: https://www.stadsbrouwerijjoure.nl"], "latitude": 52.9681, "longitude": 5.7982}, {"id": 1210, "title": "Brouwerij Lemmer", "location": "Lemmer", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kortestreek 8, Lemmer", "Website: https://www.brouwerijlemmer.nl"], "latitude": 52.8481, "longitude": 5.7082}, {"id": 1211, "title": "Brouwerij Workum", "location": "Workum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Begine 12, Workum", "Website: https://www.brouwerijworkum.nl"], "latitude": 52.9781, "longitude": 5.4482}, {"id": 1212, "title": "Brouwerij Hindeloopen", "location": "Hindeloopen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 2, Hindeloopen", "Website: https://www.brouwerijhindeloopen.nl"], "latitude": 52.9422, "longitude": 5.4012}, {"id": 1213, "title": "Stadsbrouwerij Stavoren", "location": "Stavoren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Stavoren)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Haven 4, Stavoren", "Website: https://www.stadsbrouwerijstavoren.nl"], "latitude": 52.8881, "longitude": 5.3582}, {"id": 1214, "title": "Brouwerij Harlingen", "location": "Harlingen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Harlingen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Noorderhaven 12, Harlingen", "Website: https://www.brouwerijharlingen.nl"], "latitude": 53.1751, "longitude": 5.4182}, {"id": 1215, "title": "Brouwerij Franeker", "location": "Franeker", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Voorstraat 20, Franeker", "Website: https://www.brouwerijfraneker.nl"], "latitude": 53.1881, "longitude": 5.5382}, {"id": 1216, "title": "Stadsbrouwerij Leeuwarden In De Koperen Tuin", "location": "Leeuwarden", "about": "Proeflokaal/restaurant: Ja (Restaurant & Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Prinsentuin 1, Leeuwarden", "Website: https://www.indekoperentuin.nl"], "latitude": 53.2051, "longitude": 5.7912}, {"id": 1217, "title": "Brouwerij Crooked Spider", "location": "Wassenaar", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Energieweg 12, Wassenaar", "Website: https://www.crookedspider.nl"], "latitude": 52.1381, "longitude": 4.3982}, {"id": 1218, "title": "Brouwerij De Pelgrim Katwijk", "location": "Katwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Strand)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Boulevard 10, Katwijk", "Website: https://www.pelgrimkatwijk.nl"], "latitude": 52.2012, "longitude": 4.3912}, {"id": 1219, "title": "Brouwerij Noordwijk", "location": "Noordwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Strand)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Parallelboulevard 20, Noordwijk", "Website: https://www.brouwerijnoordwijk.nl"], "latitude": 52.2412, "longitude": 4.4312}, {"id": 1220, "title": "Stadsbrouwerij Zandvoort", "location": "Zandvoort", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Thorbeckestraat 4, Zandvoort", "Website: https://www.stadsbrouwerijzandvoort.nl"], "latitude": 52.3722, "longitude": 4.5282}, {"id": 1221, "title": "Brouwerij IJmuiden", "location": "IJmuiden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Havenkade 12, IJmuiden", "Website: https://www.brouwerijijmuiden.nl"], "latitude": 52.4581, "longitude": 4.5882}, {"id": 1222, "title": "Brouwerij Alkmaar", "location": "Alkmaar", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Alkmaar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Plompetorengracht 4, Alkmaar", "Website: https://www.brouwerijalkmaar.nl"], "latitude": 52.6312, "longitude": 4.7482}, {"id": 1223, "title": "Brouwerij De Boom", "location": "Alkmaar", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Boom)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Houttil 1, Alkmaar", "Website: https://www.proeflokaaldeboom.nl"], "latitude": 52.6315, "longitude": 4.7501}, {"id": 1224, "title": "Brouwerij Bergen", "location": "Bergen (NH)", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 12, Bergen (NH)", "Website: https://www.brouwerijbergen.nl"], "latitude": 52.6712, "longitude": 4.7012}, {"id": 1225, "title": "Brouwerij Schoorl", "location": "Schoorl", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Schoorl)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Duinweg 8, Schoorl", "Website: https://www.brouwerijschoorl.nl"], "latitude": 52.7012, "longitude": 4.6912}, {"id": 1226, "title": "Brouwerij Den Helder", "location": "Den Helder", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Willemsoord)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Willemsoord 42, Den Helder", "Website: https://www.brouwerijdenhelder.nl"], "latitude": 52.9581, "longitude": 4.7682}, {"id": 1227, "title": "Stadsbrouwerij Enkhuizen", "location": "Enkhuizen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Enkhuizen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dijk 12, Enkhuizen", "Website: https://www.stadsbrouwerijenkhuizen.nl"], "latitude": 52.7012, "longitude": 5.2912}, {"id": 1228, "title": "Brouwerij Hoorn", "location": "Hoorn", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hoorn)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grote Oost 20, Hoorn", "Website: https://www.brouwerijhoorn.nl"], "latitude": 52.6412, "longitude": 5.0612}, {"id": 1229, "title": "Brouwerij Volendam", "location": "Volendam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Volendam)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Haven 40, Volendam", "Website: https://www.brouwerijvolendam.nl"], "latitude": 52.4951, "longitude": 5.0712}, {"id": 1230, "title": "Brouwerij Marken", "location": "Marken", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Marken)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkbuurt 12, Marken", "Website: https://www.brouwerijmarken.nl"], "latitude": 52.4581, "longitude": 5.1082}, {"id": 1231, "title": "Brouwerij Monnickendam", "location": "Monnickendam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Noordeinde 10, Monnickendam", "Website: https://www.brouwerijmonnickendam.nl"], "latitude": 52.4612, "longitude": 5.0382}, {"id": 1232, "title": "Stadsbrouwerij Edam", "location": "Edam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Edam)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Spui 4, Edam", "Website: https://www.stadsbrouwerijedam.nl"], "latitude": 52.5112, "longitude": 5.0482}, {"id": 1233, "title": "Brouwerij Wormerveer", "location": "Wormerveer", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zaan)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Zaanweg 20, Wormerveer", "Website: https://www.brouwerijwormerveer.nl"], "latitude": 52.4912, "longitude": 4.8012}, {"id": 1234, "title": "Brouwerij Krommenie", "location": "Krommenie", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Zuiderhoofdstraat 12, Krommenie", "Website: https://www.brouwerijkrommenie.nl"], "latitude": 52.5012, "longitude": 4.7682}, {"id": 1235, "title": "Brouwerij Castricum", "location": "Castricum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 40, Castricum", "Website: https://www.brouwerijcastricum.nl"], "latitude": 52.5481, "longitude": 4.6682}, {"id": 1236, "title": "Brouwerij Heemskerk", "location": "Heemskerk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkweg 10, Heemskerk", "Website: https://www.brouwerijheemskerk.nl"], "latitude": 52.5112, "longitude": 4.6712}, {"id": 1237, "title": "Stadsbrouwerij Purmerend", "location": "Purmerend", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstraat 12, Purmerend", "Website: https://www.stadsbrouwerijpurmerend.nl"], "latitude": 52.5081, "longitude": 4.9582}, {"id": 1238, "title": "Brouwerij Landsmeer", "location": "Landsmeer", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 20, Landsmeer", "Website: https://www.brouwerijlandsmeer.nl"], "latitude": 52.4312, "longitude": 4.9112}, {"id": 1239, "title": "Brouwerij Oostzaan", "location": "Oostzaan", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkbuurt 8, Oostzaan", "Website: https://www.brouwerijoostzaan.nl"], "latitude": 52.4412, "longitude": 4.8782}, {"id": 1240, "title": "Brouwerij Huizen", "location": "Huizen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Nautisch)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Havenstraat 14, Huizen", "Website: https://www.brouwerijhuizen.nl"], "latitude": 52.3012, "longitude": 5.2412}, {"id": 1241, "title": "Stadsbrouwerij Laren", "location": "Laren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Brink)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Brink 12, Laren", "Website: https://www.stadsbrouwerijlaren.nl"], "latitude": 52.2581, "longitude": 5.2282}, {"id": 1242, "title": "Brouwerij Blaricum", "location": "Blaricum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Blaricum)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 10, Blaricum", "Website: https://www.brouwerijblaricum.nl"], "latitude": 52.2712, "longitude": 5.2482}, {"id": 1243, "title": "Brouwerij Bussum", "location": "Bussum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Bussum)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kapelstraat 20, Bussum", "Website: https://www.brouwerijbussum.nl"], "latitude": 52.2781, "longitude": 5.1612}, {"id": 1244, "title": "Brouwerij Naarden", "location": "Naarden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Marktstraat 10, Naarden", "Website: https://www.brouwerijnaarden.nl"], "latitude": 52.2981, "longitude": 5.1621}, {"id": 1245, "title": "Brouwerij Muiden", "location": "Muiden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Muiderslot)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hellingstraat 4, Muiden", "Website: https://www.brouwerijmuiden.nl"], "latitude": 52.3312, "longitude": 5.0682}, {"id": 1246, "title": "Brouwerij Abcoude", "location": "Abcoude", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Abcoude)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoogstraat 12, Abcoude", "Website: https://www.brouwerijabcoude.nl"], "latitude": 52.2712, "longitude": 4.9782}, {"id": 1247, "title": "Stadsbrouwerij Breukelen", "location": "Breukelen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Vecht)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Straatweg 10, Breukelen", "Website: https://www.stadsbrouwerijbreukelen.nl"], "latitude": 52.1712, "longitude": 5.0012}, {"id": 1248, "title": "Brouwerij Maarssen", "location": "Maarssen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkweg 4, Maarssen", "Website: https://www.brouwerijmaarssen.nl"], "latitude": 52.1412, "longitude": 5.0412}, {"id": 1249, "title": "Brouwerij IJsselstein", "location": "IJsselstein", "about": "Proeflokaal/restaurant: Ja (Proeflokaal IJsselstein)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 20, IJsselstein", "Website: https://www.brouwerijijsselstein.nl"], "latitude": 52.0212, "longitude": 5.0412}, {"id": 1250, "title": "Brouwerij Nieuwegein", "location": "Nieuwegein", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Stadsplein 1, Nieuwegein", "Website: https://www.brouwerijnieuwegein.nl"], "latitude": 52.0312, "longitude": 5.0812}, {"id": 1251, "title": "Brouwerij Houten", "location": "Houten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Houten)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Het Rond 12, Houten", "Website: https://www.brouwerijhouten.nl"], "latitude": 52.0381, "longitude": 5.1682}, {"id": 1252, "title": "Stadsbrouwerij Wijk bij Duurstede", "location": "Wijk bij Duurstede", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 4, Wijk bij Duurstede", "Website: https://www.stadsbrouwerijwijk.nl"], "latitude": 51.9712, "longitude": 5.3482}, {"id": 1253, "title": "Brouwerij Rhenen", "location": "Rhenen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Rhenen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 12, Rhenen", "Website: https://www.brouwerijrhenen.nl"], "latitude": 51.9581, "longitude": 5.5682}, {"id": 1254, "title": "Brouwerij Veenendaal", "location": "Veenendaal", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdstraat 40, Veenendaal", "Website: https://www.brouwerijveenendaal.nl"], "latitude": 52.0281, "longitude": 5.5582}, {"id": 1255, "title": "Stadsbrouwerij Barneveld", "location": "Barneveld", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Jan van Schaffelaarstraat 10, Barneveld", "Website: https://www.stadsbrouwerijbarneveld.nl"], "latitude": 52.1412, "longitude": 5.5882}, {"id": 1256, "title": "Brouwerij Scherpenzeel", "location": "Scherpenzeel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 22, Scherpenzeel", "Website: https://www.brouwerijscherpenzeel.nl"], "latitude": 52.0781, "longitude": 5.4882}, {"id": 1257, "title": "Brouwerij Leusden", "location": "Leusden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Leusden)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hamersveldseweg 30, Leusden", "Website: https://www.brouwerijleusden.nl"], "latitude": 52.1312, "longitude": 5.4282}, {"id": 1258, "title": "Brouwerij Nijkerk", "location": "Nijkerk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Pleintje 4, Nijkerk", "Website: https://www.brouwerijnijkerk.nl"], "latitude": 52.2212, "longitude": 5.4882}, {"id": 1259, "title": "Brouwerij Putten", "location": "Putten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Putten)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 18, Putten", "Website: https://www.brouwerijputten.nl"], "latitude": 52.2581, "longitude": 5.6082}, {"id": 1260, "title": "Brouwerij Zeist", "location": "Zeist", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Slot Zeist)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Slotlaan 100, Zeist", "Website: https://www.brouwerijzeist.nl"], "latitude": 52.0881, "longitude": 5.2382}, {"id": 1261, "title": "Brouwerij De Bilt", "location": "De Bilt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Utrechtseweg 12, De Bilt", "Website: https://www.brouwerijdebilt.nl"], "latitude": 52.1081, "longitude": 5.1882}, {"id": 1262, "title": "Brouwerij Bunnik", "location": "Bunnik", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Bunnik)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 8, Bunnik", "Website: https://www.brouwerijbunnik.nl"], "latitude": 52.0681, "longitude": 5.2082}, {"id": 1263, "title": "Brouwerij Soest", "location": "Soest", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Soest)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Soesterbergsestraat 20, Soest", "Website: https://www.brouwerijsoest.nl"], "latitude": 52.1712, "longitude": 5.2882}, {"id": 1264, "title": "Brouwerij Baarn", "location": "Baarn", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Baarn)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Laanstraat 40, Baarn", "Website: https://www.brouwerijbaarn.nl"], "latitude": 52.2122, "longitude": 5.2882}, {"id": 1265, "title": "Stadsbrouwerij Zevenaar", "location": "Zevenaar", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 10, Zevenaar", "Website: https://www.stadsbrouwerijzevenaar.nl"], "latitude": 51.9281, "longitude": 6.0782}, {"id": 1266, "title": "Brouwerij Duiven", "location": "Duiven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg 20, Duiven", "Website: https://www.brouwerijduiven.nl"], "latitude": 51.9481, "longitude": 6.0182}, {"id": 1267, "title": "Brouwerij Westervoort", "location": "Westervoort", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 14, Westervoort", "Website: https://www.brouwerijwestervoort.nl"], "latitude": 51.9612, "longitude": 5.9712}, {"id": 1268, "title": "Brouwerij Elst", "location": "Elst (Gld)", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Elst)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 30, Elst (Gld)", "Website: https://www.brouwerijelst.nl"], "latitude": 51.9181, "longitude": 5.8482}, {"id": 1269, "title": "Brouwerij Huissen", "location": "Huissen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Langekerkstraat 4, Huissen", "Website: https://www.brouwerijhuissen.nl"], "latitude": 51.9381, "longitude": 5.9482}, {"id": 1270, "title": "Stadsbrouwerij Bemmel", "location": "Bemmel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kasteel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kinkelenburglaan 1, Bemmel", "Website: https://www.stadsbrouwerijbemmel.nl"], "latitude": 51.8912, "longitude": 5.8982}, {"id": 1271, "title": "Brouwerij Wijchen", "location": "Wijchen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kasteel Wijchen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kasteellaan 10, Wijchen", "Website: https://www.brouwerijwijchen.nl"], "latitude": 51.8081, "longitude": 5.7282}, {"id": 1272, "title": "Brouwerij Beuningen", "location": "Beuningen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Wilhelminalaan 12, Beuningen", "Website: https://www.brouwerijbeuningen.nl"], "latitude": 51.8581, "longitude": 5.7682}, {"id": 1273, "title": "Brouwerij Druten", "location": "Druten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Druten)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hogt 4, Druten", "Website: https://www.brouwerijdruten.nl"], "latitude": 51.8881, "longitude": 5.6082}, {"id": 1274, "title": "Stadsbrouwerij Groenlo", "location": "Groenlo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Grolsch Historie)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Beltrumsestraat 10, Groenlo", "Website: https://www.stadsbrouwerijgroenlo.nl"], "latitude": 52.0412, "longitude": 6.6182}, {"id": 1275, "title": "Brouwerij Winterswijk", "location": "Winterswijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Winterswijk)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 20, Winterswijk", "Website: https://www.brouwerijwinterswijk.nl"], "latitude": 51.9712, "longitude": 6.7212}, {"id": 1276, "title": "Brouwerij Aalten", "location": "Aalten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dinxperlosestraatweg 12, Aalten", "Website: https://www.brouwerijaalten.nl"], "latitude": 51.9281, "longitude": 6.5812}, {"id": 1277, "title": "Brouwerij Lichtenvoorde", "location": "Lichtenvoorde", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rapenburg 4, Lichtenvoorde", "Website: https://www.brouwerijlichtenvoorde.nl"], "latitude": 51.9881, "longitude": 6.5712}, {"id": 1278, "title": "Brouwerij Lochem", "location": "Lochem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Lochem)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 8, Lochem", "Website: https://www.brouwerijlochem.nl"], "latitude": 52.1581, "longitude": 6.4182}, {"id": 1279, "title": "Brouwerij Borculo", "location": "Borculo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 12, Borculo", "Website: https://www.brouwerijborculo.nl"], "latitude": 52.1122, "longitude": 6.5282}, {"id": 1280, "title": "Brouwerij Eibergen", "location": "Eibergen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 20, Eibergen", "Website: https://www.brouwerijeibergen.nl"], "latitude": 52.1012, "longitude": 6.6482}, {"id": 1281, "title": "Stadsbrouwerij Needse", "location": "Neede", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 10, Neede", "Website: https://www.stadsbrouwerijneede.nl"], "latitude": 52.1381, "longitude": 6.6182}, {"id": 1282, "title": "Brouwerij Haaksbergen", "location": "Haaksbergen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Haaksbergen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 14, Haaksbergen", "Website: https://www.brouwerijhaaksbergen.nl"], "latitude": 52.1581, "longitude": 6.7412}, {"id": 1283, "title": "Brouwerij Oldenzaal", "location": "Oldenzaal", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Oldenzaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 12, Oldenzaal", "Website: https://www.brouwerijoldenzaal.nl"], "latitude": 52.3122, "longitude": 6.9282}, {"id": 1284, "title": "Brouwerij Ootmarsum", "location": "Ootmarsum", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ootmarsum)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Markt 4, Ootmarsum", "Website: https://www.brouwerijootmarsum.nl"], "latitude": 52.4081, "longitude": 6.8982}, {"id": 1285, "title": "Brouwerij Tubbergen", "location": "Tubbergen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 18, Tubbergen", "Website: https://www.brouwerijtubbergen.nl"], "latitude": 52.4081, "longitude": 6.7812}, {"id": 1286, "title": "Brouwerij Den Ham", "location": "Den Ham", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Brink 10, Den Ham", "Website: https://www.brouwerijdenham.nl"], "latitude": 52.4612, "longitude": 6.4982}, {"id": 1287, "title": "Brouwerij Rijssen", "location": "Rijssen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Eshuisstraat 12, Rijssen", "Website: https://www.brouwerijrijssen.nl"], "latitude": 52.3081, "longitude": 6.5182}, {"id": 1288, "title": "Brouwerij Goor", "location": "Goor", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 30, Goor", "Website: https://www.brouwerijgoor.nl"], "latitude": 52.2322, "longitude": 6.5882}, {"id": 1289, "title": "Brouwerij Delden", "location": "Delden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kasteel Twickel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Langestraat 10, Delden", "Website: https://www.brouwerijdelden.nl"], "latitude": 52.2612, "longitude": 6.7112}, {"id": 1290, "title": "Brouwerij Markelo", "location": "Markelo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 14, Markelo", "Website: https://www.brouwerijmarkelo.nl"], "latitude": 52.2381, "longitude": 6.4982}, {"id": 1291, "title": "Brouwerij Raalte", "location": "Raalte", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Plasmanstraat 4, Raalte", "Website: https://www.brouwerijraalte.nl"], "latitude": 52.3881, "longitude": 6.2782}, {"id": 1292, "title": "Brouwerij Wijhe", "location": "Wijhe", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wijhe)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Langstraat 20, Wijhe", "Website: https://www.brouwerijwijhe.nl"], "latitude": 52.3881, "longitude": 6.1382}, {"id": 1293, "title": "Brouwerij Olst", "location": "Olst", "about": "Proeflokaal/restaurant: Ja (Proeflokaal IJssel)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Aamsoort 2, Olst", "Website: https://www.brouwerijolst.nl"], "latitude": 52.3381, "longitude": 6.1182}, {"id": 1294, "title": "Brouwerij Lemelerveld", "location": "Lemelerveld", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 8, Lemelerveld", "Website: https://www.brouwerijlemelerveld.nl"], "latitude": 52.4481, "longitude": 6.3482}, {"id": 1295, "title": "Brouwerij Nijverdal", "location": "Nijverdal", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Grotestraat 40, Nijverdal", "Website: https://www.brouwerijnijverdal.nl"], "latitude": 52.3612, "longitude": 6.4612}, {"id": 1296, "title": "Stadsbrouwerij Steenwijkerwold", "location": "Steenwijkerwold", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 2, Steenwijkerwold", "Website: https://www.brouwerijsteenwijkerwold.nl"], "latitude": 52.8081, "longitude": 6.0682}, {"id": 1297, "title": "Brouwerij Appingedam", "location": "Appingedam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Appingedam)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dijkstraat 12, Appingedam", "Website: https://www.brouwerijappingedam.nl"], "latitude": 53.2181, "longitude": 6.8582}, {"id": 1298, "title": "Brouwerij Delfzijl", "location": "Delfzijl", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Waterstraat 4, Delfzijl", "Website: https://www.brouwerijdelfzijl.nl"], "latitude": 53.3312, "longitude": 6.9212}, {"id": 1299, "title": "Brouwerij Veendam", "location": "Veendam", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 10, Veendam", "Website: https://www.brouwerijveendam.nl"], "latitude": 53.1081, "longitude": 6.8782}, {"id": 1300, "title": "Brouwerij Stadskanaal", "location": "Stadskanaal", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Europalaan 2, Stadskanaal", "Website: https://www.brouwerijstadskanaal.nl"], "latitude": 52.9881, "longitude": 6.9582}, {"id": 1301, "title": "Brouwerij Winschoten", "location": "Winschoten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Torenstraat 14, Winschoten", "Website: https://www.brouwerijwinschoten.nl"], "latitude": 53.1481, "longitude": 7.0382}, {"id": 1302, "title": "Brouwerij Haren", "location": "Haren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Haren)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Rijksstraatweg 100, Haren", "Website: https://www.brouwerijharen.nl"], "latitude": 53.1712, "longitude": 6.6082}, {"id": 1303, "title": "Brouwerij Roden", "location": "Roden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Roden)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Albertsbaan 2, Roden", "Website: https://www.brouwerijroden.nl"], "latitude": 53.1381, "longitude": 6.4382}, {"id": 1304, "title": "Brouwerij Leek", "location": "Leek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Nienoord)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Tolberterstraat 12, Leek", "Website: https://www.brouwerijleek.nl"], "latitude": 53.1612, "longitude": 6.3882}, {"id": 1305, "title": "Brouwerij Assen", "location": "Assen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Assen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Marktstraat 10, Assen", "Website: https://www.brouwerijassen.nl"], "latitude": 52.9981, "longitude": 6.5621}, {"id": 1306, "title": "Brouwerij Zuidlaren", "location": "Zuidlaren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: De Deuring 4, Zuidlaren", "Website: https://www.brouwerijzuidlaren.nl"], "latitude": 53.0981, "longitude": 6.6882}, {"id": 1307, "title": "Brouwerij Gieten", "location": "Gieten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gieten)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Dorpsstraat 12, Gieten", "Website: https://www.brouwerijgieten.nl"], "latitude": 53.0081, "longitude": 6.7682}, {"id": 1308, "title": "Brouwerij Borger", "location": "Borger", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hunebed)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdstraat 20, Borger", "Website: https://www.brouwerijborger.nl"], "latitude": 52.9281, "longitude": 6.7921}, {"id": 1309, "title": "Brouwerij Emmen", "location": "Emmen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Emmen)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Hoofdstraat 50, Emmen", "Website: https://www.brouwerijemmen.nl"], "latitude": 52.7881, "longitude": 6.8982}, {"id": 1310, "title": "Brouwerij Klazienaveen", "location": "Klazienaveen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Van Echtenstraat 10, Klazienaveen", "Website: https://www.brouwerijklazienaveen.nl"], "latitude": 52.7212, "longitude": 6.9882}, {"id": 1311, "title": "Brouwerij Coevorden Kasteel", "location": "Coevorden", "about": "Proeflokaal/restaurant: Ja (Kasteel Restaurant & Bar)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Kasteel 1, Coevorden", "Website: https://www.kasteelcoevorden.nl"], "latitude": 52.6622, "longitude": 6.7421}, {"id": 1312, "title": "Brouwerij Ter Apel", "location": "Ter Apel", "about": "Proeflokaal/restaurant: Ja (Klooster Proeflokaal)", "tags": ["NEDERLAND", "PROEFLOKAAL"], "facts": ["Adres: Boslaan 2, Ter Apel", "Website: https://www.brouwerijterapel.nl"], "latitude": 52.8781, "longitude": 7.0682}, {"id": 2001, "title": "Brouwerij Cantillon", "location": "Anderlecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Museum)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Gheudestraat 56, Anderlecht", "Website: https://www.cantillon.be"], "latitude": 50.8415, "longitude": 4.3353}, {"id": 2002, "title": "Brouwerij 3 Fonteinen", "location": "Lot", "about": "Proeflokaal/restaurant: Ja (Lambik-O-Droom)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Molenstraat 47, Lot", "Website: https://www.3fonteinen.be"], "latitude": 50.7634, "longitude": 4.2764}, {"id": 2003, "title": "Brouwerij Oud Beersel", "location": "Beersel", "about": "Proeflokaal/restaurant: Ja (Bierhuis Oud Beersel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Laarheidestraat 230, Beersel", "Website: https://www.oudbeersel.com"], "latitude": 50.7584, "longitude": 4.3012}, {"id": 2004, "title": "Brouwerij Boon", "location": "Lembeek", "about": "Proeflokaal/restaurant: Ja (Boon Bar)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Indiestraat 21, Lembeek", "Website: https://www.boon.be"], "latitude": 50.7121, "longitude": 4.2231}, {"id": 2005, "title": "Brouwerij Lindemans", "location": "Vlezenbeek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Lenniksebaan 1431, Vlezenbeek", "Website: https://www.lindemans.be"], "latitude": 50.8162, "longitude": 4.2123}, {"id": 2006, "title": "Brouwerij Timmermans", "location": "Itterbeek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 11, Itterbeek", "Website: https://brasserietimmermans.be"], "latitude": 50.8421, "longitude": 4.2482}, {"id": 2007, "title": "Brouwerij De Troch", "location": "Wambeek", "about": "Proeflokaal/restaurant: Nee (Proeflokaal op afspraak)", "tags": ["BELGIË"], "facts": ["Adres: Langestraat 64, Wambeek", "Website: https://www.detroch.be"], "latitude": 50.8582, "longitude": 4.1612}, {"id": 2008, "title": "Brouwerij Girardin", "location": "Sint-Ulriks-Kapelle", "about": "Proeflokaal/restaurant: Nee (Winkel)", "tags": ["BELGIË"], "facts": ["Adres: Delestraat 10, Sint-Ulriks-Kapelle", "Website: https://www.girardin.be"], "latitude": 50.8781, "longitude": 4.2112}, {"id": 2009, "title": "Brouwerij De Dochter van de Korenaar", "location": "Baarle-Hertog", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grens 2, Baarle-Hertog", "Website: https://www.dedochtervandekorenaar.be"], "latitude": 51.4481, "longitude": 4.9282}, {"id": 2010, "title": "Brouwerij Het Anker", "location": "Mechelen", "about": "Proeflokaal/restaurant: Ja (Brasserie Het Anker)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Guido Gezellelaan 49, Mechelen", "Website: https://www.hetanker.be"], "latitude": 51.0315, "longitude": 4.4732}, {"id": 2011, "title": "Brouwerij De Halve Maan", "location": "Brugge", "about": "Proeflokaal/restaurant: Ja (Brasserie & Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Walplein 26, Brugge", "Website: https://www.halvemaan.be"], "latitude": 51.2025, "longitude": 3.2241}, {"id": 2012, "title": "Brouwerij Bourgogne des Flandres", "location": "Brugge", "about": "Proeflokaal/restaurant: Ja (Alehouse & Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kartuizersstraat 6, Brugge", "Website: https://www.bourgognedesflandres.be"], "latitude": 51.2062, "longitude": 3.2265}, {"id": 2013, "title": "Brouwerij Fort Lapin", "location": "Brugge", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Fort Lapin 25, Brugge", "Website: https://www.fortlapin.com"], "latitude": 51.2212, "longitude": 3.2351}, {"id": 2014, "title": "Brouwerij Rodenbach", "location": "Roeselare", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum & Bar)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Spanjestraat 133, Roeselare", "Website: https://www.rodenbach.be"], "latitude": 50.9512, "longitude": 3.1282}, {"id": 2015, "title": "Brouwerij Kazematten", "location": "Ieper", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Houten Paard 1, Ieper", "Website: https://www.kazematten.be"], "latitude": 50.8492, "longitude": 2.8951}, {"id": 2016, "title": "Brouwerij De Ranke", "location": "Dottignies", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stoney Road 12, Dottignies", "Website: https://www.deranke.be"], "latitude": 50.7321, "longitude": 3.3212}, {"id": 2017, "title": "Brouwerij Het Steenberge", "location": "Ertvelde", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Bar D'Achouffe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Doornzelestraat 3, Ertvelde", "Website: https://www.vansteenberge.com"], "latitude": 51.1781, "longitude": 3.7482}, {"id": 2018, "title": "Stadsbrouwerij Gruut", "location": "Gent", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rendersglas 17, Gent", "Website: https://www.gruut.be"], "latitude": 51.0531, "longitude": 3.7312}, {"id": 2019, "title": "Dulle Griet Taproom", "location": "Gent", "about": "Proeflokaal/restaurant: Ja (Biercafé)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Vrijdagmarkt 50, Gent", "Website: https://www.dullegriet.be"], "latitude": 51.0562, "longitude": 3.7261}, {"id": 2020, "title": "Brouwerij Huyghe", "location": "Melle", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Geraardsbergsesteenweg 14B, Melle", "Website: https://www.delirium.be"], "latitude": 51.0021, "longitude": 3.8012}, {"id": 2021, "title": "Brouwerij Verhaeghe", "location": "Vichte", "about": "Proeflokaal/restaurant: Nee (Brouwerijwinkel)", "tags": ["BELGIË"], "facts": ["Adres: Kasterstraat 67, Vichte", "Website: https://www.brouwerijverhaeghe.be"], "latitude": 50.8351, "longitude": 3.3682}, {"id": 2022, "title": "Brouwerij De Poes", "location": "Tielt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal op afspraak)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kasteelstraat 21, Tielt", "Website: https://www.brouwerijdepoes.be"], "latitude": 51.0012, "longitude": 3.3282}, {"id": 2023, "title": "Brouwerij Omer Vander Ghinste", "location": "Bellegem", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 24, Bellegem", "Website: https://www.omervanderghinste.be"], "latitude": 50.7781, "longitude": 3.2882}, {"id": 2024, "title": "Brouwerij St.Bernardus", "location": "Watou", "about": "Proeflokaal/restaurant: Ja (Bar Bernard Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Trappistenweg 23, Watou", "Website: https://www.sintbernardus.be"], "latitude": 50.8412, "longitude": 2.6312}, {"id": 2025, "title": "Brouwerij De Struise Brouwers", "location": "Oostvleteren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Oud Schooltje)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Schoolstraat 22, Oostvleteren", "Website: https://www.struise.com"], "latitude": 50.9312, "longitude": 2.7382}, {"id": 2026, "title": "Brouwerij De Ryck", "location": "Herzele", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 10, Herzele", "Website: https://www.brouwerijderyck.be"], "latitude": 50.8881, "longitude": 3.8912}, {"id": 2027, "title": "Brouwerij Contreras", "location": "Gavere", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Molenstraat 11, Gavere", "Website: https://www.kontreras.be"], "latitude": 50.9312, "longitude": 3.6612}, {"id": 2028, "title": "Brouwerij Liefmans", "location": "Oudenaarde", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Aalststraat 200, Oudenaarde", "Website: https://www.liefmans.be"], "latitude": 50.8412, "longitude": 3.6112}, {"id": 2029, "title": "Brouwerij Roman", "location": "Mater", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Maurits Romanstraat 1, Mater", "Website: https://www.roman.be"], "latitude": 50.8381, "longitude": 3.6582}, {"id": 2030, "title": "Brouwerij Cnudde", "location": "Ename", "about": "Proeflokaal/restaurant: Nee (Lokale verkoop)", "tags": ["BELGIË"], "facts": ["Adres: Fabriekstraat 3, Ename", "Website: https://www.brouwerijcnudde.be"], "latitude": 50.8612, "longitude": 3.6312}, {"id": 2031, "title": "Brouwerij Smisje", "location": "Mater", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Materplein 8, Mater", "Website: https://www.smisje.be"], "latitude": 50.8391, "longitude": 3.6621}, {"id": 2032, "title": "Brouwerij 't Verzet", "location": "Anzegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Deisselkercke 14, Anzegem", "Website: https://www.brouwerijtverzet.be"], "latitude": 50.8312, "longitude": 3.4782}, {"id": 2033, "title": "Brouwerij De Busschere", "location": "Hulste", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstraat 12, Hulste", "Website: https://www.debusschere.be"], "latitude": 50.8812, "longitude": 3.2882}, {"id": 2034, "title": "Brouwerij De Brabandere", "location": "Bavikhove", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg 33, Bavikhove", "Website: https://www.brouwerijdebrabandere.be"], "latitude": 50.8612, "longitude": 3.3182}, {"id": 2035, "title": "Brouwerij Van Eecke", "location": "Watou", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Het Brouwershuis)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Douvieweg 2, Watou", "Website: https://www.hetkapittel.be"], "latitude": 50.8581, "longitude": 2.6212}, {"id": 2036, "title": "Brouwerij Leroy", "location": "Boezinge", "about": "Proeflokaal/restaurant: Nee (Brouwerijwinkel)", "tags": ["BELGIË"], "facts": ["Adres: Elverdingestraat 40, Boezinge", "Website: https://www.leroybreweries.be"], "latitude": 50.8981, "longitude": 2.8582}, {"id": 2037, "title": "Brasserie Dubuisson", "location": "Pipaix", "about": "Proeflokaal/restaurant: Ja (Taverne Dubuisson)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Chaussée de Mons 28, Pipaix", "Website: https://www.dubuisson.com"], "latitude": 50.5681, "longitude": 3.5782}, {"id": 2038, "title": "Brasserie Dupont", "location": "Tourpes", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Boucherie 5, Tourpes", "Website: https://www.brasserie-dupont.com"], "latitude": 50.5781, "longitude": 3.6482}, {"id": 2039, "title": "Brasserie Saint-Monon", "location": "Ambly", "about": "Proeflokaal/restaurant: Ja (Taverne)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Chapelle 12, Ambly", "Website: https://www.saintmonon.be"], "latitude": 50.1281, "longitude": 5.3082}, {"id": 2040, "title": "Brasserie de Silly", "location": "Silly", "about": "Proeflokaal/restaurant: Ja (Taverne Silly)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue Bâtiment 3, Silly", "Website: https://silly-beer.com"], "latitude": 50.6481, "longitude": 3.9182}, {"id": 2041, "title": "Brasserie de Blaugies", "location": "Blaugies", "about": "Proeflokaal/restaurant: Ja (Restaurant Le Sentier)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue Dour 12, Blaugies", "Website: https://www.brasseriedeblaugies.com"], "latitude": 50.3681, "longitude": 3.7782}, {"id": 2042, "title": "Brasserie de Cazeau", "location": "Templeuve", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Kervyn 12, Templeuve", "Website: https://www.brasseriedecazeau.be"], "latitude": 50.6412, "longitude": 3.2882}, {"id": 2043, "title": "Brasserie Des Légendes", "location": "Irchonwelz", "about": "Proeflokaal/restaurant: Ja (Taverne de la Moinette)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Castel 1, Irchonwelz", "Website: https://www.brasseriedeslegendes.be"], "latitude": 50.6281, "longitude": 3.7682}, {"id": 2044, "title": "Brasserie de Jandrain-Jandrenouille", "location": "Jandrain", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Brabant 1, Jandrain", "Website: https://www.jandrain-jandrenouille.net"], "latitude": 50.6881, "longitude": 4.9782}, {"id": 2045, "title": "Brasserie de Silenrieux", "location": "Silenrieux", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Gare 2, Silenrieux", "Website: https://www.brasseriedesilenrieux.be"], "latitude": 50.2181, "longitude": 4.4182}, {"id": 2046, "title": "Brasserie de l'Abbaye de Val-Dieu", "location": "Aubel", "about": "Proeflokaal/restaurant: Ja (Casse-Croûte Val-Dieu)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Val-Dieu 227, Aubel", "Website: https://www.val-dieu.com"], "latitude": 50.7012, "longitude": 5.8082}, {"id": 2047, "title": "Brasserie Bellevaux", "location": "Bellevaux", "about": "Proeflokaal/restaurant: Ja (Taverne & Terras)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Venne 12, Bellevaux", "Website: https://www.brasseriedebellevaux.com"], "latitude": 50.3912, "longitude": 6.0082}, {"id": 2048, "title": "Brasserie Peak Beer", "location": "Sourbrodt", "about": "Proeflokaal/restaurant: Ja (Peak Beer Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Botrange 123, Sourbrodt", "Website: https://peakbeer.be"], "latitude": 50.4812, "longitude": 6.1082}, {"id": 2049, "title": "Brasserie d'Achouffe", "location": "Wibrin", "about": "Proeflokaal/restaurant: Ja (Auberge des Lutins)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Achouffe 32, Wibrin", "Website: https://chouffe.com"], "latitude": 50.1501, "longitude": 5.7461}, {"id": 2050, "title": "Brasserie de Bastogne", "location": "Sibret", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Renuamont 3, Sibret", "Website: https://www.brasseriedebastogne.be"], "latitude": 49.9781, "longitude": 5.6382}, {"id": 2051, "title": "Brasserie de Bouillon", "location": "Bouillon", "about": "Proeflokaal/restaurant: Ja (Le Moulin de Bouillon)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Moinil 1, Bouillon", "Website: https://www.brasseriedebouillon.be"], "latitude": 49.7981, "longitude": 5.0682}, {"id": 2052, "title": "Brasserie de Rochehaut", "location": "Rochehaut", "about": "Proeflokaal/restaurant: Ja (L'Auberge de la Ferme)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Cense 12, Rochehaut", "Website: https://www.rochehaut-attractions.be"], "latitude": 49.8381, "longitude": 4.9982}, {"id": 2053, "title": "Brasserie Gengoulf", "location": "Villers-devant-Orval", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Cloche 2, Villers-devant-Orval", "Website: https://www.gengoulf.be"], "latitude": 49.6281, "longitude": 5.3482}, {"id": 2054, "title": "Brasserie de la Lesse", "location": "Eprave", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Bio Eetcafé)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Bois 4, Eprave", "Website: https://www.brasseriedelalesse.be"], "latitude": 50.1381, "longitude": 5.1582}, {"id": 2055, "title": "Brasserie Caracole", "location": "Falmignoul", "about": "Proeflokaal/restaurant: Ja (Taverne & Ambachtelijke Brouwerij)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Côte de Marie-Thérèse 86, Falmignoul", "Website: https://www.brasseriecaracole.be"], "latitude": 50.2181, "longitude": 4.8682}, {"id": 2056, "title": "Brasserie du Bocq", "location": "Purnode", "about": "Proeflokaal/restaurant: Ja (Taverne du Bocq)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Brasserie 4, Purnode", "Website: https://www.bocq.be"], "latitude": 50.3181, "longitude": 4.9482}, {"id": 2057, "title": "Brasserie Bertinchamps", "location": "Gembloux", "about": "Proeflokaal/restaurant: Ja (Bistrot de Bertinchamps)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Bertinchamps 4, Gembloux", "Website: https://www.bertinchamps.be"], "latitude": 50.5612, "longitude": 4.6982}, {"id": 2058, "title": "Brasserie Lefebvre", "location": "Quenast", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Chemin du Croly 2, Quenast", "Website: https://www.brasserielefebvre.be"], "latitude": 50.6681, "longitude": 4.1682}, {"id": 2059, "title": "Brasserie de Tubize", "location": "Tubize", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Déportation 12, Tubize", "Website: https://www.brasseriedetubize.be"], "latitude": 50.6981, "longitude": 4.2082}, {"id": 2060, "title": "Brasserie de l'Ermitage", "location": "Anderlecht", "about": "Proeflokaal/restaurant: Ja (Taproom l'Ermitage)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Rasante 28, Anderlecht", "Website: https://ermitagelabeer.com"], "latitude": 50.8381, "longitude": 4.3182}, {"id": 2061, "title": "Brasserie de la Senne", "location": "Brussel", "about": "Proeflokaal/restaurant: Ja (Brewpub Senne)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Drève de Anna 1, Brussel", "Website: https://brasseriedelasenne.be"], "latitude": 50.8712, "longitude": 4.3412}, {"id": 2062, "title": "Brussels Beer Project", "location": "Brussel", "about": "Proeflokaal/restaurant: Ja (Dansaert Taproom)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Antoine Dansaertstraat 188, Brussel", "Website: https://www.beerproject.be"], "latitude": 50.8512, "longitude": 4.3421}, {"id": 2063, "title": "Beerstorming", "location": "Sint-Gillis", "about": "Proeflokaal/restaurant: Ja (Workshop & Taproom)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Chaussée de Alsemberg 142, Sint-Gillis", "Website: https://www.beerstorming.net"], "latitude": 50.8281, "longitude": 4.3482}, {"id": 2064, "title": "En Stoemelings", "location": "Laken", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dieleghemstraat 24, Laken", "Website: https://enstoemelings.brussels"], "latitude": 50.8781, "longitude": 4.3382}, {"id": 2065, "title": "L'Annexe Brasserie Fermenterie", "location": "Sint-Gillis", "about": "Proeflokaal/restaurant: Ja (Taproom)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Fort 12, Sint-Gillis", "Website: https://www.lannexe.brussels"], "latitude": 50.8312, "longitude": 4.3412}, {"id": 2066, "title": "Brasserie de la Cambre", "location": "Elsene", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Abbaye)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Impasse du Val 2, Elsene", "Website: https://www.brasseriedelacambre.be"], "latitude": 50.8181, "longitude": 4.3782}, {"id": 2067, "title": "Brouwerij De Koninck", "location": "Antwerpen", "about": "Proeflokaal/restaurant: Ja (De Koninck Bar & Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Mechelsesteenweg 291, Antwerpen", "Website: https://www.dekoninck.be"], "latitude": 51.1991, "longitude": 4.4162}, {"id": 2068, "title": "Stadsbrouwerij De Pelgrim", "location": "Antwerpen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Pelgrim)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Pelgrimstraat 12, Antwerpen", "Website: https://www.pelgrim-antwerpen.be"], "latitude": 51.2212, "longitude": 4.4012}, {"id": 2069, "title": "Seefbier Brouwerij (Antwerpse)", "location": "Antwerpen", "about": "Proeflokaal/restaurant: Ja (Seef Taproom & Biergarten)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Indiestraat 21, Antwerpen", "Website: https://www.seef.be"], "latitude": 51.2381, "longitude": 4.4121}, {"id": 2070, "title": "Galea Craft Beers", "location": "Zandhoven", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Sint-Antoniusbaan 12, Zandhoven", "Website: https://www.galeacraftbeers.be"], "latitude": 51.2181, "longitude": 4.6582}, {"id": 2071, "title": "Brouwerij Het Nest", "location": "Turnhout", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Het Nest)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Lierseweg 18, Turnhout", "Website: https://www.brouwerijhetnest.be"], "latitude": 51.3212, "longitude": 4.9282}, {"id": 2072, "title": "Brouwerij Scheldebrouwerij", "location": "Meer", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rijksweg 12, Meer", "Website: https://www.scheldebrouwerij.com"], "latitude": 51.4681, "longitude": 4.7482}, {"id": 2073, "title": "Brouwerij Sterkens", "location": "Hoogstraten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Dreef)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Meersel-Dreef 12, Hoogstraten", "Website: https://www.sterkens.be"], "latitude": 51.4881, "longitude": 4.7812}, {"id": 2074, "title": "Brouwerij Cabardouche", "location": "Deurne", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Borsbeeksebinnenweg 4, Deurne", "Website: https://www.cabardouche.be"], "latitude": 51.2012, "longitude": 4.4582}, {"id": 2075, "title": "Brouwerij Vliegende Paard", "location": "Beernem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 2, Beernem", "Website: https://www.vliegendepaard.be"], "latitude": 51.1381, "longitude": 3.3382}, {"id": 2076, "title": "Brouwerij Gulden Spoor", "location": "Kortrijk", "about": "Proeflokaal/restaurant: Ja (Biercafé Gulden Spoor)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 10, Kortrijk", "Website: https://www.guldenspoor.be"], "latitude": 50.8281, "longitude": 3.2682}, {"id": 2077, "title": "Brouwerij Toye", "location": "Heule", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Goedendag)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Heulebekestraat 12, Heule", "Website: https://www.goedendagbier.be"], "latitude": 50.8481, "longitude": 3.2382}, {"id": 2078, "title": "Brouwerij De Plokkers", "location": "Watou", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Watou)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Plokkerstraat 2, Watou", "Website: https://www.deplokkers.be"], "latitude": 50.8512, "longitude": 2.6182}, {"id": 2079, "title": "Brouwerij De Halve Maan Veurne", "location": "Veurne", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Veurne)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 1, Veurne", "Website: https://www.halvemaanveurne.be"], "latitude": 51.0722, "longitude": 2.6612}, {"id": 2080, "title": "Stadsbrouwerij Diksmuide", "location": "Diksmuide", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 12, Diksmuide", "Website: https://www.stadsbrouwerijdiksmuide.be"], "latitude": 51.0312, "longitude": 2.8682}, {"id": 2081, "title": "Brouwerij De Graal", "location": "Brakel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Graal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Warandestraat 1, Brakel", "Website: https://www.degraal.be"], "latitude": 50.8012, "longitude": 3.7682}, {"id": 2082, "title": "Brouwerij De Hoeve", "location": "Zwalm", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zwalm)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 10, Zwalm", "Website: https://www.brouwerijdehoeve.be"], "latitude": 50.8881, "longitude": 3.7282}, {"id": 2083, "title": "Brouwerij Verzetje", "location": "Kruishoutem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stationsstraat 22, Kruishoutem", "Website: https://www.brouwerijverzetje.be"], "latitude": 50.9081, "longitude": 3.5282}, {"id": 2084, "title": "Brouwerij Clarysse", "location": "Oudenaarde", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Félix)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kasteelstraat 12, Oudenaarde", "Website: https://www.felixbier.be"], "latitude": 50.8451, "longitude": 3.6082}, {"id": 2085, "title": "Brouwerij De Smedt", "location": "Opwijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Op-Ale)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 10, Opwijk", "Website: https://www.desmedtbrouwerij.be"], "latitude": 50.9681, "longitude": 4.1882}, {"id": 2086, "title": "Brouwerij Affligem (Heineken BE)", "location": "Opwijk", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum Affligem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 89, Opwijk", "Website: https://www.affligembeer.com"], "latitude": 50.9581, "longitude": 4.1482}, {"id": 2087, "title": "Brouwerij Mort Subite", "location": "Kobbegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Mort Subite)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kobbegemstraat 1, Kobbegem", "Website: https://www.mort-subite.be"], "latitude": 50.9122, "longitude": 4.2582}, {"id": 2088, "title": "Brouwerij De Landtsheer", "location": "Buggenhout", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Malheur)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Mandemakerstraat 1, Buggenhout", "Website: https://www.malheur.be"], "latitude": 51.0122, "longitude": 4.2082}, {"id": 2089, "title": "Brouwerij Bosteels", "location": "Buggenhout", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum Kwak/Tripel Karmeliet)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 92, Buggenhout", "Website: https://www.bestbelgianbeers.com"], "latitude": 51.0181, "longitude": 4.2021}, {"id": 2090, "title": "Brouwerij Slaghmuylder", "location": "Ninove", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Witkap)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Sint-Jorisstraat 2, Ninove", "Website: https://www.witkap.be"], "latitude": 50.8381, "longitude": 4.0182}, {"id": 2091, "title": "Brouwerij Haacht", "location": "Boortmeerbeek", "about": "Proeflokaal/restaurant: Ja (Brouwershuis & Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Proefbrouwerij-site 1, Boortmeerbeek", "Website: https://www.haacht.com"], "latitude": 50.9812, "longitude": 4.5882}, {"id": 2092, "title": "Brouwerij Het Anker Taproom", "location": "Mechelen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gouden Carolus)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kattestraat 12, Mechelen", "Website: https://www.hetanker.be"], "latitude": 51.0281, "longitude": 4.4782}, {"id": 2093, "title": "Microbrouwerij Urthel", "location": "Ruiselede", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Urthel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 12, Ruiselede", "Website: https://www.urthel.com"], "latitude": 51.0412, "longitude": 3.3982}, {"id": 2094, "title": "Brouwerij De Block", "location": "Peizegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Satan Beer)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 24, Peizegem", "Website: https://www.satanbeer.com"], "latitude": 50.9781, "longitude": 4.2282}, {"id": 2095, "title": "Brouwerij Palm (Swinkels BE)", "location": "Steenhuffel", "about": "Proeflokaal/restaurant: Ja (Stoeterij Palm & Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Steenhuffeldorp 24, Steenhuffel", "Website: https://www.palm.be"], "latitude": 50.9981, "longitude": 4.2682}, {"id": 2096, "title": "Brouwerij De Hoorn", "location": "Steenhuffel", "about": "Proeflokaal/restaurant: Ja (Microbrouwerij Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Steenhuffeldorp 26, Steenhuffel", "Website: https://www.cornetbeer.com"], "latitude": 50.9991, "longitude": 4.2692}, {"id": 2097, "title": "Brouwerij Duvel Moortgat", "location": "Puurs-Sint-Amands", "about": "Proeflokaal/restaurant: Ja (Duvel Depot & Cafe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Breendonkdorp 58, Puurs-Sint-Amands", "Website: https://www.duvel.com"], "latitude": 51.0431, "longitude": 4.3312}, {"id": 2098, "title": "Brouwerij Gouden Carolus Proeflokaal", "location": "Mechelen", "about": "Proeflokaal/restaurant: Ja (Biercafé Carolus)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 1, Mechelen", "Website: https://www.hetanker.be"], "latitude": 51.0281, "longitude": 4.4812}, {"id": 2099, "title": "Brouwerij Hof ten Dormaal", "location": "Tildonk", "about": "Proeflokaal/restaurant: Ja (Hoeveproeflokaal & Terras)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Caubergstraat 2, Tildonk", "Website: https://www.hoftendormaal.be"], "latitude": 50.9481, "longitude": 4.6582}, {"id": 2100, "title": "Brouwerij De Vlier", "location": "Holsbeek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal De Vlier)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kortenbergsebaan 75, Holsbeek", "Website: https://www.brouwerijdevlier.be"], "latitude": 50.9181, "longitude": 4.7282}, {"id": 2101, "title": "Stadsbrouwerij Luik (Brasserie C)", "location": "Luik", "about": "Proeflokaal/restaurant: Ja (Brasserie C Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Impasse des Ursulines 14, Luik", "Website: https://www.brasseriec.com"], "latitude": 50.6462, "longitude": 5.5782}, {"id": 2102, "title": "Brasserie de l'Abbaye de Val-Dieu Taproom", "location": "Aubel", "about": "Proeflokaal/restaurant: Ja (Abbaye Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Val-Dieu 228, Aubel", "Website: https://www.val-dieu.com"], "latitude": 50.7022, "longitude": 5.8092}, {"id": 2103, "title": "Brasserie Grain d'Orge", "location": "Hombourg", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Brice)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Pauly 1, Hombourg", "Website: https://www.grain-dorge.com"], "latitude": 50.7181, "longitude": 5.9282}, {"id": 2104, "title": "Brasserie Elfique", "location": "Aywaille", "about": "Proeflokaal/restaurant: Ja (Proeflokaal & Terras)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Raboriver 2, Aywaille", "Website: https://www.elfique.be"], "latitude": 50.4781, "longitude": 5.6882}, {"id": 2105, "title": "Brasserie de l'Amblève", "location": "Stavelot", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Amblève)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Gare 10, Stavelot", "Website: https://www.brasseriedelambleve.be"], "latitude": 50.3981, "longitude": 5.9382}, {"id": 2106, "title": "Brasserie de Malmedy", "location": "Malmedy", "about": "Proeflokaal/restaurant: Ja (Brasserie de la Warche)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place Albert 1er 12, Malmedy", "Website: https://www.malmedybeer.be"], "latitude": 50.4281, "longitude": 6.0282}, {"id": 2107, "title": "Brasserie de la Lienne", "location": "Lierneux", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Lienne)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Reharmont 7, Lierneux", "Website: https://www.brasseriedelalienne.com"], "latitude": 50.3281, "longitude": 5.7982}, {"id": 2108, "title": "Brasserie de Saint-Hubert", "location": "Saint-Hubert", "about": "Proeflokaal/restaurant: Ja (Taverne du Saint-Hubert)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place du Marché 1, Saint-Hubert", "Website: https://www.st-hubert-beer.be"], "latitude": 50.0281, "longitude": 5.3782}, {"id": 2109, "title": "Brasserie de l'Abbaye d'Orval", "location": "Villers-devant-Orval", "about": "Proeflokaal/restaurant: Ja (Auberge Ange Gardien)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Orval 1, Villers-devant-Orval", "Website: https://www.orval.be"], "latitude": 49.6381, "longitude": 5.3482}, {"id": 2110, "title": "Brasserie de Rochefort (Abbaye)", "location": "Rochefort", "about": "Proeflokaal/restaurant: Nee (Geen publiek bezoek, Lokaal verkooppunt)", "tags": ["BELGIË"], "facts": ["Adres: Rue de l'Abbaye 8, Rochefort", "Website: https://www.trappistes-rochefort.be"], "latitude": 50.1781, "longitude": 5.2282}, {"id": 2111, "title": "Brasserie de Chimay", "location": "Chimay", "about": "Proeflokaal/restaurant: Ja (Espace Chimay Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de l'Abbaye 3, Chimay", "Website: https://www.chimay.com"], "latitude": 50.0481, "longitude": 4.3382}, {"id": 2112, "title": "Brasserie de Westmalle", "location": "Malle", "about": "Proeflokaal/restaurant: Ja (Café Trappisten Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Oostmallebaan 45, Malle", "Website: https://www.trappistwestmalle.be"], "latitude": 51.2851, "longitude": 4.6582}, {"id": 2113, "title": "Brouwerij Westvleteren (Sint-Sixtus)", "location": "Vleteren", "about": "Proeflokaal/restaurant: Ja (In de Vrede Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Donkerstraat 12, Vleteren", "Website: https://www.sintsixtus.be"], "latitude": 50.8951, "longitude": 2.7212}, {"id": 2114, "title": "Brasserie de Scourmont", "location": "Bourlers", "about": "Proeflokaal/restaurant: Ja (Auberge de Poteaupré)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Scourmont 1, Bourlers", "Website: https://www.poteaupre.be"], "latitude": 50.0412, "longitude": 4.3312}, {"id": 2115, "title": "Brasserie de St. Feuillien", "location": "Rœulx", "about": "Proeflokaal/restaurant: Ja (Bezoekerscentrum)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Chaussee 2, Rœulx", "Website: https://www.st-feuillien.com"], "latitude": 50.5012, "longitude": 4.1082}, {"id": 2116, "title": "Brasserie de Binche", "location": "Binche", "about": "Proeflokaal/restaurant: Ja (Taverne de Binche)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Faubourg de Postes 1, Binche", "Website: https://www.brasseriedebinche.be"], "latitude": 50.4122, "longitude": 4.1682}, {"id": 2117, "title": "Brasserie de Brunehaut", "location": "Brunehaut", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Organic Beer)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Pense-Mont 2, Brunehaut", "Website: https://brunehaut.com"], "latitude": 50.5181, "longitude": 3.4182}, {"id": 2118, "title": "Brasserie des Carrières", "location": "Basècles", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Diôle)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 12, Basècles", "Website: https://www.brasseriedescarrieres.be"], "latitude": 50.5181, "longitude": 3.6482}, {"id": 2119, "title": "Brasserie des Vignes", "location": "Tournai", "about": "Proeflokaal/restaurant: Ja (Taverne des Vignes)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue des Vignes 4, Tournai", "Website: https://www.brasseriedesvignes.be"], "latitude": 50.6081, "longitude": 3.3882}, {"id": 2120, "title": "Brasserie de l'Abbaye de Bonne-Espérance", "location": "Vellereille-les-Brayeux", "about": "Proeflokaal/restaurant: Ja (Taverne Bonne-Espérance)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de l'Abbaye 1, Vellereille-les-Brayeux", "Website: https://www.bonne-esperance.be"], "latitude": 50.3881, "longitude": 4.1382}, {"id": 2121, "title": "Brasserie des Fagnes", "location": "Mariembourg", "about": "Proeflokaal/restaurant: Ja (Brasserie-Restaurant des Fagnes)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Route de Nismes 26, Mariembourg", "Website: https://www.brasseriedesfagnes.com"], "latitude": 50.0981, "longitude": 4.5282}, {"id": 2122, "title": "Brasserie de Couvin", "location": "Couvin", "about": "Proeflokaal/restaurant: Ja (Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Faubourg de Charleroi 12, Couvin", "Website: https://www.brasseriedecouvin.be"], "latitude": 50.0581, "longitude": 4.4982}, {"id": 2123, "title": "Brasserie de la Lesse Dinant", "location": "Dinant", "about": "Proeflokaal/restaurant: Ja (Taverne Dinant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grand Place 1, Dinant", "Website: https://www.brasseriedelalesse.be"], "latitude": 50.2612, "longitude": 4.9121}, {"id": 2124, "title": "Brasserie de Namur", "location": "Namen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Namur)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Croix 10, Namen", "Website: https://www.brasseriedenamur.be"], "latitude": 50.4651, "longitude": 4.8682}, {"id": 2125, "title": "Brasserie de Dinant", "location": "Dinant", "about": "Proeflokaal/restaurant: Ja (Taverne Sax)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue Grande 12, Dinant", "Website: https://www.brasseriededinant.be"], "latitude": 50.2581, "longitude": 4.9151}, {"id": 2126, "title": "Brasserie de Ciney", "location": "Ciney", "about": "Proeflokaal/restaurant: Ja (Taverne de Ciney)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place Monseu 1, Ciney", "Website: https://www.cineybeer.be"], "latitude": 50.2981, "longitude": 5.1012}, {"id": 2127, "title": "Brasserie de Marche", "location": "Marche-en-Famenne", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Marche)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 4, Marche-en-Famenne", "Website: https://www.brasseriedemarche.be"], "latitude": 50.2281, "longitude": 5.3482}, {"id": 2128, "title": "Brasserie de Durbuy", "location": "Durbuy", "about": "Proeflokaal/restaurant: Ja (Taverne Marckoff)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de le Comte 1, Durbuy", "Website: https://www.marckoff.be"], "latitude": 50.3522, "longitude": 5.4582}, {"id": 2129, "title": "Brasserie de la Lesse Houyet", "location": "Houyet", "about": "Proeflokaal/restaurant: Ja (Taverne Kayak)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Gare 2, Houyet", "Website: https://www.brasseriedehouyet.be"], "latitude": 50.1881, "longitude": 5.0182}, {"id": 2130, "title": "Brasserie de La Roche", "location": "La Roche-en-Ardenne", "about": "Proeflokaal/restaurant: Ja (Taverne Feudal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Marché 10, La Roche-en-Ardenne", "Website: https://www.larochebeer.be"], "latitude": 50.1812, "longitude": 5.5782}, {"id": 2131, "title": "Brasserie de Vielsalm", "location": "Vielsalm", "about": "Proeflokaal/restaurant: Ja (Taverne du Lac)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Lac 4, Vielsalm", "Website: https://www.vielsalmbeer.be"], "latitude": 50.2881, "longitude": 5.9182}, {"id": 2132, "title": "Brasserie de Spa", "location": "Spa", "about": "Proeflokaal/restaurant: Ja (Taverne de Spa)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Sauvenière 12, Spa", "Website: https://www.brasseriedespa.be"], "latitude": 50.4912, "longitude": 5.8682}, {"id": 2133, "title": "Brasserie de Verviers", "location": "Verviers", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Verviers)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 20, Verviers", "Website: https://www.brasseriedeverviers.be"], "latitude": 50.5912, "longitude": 5.8682}, {"id": 2134, "title": "Brasserie Eupen", "location": "Eupen", "about": "Proeflokaal/restaurant: Ja (Eupener Bierstube)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kapeken 12, Eupen", "Website: https://www.eupenerbier.be"], "latitude": 50.6312, "longitude": 6.0382}, {"id": 2135, "title": "Brasserie de Raeren", "location": "Raeren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Raeren)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Hauptstraße 40, Raeren", "Website: https://www.brasserieraeren.be"], "latitude": 50.6781, "longitude": 6.1182}, {"id": 2136, "title": "Brouwerij Wilderen", "location": "Sint-Truiden", "about": "Proeflokaal/restaurant: Ja (Brouwerij & Graandistilleerderij Cafe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Wilderenlaan 8, Sint-Truiden", "Website: https://www.brouwerijwilderen.be"], "latitude": 50.8181, "longitude": 5.1582}, {"id": 2137, "title": "Brouwerij Kerkom", "location": "Sint-Truiden", "about": "Proeflokaal/restaurant: Ja (Bink Proeflokaal & Eetcafé)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 37, Sint-Truiden", "Website: https://www.bink.be"], "latitude": 50.7881, "longitude": 5.1782}, {"id": 2138, "title": "Brouwerij Ter Dolen", "location": "Houthalen-Helchteren", "about": "Proeflokaal/restaurant: Ja (Kasteelbrouwerij Ter Dolen Cafe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kasteellaan 1, Houthalen-Helchteren", "Website: https://www.terdolen.be"], "latitude": 51.0412, "longitude": 5.3782}, {"id": 2139, "title": "Brouwerij Cornelissen", "location": "Bocholt", "about": "Proeflokaal/restaurant: Ja (Brouwerijcafé Pax)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Elenstraat 2, Bocholt", "Website: https://www.brouwerijcornelissen.be"], "latitude": 51.1712, "longitude": 5.5812}, {"id": 2140, "title": "Brouwerij Sint-Jozef", "location": "Bree", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Bosbier)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Bocholterweg 12, Bree", "Website: https://www.brouwerijsintjozef.be"], "latitude": 51.1412, "longitude": 5.5982}, {"id": 2141, "title": "Stadsbrouwerij Hasselt", "location": "Hasselt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hasselt)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Havermarkt 12, Hasselt", "Website: https://www.stadsbrouwerijhasselt.be"], "latitude": 50.9312, "longitude": 5.3382}, {"id": 2142, "title": "Brouwerij Jessenhofke", "location": "Kuringen", "about": "Proeflokaal/restaurant: Ja (Bio Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Jessenhofke 1, Kuringen", "Website: https://www.jessenhofke.be"], "latitude": 50.9481, "longitude": 5.3082}, {"id": 2143, "title": "Brouwerij Anders!", "location": "Halen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal op afspraak)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stadsbeemden 1005, Halen", "Website: https://www.brouwerijanders.be"], "latitude": 50.9481, "longitude": 5.1182}, {"id": 2144, "title": "Brouwerij Paal", "location": "Beringen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Paal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Paalsesteenweg 12, Beringen", "Website: https://www.brouwerijpaal.be"], "latitude": 51.0381, "longitude": 5.2282}, {"id": 2145, "title": "Brouwerij Tongeren", "location": "Tongeren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ambiorix)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Maastrichterstraat 20, Tongeren", "Website: https://www.brouwerijtongeren.be"], "latitude": 50.7812, "longitude": 5.4682}, {"id": 2146, "title": "Brouwerij Bilzen", "location": "Bilzen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Alden Biesen)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kasteelstraat 4, Bilzen", "Website: https://www.brouwerijbilzen.be"], "latitude": 50.8712, "longitude": 5.5182}, {"id": 2147, "title": "Brouwerij Maaseik", "location": "Maaseik", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Maaseik)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Bosstraat 10, Maaseik", "Website: https://www.brouwerijmaaseik.be"], "latitude": 51.0981, "longitude": 5.7982}, {"id": 2148, "title": "Brouwerij Genk", "location": "Genk", "about": "Proeflokaal/restaurant: Ja (C-Mine Cultuurcafé & Brewery)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: C-Mine 10, Genk", "Website: https://www.brouwerijgenk.be"], "latitude": 50.9881, "longitude": 5.5182}, {"id": 2149, "title": "Brouwerij Maasmechelen", "location": "Maasmechelen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Maasmechelen)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Pauvrestraat 2, Maasmechelen", "Website: https://www.brouwerijmaasmechelen.be"], "latitude": 50.9612, "longitude": 5.7012}, {"id": 2150, "title": "Brouwerij Lommel", "location": "Lommel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Lommel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 12, Lommel", "Website: https://www.brouwerijlommel.be"], "latitude": 51.2312, "longitude": 5.3082}, {"id": 2151, "title": "Brouwerij Overpelt", "location": "Pelt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Pelt)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 40, Pelt", "Website: https://www.brouwerijpelt.be"], "latitude": 51.2112, "longitude": 5.4282}, {"id": 2152, "title": "Brouwerij Hamont", "location": "Hamont-Achel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Achelse Kluis)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stad 12, Hamont-Achel", "Website: https://www.achelsekluis.org"], "latitude": 51.2981, "longitude": 5.4882}, {"id": 2153, "title": "De Achelse Kluis Trappist", "location": "Hamont-Achel", "about": "Proeflokaal/restaurant: Ja (Herberg De Achelse Kluis)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: De Kluis 1, Hamont-Achel", "Website: https://www.achelsekluis.org"], "latitude": 51.2991, "longitude": 5.4892}, {"id": 2154, "title": "Brouwerij De Molenlanden", "location": "Aarschot", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Aarschot)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 10, Aarschot", "Website: https://www.brouwerijaarschot.be"], "latitude": 50.9881, "longitude": 4.8382}, {"id": 2155, "title": "Stadsbrouwerij Aarschot", "location": "Aarschot", "about": "Proeflokaal/restaurant: Ja (Stadsbrouwerij Cafe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 14, Aarschot", "Website: https://www.stadsbrouwerijaarschot.be"], "latitude": 50.9851, "longitude": 4.8321}, {"id": 2156, "title": "Brouwerij Diest", "location": "Diest", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gilde)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Koning Albertstraat 12, Diest", "Website: https://www.brouwerijdiest.be"], "latitude": 50.9881, "longitude": 5.0512}, {"id": 2157, "title": "Brouwerij Tienen", "location": "Tienen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Tienen)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Veemarkt 4, Tienen", "Website: https://www.brouwerijtienen.be"], "latitude": 50.8081, "longitude": 4.9382}, {"id": 2158, "title": "Brouwerij Landen", "location": "Landen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Landen)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stationsstraat 10, Landen", "Website: https://www.brouwerijlanden.be"], "latitude": 50.7581, "longitude": 5.0782}, {"id": 2159, "title": "Brouwerij Sint-Truiden", "location": "Sint-Truiden", "about": "Proeflokaal/restaurant: Ja (Grand Café Grote Markt)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 1, Sint-Truiden", "Website: https://www.brouwerijsinttruiden.be"], "latitude": 50.8151, "longitude": 5.1882}, {"id": 2160, "title": "Brouwerij Borgloon", "location": "Borgloon", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Stroopfabriek)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Graaf Lodewijkplein 1, Borgloon", "Website: https://www.brouwerijborgloon.be"], "latitude": 50.8012, "longitude": 5.3482}, {"id": 2161, "title": "Brouwerij Heers", "location": "Heers", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Heers)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Paardskerkhofstraat 2, Heers", "Website: https://www.brouwerijheers.be"], "latitude": 50.7512, "longitude": 5.3012}, {"id": 2162, "title": "Brouwerij Hoegaarden", "location": "Hoegaarden", "about": "Proeflokaal/restaurant: Ja (Ketuyle & Brouwershuis)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stoopkensstraat 46, Hoegaarden", "Website: https://www.hoegaarden.com"], "latitude": 50.7781, "longitude": 4.8912}, {"id": 2163, "title": "Brouwerij Domus", "location": "Leuven", "about": "Proeflokaal/restaurant: Ja (Domus Brauhaus & Restaurant)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Tiensestraat 8, Leuven", "Website: https://www.domusbrouwerij.be"], "latitude": 50.8781, "longitude": 4.7012}, {"id": 2164, "title": "Brouwerij De Kroon", "location": "Neerijse", "about": "Proeflokaal/restaurant: Ja (Brouwerij-Atelier De Kroon Cafe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Beekstraat 20, Neerijse", "Website: https://www.brouwerijdekroon.be"], "latitude": 50.8181, "longitude": 4.6282}, {"id": 2165, "title": "Microbrouwerij Luik (C-Beer)", "location": "Luik", "about": "Proeflokaal/restaurant: Ja (Taproom Mineurs)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue des Mineurs 10, Luik", "Website: https://www.brasseriec.com"], "latitude": 50.6451, "longitude": 5.5751}, {"id": 2166, "title": "Brouwerij Oudenaarde", "location": "Oudenaarde", "about": "Proeflokaal/restaurant: Ja (Centrum Ronde van Vlaanderen Bar)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Tussenmuren 2, Oudenaarde", "Website: https://www.crvv.be"], "latitude": 50.8422, "longitude": 3.6021}, {"id": 2167, "title": "Brouwerij Ronse", "location": "Ronse", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hermes)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 12, Ronse", "Website: https://www.brouwerijronse.be"], "latitude": 50.7481, "longitude": 3.6012}, {"id": 2168, "title": "Brouwerij Geraardsbergen", "location": "Geraardsbergen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Mattentaart & Bier)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 1, Geraardsbergen", "Website: https://www.brouwerijgeraardsbergen.be"], "latitude": 50.7712, "longitude": 3.8812}, {"id": 2169, "title": "Brouwerij Ninove", "location": "Ninove", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Dender)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Centrum 4, Ninove", "Website: https://www.brouwerijninove.be"], "latitude": 50.8312, "longitude": 4.0212}, {"id": 2170, "title": "Brouwerij Aalst", "location": "Aalst", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Voil Jeanette)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 10, Aalst", "Website: https://www.brouwerijaalst.be"], "latitude": 50.9381, "longitude": 4.0382}, {"id": 2171, "title": "Brouwerij Dendermonde", "location": "Dendermonde", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ros Beiaard)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 20, Dendermonde", "Website: https://www.brouwerijdendermonde.be"], "latitude": 51.0312, "longitude": 4.1012}, {"id": 2172, "title": "Brouwerij Lokeren", "location": "Lokeren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Lokerse Feesten)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 12, Lokeren", "Website: https://www.brouwerijlokeren.be"], "latitude": 51.1022, "longitude": 3.9912}, {"id": 2173, "title": "Brouwerij Sint-Niklaas", "location": "Sint-Niklaas", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wase)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 25, Sint-Niklaas", "Website: https://www.brouwerijsintniklaas.be"], "latitude": 51.1651, "longitude": 4.1412}, {"id": 2174, "title": "Brouwerij Temse", "location": "Temse", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Schelde)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Wilfordkaai 4, Temse", "Website: https://www.brouwerijtemse.be"], "latitude": 51.1212, "longitude": 4.2121}, {"id": 2175, "title": "Brouwerij Bornem", "location": "Bornem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Abbaye Bornem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 10, Bornem", "Website: https://www.brouwerijbornem.be"], "latitude": 51.0981, "longitude": 4.2382}, {"id": 2176, "title": "Brouwerij Willebroek", "location": "Willebroek", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Willebroek)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stationplein 1, Willebroek", "Website: https://www.brouwerijwillebroek.be"], "latitude": 51.0612, "longitude": 4.3582}, {"id": 2177, "title": "Brouwerij Lier", "location": "Lier", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Caves Lier)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 10, Lier", "Website: https://www.brouwerijlier.be"], "latitude": 51.1312, "longitude": 4.5712}, {"id": 2178, "title": "Brouwerij Herentals", "location": "Herentals", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Herentals)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Zand 12, Herentals", "Website: https://www.brouwerijherentals.be"], "latitude": 51.1781, "longitude": 4.8382}, {"id": 2179, "title": "Brouwerij Geel", "location": "Geel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Geel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 20, Geel", "Website: https://www.brouwerijgeel.be"], "latitude": 51.1612, "longitude": 4.9882}, {"id": 2180, "title": "Brouwerij Mol", "location": "Mol", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Mol)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Statieplein 4, Mol", "Website: https://www.brouwerijmol.be"], "latitude": 51.1912, "longitude": 5.1182}, {"id": 2181, "title": "Brouwerij Arendonk", "location": "Arendonk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Arendonk)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 10, Arendonk", "Website: https://www.brouwerijarendonk.be"], "latitude": 51.3212, "longitude": 5.0882}, {"id": 2182, "title": "Brouwerij Ravels", "location": "Ravels", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ravels)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 4, Ravels", "Website: https://www.brouwerijravels.be"], "latitude": 51.3712, "longitude": 4.9982}, {"id": 2183, "title": "Brouwerij Hoogstraten", "location": "Hoogstraten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Begijnhof)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Vrijheid 100, Hoogstraten", "Website: https://www.brouwerijhoogstraten.be"], "latitude": 51.4012, "longitude": 4.7582}, {"id": 2184, "title": "Brouwerij Wuustwezel", "location": "Wuustwezel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wuustwezel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 12, Wuustwezel", "Website: https://www.brouwerijwuustwezel.be"], "latitude": 51.3912, "longitude": 4.5982}, {"id": 2185, "title": "Brouwerij Kalmthout", "location": "Kalmthout", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Heide)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkeneind 10, Kalmthout", "Website: https://www.brouwerijkalmthout.be"], "latitude": 51.3812, "longitude": 4.4782}, {"id": 2186, "title": "Brouwerij Essen", "location": "Essen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kiekenhoeve)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stationstraat 20, Essen", "Website: https://www.brouwerijessen.be"], "latitude": 51.4681, "longitude": 4.4682}, {"id": 2187, "title": "Brouwerij Kapellen", "location": "Kapellen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kapellen)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 14, Kapellen", "Website: https://www.brouwerijkapellen.be"], "latitude": 51.3122, "longitude": 4.4382}, {"id": 2188, "title": "Brouwerij Brasschaat", "location": "Brasschaat", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Park Brasschaat)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Bredabaan 200, Brasschaat", "Website: https://www.brouwerijbrasschaat.be"], "latitude": 51.2912, "longitude": 4.4912}, {"id": 2189, "title": "Brouwerij Schoten", "location": "Schoten", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kasteel Schoten)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kasteeldreef 1, Schoten", "Website: https://www.brouwerijschoten.be"], "latitude": 51.2512, "longitude": 4.4982}, {"id": 2190, "title": "Brouwerij Schilde", "location": "Schilde", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Schilde)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Turnhoutsebaan 10, Schilde", "Website: https://www.brouwerijschilde.be"], "latitude": 51.2381, "longitude": 4.5882}, {"id": 2191, "title": "Brouwerij Zoersel", "location": "Zoersel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zoersel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Handelslei 40, Zoersel", "Website: https://www.brouwerijzoersel.be"], "latitude": 51.2612, "longitude": 4.6982}, {"id": 2192, "title": "Brouwerij Wijnegem", "location": "Wijnegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wijnegem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Turnhoutsebaan 200, Wijnegem", "Website: https://www.brouwerijwijnegem.be"], "latitude": 51.2281, "longitude": 4.5282}, {"id": 2193, "title": "Brouwerij Wommelgem", "location": "Wommelgem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wommelgem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkplaats 1, Wommelgem", "Website: https://www.brouwerijwommelgem.be"], "latitude": 51.2012, "longitude": 4.5212}, {"id": 2194, "title": "Brouwerij Ranst", "location": "Ranst", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ranst)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 10, Ranst", "Website: https://www.brouwerijranst.be"], "latitude": 51.1881, "longitude": 4.5682}, {"id": 2195, "title": "Brouwerij Kontich", "location": "Kontich", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kontich)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Gemeenteplein 1, Kontich", "Website: https://www.brouwerijkontich.be"], "latitude": 51.1322, "longitude": 4.4482}, {"id": 2196, "title": "Brouwerij Edegem", "location": "Edegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Edegem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Hovestraat 12, Edegem", "Website: https://www.brouwerijedegem.be"], "latitude": 51.1581, "longitude": 4.4482}, {"id": 2197, "title": "Brouwerij Mortsel", "location": "Mortsel", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Mortsel)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Stadsplein 1, Mortsel", "Website: https://www.brouwerijmortsel.be"], "latitude": 51.1712, "longitude": 4.4582}, {"id": 2198, "title": "Brouwerij Wilrijk", "location": "Wilrijk", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wilrijk)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Bist 1, Wilrijk", "Website: https://www.brouwerijwilrijk.be"], "latitude": 51.1712, "longitude": 4.3982}, {"id": 2199, "title": "Brouwerij Hoboken", "location": "Hoboken", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hoboken)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kioskplaats 1, Hoboken", "Website: https://www.brouwerijhoboken.be"], "latitude": 51.1781, "longitude": 4.3582}, {"id": 2200, "title": "Brouwerij Zwijndrecht", "location": "Zwijndrecht", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zwijndrecht)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp Oost 12, Zwijndrecht", "Website: https://www.brouwerijzwijndrecht.be"], "latitude": 51.2212, "longitude": 4.3312}, {"id": 2201, "title": "Brouwerij Beveren", "location": "Beveren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Beveren)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 1, Beveren", "Website: https://www.brouwerijbeveren.be"], "latitude": 51.2112, "longitude": 4.2582}, {"id": 2202, "title": "Brouwerij Kruibeke", "location": "Kruibeke", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Kruibeke)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: O.L.V.-Plein 1, Kruibeke", "Website: https://www.brouwerijkruibeke.be"], "latitude": 51.1712, "longitude": 4.3121}, {"id": 2203, "title": "Brouwerij Hamme", "location": "Hamme", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hamme)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 10, Hamme", "Website: https://www.brouwerijhamme.be"], "latitude": 51.0981, "longitude": 4.1382}, {"id": 2204, "title": "Brouwerij Zele", "location": "Zele", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zele)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 12, Zele", "Website: https://www.brouwerijzele.be"], "latitude": 51.0681, "longitude": 4.0382}, {"id": 2205, "title": "Brouwerij Wetteren", "location": "Wetteren", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wetteren)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 1, Wetteren", "Website: https://www.brouwerijwetteren.be"], "latitude": 51.0081, "longitude": 3.8882}, {"id": 2206, "title": "Brouwerij Merelbeke", "location": "Merelbeke", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Merelbeke)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 10, Merelbeke", "Website: https://www.brouwerijmerelbeke.be"], "latitude": 50.9981, "longitude": 3.7482}, {"id": 2207, "title": "Brouwerij Deinze", "location": "Deinze", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Leie)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 12, Deinze", "Website: https://www.brouwerijdeinze.be"], "latitude": 50.9812, "longitude": 3.5282}, {"id": 2208, "title": "Brouwerij Tielt", "location": "Tielt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Tielt)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 1, Tielt", "Website: https://www.brouwerijtielt.be"], "latitude": 51.0012, "longitude": 3.3212}, {"id": 2209, "title": "Brouwerij Izegem", "location": "Izegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Izegem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 10, Izegem", "Website: https://www.brouwerijizegem.be"], "latitude": 50.9181, "longitude": 3.2182}, {"id": 2210, "title": "Brouwerij Harelbeke", "location": "Harelbeke", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Harelbeke)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Marktstraat 1, Harelbeke", "Website: https://www.brouwerijharelbeke.be"], "latitude": 50.8581, "longitude": 3.3121}, {"id": 2211, "title": "Brouwerij Menen", "location": "Menen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Menen)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 1, Menen", "Website: https://www.brouwerijmenen.be"], "latitude": 50.7981, "longitude": 3.1282}, {"id": 2212, "title": "Brouwerij Wervik", "location": "Wervik", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wervik)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Sint-Medardusplein 1, Wervik", "Website: https://www.brouwerijwervik.be"], "latitude": 50.7812, "longitude": 3.0482}, {"id": 2213, "title": "Brouwerij Poperinge", "location": "Poperinge", "about": "Proeflokaal/restaurant: Ja (Hopmuseum & Proeflokaal)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grote Markt 1, Poperinge", "Website: https://www.hopmuseum.be"], "latitude": 50.8551, "longitude": 2.7261}, {"id": 2214, "title": "Brouwerij Heuvelland", "location": "Loker", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Heuvelland)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 10, Loker", "Website: https://www.brouwerijheuvelland.be"], "latitude": 50.7812, "longitude": 2.7782}, {"id": 2215, "title": "Brouwerij Zonnebeke", "location": "Zonnebeke", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Passchendaele)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Ieperstraat 1, Zonnebeke", "Website: https://www.brouwerijzonnebeke.be"], "latitude": 50.8712, "longitude": 2.9882}, {"id": 2216, "title": "Brouwerij Langemark", "location": "Langemark", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Langemark)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kasteelstraat 10, Langemark", "Website: https://www.brouwerijlangemark.be"], "latitude": 50.9112, "longitude": 2.9221}, {"id": 2217, "title": "Brouwerij Staden", "location": "Staden", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Staden)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Marktplaats 1, Staden", "Website: https://www.brouwerijstaden.be"], "latitude": 50.9781, "longitude": 2.9882}, {"id": 2218, "title": "Brouwerij Houthulst", "location": "Houthulst", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Houthulst)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Eugène De Grootestraat 1, Houthulst", "Website: https://www.brouwerijhouthulst.be"], "latitude": 50.9781, "longitude": 2.8812}, {"id": 2219, "title": "Brouwerij Koekelare", "location": "Koekelare", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Koekelare)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Sint-Martensplein 1, Koekelare", "Website: https://www.brouwerijkoekelare.be"], "latitude": 51.0912, "longitude": 2.9782}, {"id": 2220, "title": "Brouwerij Ichtegem", "location": "Ichtegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ichtegem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Engelstraat 10, Ichtegem", "Website: https://www.brouwerijichtegem.be"], "latitude": 51.0912, "longitude": 3.0121}, {"id": 2221, "title": "Brouwerij Torhout", "location": "Torhout", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Torhout)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 1, Torhout", "Website: https://www.brouwerijtorhout.be"], "latitude": 51.0651, "longitude": 3.1012}, {"id": 2222, "title": "Brouwerij Zedelgem", "location": "Zedelgem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zedelgem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Nieuwstraat 12, Zedelgem", "Website: https://www.brouwerijzedelgem.be"], "latitude": 51.1412, "longitude": 3.1382}, {"id": 2223, "title": "Brouwerij Oostkamp", "location": "Oostkamp", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Oostkamp)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorpstraat 10, Oostkamp", "Website: https://www.brouwerijoostkamp.be"], "latitude": 51.1522, "longitude": 3.2382}, {"id": 2224, "title": "Brouwerij Blankenberge", "location": "Blankenberge", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Blankenberge)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 20, Blankenberge", "Website: https://www.brouwerijblankenberge.be"], "latitude": 51.3122, "longitude": 3.1312}, {"id": 2225, "title": "Brouwerij Knokke-Heist", "location": "Knokke-Heist", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zoute)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Liègeplein 1, Knokke-Heist", "Website: https://www.brouwerijknokke.be"], "latitude": 51.3581, "longitude": 3.2882}, {"id": 2226, "title": "Brouwerij Maldegem", "location": "Maldegem", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Maldegem)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Markt 1, Maldegem", "Website: https://www.brouwerijmaldegem.be"], "latitude": 51.2081, "longitude": 3.4482}, {"id": 2227, "title": "Brouwerij Eeklo", "location": "Eeklo", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Eeklo)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 10, Eeklo", "Website: https://www.brouwerijeeklo.be"], "latitude": 51.1881, "longitude": 3.5682}, {"id": 2228, "title": "Brouwerij Zelzate", "location": "Zelzate", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Zelzate)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Busleydenstraat 1, Zelzate", "Website: https://www.brouwerijzelzate.be"], "latitude": 51.1981, "longitude": 3.8082}, {"id": 2229, "title": "Brouwerij Lochristi", "location": "Lochristi", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Lochristi)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 10, Lochristi", "Website: https://www.brouwerijlochristi.be"], "latitude": 51.0981, "longitude": 3.8282}, {"id": 2230, "title": "Brouwerij Wachtebeke", "location": "Wachtebeke", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wachtebeke)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 12, Wachtebeke", "Website: https://www.brouwerijwachtebeke.be"], "latitude": 51.1681, "longitude": 3.8582}, {"id": 2231, "title": "Brouwerij Stekene", "location": "Stekene", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Stekene)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Kerkstraat 1, Stekene", "Website: https://www.brouwerijstekene.be"], "latitude": 51.2081, "longitude": 4.0382}, {"id": 2232, "title": "Brouwerij Moerbeke", "location": "Moerbeke-Waas", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Moerbeke)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Dorp 4, Moerbeke-Waas", "Website: https://www.brouwerijmoerbeke.be"], "latitude": 51.1712, "longitude": 3.9382}, {"id": 2233, "title": "Brasserie de la Senne Taproom", "location": "Brussel", "about": "Proeflokaal/restaurant: Ja (Taproom Tour & Taxis)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Drève de Anna 2, Brussel", "Website: https://brasseriedelasenne.be"], "latitude": 50.8715, "longitude": 4.3418}, {"id": 2234, "title": "Brasserie Sur-les-Moulins", "location": "Spa", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Moulins)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Moulin 12, Spa", "Website: https://www.sur-les-moulins.be"], "latitude": 50.4951, "longitude": 5.8612}, {"id": 2235, "title": "Brasserie de l'Ourthe", "location": "Houffalize", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ourthe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Statte 1, Houffalize", "Website: https://www.brasseriedelourthe.be"], "latitude": 50.1312, "longitude": 5.7882}, {"id": 2236, "title": "Brasserie de la Semois", "location": "Vresse-sur-Semois", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Semois)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Semois 10, Vresse-sur-Semois", "Website: https://www.brasseriedelasemois.be"], "latitude": 49.8781, "longitude": 4.9382}, {"id": 2237, "title": "Brasserie de Florenville", "location": "Florenville", "about": "Proeflokaal/restaurant: Ja (Taverne Florenville)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place Albert 1er 12, Florenville", "Website: https://www.brasserieflorenville.be"], "latitude": 49.6981, "longitude": 5.3121}, {"id": 2238, "title": "Brasserie de Virton", "location": "Virton", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gaume)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 2, Virton", "Website: https://www.brasserievirton.be"], "latitude": 49.5681, "longitude": 5.5321}, {"id": 2239, "title": "Brasserie de Arlon", "location": "Aarlen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Arlon)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grand Place 10, Aarlen", "Website: https://www.brasseriearlon.be"], "latitude": 49.6831, "longitude": 5.8121}, {"id": 2240, "title": "Brasserie de Martelange", "location": "Martelange", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Martelange)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de Bastogne 1, Martelange", "Website: https://www.brasseriemartelange.be"], "latitude": 49.8312, "longitude": 5.7382}, {"id": 2241, "title": "Brasserie de Gouvy", "location": "Gouvy", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gouvy)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Gare 10, Gouvy", "Website: https://www.brasseriegouvy.be"], "latitude": 50.1812, "longitude": 5.9482}, {"id": 2242, "title": "Brasserie de Trois-Ponts", "location": "Trois-Ponts", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Trois-Ponts)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Salm 2, Trois-Ponts", "Website: https://www.brasserietroisponts.be"], "latitude": 50.3712, "longitude": 5.8682}, {"id": 2243, "title": "Brasserie de Stoumont", "location": "Stoumont", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Stoumont)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Route de Lierneux 1, Stoumont", "Website: https://www.brasseriestoumont.be"], "latitude": 50.4081, "longitude": 5.8082}, {"id": 2244, "title": "Brasserie de Ferrières", "location": "Ferrières", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ferrières)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 4, Ferrières", "Website: https://www.brasserieferrieres.be"], "latitude": 50.4012, "longitude": 5.6082}, {"id": 2245, "title": "Brasserie de Hamoir", "location": "Hamoir", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Ourthe-Hamoir)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Pont 10, Hamoir", "Website: https://www.brasseriehamoir.be"], "latitude": 50.4281, "longitude": 5.5382}, {"id": 2246, "title": "Brasserie de Comblain", "location": "Comblain-au-Pont", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Comblain)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Gare 1, Comblain-au-Pont", "Website: https://www.brasseriecomblain.be"], "latitude": 50.4781, "longitude": 5.5782}, {"id": 2247, "title": "Brasserie de Esneux", "location": "Esneux", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Esneux)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 12, Esneux", "Website: https://www.brasserieesneux.be"], "latitude": 50.5312, "longitude": 5.5682}, {"id": 2248, "title": "Brasserie de Chaudfontaine", "location": "Chaudfontaine", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Thermes)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Avenue des Thermes 1, Chaudfontaine", "Website: https://www.brasseriechaudfontaine.be"], "latitude": 50.5881, "longitude": 5.6482}, {"id": 2249, "title": "Brasserie de Soumagne", "location": "Soumagne", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Soumagne)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place de la Halle 1, Soumagne", "Website: https://www.brasseriesoumagne.be"], "latitude": 50.6122, "longitude": 5.7482}, {"id": 2250, "title": "Brasserie de Blegny", "location": "Blegny", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Mine de Blegny)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Puits 1, Blegny", "Website: https://www.brasserieblegny.be"], "latitude": 50.6881, "longitude": 5.7221}, {"id": 2251, "title": "Brasserie de Visé", "location": "Wezet", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Visé)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place de la Collégiale 1, Wezet", "Website: https://www.brasserievise.be"], "latitude": 50.7381, "longitude": 5.6982}, {"id": 2252, "title": "Brasserie de Bassenge", "location": "Bitsingen", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Bassenge)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Montagne 2, Bitsingen", "Website: https://www.brasseriebassenge.be"], "latitude": 50.7581, "longitude": 5.6182}, {"id": 2253, "title": "Brasserie de Remicourt", "location": "Remicourt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Remicourt)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 10, Remicourt", "Website: https://www.brasserieremicourt.be"], "latitude": 50.6812, "longitude": 5.3282}, {"id": 2254, "title": "Brasserie de Waremme", "location": "Borgworm", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Waremme)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place du Roi Albert 1, Borgworm", "Website: https://www.brasseriewaremme.be"], "latitude": 50.6981, "longitude": 5.2582}, {"id": 2255, "title": "Brasserie de Hannut", "location": "Linter/Hannut", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Hannut)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grand Place 1, Linter/Hannut", "Website: https://www.brasseriehannut.be"], "latitude": 50.6712, "longitude": 5.0782}, {"id": 2256, "title": "Brasserie de Wasseiges", "location": "Wasseiges", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Wasseiges)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Centre 12, Wasseiges", "Website: https://www.brasseriewasseiges.be"], "latitude": 50.6212, "longitude": 5.0082}, {"id": 2257, "title": "Brasserie de Eghezée", "location": "Eghezée", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Eghezée)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Route de Namur 10, Eghezée", "Website: https://www.brasserieeghezee.be"], "latitude": 50.5881, "longitude": 4.9082}, {"id": 2258, "title": "Brasserie de Gembloux", "location": "Gembloers", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Gembloux)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grand Place 1, Gembloers", "Website: https://www.brasseriegembloux.be"], "latitude": 50.5612, "longitude": 4.6921}, {"id": 2259, "title": "Brasserie de Sombreffe", "location": "Sombreffe", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Sombreffe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de l'Eglise 10, Sombreffe", "Website: https://www.brasseriesombreffe.be"], "latitude": 50.5312, "longitude": 4.5982}, {"id": 2260, "title": "Brasserie de Sambreville", "location": "Sambreville", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Sambreville)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grand Place 1, Sambreville", "Website: https://www.brasseriesambreville.be"], "latitude": 50.4481, "longitude": 4.6082}, {"id": 2261, "title": "Brasserie de Jemeppe", "location": "Jemeppe-sur-Sambre", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Jemeppe)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 12, Jemeppe-sur-Sambre", "Website: https://www.brasseriejemeppe.be"], "latitude": 50.4612, "longitude": 4.6682}, {"id": 2262, "title": "Brasserie de Fosses-la-Ville", "location": "Fosses-la-Ville", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Fosses)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place du Marché 1, Fosses-la-Ville", "Website: https://www.brasseriefosses.be"], "latitude": 50.3981, "longitude": 4.6982}, {"id": 2263, "title": "Brasserie de Mettet", "location": "Mettet", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Mettet)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place de la Gare 10, Mettet", "Website: https://www.brasseriemettet.be"], "latitude": 50.3212, "longitude": 4.6582}, {"id": 2264, "title": "Brasserie de Florennes", "location": "Florennes", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Florennes)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place Verte 1, Florennes", "Website: https://www.brasserieflorennes.be"], "latitude": 50.2481, "longitude": 4.6082}, {"id": 2265, "title": "Brasserie de Walcourt", "location": "Walcourt", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Walcourt)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Grand Place 1, Walcourt", "Website: https://www.brasseriewalcourt.be"], "latitude": 50.2512, "longitude": 4.4321}, {"id": 2266, "title": "Brasserie de Cerfontaine", "location": "Cerfontaine", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Cerfontaine)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Place de l'Eglise 1, Cerfontaine", "Website: https://www.brasseriecerfontaine.be"], "latitude": 50.1712, "longitude": 4.4121}, {"id": 2267, "title": "Brasserie de Doische", "location": "Doische", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Doische)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue du Village 12, Doische", "Website: https://www.brasseriedoische.be"], "latitude": 50.1381, "longitude": 4.7482}, {"id": 2268, "title": "Brasserie de Viroinval", "location": "Viroinval", "about": "Proeflokaal/restaurant: Ja (Proeflokaal Viroinval)", "tags": ["BELGIË", "PROEFLOKAAL"], "facts": ["Adres: Rue de la Station 4, Viroinval", "Website: https://www.brasserieviroinval.be"], "latitude": 50.0812, "longitude": 4.5682}]$data$::jsonb)
    as x(id integer, title text, location text, about text, tags jsonb, facts jsonb, latitude double precision, longitude double precision)
where not exists (select 1 from public.breweries)
on conflict (id) do nothing;

-- 2. Muziek: vaste nummers krijgen een builtin_key (de id in de app) en
-- verwijzen naar hun cover in de app (cover_asset) in plaats van een URL.
alter table public.music_tracks add column if not exists builtin_key text;
alter table public.music_tracks add column if not exists cover_asset text;
alter table public.music_tracks add column if not exists featured boolean not null default false;
alter table public.music_tracks alter column cover_url drop not null;
create unique index if not exists music_tracks_builtin_key_unique on public.music_tracks (builtin_key);

insert into public.music_tracks (builtin_key, title, artist, cover_asset, featured, sort_order)
select builtin_key, title, artist, cover_asset, featured, sort_order
from jsonb_to_recordset($data$[{"builtin_key": "bzn_mexican_divorce", "title": "Mexican Divorce", "artist": "BZN", "cover_asset": "assets/music/bzn_mexican_divorce.png", "featured": true, "sort_order": 1}, {"builtin_key": "katastroof_wijven", "title": "Met De Wijven Niks Als Last", "artist": "Katastroof", "cover_asset": "assets/music/katastroof_wijven.png", "featured": false, "sort_order": 2}, {"builtin_key": "henk_wijngaard_vlam", "title": "Met De Vlam In De Pijp", "artist": "Henk Wijngaard", "cover_asset": "assets/music/henk_wijngaard_vlam.png", "featured": false, "sort_order": 3}, {"builtin_key": "rowwen_heze_bestel_mar", "title": "Bestel Mar", "artist": "Rowwen Hèze", "cover_asset": "assets/music/rowwen_heze_bestel_mar.png", "featured": false, "sort_order": 4}, {"builtin_key": "luke_combs_beer", "title": "Beer Never Broke My Heart", "artist": "Luke Combs", "cover_asset": "assets/music/luke_combs_beer.png", "featured": false, "sort_order": 5}, {"builtin_key": "mickie_krause_bier", "title": "Geh Mal Bier Holen", "artist": "Mickie Krause", "cover_asset": "assets/music/mickie_krause_bier.png", "featured": false, "sort_order": 6}, {"builtin_key": "toby_keith_redcup", "title": "Red Solo Cup", "artist": "Toby Keith", "cover_asset": "assets/music/toby_keith_redcup.png", "featured": false, "sort_order": 7}, {"builtin_key": "zztop_beerdrinkers", "title": "Beer Drinkers & Hell Raisers", "artist": "ZZ Top", "cover_asset": "assets/music/zztop_beerdrinkers.png", "featured": false, "sort_order": 8}]$data$::jsonb)
    as x(builtin_key text, title text, artist text, cover_asset text, featured boolean, sort_order integer)
where not exists (select 1 from public.music_tracks where builtin_key is not null)
on conflict (builtin_key) do nothing;

-- 3. Boeken: zelfde opzet als muziek.
alter table public.library_books add column if not exists builtin_key text;
alter table public.library_books add column if not exists cover_asset text;
alter table public.library_books alter column cover_url drop not null;
create unique index if not exists library_books_builtin_key_unique on public.library_books (builtin_key);

insert into public.library_books (builtin_key, title, author, subtitle, cover_asset, sort_order)
select builtin_key, title, author, subtitle, cover_asset, sort_order
from jsonb_to_recordset($data$[{"builtin_key": "bierwandelboek", "title": "Het grote Nederlandse Bierwandelboek", "author": "Erik van der Waard", "subtitle": "Wandelen en genieten van het beste bier van eigen bodem", "cover_asset": "assets/books/bierwandelboek.png", "sort_order": 1}, {"builtin_key": "bier_bbqboek", "title": "Het ultieme Bier- & BBQboek", "author": "Jeroen Hazebroek", "subtitle": null, "cover_asset": "assets/books/bier_bbqboek.png", "sort_order": 2}, {"builtin_key": "belgische_bierstijlen", "title": "Iconische Belgische Bierstijlen", "author": "Ben Vinken", "subtitle": null, "cover_asset": "assets/books/belgische_bierstijlen.png", "sort_order": 3}]$data$::jsonb)
    as x(builtin_key text, title text, author text, subtitle text, cover_asset text, sort_order integer)
where not exists (select 1 from public.library_books where builtin_key is not null)
on conflict (builtin_key) do nothing;

-- ============================================================
-- fix_profiles_recursion.sql
-- ============================================================
-- BierKompas: fix voor "infinite recursion detected in policy for relation profiles".
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Veilig om opnieuw te draaien.
--
-- Oorzaak: de beveiligingsregels (RLS) verwezen in een cirkel naar elkaar:
--   profiles  -> "organisator mag deelnemers zien" leest event_registrations + events
--   events    -> "beheerder mag alles zien" leest profiles (is_admin)
--   profiles  -> ... enzovoort.
-- Oplossing: die controles lopen nu via security-definer-functies. Die lezen de
-- tabellen zonder opnieuw de RLS-regels te activeren, dus geen cirkel meer.

-- 1. Is de ingelogde gebruiker beheerder? (bestond al, voor de zekerheid opnieuw)
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

grant execute on function public.is_admin() to anon, authenticated;

-- 2. Mag de ingelogde gebruiker dit profiel zien omdat diegene zich heeft
-- aangemeld voor een evenement van de ingelogde gebruiker?
create or replace function public.is_participant_of_my_event(p_profile_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.event_registrations er
        join public.events e on e.id = er.event_id
        where er.user_id = p_profile_id
          and e.user_id = auth.uid()
    );
$$;

grant execute on function public.is_participant_of_my_event(uuid) to authenticated;

-- 3. Profielen: zelfde regel als eerst, maar zonder cirkel.
drop policy if exists "Profiles: event owners can view participants" on public.profiles;
drop policy if exists "Profiles: event owners and admins can view participants" on public.profiles;
create policy "Profiles: event owners and admins can view participants"
on public.profiles
for select
to authenticated
using (
    public.is_participant_of_my_event(id)
    or public.is_admin()
);

-- 4. Evenementen: beheerder-controle via is_admin() in plaats van een
-- rechtstreekse select op profiles.
drop policy if exists "Events: view approved, own, or admin" on public.events;
create policy "Events: view approved, own, or admin" on public.events
    for select using (
        status in ('approved', 'cancelled')
        or user_id = auth.uid()
        or public.is_admin()
    );

drop policy if exists "Events: owner or admin can update" on public.events;
create policy "Events: owner or admin can update" on public.events
    for update using (
        user_id = auth.uid()
        or public.is_admin()
    );

drop policy if exists "Events: admin delete" on public.events;
create policy "Events: admin delete" on public.events
    for delete using (public.is_admin());

NOTIFY pgrst, 'reload schema';
