-- BierKompas: Infinite Scroll Feed voor de Ontdek-pagina.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Kan veilig opnieuw worden uitgevoerd.
--
-- - feed_items: losse feed-content (mini-reviews, biertips, weetjes en brouwerij-posts).
--   beer_id / brewery_id verwijzen naar de vaste bieren en brouwerijen in de app
--   (lib/features/favorites/beers.dart en lib/features/map/breweries.dart). Liken van zo'n
--   post slaat het bier of de brouwerij op als favoriet; andere posts worden zelf bewaard.
-- - feed (view): voegt feed_items samen met de bestaande tabel events, zodat
--   evenementen uit de Agenda automatisch ook in de feed verschijnen.
-- De app leest alleen de view, in batches van 15 via range (limit/offset),
-- gesorteerd op created_at en daarna feed_key.

create table if not exists public.feed_items (
    id bigint generated always as identity primary key,
    item_type text not null,
    title text not null,
    body text not null,
    image_url text,
    author text,
    rating numeric(2,1) check (rating between 0 and 5),
    beer_id bigint,
    brewery_id bigint,
    created_at timestamptz not null default now()
);

-- Voor het geval de tabel al bestond zonder deze kolommen of met een oudere controle.
alter table public.feed_items add column if not exists beer_id bigint;
alter table public.feed_items add column if not exists brewery_id bigint;
alter table public.feed_items drop constraint if exists feed_items_item_type_check;
alter table public.feed_items add constraint feed_items_item_type_check
    check (item_type in ('review', 'tip', 'weetje', 'brouwerij'));

create index if not exists feed_items_created_at_idx on public.feed_items (created_at desc);

alter table public.feed_items enable row level security;

drop policy if exists "Feed items: everyone can view" on public.feed_items;
create policy "Feed items: everyone can view"
on public.feed_items for select using (true);

grant select on public.feed_items to anon, authenticated;

-- Eén gemengde stroom. feed_key is uniek over beide tabellen en dient als
-- tiebreaker, zodat paginering met offset geen items overslaat of dubbel toont.
-- security_invoker zorgt dat de RLS-regels van de onderliggende tabellen gelden.
drop view if exists public.feed;
create view public.feed
with (security_invoker = on) as
select
    'item-' || id as feed_key,
    item_type,
    title,
    body,
    image_url,
    author,
    rating,
    beer_id,
    brewery_id,
    null::timestamptz as event_start,
    null::text as event_location,
    created_at
from public.feed_items
union all
select
    'event-' || id,
    'evenement',
    name,
    description,
    null,
    null,
    null,
    null,
    null,
    start_date,
    location_name || ', ' || city,
    created_at
from public.events;

grant select on public.feed to anon, authenticated;

