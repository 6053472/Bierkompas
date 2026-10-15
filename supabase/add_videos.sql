-- BierKompas: video-reel ("Brouwerij Highlights"), beheerd door beheerders.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- De app toont deze video's als een horizontale "reel" op de Ontdek-pagina
-- (zie bierkompas paginas/brouwerij_highlights_reels). Zolang een beheerder
-- hier niets heeft toegevoegd, toont de app een lege staat -- er wordt geen
-- nepcontent verzonnen.

create table if not exists public.videos (
    id bigint generated always as identity primary key,
    title text not null,
    category text not null default 'Tasting',
    thumbnail_url text not null,
    video_url text not null,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.videos enable row level security;

drop policy if exists "Videos: iedereen mag lezen" on public.videos;
create policy "Videos: iedereen mag lezen" on public.videos
    for select using (true);

drop policy if exists "Videos: alleen beheerders mogen wijzigen" on public.videos;
create policy "Videos: alleen beheerders mogen wijzigen" on public.videos
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

NOTIFY pgrst, 'reload schema';
