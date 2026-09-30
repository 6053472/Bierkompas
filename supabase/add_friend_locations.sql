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

NOTIFY pgrst, 'reload schema';
