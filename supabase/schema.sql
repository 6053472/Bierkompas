-- =========================================================
-- BierKompas Supabase schema
-- Volledige versie
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


-- Admin controleren zonder RLS-recursie
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
    select coalesce(
        (
            select is_admin
            from public.profiles
            where id = auth.uid()
        ),
        false
    );
$$;


-- Oude policies verwijderen
drop policy if exists "Profiles: select own" on public.profiles;
drop policy if exists "Profiles: update own" on public.profiles;
drop policy if exists "Profiles: event owners can view participants" on public.profiles;
drop policy if exists "Profiles: event owners and admins can view participants" on public.profiles;


-- Eigen profiel bekijken
create policy "Profiles: select own"
on public.profiles
for select
to authenticated
using (
    auth.uid() = id
);


-- Eigen profiel aanpassen
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


-- Eventmaker en admin mogen deelnemersprofielen bekijken
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


-- Nieuwe gebruiker automatisch profiel geven
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


drop trigger if exists on_auth_user_created on auth.users;

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

drop policy if exists "Consents: select own" on public.user_consents;
drop policy if exists "Consents: insert own" on public.user_consents;
drop policy if exists "Consents: update own" on public.user_consents;

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

drop policy if exists "Favorites: select own" on public.favorites;
drop policy if exists "Favorites: insert own" on public.favorites;
drop policy if exists "Favorites: delete own" on public.favorites;

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


drop policy if exists "Events: everyone can view" on public.events;
drop policy if exists "Events: authenticated users can insert" on public.events;
drop policy if exists "Events: owner can update" on public.events;
drop policy if exists "Events: owner can delete" on public.events;
drop policy if exists "Events: admins can update" on public.events;
drop policy if exists "Events: admins can delete" on public.events;


-- Iedereen mag evenementen bekijken
create policy "Events: everyone can view"
on public.events
for select
using (
    true
);


-- Ingelogde gebruikers mogen evenementen maken
create policy "Events: authenticated users can insert"
on public.events
for insert
to authenticated
with check (
    auth.uid() = user_id
);


-- Eigenaar mag eigen evenement aanpassen
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


-- Admin mag evenementen aanpassen
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


-- Eigenaar mag eigen evenement verwijderen
create policy "Events: owner can delete"
on public.events
for delete
to authenticated
using (
    auth.uid() = user_id
);


-- Admin mag evenementen verwijderen
create policy "Events: admins can delete"
on public.events
for delete
to authenticated
using (
    public.is_admin()
);


grant select on public.events to anon;

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


-- Voor bestaande databases
alter table public.event_registrations
add column if not exists status text not null default 'pending';


-- Controleer eventuele lege status
update public.event_registrations
set status = 'pending'
where status is null;


-- Constraint toevoegen als die nog niet bestaat
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


alter table public.event_registrations enable row level security;


-- Oude policies verwijderen
drop policy if exists "Registrations: select own" on public.event_registrations;
drop policy if exists "Registrations: event owner can view" on public.event_registrations;
drop policy if exists "Registrations: admins can view" on public.event_registrations;
drop policy if exists "Registrations: insert own" on public.event_registrations;
drop policy if exists "Registrations: delete own" on public.event_registrations;
drop policy if exists "Registrations: owner can update" on public.event_registrations;
drop policy if exists "Registrations: admins can update" on public.event_registrations;


-- Gebruiker kan eigen aanmelding bekijken
create policy "Registrations: select own"
on public.event_registrations
for select
to authenticated
using (
    auth.uid() = user_id
);


-- Eigenaar van evenement kan aanmeldingen bekijken
create policy "Registrations: event owner can view"
on public.event_registrations
for select
to authenticated
using (
    exists (
        select 1
        from public.events
        where public.events.id = event_registrations.event_id
        and public.events.user_id = auth.uid()
    )
);


-- Admin kan alle aanmeldingen bekijken
create policy "Registrations: admins can view"
on public.event_registrations
for select
to authenticated
using (
    public.is_admin()
);


-- Gebruiker kan zichzelf aanmelden
create policy "Registrations: insert own"
on public.event_registrations
for insert
to authenticated
with check (
    auth.uid() = user_id
);


-- Gebruiker kan eigen aanmelding verwijderen
create policy "Registrations: delete own"
on public.event_registrations
for delete
to authenticated
using (
    auth.uid() = user_id
);


-- Eigenaar kan status aanpassen
create policy "Registrations: owner can update"
on public.event_registrations
for update
to authenticated
using (
    exists (
        select 1
        from public.events
        where public.events.id = event_registrations.event_id
        and public.events.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.events
        where public.events.id = event_registrations.event_id
        and public.events.user_id = auth.uid()
    )
);


-- Admin kan status aanpassen
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

    or

    public.is_admin()

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
-- 8. SUPABASE SCHEMA CACHE VERVERSEN
-- =========================================================

notify pgrst, 'reload schema';