-- Voorbeeldcontent (fictieve bieren), zodat de feed meerdere batches heeft.
-- Wordt alleen toegevoegd als feed_items nog leeg is; de volgorde bepaalt de id's
-- en komt overeen met lib/features/feed/feed_samples.dart.
insert into public.feed_items (item_type, title, body, image_url, author, rating, created_at)
select v.item_type, v.title, v.body, v.image_url, v.author, v.rating, v.created_at
from (values
    ('review', 'Koperen Nacht Tripel', 'Goudkoper van kleur met een romige schuimkraag. Kruidig, tonen van karamel en een warme afdronk. Gevaarlijk doordrinkbaar.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuANIbUEodWyxyWEqbHFoWd_APYDtoiXgTOVbAJ5TIOp9PKG4baeF5XYwf34634GW-PHvDpk4FhxpB1XlsZEFAl3BsWVxT8Gq-KlOZ01ggozbCfeF3fRoufrH8N5tDetdyMY9uKUxDAadw9wON36RlMvSHNjV30Ol5XjZ06tnPRARXfPUGTEFIa5xw_1m7rvTyggDsC2HvYxMuo3GNidOYo-3ypVQq14WiAoZWsApQQMn_T-2VSeoFN7', 'Sanne', 4.5, now() - interval '1 hour'),
    ('tip', 'Spoel je glas eerst koud om', 'Een koud gespoeld glas zorgt voor een mooiere schuimkraag en voorkomt dat je bier te snel opwarmt.', null, 'BierKompas', null, now() - interval '2 hours'),
    ('weetje', 'Waarom heet het trappist?', 'Een bier mag het logo "Authentic Trappist Product" alleen dragen als het onder toezicht van monniken binnen een trappistenabdij wordt gebrouwen.', null, null, null, now() - interval '3 hours'),
    ('review', 'Amber Kompas IPA', 'Fris bitter met grapefruit en dennen, maar de moutbasis houdt alles mooi in balans. Een perfect terrasbier.', null, 'Joris', 4.0, now() - interval '4 hours'),
    ('tip', 'Schenk schuin, eindig recht', 'Houd het glas schuin tijdens het inschenken en zet het halverwege rechtop. Zo krijg je een kraag van ongeveer twee vingers.', null, 'BierKompas', null, now() - interval '5 hours'),
    ('weetje', 'Bock komt uit Einbeck', 'De naam bockbier is waarschijnlijk een verbastering van Einbeck, een Duitse stad die in de middeleeuwen bekend was om zijn sterke bier.', null, null, null, now() - interval '6 hours'),
    ('review', 'Donkere Molen Stout', 'Koffie, pure chocolade en een fluweelzachte mondvulling. Laat hem iets opwarmen, dan komt de vanille los.', null, 'Fatima', 4.5, now() - interval '7 hours'),
    ('tip', 'Niet elk bier hoort ijskoud', 'Pils smaakt het best rond 3 tot 5 graden, maar dubbels, tripels en stouts komen pas echt tot hun recht rond 8 tot 12 graden.', null, 'BierKompas', null, now() - interval '8 hours'),
    ('weetje', 'Hop is familie van hennep', 'Hop en hennep horen allebei bij de plantenfamilie Cannabaceae. Hop geeft bier bitterheid, aroma en een langere houdbaarheid.', null, null, null, now() - interval '9 hours'),
    ('review', 'Zomerhaven Witbier', 'Troebel, met citrus en koriander. Iets te zoet naar mijn smaak, maar heerlijk als het buiten 25 graden is.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDQhKscA00YiHmLOCdFOnKCDnUdAW9kZbBWb69ou6CZYBeHe2q_KbKtwlHDL0lQkAPAzsuvqmU8pVUmGHnRg0EWpY5Ik6FPaApETd4GFJ8GNjNmCAwJ6UFY300bVAFedalKlJ4kScOIAVCDoLzrV9zFMfi2_qs893DP-Tb2j9J-xeHYZerm49wZU1lpqFBiWmJnNAe65PEpi4vsS5PdJhcm0R7KwgjTuk-DTrYbqCMr6frfIMKx7qQK', 'Daan', 3.5, now() - interval '10 hours'),
    ('tip', 'Bewaar flessen rechtop', 'Rechtop, koel en donker bewaard blijft bier langer goed. Licht kan zorgen voor een onaangename, muffe smaak.', null, 'BierKompas', null, now() - interval '11 hours'),
    ('weetje', 'Spontane vergisting', 'Lambiek wordt spontaan vergist met wilde gisten en bacteriën uit de lucht, traditioneel in de regio rond Brussel.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDknuVmwDTa5jB4wik1JsFZcg3HGHEguJ8tKYPIGvMOxeMgWo55nIZ92P0i_iTaZK5gCmhHDfSDDGd8HAgulU_Nt_waa4YIg1QNZCDQnGG9J70xbRh0XNaZFjxojqCPad3s7iiMSHzET5kRpj3GQcD9-hE4MuWtaKdUaP4Wkk6S1kxJhurPAITpPBmmuOIAnJ0_rU6wNjOB6JuYsppLKZZ370oFdfVTbvOpttwPVmC3aU02O1rJkSR2', null, null, now() - interval '12 hours'),
    ('review', 'Oude Sluis Dubbel', 'Rozijnen, bruine suiker en een vleugje drop. Een klassieke dubbel zonder poespas.', null, 'Emma', 4.0, now() - interval '13 hours'),
    ('tip', 'Stout bij chocolade', 'De geroosterde tonen van een stout versterken een chocoladedessert. Probeer het eens met een brownie.', null, 'BierKompas', null, now() - interval '14 hours'),
    ('weetje', 'Gueuze is een blend', 'Gueuze ontstaat door jonge en oude lambiek te mengen en op fles na te laten gisten. Daardoor krijgt het zijn bruisende, zure karakter.', null, null, null, now() - interval '15 hours'),
    ('review', 'Veldkers Saison', 'Droog, peperig en licht fruitig. Elke slok maakt dorst naar de volgende.', null, 'Luuk', 4.5, now() - interval '16 hours'),
    ('tip', 'Witbier bij vis en mosselen', 'De citrus- en korianderaroma''s van witbier passen perfect bij vis, mosselen en frisse salades.', null, 'BierKompas', null, now() - interval '17 hours'),
    ('weetje', 'Het Reinheitsgebot', 'In 1516 bepaalde Beieren dat bier alleen van water, gerst en hop gemaakt mocht worden. Gist werd pas later ontdekt en toegevoegd.', null, null, null, now() - interval '18 hours'),
    ('review', 'Koperen Nacht Blond', 'Honingzoet begin en een licht bittere finish. Toegankelijk, maar het mist wat karakter.', null, 'Noor', 3.0, now() - interval '19 hours'),
    ('tip', 'Proef van licht naar zwaar', 'Begin een proeverij met lichte, frisse bieren en werk toe naar zware en zure bieren, zodat je smaakpapillen niet overweldigd raken.', null, 'BierKompas', null, now() - interval '20 hours'),
    ('weetje', 'Donker is niet sterker', 'De kleur van bier komt van de mout, niet van het alcoholpercentage. Een donkere stout kan lichter zijn dan een blonde tripel.', null, null, null, now() - interval '21 hours'),
    ('review', 'Winterlicht Bock', 'Karamel en geroosterd brood: precies wat je wilt als het buiten stormt.', null, 'Milan', 4.0, now() - interval '22 hours'),
    ('tip', 'Ruik voordat je proeft', 'Een groot deel van wat je proeft is eigenlijk geur. Houd het glas even onder je neus voor de eerste slok.', null, 'BierKompas', null, now() - interval '23 hours'),
    ('weetje', 'Kölsch is een beschermde naam', 'Volgens de Kölsch-Konvention mag alleen bier dat in en rond Keulen wordt gebrouwen zich Kölsch noemen.', null, null, null, now() - interval '24 hours'),
    ('review', 'Havenmeester Pale Ale', 'Mooi helder, bloemige hop en een droge afdronk. Een echte allrounder.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDzhnMA6a-cCYnZ4dSjHCbGFUCvVBqXUZ9Mjk381yzhl0FoUiVgLmBWOKSPR3dEAVnnWVP1ViPRMKTviMaubvedPJI8ZXYMKr2bHJp9kjDRoEAO6A3vh371Km-kVjS9517tTWX1sD4_SpqLSWD2-RUMkSVP5qWL233CRvFNvB207EKaTmWkQClVLTqYIyOY1ub3PvqQO7wKkKnn-D4nvwFWeRXl3ZPDG8Oz-xe3t4BW9-cK5h3r3pSO', 'Lotte', 4.0, now() - interval '25 hours'),
    ('tip', 'Kies het juiste glas', 'Een tulpglas houdt het aroma van speciaalbier vast; een smal pilsglas houdt het koolzuur langer vast.', null, 'BierKompas', null, now() - interval '26 hours'),
    ('weetje', 'Witbier kwam terug dankzij een melkboer', 'Nadat witbier in België was verdwenen, bracht melkboer Pierre Celis de stijl in 1966 terug in Hoegaarden.', null, null, null, now() - interval '27 hours'),
    ('review', 'Kelderzuur Kriek', 'Zuur, kersen en een tikje amandel. Niet voor iedereen, wel voor mij.', null, 'Yara', 5.0, now() - interval '28 hours'),
    ('tip', 'Laat de gist in de fles', 'Bij bieren met nagisting op fles zit gistbezinksel onderin. Schenk rustig en laat het laatste bodempje staan.', null, 'BierKompas', null, now() - interval '29 hours'),
    ('weetje', 'De kraag doet ertoe', 'De schuimkraag houdt aroma''s vast, zodat je neus meeproeft. Zonder kraag verliest bier sneller zijn geur.', null, null, null, now() - interval '30 hours')
) as v(item_type, title, body, image_url, author, rating, created_at)
where not exists (select 1 from public.feed_items);

