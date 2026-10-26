-- BierKompas: gebruikers kunnen een onbekend bier aanmelden (bijv. als de
-- scanner geen match vindt). Een beheerder keurt het goed of af; pas na
-- goedkeuring komt het bier in de tabel `bieren` en is het voor iedereen
-- zichtbaar. Zelfde patroon als brewery_submissions, zodat de database niet
-- vervuilt met dubbele of foutieve bieren.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_bier_toevoegen.sql, add_beer_scan_photo.sql en
-- add_notifications.sql (eerder uitgevoerd).

create table if not exists public.beer_submissions (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,

    naam text not null,
    brouwerij text not null,
    stijl text,
    abv text,
    beschrijving text,
    barcode text,
    photo_url text,

    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now(),
    approved_at timestamptz,
    approved_by uuid references public.profiles(id),
    rejection_reason text,

    -- Het bier dat bij goedkeuring in `bieren` is aangemaakt.
    beer_id integer references public.bieren(id) on delete set null
);

alter table public.beer_submissions enable row level security;

-- De indiener ziet zijn eigen aanmeldingen, beheerders zien alles.
drop policy if exists "Beer submissions: view own or admin" on public.beer_submissions;
create policy "Beer submissions: view own or admin" on public.beer_submissions
    for select using (
        user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Beer submissions: insert own" on public.beer_submissions;
create policy "Beer submissions: insert own" on public.beer_submissions
    for insert with check (user_id = auth.uid() and status = 'pending');

-- Geen update/delete voor gewone gebruikers: goedkeuren/afwijzen gaat via
-- de functies hieronder.

-- Beheerder keurt goed. De beheerder kan naam, brouwerij, stijl, alcohol en
-- barcode nog verbeteren (null = ingestuurde waarde houden). Het bier komt in
-- `bieren`; een barcode die al bij een ander bier hoort wordt niet
-- overgenomen.
create or replace function public.approve_beer_submission(
    p_submission_id bigint,
    p_naam text default null,
    p_brouwerij text default null,
    p_stijl text default null,
    p_abv text default null,
    p_barcode text default null
)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
    v_sub public.beer_submissions;
    v_barcode text;
    v_beer_id integer;
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen bieren goedkeuren';
    end if;

    select * into v_sub from public.beer_submissions
        where id = p_submission_id and status = 'pending'
        for update;
    if not found then
        raise exception 'Aanmelding niet gevonden of al afgehandeld';
    end if;

    v_barcode := nullif(trim(coalesce(p_barcode, v_sub.barcode, '')), '');
    if v_barcode is not null and exists (select 1 from public.bieren where barcode = v_barcode) then
        v_barcode := null;
    end if;

    insert into public.bieren (naam, brouwerij, stijl, abv, beschrijving, foto_url, barcode)
    values (
        coalesce(nullif(trim(p_naam), ''), v_sub.naam),
        coalesce(nullif(trim(p_brouwerij), ''), v_sub.brouwerij),
        coalesce(nullif(trim(p_stijl), ''), v_sub.stijl),
        coalesce(nullif(trim(p_abv), ''), v_sub.abv),
        v_sub.beschrijving,
        v_sub.photo_url,
        v_barcode
    )
    returning id into v_beer_id;

    update public.beer_submissions
        set status = 'approved', approved_at = now(), approved_by = auth.uid(), beer_id = v_beer_id
        where id = p_submission_id;

    insert into public.notifications (user_id, title, body)
    values (v_sub.user_id, 'Bier goedgekeurd',
            'Je aangemelde bier "' || coalesce(nullif(trim(p_naam), ''), v_sub.naam) || '" staat nu in Bierkompas.');

    return v_beer_id;
end;
$$;

grant execute on function public.approve_beer_submission(bigint, text, text, text, text, text) to authenticated;

create or replace function public.reject_beer_submission(p_submission_id bigint, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_owner uuid;
    v_naam text;
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen bieren afwijzen';
    end if;

    update public.beer_submissions
        set status = 'rejected', rejection_reason = p_reason
        where id = p_submission_id and status = 'pending'
        returning user_id, naam into v_owner, v_naam;

    if v_owner is not null then
        insert into public.notifications (user_id, title, body)
        values (v_owner, 'Bier niet toegevoegd',
                'Je aangemelde bier "' || coalesce(v_naam, '') || '" is niet toegevoegd'
                || coalesce('. Reden: ' || nullif(trim(p_reason), ''), '') || '.');
    end if;
end;
$$;

grant execute on function public.reject_beer_submission(bigint, text) to authenticated;

NOTIFY pgrst, 'reload schema';
