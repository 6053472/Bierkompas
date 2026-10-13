-- BierKompas: beheerders kunnen zelf muziek, boeken, evenementen,
-- brouwerijen en proeflokalen/horeca toevoegen en publiceren via de
-- admin-pagina. Uitvoeren via het Supabase-dashboard: SQL Editor -> New query
-- -> plak dit bestand -> Run. Vereist add_event_status.sql,
-- add_brewery_submissions.sql en add_horeca_submissions.sql (eerder uitgevoerd).

-- 1. Muziek ("Brouwers Beats"). De bestaande nummers staan hardcoded in de
-- app; nummers die hier worden toegevoegd komen er automatisch bij.
create table if not exists public.music_tracks (
    id bigint generated always as identity primary key,
    title text not null,
    artist text not null,
    cover_url text not null,
    listen_url text,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.music_tracks enable row level security;

drop policy if exists "Muziek: iedereen mag lezen" on public.music_tracks;
create policy "Muziek: iedereen mag lezen" on public.music_tracks
    for select using (true);

drop policy if exists "Muziek: alleen beheerders mogen wijzigen" on public.music_tracks;
create policy "Muziek: alleen beheerders mogen wijzigen" on public.music_tracks
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- 2. Boeken (bibliotheek). Zelfde opzet als muziek.
create table if not exists public.library_books (
    id bigint generated always as identity primary key,
    title text not null,
    author text not null,
    subtitle text,
    cover_url text not null,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.library_books enable row level security;

drop policy if exists "Boeken: iedereen mag lezen" on public.library_books;
create policy "Boeken: iedereen mag lezen" on public.library_books
    for select using (true);

drop policy if exists "Boeken: alleen beheerders mogen wijzigen" on public.library_books;
create policy "Boeken: alleen beheerders mogen wijzigen" on public.library_books
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- 3. Beheerders mogen aangemelde en zelf toegevoegde brouwerijen/horeca en
-- evenementen bijwerken en verwijderen (voorheen alleen goed-/afkeuren).
drop policy if exists "Brewery submissions: admin update" on public.brewery_submissions;
create policy "Brewery submissions: admin update" on public.brewery_submissions
    for update using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Brewery submissions: admin delete" on public.brewery_submissions;
create policy "Brewery submissions: admin delete" on public.brewery_submissions
    for delete using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Horeca submissions: admin update" on public.horeca_submissions;
create policy "Horeca submissions: admin update" on public.horeca_submissions
    for update using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Horeca submissions: admin delete" on public.horeca_submissions;
create policy "Horeca submissions: admin delete" on public.horeca_submissions
    for delete using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Events: admin delete" on public.events;
create policy "Events: admin delete" on public.events
    for delete using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

NOTIFY pgrst, 'reload schema';
