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
update public.events set status = 'approved' where status = 'pending';

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
alter table public.bieren alter column id add generated by default as identity;
select setval(pg_get_serial_sequence('public.bieren', 'id'), 1000, false);

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

NOTIFY pgrst, 'reload schema';
