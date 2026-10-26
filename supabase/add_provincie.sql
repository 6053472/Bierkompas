-- BierKompas: provincie bij het adres van evenementen, brouwerij- en
-- horeca-aanmeldingen. Wordt in de app automatisch ingevuld op basis van de
-- postcode (NL via PDOK, BE via de postcodereeks) en is handmatig aan te
-- passen. Optioneel veld: bestaande rijen blijven leeg.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run.

alter table public.events add column if not exists province text;
alter table public.brewery_submissions add column if not exists province text;
alter table public.horeca_submissions add column if not exists province text;

NOTIFY pgrst, 'reload schema';
