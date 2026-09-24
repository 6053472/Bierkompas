-- ============================================================
-- BierKompas - Supabase schema.sql
-- ============================================================


-- ============================================================
-- 1. PROFILES
-- ============================================================

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


-- ============================================================
-- 2. ADMIN FUNCTIE
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public, pg_temp
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


-- ============================================================
-- 3. PROFILE POLICIES
-- ============================================================

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


create policy "Profiles: event owners and admins can view participants"
on public.profiles
for select
to authenticated
using (
    public.is_admin()
    OR
    exists (
        select 1
        from public.event_registrations er
        inner join public.events e
            on e.id = er.event_id
        where er.user_id = public.profiles.id
        and e.user_id = auth.uid()
    )
);


-- ============================================================
-- 4. NIEUWE GEBRUIKER -> PROFILE
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

    insert into public.profiles (
        id,
        name,
        email
    )
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'name', ''),
        coalesce(new.email, '')
    )
    on conflict (id) do update
    set
        name = excluded.name,
        email = excluded.email;

    return new;

end;
$$;


drop trigger if exists on_auth_user_created
on auth.users;


create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();


-- ============================================================
-- 5. USER CONSENTS
-- ============================================================

create table if not exists public.user_consents (
    id bigint generated always as identity primary key,

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    consent_type text not null,

    accepted boolean not null default false,

    created_at timestamptz not null default now(),

    constraint unique_user_consent
        unique (user_id, consent_type)
);

alter table public.user_consents
enable row level security;


drop policy if exists "User consents: own select"
on public.user_consents;

drop policy if exists "User consents: own insert"
on public.user_consents;

drop policy if exists "User consents: own update"
on public.user_consents;


create policy "User consents: own select"
on public.user_consents
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "User consents: own insert"
on public.user_consents
for insert
to authenticated
with check (
    auth.uid() = user_id
);


create policy "User consents: own update"
on public.user_consents
for update
to authenticated
using (
    auth.uid() = user_id
)
with check (
    auth.uid() = user_id
);


-- ============================================================
-- 6. FAVORITES
-- ============================================================

create table if not exists public.favorites (
    id bigint generated always as identity primary key,

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    event_id bigint,

    created_at timestamptz not null default now()
);

alter table public.favorites
enable row level security;


drop policy if exists "Favorites: own select"
on public.favorites;

drop policy if exists "Favorites: own insert"
on public.favorites;

drop policy if exists "Favorites: own delete"
on public.favorites;


create policy "Favorites: own select"
on public.favorites
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "Favorites: own insert"
on public.favorites
for insert
to authenticated
with check (
    auth.uid() = user_id
);


create policy "Favorites: own delete"
on public.favorites
for delete
to authenticated
using (
    auth.uid() = user_id
);


-- ============================================================
-- 7. EVENTS
-- ============================================================

create table if not exists public.events (
    id bigint generated always as identity primary key,

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    name text not null,

    event_type text not null default 'Festival',

    start_date timestamptz not null,

    end_date timestamptz,

    opening_hours text,

    street text,

    house_number text,

    postal_code text,

    city text,

    location_name text,

    description text,

    ticket_regular numeric,

    ticket_beer numeric,

    ticket_vip numeric,

    price numeric default 0.00,

    price_incl_btw boolean not null default true,

    price_excl_btw boolean not null default false,

    image_asset text,

    status text not null default 'pending',

    created_at timestamptz not null default now(),

    constraint event_status_check
        check (
            status in (
                'pending',
                'approved',
                'rejected',
                'cancelled'
            )
        )
);

alter table public.events
enable row level security;


-- ============================================================
-- 8. EVENTS POLICIES
-- ============================================================

drop policy if exists "Events: everyone can view approved"
on public.events;

drop policy if exists "Events: authenticated users can create"
on public.events;

drop policy if exists "Events: owners can update"
on public.events;

drop policy if exists "Events: owners can delete"
on public.events;

drop policy if exists "Events: admins can update"
on public.events;

drop policy if exists "Events: admins can delete"
on public.events;


