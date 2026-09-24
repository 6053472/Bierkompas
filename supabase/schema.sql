```sql
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
```
