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

NOTIFY pgrst, 'reload schema';
