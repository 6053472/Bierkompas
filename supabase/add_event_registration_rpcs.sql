-- BierKompas: ontbrekende functies voor het "aanmelden voor een evenement"
-- -flow (event_registrations, zie schema.sql). De app (events_page.dart)
-- roept get_event_pending_registrations en get_event_approved_participants
-- al aan, maar deze functies stonden nog in geen enkel SQL-bestand -- zonder
-- deze migratie ziet een organisator dus nooit zijn wachtende of
-- goedgekeurde aanmeldingen (de query mislukt stil en toont een lege lijst).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist schema.sql (event_registrations-tabel + is_admin()-functie).

-- Bestaande versies (rechtstreeks in Supabase aangemaakt, niet in deze repo)
-- kunnen een ander retourtype hebben -- Postgres staat geen wijziging van het
-- retourtype toe via 'create or replace', dus eerst verwijderen.
drop function if exists public.get_event_pending_registrations(bigint);
drop function if exists public.get_event_approved_participants(bigint);

create or replace function public.get_event_pending_registrations(p_event_id bigint)
returns table(
    id bigint,
    user_id uuid,
    status text,
    created_at timestamptz,
    name text,
    avatar_url text
)
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (
        select 1 from public.events e
        where e.id = p_event_id and (e.user_id = auth.uid() or public.is_admin())
    ) then
        raise exception 'Alleen de organisator of een beheerder mag aanmeldingen bekijken';
    end if;

    return query
        select er.id, er.user_id, er.status, er.created_at, p.name, p.avatar_url
        from public.event_registrations er
        join public.profiles p on p.id = er.user_id
        where er.event_id = p_event_id and er.status = 'pending'
        order by er.created_at;
end;
$$;

grant execute on function public.get_event_pending_registrations(bigint) to authenticated;

create or replace function public.get_event_approved_participants(p_event_id bigint)
returns table(
    id bigint,
    user_id uuid,
    name text,
    avatar_url text
)
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (
        select 1 from public.events e
        where e.id = p_event_id and (e.user_id = auth.uid() or public.is_admin())
    ) then
        raise exception 'Alleen de organisator of een beheerder mag deelnemers bekijken';
    end if;

    return query
        select er.id, er.user_id, p.name, p.avatar_url
        from public.event_registrations er
        join public.profiles p on p.id = er.user_id
        where er.event_id = p_event_id and er.status = 'approved'
        order by er.created_at;
end;
$$;

grant execute on function public.get_event_approved_participants(bigint) to authenticated;

NOTIFY pgrst, 'reload schema';