create policy "Events: everyone can view approved"
on public.events
for select
using (
    status = 'approved'
    or user_id = auth.uid()
    or public.is_admin()
);


create policy "Events: authenticated users can create"
on public.events
for insert
to authenticated
with check (
    user_id = auth.uid()
);


create policy "Events: owners can update"
on public.events
for update
to authenticated
using (
    user_id = auth.uid()
)
with check (
    user_id = auth.uid()
);


create policy "Events: owners can delete"
on public.events
for delete
to authenticated
using (
    user_id = auth.uid()
);


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


create policy "Events: admins can delete"
on public.events
for delete
to authenticated
using (
    public.is_admin()
);


-- ============================================================
-- 9. EVENT REGISTRATIONS
-- ============================================================

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
enable row level security;


-- ============================================================
-- 10. REGISTRATION POLICIES
-- ============================================================

drop policy if exists "Registrations: own select"
on public.event_registrations;

drop policy if exists "Registrations: event owner select"
on public.event_registrations;

drop policy if exists "Registrations: admin select"
on public.event_registrations;

drop policy if exists "Registrations: own insert"
on public.event_registrations;

drop policy if exists "Registrations: own delete"
on public.event_registrations;

drop policy if exists "Registrations: event owner update"
on public.event_registrations;

drop policy if exists "Registrations: admin update"
on public.event_registrations;


create policy "Registrations: own select"
on public.event_registrations
for select
to authenticated
using (
    user_id = auth.uid()
);


create policy "Registrations: event owner select"
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


create policy "Registrations: admin select"
on public.event_registrations
for select
to authenticated
using (
    public.is_admin()
);


create policy "Registrations: own insert"
on public.event_registrations
for insert
to authenticated
with check (
    user_id = auth.uid()
);


create policy "Registrations: own delete"
on public.event_registrations
for delete
to authenticated
using (
    user_id = auth.uid()
);


create policy "Registrations: event owner update"
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


create policy "Registrations: admin update"
on public.event_registrations
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);


-- ============================================================
-- 11. GOEDGEKEURDE DEELNEMERS OPHALEN
-- ============================================================

drop function if exists public.get_event_approved_participants(bigint);

create function public.get_event_approved_participants(
    p_event_id bigint
)
returns table (
    id uuid,
    name text,
    avatar_url text
)
language sql
security definer
set search_path = public, pg_temp
as $$
    select
        p.id,
        p.name,
        p.avatar_url

    from public.event_registrations er

    inner join public.profiles p
        on p.id = er.user_id

    inner join public.events e
        on e.id = er.event_id

    where er.event_id = p_event_id

      and er.status = 'approved'

      and (
          e.user_id = auth.uid()
          or public.is_admin()
      )

    order by er.created_at;
$$;


revoke all
on function public.get_event_approved_participants(bigint)
from public;


grant execute
on function public.get_event_approved_participants(bigint)
to authenticated;


-- ============================================================
-- 12. EVENEMENT LATEN VERVALLEN
-- ============================================================

create or replace function public.cancel_event(
    p_event_id bigint
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

    if not exists (
        select 1
        from public.events
        where id = p_event_id
        and (
            user_id = auth.uid()
            or public.is_admin()
        )
    ) then

        raise exception
            'Geen toestemming om dit evenement te annuleren.';

    end if;


    update public.events

    set status = 'cancelled'

    where id = p_event_id;

end;
$$;


grant execute
on function public.cancel_event(bigint)
to authenticated;


-- ============================================================
-- 13. GRANTS
-- ============================================================

grant select, insert, update, delete
on public.profiles
to authenticated;


grant select, insert, update, delete
on public.events
to authenticated;


grant select, insert, update, delete
on public.event_registrations
to authenticated;


grant select, insert, update, delete
on public.user_consents
to authenticated;


grant select, insert, update, delete
on public.favorites
to authenticated;


-- ============================================================
-- 14. IDENTITY / SEQUENCES
-- ============================================================

grant usage, select
on all sequences in schema public
to authenticated;


-- ============================================================
-- 15. POSTGREST SCHEMA RELOAD
-- ============================================================

notify pgrst, 'reload schema';