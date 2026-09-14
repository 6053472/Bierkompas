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

create policy "Friend requests: select involved" on public.friend_requests
    for select using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Friend requests: insert own" on public.friend_requests
    for insert with check (auth.uid() = requester_id);

create policy "Friend requests: addressee can update" on public.friend_requests
    for update using (auth.uid() = addressee_id);

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

NOTIFY pgrst, 'reload schema';
