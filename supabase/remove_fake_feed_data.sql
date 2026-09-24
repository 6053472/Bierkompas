-- BierKompas: verwijder de verzonnen voorbeeldcontent uit de Bierfeed die
-- add_feed.sql ooit heeft ingevoegd (nep-reviews van bestaande namen als
-- "Sanne"/"Joris", en nep-brouwerijposts die verwijzen naar brouwerijen die
-- inmiddels ook al verwijderd zijn uit de app, zie breweries.dart).
--
-- Veilig: deze verwijdering raakt uitsluitend rijen zonder user_id. Echte,
-- door gebruikers geplaatste posts hebben altijd een user_id (zie
-- add_user_posts.sql: 'Feed items: insert own post' vereist auth.uid() =
-- user_id), dus die blijven gewoon staan.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

delete from public.feed_items where user_id is null;

NOTIFY pgrst, 'reload schema';
