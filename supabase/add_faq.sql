-- BierKompas: Support & FAQ (veelgestelde vragen), beheerd via de admin-pagina.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist profiles.is_admin (eerder aangemaakt).
--
-- Vaste rubrieken (volgens afspraak met Huub):
--   account   = Account- en profielinstellingen
--   inchecken = Inchecken
--   bieren    = Bieren en beoordelingen
--   badges    = Badges
--   vrienden  = Vrienden en interactie
--   bronnen   = Toevoegen van bronnen en content
--
-- De startvragen onderaan beschrijven alleen wat de app nu echt doet; een
-- beheerder kan ze via de admin-pagina aanpassen of aanvullen.

create table if not exists public.faq_items (
    id bigint generated always as identity primary key,
    category text not null check (category in ('account', 'inchecken', 'bieren', 'badges', 'vrienden', 'bronnen')),
    question text not null,
    answer text not null,
    sort_order integer not null default 0,
    created_at timestamptz not null default now()
);

create index if not exists faq_items_category_idx on public.faq_items (category, sort_order, id);

alter table public.faq_items enable row level security;

drop policy if exists "FAQ: iedereen mag lezen" on public.faq_items;
create policy "FAQ: iedereen mag lezen" on public.faq_items
    for select using (true);

drop policy if exists "FAQ: alleen beheerders mogen wijzigen" on public.faq_items;
create policy "FAQ: alleen beheerders mogen wijzigen" on public.faq_items
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- Startvragen: alleen invoegen als de tabel nog leeg is, zodat opnieuw
-- draaien van dit script nooit dubbele vragen of overschreven aanpassingen
-- van een beheerder oplevert.
insert into public.faq_items (category, question, answer, sort_order)
select v.category, v.question, v.answer, v.sort_order
from (values
    ('account', 'Hoe pas ik mijn profiel aan?', 'Ga naar het tabblad Profiel en tik op "Bewerk Profiel". Daar kun je onder meer je naam en profielfoto wijzigen.', 1),
    ('account', 'Wie ziet mijn locatie?', 'Alleen bevestigde vrienden, en alleen als je dat zelf aanzet. Ga naar Profiel > Instellingen en zet "Deel mijn locatie met vrienden" aan of uit. Je vrienden zien je dan op de kaart onder "Bierliefhebbers in de buurt".', 2),
    ('account', 'Waar vind ik de Algemene Voorwaarden en het Privacybeleid?', 'Onder Profiel > Instellingen staan de Algemene Voorwaarden en het Privacybeleid.', 3),
    ('account', 'Hoe log ik uit?', 'Ga naar het tabblad Profiel en tik onderaan het profielblok op "Uitloggen".', 4),
    ('account', 'Hoe kan ik mijn account verwijderen?', 'Ga naar Profiel > Instellingen en kies "Account verwijderen". Je krijgt eerst een bevestigingsvraag. Het verwijderen is definitief en kan niet worden teruggedraaid.', 5),

    ('inchecken', 'Hoe check ik een bier in?', 'Gebruik de scanknop op het Ontdek-scherm (bij "Vinden & Proeven") of in je Favorieten. Scan de barcode van het bier, of kies de fotooptie en geef zelf aan welk bier het is. Het bier komt daarna in je Bier-Paspoort.', 1),
    ('inchecken', 'Mijn barcode wordt niet herkend, wat nu?', 'Niet elk bier heeft al een barcode in Bierkompas. Gebruik dan de fotooptie en kies zelf het bier uit de lijst. Staat het bier er niet tussen, dan kan een beheerder het toevoegen.', 2),
    ('inchecken', 'Wat is de Bier Streak?', 'Je streak telt hoeveel dagen op rij je actief bent. Een bier scannen of loggen, een proefnotitie schrijven of een post plaatsen telt als activiteit. Je ziet je streak als 🔥 linksboven in de app. Sla je een dag over, dan begint hij weer bij 1.', 3),

    ('bieren', 'Hoe schrijf ik een proefnotitie?', 'Ga naar Profiel en open Mijn Proefnotities. Kies het bier, geef een beoordeling van 1 tot 5 sterren en schrijf je notitie. Met de schakelaar "Ook delen als bierpost" deel je je notitie ook in de Ontdek-feed.', 1),
    ('bieren', 'Waarom zie ik mijn post nog niet in de Ontdek-feed?', 'Eigen posts worden eerst beoordeeld door een beheerder voordat ze voor iedereen zichtbaar zijn. Na het versturen zie je een melding dat je post is verstuurd.', 2),
    ('bieren', 'Kan ik reageren op de proeverij van iemand anders?', 'Ja. Tik op het reactie-icoon bij een post in de Ontdek-feed. Bij een mini-review kun je er ook een beoordeling van 1 tot 5 sterren als proefnotitie bij achterlaten.', 3),
    ('bieren', 'Hoe bewaar ik een bier of brouwerij als favoriet?', 'Tik op het hartje bij een bier, brouwerij of post. Je favorieten vind je terug in het tabblad Favorieten.', 4),

    ('badges', 'Hoe verdien ik badges?', 'Je verdient badges door de app te gebruiken: een streak opbouwen, bieren van verschillende stijlen scannen en proeven, vrienden proosten, iets delen of een eigen post plaatsen. In je Bier-Paspoort staat per badge wat daarvoor nodig is.', 1),
    ('badges', 'Waar zie ik mijn badges en voortgang?', 'Op Profiel onder "Mijn Bier-Paspoort". Tik op "Bekijk alles" voor alle badges, ingedeeld per categorie, met een voortgangsbalk waar dat meetbaar is.', 2),
    ('badges', 'Waarom staat een badge nog op vergrendeld?', 'Dan heb je de vereiste actie nog niet gedaan, of de voortgang is nog niet hoog genoeg. Sommige badges, zoals "La Crème de la Crème", krijg je pas nadat je al meerdere andere badges hebt verdiend.', 3),

    ('vrienden', 'Hoe voeg ik een vriend toe?', 'Ga naar Profiel en kies "Vrienden toevoegen". Zoek op naam en stuur een vriendschapsverzoek. Zodra de ander accepteert, zijn jullie bier-vrienden.', 1),
    ('vrienden', 'Hoe stuur ik een Proost?', 'Je kunt een Proost sturen naar bevestigde vrienden, via je vriendenlijst op Profiel of via "Bierliefhebbers in de buurt" op de kaart. De ander ziet je Proost meteen als pop-up en kan terugproosten.', 2),
    ('vrienden', 'Kan ik met vrienden chatten?', 'Ja, vanuit je vriendenlijst op Profiel kun je een chat met een bier-vriend openen.', 3),

    ('bronnen', 'Hoe meld ik een brouwerij aan?', 'Open het tabblad Kaart, kies "Brouwerijen" en tik op "Brouwerij toevoegen". Na goedkeuring door een beheerder verschijnt de brouwerij op de kaart.', 1),
    ('bronnen', 'Hoe meld ik een café of proeflokaal aan?', 'Open het tabblad Kaart, kies "Horeca" en tik op "Horeca toevoegen". Na goedkeuring door een beheerder verschijnt de locatie op de kaart.', 2),
    ('bronnen', 'Hoe voeg ik een evenement toe?', 'Ga naar het tabblad Agenda en maak een evenement aan met de plusknop. Je evenement staat onder "Mijn evenementen" totdat een beheerder het goedkeurt, daarna verschijnt het in de agenda.', 3),
    ('bronnen', 'Mijn evenement is afgewezen, waarom?', 'Je krijgt een bericht (Profiel > Berichten) en onder "Mijn evenementen" zie je de reden, als de beheerder die heeft ingevuld. Je kunt het evenement verwijderen en met aangepaste gegevens opnieuw aanmelden.', 4)
) as v(category, question, answer, sort_order)
where not exists (select 1 from public.faq_items);

NOTIFY pgrst, 'reload schema';
