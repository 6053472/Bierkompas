-- ============================================================
-- fix_bier_spijs_websites.sql
-- ============================================================
-- BierKompas: kapotte "Website brouwerij"-links in Bier & Spijs
-- (tabel beer_pairings, kolom link_website) herstellen.
--
-- Gecontroleerd op 2026-11-20: van de 37 verschillende links bestonden 14
-- domeinen niet (de knop opende een foutpagina) en hadden er 5 een
-- certificaat- of verbindingsfout. Hieronder alleen vervangingen waarvan de
-- nieuwe site live is gecontroleerd en echt van die brouwerij is.
-- Elke update geldt alleen voor de exacte oude link bij die brouwerij, dus
-- andere rijen veranderen niet. Veilig om opnieuw te draaien.
--
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run.

update public.beer_pairings set link_website = 'https://www.brouwerijdehemel.nl'
 where brouwerij = 'Brouwerij De Hemel' and link_website = 'https://www.brouwerijdeemmer.nl';      -- bestond niet (andere brouwerij)

update public.beer_pairings set link_website = 'https://www.brouwerijdemolen.nl'
 where brouwerij = 'Brouwerij De Molen' and link_website = 'https://www.geitenbrei.nl';            -- bestond niet (andere brouwerij)

update public.beer_pairings set link_website = 'https://www.gulpener.nl'
 where brouwerij = 'Gulpener Bierbrouwerij' and link_website = 'https://www.brouwerijgulpener.nl'; -- bestond niet

update public.beer_pairings set link_website = 'https://www.latrappetrappist.com'
 where brouwerij = 'La Trappe Trappist' and link_website = 'https://www.brouwerijdekoningshoeven.nl'; -- bestond niet

update public.beer_pairings set link_website = 'https://www.brouwerijhetij.nl'
 where brouwerij = 'Brouwerij ''t IJ' and link_website = 'https://www.brouwerijij.nl';             -- bestond niet

update public.beer_pairings set link_website = 'https://www.brouwerijhetij.nl'
 where brouwerij = 'Brouwerij ''t IJ x Duvel' and link_website = 'https://www.brouwerijduvelmoortgat.nl'; -- bestond niet

update public.beer_pairings set link_website = 'https://www.sintbernardus.be'
 where brouwerij = 'St. Bernardus (NL distribution)' and link_website = 'https://www.brouwerijstbernardus.be'; -- bestond niet

update public.beer_pairings set link_website = 'https://www.dedrieringen.nl'
 where brouwerij = 'Stadsbrouwerij De Drie Ringen' and link_website = 'https://www.drie-ringen.nl'; -- bestond niet

update public.beer_pairings set link_website = 'https://www.leeuwbier.nl'
 where brouwerij = 'Brouwerij Leeuw' and link_website = 'https://www.brouwerijdeleeuw.nl';          -- bestond niet

update public.beer_pairings set link_website = 'https://www.oproerbrouwerij.nl'
 where brouwerij = 'Oproer Brouwerij' and link_website = 'https://www.Oproer.nl';                  -- verlopen certificaat

update public.beer_pairings set link_website = 'https://www.lindeboom.nl'
 where brouwerij = 'Lindeboom Brouwerij' and link_website = 'https://www.brouwerijlindeboom.nl';   -- ongeldig certificaat

update public.beer_pairings set link_website = 'https://www.hetanker.be'
 where brouwerij = 'Het Anker (NL Horeca)' and link_website = 'https://www.brouwerijhetanker.be';  -- geen verbinding

-- Niet automatisch te herstellen (juiste site niet met zekerheid te vinden);
-- de link werkt nu niet. Vul de juiste site in via het beheerpaneel
-- (Bier & Spijs -> Bewerken), of haal de link weg door hieronder de
-- streepjes voor "update" te verwijderen; dan verdwijnt de knop.
--   Brouwerij Eem                    https://www.brouwerijceven.nl          (bestaat niet)
--   De Halve Maan (NL distribution)  https://www.brouwerijdehalvemaan.nl    (bestaat niet; mogelijk halvemaan.be)
--   Sint Christoffel                 https://www.brouwerijstchristoffel.nl  (bestaat niet)
--   Oirschots Bier                   https://www.brouwerijvandeoirschotse.nl (bestaat niet)
--   Oirschotse Brouwerij             https://www.vandeoirschotse.nl         (bestaat niet)
-- update public.beer_pairings set link_website = null where link_website in (
--     'https://www.brouwerijceven.nl', 'https://www.brouwerijdehalvemaan.nl',
--     'https://www.brouwerijstchristoffel.nl', 'https://www.brouwerijvandeoirschotse.nl',
--     'https://www.vandeoirschotse.nl');

-- Controle: deze query hoort na het uitvoeren alleen nog de vijf links
-- hierboven te tonen (en Kompaan/Naeckte Brouwers, die wel bestaan maar
-- geautomatiseerde controles weren).
select brouwerij, link_website, count(*) from public.beer_pairings
 group by brouwerij, link_website order by brouwerij;
