-- BierKompas: eigen brouwerij aanmelden voor de kaart, met goedkeuring door
-- een beheerder (zelfde patroon als evenementen, zie add_event_status.sql).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

create table if not exists public.brewery_submissions (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,

    naam text not null,
    beschrijving text,

    street text not null,
    house_number text not null,
    postal_code text not null,
    city text not null,

    -- Automatisch bepaald bij het aanmelden (geocoding op het ingevulde
    -- adres). Kan null zijn als geocoding niet lukte; zo'n aanmelding kan een
    -- beheerder nog wel goedkeuren, maar verschijnt pas op de kaart zodra er
    -- coördinaten bekend zijn.
    latitude double precision,
    longitude double precision,

    photo_url text,

    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now(),
    approved_at timestamptz,
    approved_by uuid references public.profiles(id),
    rejection_reason text
);

alter table public.brewery_submissions enable row level security;

-- Iedereen ziet goedgekeurde aanmeldingen (die horen op de kaart); de
-- indiener ziet ook zijn eigen nog-niet-goedgekeurde aanmelding; beheerders
-- zien alles (voor de goedkeuringswachtrij).
drop policy if exists "Brewery submissions: view approved, own, or admin" on public.brewery_submissions;
create policy "Brewery submissions: view approved, own, or admin" on public.brewery_submissions
    for select using (
        status = 'approved'
        or user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Brewery submissions: insert own" on public.brewery_submissions;
create policy "Brewery submissions: insert own" on public.brewery_submissions
    for insert with check (user_id = auth.uid());

-- Geen update/delete-policy voor gewone gebruikers: goedkeuren/afwijzen gaat
-- uitsluitend via de onderstaande functies (security definer).

create or replace function public.approve_brewery_submission(p_submission_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen brouwerij-aanmeldingen goedkeuren';
    end if;

    update public.brewery_submissions
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.approve_brewery_submission(bigint) to authenticated;

create or replace function public.reject_brewery_submission(p_submission_id bigint, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen brouwerij-aanmeldingen afwijzen';
    end if;

    update public.brewery_submissions
        set status = 'rejected', rejection_reason = p_reason
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.reject_brewery_submission(bigint, text) to authenticated;

-- Storage-bucket voor brouwerij-foto's (publiek leesbaar, alleen de indiener
-- mag in zijn eigen map schrijven -- zelfde opzet als avatars, zie add_avatar.sql).
insert into storage.buckets (id, name, public)
values ('brewery-photos', 'brewery-photos', true)
on conflict (id) do nothing;

drop policy if exists "Brewery photos: public read" on storage.objects;
create policy "Brewery photos: public read" on storage.objects
    for select using (bucket_id = 'brewery-photos');

drop policy if exists "Brewery photos: insert own" on storage.objects;
create policy "Brewery photos: insert own" on storage.objects
    for insert with check (
        bucket_id = 'brewery-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

NOTIFY pgrst, 'reload schema';
