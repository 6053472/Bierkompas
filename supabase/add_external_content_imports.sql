-- BierKompas: importeren van externe bronnen (bierdatabase, agenda, nieuws).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_event_status.sql, add_news_articles.sql en
-- add_admin_content_management.sql (eerder uitgevoerd).
--
-- De gegevens zelf worden niet via SQL geladen maar met de knoppen op het
-- admin-tabblad "Data-imports" (veilig opnieuw te draaien: bestaande
-- regels worden bijgewerkt in plaats van dubbel aangemaakt).

-- 1. Bierdatabase. Aparte tabel naast `bieren` (die alleen de koppeling
-- barcode <-> bier-id voor de scanfunctie bevat en in zijn geheel in het
-- geheugen van de app wordt geladen -- bij ~4.500 bieren zoeken en pagineren
-- we juist op de server).
-- untappd_score en untappd_aantal staan in de kolomlijst van Huub, maar de
-- bron (Nederlandse Biercultuur) heeft die gegevens niet; Untappd staat
-- scrapen niet toe. De kolommen blijven daarom leeg tot er een toegestane
-- bron voor is.
create table if not exists public.beer_catalog (
    id bigint primary key,
    naam text not null,
    brouwerij text,
    brouwerij_id bigint,
    stijl text,
    smaakcategorie text,
    verpakking text,
    land text,
    alcohol numeric(4,2),
    ibu integer,
    gisting text,
    smaaktonen text,
    untappd_score numeric(3,2),
    untappd_aantal integer,
    bron text not null default 'Stichting Erfgoed Nederlandse Biercultuur',
    bron_url text,
    created_at timestamptz not null default now()
);

create index if not exists beer_catalog_naam_idx on public.beer_catalog (lower(naam));
create index if not exists beer_catalog_brouwerij_idx on public.beer_catalog (lower(brouwerij));
create index if not exists beer_catalog_stijl_idx on public.beer_catalog (stijl);

-- Foto en kleur, gevuld door de import van Belgian Beer Factory en Mitra
-- (supabase/bierdatabase/bierdatabase_belgie_en_nederland.sql).
alter table public.beer_catalog add column if not exists image_url text;
alter table public.beer_catalog add column if not exists kleur text;

alter table public.beer_catalog enable row level security;

drop policy if exists "Bierdatabase: iedereen mag lezen" on public.beer_catalog;
create policy "Bierdatabase: iedereen mag lezen" on public.beer_catalog
    for select using (true);

drop policy if exists "Bierdatabase: alleen beheerders mogen wijzigen" on public.beer_catalog;
create policy "Bierdatabase: alleen beheerders mogen wijzigen" on public.beer_catalog
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- Lijst van alle bierstijlen met aantal bieren, voor het stijlfilter in de app
-- (een gewone select geeft maximaal 1000 rijen terug, dus dit doen we in de database).
create or replace function public.beer_catalog_styles()
returns table(stijl text, aantal bigint)
language sql
stable
as $$
    select stijl, count(*) as aantal
    from public.beer_catalog
    where stijl is not null and stijl <> ''
    group by stijl
    order by count(*) desc, stijl;
$$;

grant execute on function public.beer_catalog_styles() to anon, authenticated;

-- 2. Evenementen: herkomst bijhouden zodat een import niet dubbel inlaadt.
-- Gewone, door gebruikers aangemaakte evenementen hebben bron = null en
-- botsen dus nooit met de unieke index.
alter table public.events add column if not exists bron text;
alter table public.events add column if not exists bron_id text;
alter table public.events add column if not exists bron_url text;
create unique index if not exists events_bron_unique on public.events (bron, bron_id, start_date);

-- 3. Nieuws: bron van een artikel (naam + link), zodat de app naar het
-- originele artikel kan verwijzen in plaats van de tekst over te nemen.
alter table public.news_articles add column if not exists bron_naam text;
alter table public.news_articles add column if not exists bron_url text;
create unique index if not exists news_articles_bron_url_unique on public.news_articles (bron_url);

NOTIFY pgrst, 'reload schema';
