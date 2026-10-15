-- BierKompas: nieuwsartikelen voor de nieuwsrubriek (door Kirubel gebouwd in
-- lib/features/news/news_article_page.dart en home_page.dart), beheerd door
-- beheerders. Uitvoeren via het Supabase-dashboard: SQL Editor -> New query
-- -> plak dit bestand -> Run.
--
-- Zonder deze tabel blijft de nieuwsrubriek altijd leeg (de app vangt de
-- ontbrekende tabel netjes af), maar is de functie dus onbruikbaar.

create table if not exists public.news_articles (
    id bigint generated always as identity primary key,
    titel text not null,
    samenvatting text not null,
    inhoud text not null,
    foto_url text,
    status text not null default 'concept' check (status in ('concept', 'gepubliceerd')),
    gepubliceerd_op timestamptz not null default now(),
    created_at timestamptz not null default now()
);

alter table public.news_articles enable row level security;

drop policy if exists "Nieuws: iedereen mag gepubliceerde artikelen lezen" on public.news_articles;
create policy "Nieuws: iedereen mag gepubliceerde artikelen lezen" on public.news_articles
    for select using (status = 'gepubliceerd');

drop policy if exists "Nieuws: beheerders mogen alles lezen" on public.news_articles;
create policy "Nieuws: beheerders mogen alles lezen" on public.news_articles
    for select using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Nieuws: alleen beheerders mogen wijzigen" on public.news_articles;
create policy "Nieuws: alleen beheerders mogen wijzigen" on public.news_articles
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

NOTIFY pgrst, 'reload schema';
