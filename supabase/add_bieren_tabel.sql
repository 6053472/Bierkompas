-- BierKompas: bieren-tabel als bron van barcodes, beheerd door beheerders.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
--
-- De volledige bierinhoud (naam, stijl, beschrijving, ...) blijft voorlopig
-- hardcoded in de app (lib/features/favorites/beers.dart) -- deze tabel is
-- puur de koppeling bier-id <-> barcode, zodat een beheerder via de
-- admin-pagina barcodes kan instellen zonder dat de app opnieuw gebouwd
-- hoeft te worden. Naam/stijl staan er ook in, alleen zodat de beheerder
-- ziet welk bier hij aan het bewerken is.

create table if not exists public.bieren (
    id integer primary key,
    naam text not null,
    stijl text,
    brouwerij text,
    barcode text unique,
    updated_at timestamptz not null default now()
);

alter table public.bieren enable row level security;

drop policy if exists "Bieren: iedereen mag lezen" on public.bieren;
create policy "Bieren: iedereen mag lezen" on public.bieren
    for select using (true);

drop policy if exists "Bieren: alleen beheerders mogen wijzigen" on public.bieren;
create policy "Bieren: alleen beheerders mogen wijzigen" on public.bieren
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- De 14 bieren die nu al hardcoded in de app staan, met dezelfde ID's zodat
-- de koppeling klopt. Barcodes zijn de fictieve testcodes uit
-- lib/features/favorites/beers.dart -- een beheerder vervangt deze later
-- door de echte EAN-code van het bier.
insert into public.bieren (id, naam, stijl, brouwerij, barcode) values
    (1, 'Zatte', 'Tripel', E'Brouwerij \'t IJ, Amsterdam', '8710400000013'),
    (2, 'Natte', 'Dubbel', E'Brouwerij \'t IJ, Amsterdam', '8710400000020'),
    (3, 'IJwit', 'Witbier', E'Brouwerij \'t IJ, Amsterdam', '8710400000037'),
    (4, 'Columbus', 'Amber Ale', E'Brouwerij \'t IJ, Amsterdam', '8710400000044'),
    (5, 'Koperen Nacht Tripel', 'Tripel', null, '8710400000051'),
    (6, 'Amber Kompas IPA', 'IPA', null, '8710400000068'),
    (7, 'Donkere Molen Stout', 'Stout', null, '8710400000075'),
    (8, 'Zomerhaven Witbier', 'Witbier', null, '8710400000082'),
    (9, 'Oude Sluis Dubbel', 'Dubbel', null, '8710400000099'),
    (10, 'Veldkers Saison', 'Saison', null, '8710400000105'),
    (11, 'Koperen Nacht Blond', 'Blond', null, '8710400000112'),
    (12, 'Winterlicht Bock', 'Bock', null, '8710400000129'),
    (13, 'Havenmeester Pale Ale', 'Pale Ale', null, '8710400000136'),
    (14, 'Kelderzuur Kriek', 'Kriek', null, '8710400000143')
on conflict (id) do nothing;

-- user_beer_logs.beer_id verwijst nu aantoonbaar naar een bestaand bier.
alter table public.user_beer_logs
    add constraint user_beer_logs_beer_id_fkey
    foreign key (beer_id) references public.bieren(id)
    not valid;
alter table public.user_beer_logs validate constraint user_beer_logs_beer_id_fkey;

NOTIFY pgrst, 'reload schema';
