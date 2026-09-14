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

NOTIFY pgrst, 'reload schema';
