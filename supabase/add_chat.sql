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

NOTIFY pgrst, 'reload schema';
