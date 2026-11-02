-- BierKompas: "Bellen" bij een Biervriend -- de belknop in de chat opent de
-- telefoon-app met het nummer van de vriend. Een gebruiker deelt zijn
-- telefoonnummer alleen met bevestigde vrienden, en alleen na expliciete
-- toestemming (share_with_friends, aan te zetten in Profiel bewerken).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_friends.sql (voor de friend_requests-tabel).

-- Aparte tabel i.p.v. een kolom op profiles: profiles is breder leesbaar,
-- het nummer mag alleen de eigenaar zelf direct zien.
create table if not exists public.friend_phones (
    user_id uuid primary key references auth.users(id) on delete cascade,
    phone text not null,
    share_with_friends boolean not null default false,
    updated_at timestamptz not null default now()
);

alter table public.friend_phones enable row level security;

drop policy if exists "Friend phones: select own" on public.friend_phones;
create policy "Friend phones: select own" on public.friend_phones
    for select using (auth.uid() = user_id);

drop policy if exists "Friend phones: insert own" on public.friend_phones;
create policy "Friend phones: insert own" on public.friend_phones
    for insert with check (auth.uid() = user_id);

drop policy if exists "Friend phones: update own" on public.friend_phones;
create policy "Friend phones: update own" on public.friend_phones
    for update using (auth.uid() = user_id);

drop policy if exists "Friend phones: delete own" on public.friend_phones;
create policy "Friend phones: delete own" on public.friend_phones
    for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.friend_phones to authenticated;

-- Geeft het nummer van één vriend, of null als die geen nummer deelt of
-- (nog) geen bevestigde vriend is.
create or replace function public.friend_phone(p_friend_id uuid)
returns text
language sql
security definer set search_path = public
stable
as $$
    select fp.phone
    from public.friend_phones fp
    where fp.user_id = p_friend_id
        and fp.share_with_friends = true
        and fp.user_id <> auth.uid()
        and exists (
            select 1 from public.friend_requests fr
            where fr.status = 'accepted'
                and (
                    (fr.requester_id = auth.uid() and fr.addressee_id = fp.user_id)
                    or (fr.addressee_id = auth.uid() and fr.requester_id = fp.user_id)
                )
        );
$$;

grant execute on function public.friend_phone(uuid) to authenticated;

NOTIFY pgrst, 'reload schema';
