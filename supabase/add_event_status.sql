-- Evenementen: goedkeuringsflow voor beheerders + "vervallen" i.p.v.
-- verwijderen, en een eenvoudige beheerder-rol.
--
-- Een beheerder is gewoon een normale gebruiker (logt in met zijn eigen
-- account) waarvan `is_admin` op true staat. Er is bewust geen los
-- "beheerder-wachtwoord" systeem gebouwd: dat zou een tweede, zwakkere
-- authenticatielaag naast Supabase Auth betekenen. Maak iemand beheerder met:
--
--   update public.profiles set is_admin = true where email = 'naam@voorbeeld.nl';

alter table public.profiles add column if not exists is_admin boolean not null default false;

alter table public.events add column if not exists status text not null default 'pending';
alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check
    check (status in ('pending', 'approved', 'cancelled'));
alter table public.events add column if not exists approved_at timestamptz;
alter table public.events add column if not exists approved_by uuid references public.profiles(id);
alter table public.events add column if not exists cancelled_at timestamptz;

-- Bestaande evenementen (vóór deze migratie) meteen als goedgekeurd
-- behandelen, anders verdwijnen ze allemaal uit de agenda.
update public.events set status = 'approved' where status = 'pending';

-- Iedereen ziet goedgekeurde en vervallen evenementen; de eigenaar ziet ook
-- zijn eigen nog-niet-goedgekeurde evenementen; beheerders zien alles.
drop policy if exists "Events: everyone can view" on public.events;
drop policy if exists "Events: view approved, own, or admin" on public.events;
create policy "Events: view approved, own, or admin" on public.events
    for select using (
        status in ('approved', 'cancelled')
        or user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Events: owner can update" on public.events;
drop policy if exists "Events: owner or admin can update" on public.events;
create policy "Events: owner or admin can update" on public.events
    for update using (
        user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- Eigenaar laat zijn eigen (goedgekeurde) evenement vervallen i.p.v. het te
-- verwijderen: blijft zichtbaar in de agenda met een "Vervallen"-stempel.
create or replace function public.cancel_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    update public.events
        set status = 'cancelled', cancelled_at = now()
        where id = p_event_id and user_id = auth.uid() and status = 'approved';
end;
$$;

grant execute on function public.cancel_event(bigint) to authenticated;

-- Beheerder keurt een nieuw evenement goed, waarna het publiek zichtbaar wordt.
create or replace function public.approve_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen evenementen goedkeuren';
    end if;

    update public.events
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_event_id and status = 'pending';
end;
$$;

grant execute on function public.approve_event(bigint) to authenticated;

-- Beheerder wijst een nieuw evenement af (nooit gepubliceerd geweest, dus
-- gewoon verwijderen in plaats van als "vervallen" te tonen).
create or replace function public.reject_event(p_event_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen evenementen afwijzen';
    end if;

    delete from public.events where id = p_event_id and status = 'pending';
end;
$$;

grant execute on function public.reject_event(bigint) to authenticated;

NOTIFY pgrst, 'reload schema';
