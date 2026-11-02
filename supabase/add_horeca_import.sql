-- BierKompas: horecalijst van de klant importeren (admin -> Data-imports).
-- Voegt een website toe (de app toont daarmee een klikbare link en het logo)
-- en een bron-sleutel, zodat de import veilig opnieuw kan worden gedraaid
-- zonder dubbele zaken.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_horeca_submissions.sql (eerder uitgevoerd).

alter table public.horeca_submissions add column if not exists website text;
alter table public.horeca_submissions add column if not exists bron text;
alter table public.horeca_submissions add column if not exists bron_id text;
alter table public.horeca_submissions add column if not exists province text;

create unique index if not exists horeca_submissions_bron_unique
    on public.horeca_submissions (bron, bron_id);

NOTIFY pgrst, 'reload schema';
