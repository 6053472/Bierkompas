-- BierKompas: verwijdert alle testgegevens, laat de tabellen/structuur staan.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Let op: dit verwijdert ECHT ALLE gebruikers en hun data, ook eventuele echte
-- accounts. Gebruik dit alleen tijdens het testen, niet in productie.

delete from public.favorites;
delete from public.user_consents;
delete from public.profiles;

-- Verwijdert ook de auth-gebruikers zelf (login/wachtwoord), zodat je met
-- dezelfde testmailadressen opnieuw kan registreren.
delete from auth.users;
