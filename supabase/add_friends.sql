-- Bier-vrienden: gebruikers kunnen elkaar als vriend toevoegen (direct, geen aanvraag-flow).
-- Bij het toevoegen wordt de relatie in beide richtingen opgeslagen zodat beide profielen
-- elkaar meteen in hun vriendenlijst zien.

create table if not exists public.friendships (
    id bigint generated always as identity primary key,
    user_id uuid not null references public.profiles(id) on delete cascade,
    friend_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint unique_friendship unique (user_id, friend_id),
    constraint no_self_friend check (user_id <> friend_id)
);

alter table public.friendships enable row level security;

create policy "Friendships: select own" on public.friendships
    for select using (auth.uid() = user_id);

create policy "Friendships: insert own" on public.friendships
    for insert with check (auth.uid() = user_id);

create policy "Friendships: delete own" on public.friendships
    for delete using (auth.uid() = user_id);

grant select, insert, delete on public.friendships to authenticated;

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

-- Voegt een wederzijdse vriendschap toe (beide richtingen in één transactie).
create or replace function public.add_friend(p_friend_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_friend_id = auth.uid() then
        raise exception 'Je kunt jezelf niet toevoegen als vriend';
    end if;

    insert into public.friendships (user_id, friend_id)
    values (auth.uid(), p_friend_id)
    on conflict do nothing;

    insert into public.friendships (user_id, friend_id)
    values (p_friend_id, auth.uid())
    on conflict do nothing;
end;
$$;

grant execute on function public.add_friend(uuid) to authenticated;

NOTIFY pgrst, 'reload schema';
