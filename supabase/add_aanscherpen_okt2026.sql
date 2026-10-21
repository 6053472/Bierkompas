-- BierKompas: aanscherpingen oktober 2026. Uitvoeren via het
-- Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_admin_content_management.sql (eerder uitgevoerd).

-- 1. Boeken: bijschrift en externe link ("Bekijk / Kopen").
alter table public.library_books add column if not exists caption text;
alter table public.library_books add column if not exists external_url text;

-- 2. Evenementen: realtime aanzetten, zodat "In afwachting" bij de indiener
-- direct verdwijnt zodra een beheerder het evenement goedkeurt of afwijst.
-- (RLS blijft gelden: een gebruiker krijgt alleen wijzigingen die hij mag zien.)
do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'events'
    ) then
        alter publication supabase_realtime add table public.events;
    end if;
end
$$;

NOTIFY pgrst, 'reload schema';