-- Reviews gaan over een bier uit beers.dart (zelfde naam).
update public.feed_items f
set beer_id = v.beer_id
from (values
    ('Koperen Nacht Tripel', 5),
    ('Amber Kompas IPA', 6),
    ('Donkere Molen Stout', 7),
    ('Zomerhaven Witbier', 8),
    ('Oude Sluis Dubbel', 9),
    ('Veldkers Saison', 10),
    ('Koperen Nacht Blond', 11),
    ('Winterlicht Bock', 12),
    ('Havenmeester Pale Ale', 13),
    ('Kelderzuur Kriek', 14)
) as v(title, beer_id)
where f.item_type = 'review' and f.title = v.title;

-- Posts over een brouwerij uit breweries.dart.
insert into public.feed_items (item_type, title, body, author, brewery_id, created_at)
select v.item_type, v.title, v.body, v.author, v.brewery_id, v.created_at
from (values
    ('brouwerij', 'Op bezoek bij De Molen', 'In Bodegraven begon Brouwerij De Molen in de historische korenmolen De Arkduif. Inmiddels is het een van de bekendste craftbrouwerijen van Nederland.', 'BierKompas', 3, now() - interval '150 minutes'),
    ('brouwerij', 'Trappisten van Sint-Sixtus', 'In de Sint-Sixtusabdij in Westvleteren brouwen monniken sinds 1838 bier. Het is vrijwel alleen bij de abdij zelf te koop.', 'BierKompas', 2, now() - interval '510 minutes'),
    ('brouwerij', 'Proeflokaal Brouwerij Hoop', 'Zin in een vers getapte IPA? Bij Brouwerij Hoop proef je de bieren direct in het eigen proeflokaal.', 'BierKompas', 1, now() - interval '870 minutes'),
    ('brouwerij', 'Grutte Pier: bier & spijs', 'Het proeflokaal van Grutte Pier combineert Friese bieren met eten. Probeer het Dubbel stoofvlees.', 'BierKompas', 4, now() - interval '1230 minutes')
) as v(item_type, title, body, author, brewery_id, created_at)
where not exists (select 1 from public.feed_items f where f.title = v.title);

NOTIFY pgrst, 'reload schema';
