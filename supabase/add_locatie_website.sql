-- BierKompas: website bij brouwerijen die via het beheerpaneel of "Brouwerij
-- toevoegen" zijn aangemeld (horeca heeft deze kolom al sinds
-- add_horeca_import.sql). De app toont de website als klikbare link en haalt
-- er het logo mee op.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run.

alter table public.brewery_submissions add column if not exists website text;
alter table public.horeca_submissions add column if not exists website text;

NOTIFY pgrst, 'reload schema';
