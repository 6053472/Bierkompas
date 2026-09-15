-- Verwijdert alle evenementen (test-/oude data) uit de database.
-- Voer dit uit in de Supabase SQL Editor.
--
-- Let op: gedeelde evenement-uitnodigingen in de chat (message_type =
-- 'event_invite') blijven wel bestaan, maar verwijzen dan naar een
-- evenement dat niet meer bestaat. Dat is geen probleem voor de app
-- (metadata staat los in de berichten-tabel), maar als je ook die
-- berichten wilt opruimen kun je het onderste, optionele blok gebruiken.

delete from public.events;

-- Optioneel: verwijder ook chatberichten die een (nu verwijderd) evenement deelden.
-- delete from public.messages where message_type = 'event_invite';
