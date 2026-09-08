# BierKompas backend

Simpele PHP + MySQL backend voor registratie/login. Werkt op elke gedeelde hosting met PHP en phpMyAdmin.

## Setup zodra je hosting hebt

1. Maak in phpMyAdmin een database aan.
2. Open het tabblad "SQL" van die database en voer `database.sql` uit (maakt de tabellen `users` en `favorites`).
3. Upload de inhoud van deze map (`backend/`) naar je hosting, bv. naar `public_html/api/`.
4. Kopieer `config.example.php` naar `config.php` op de server en vul in:
   - `DB_HOST` (meestal `localhost`)
   - `DB_NAME`, `DB_USER`, `DB_PASS` (krijg je van je hostingpakket/phpMyAdmin)
5. Test in de browser: `https://jouwdomein.nl/api/login.php` moet een JSON-foutmelding geven ("Alleen POST toegestaan") — dat betekent dat het script werkt.

## Endpoints

- `POST register.php` — body: `{"name": "...", "email": "...", "password": "..."}`
- `POST login.php` — body: `{"email": "...", "password": "..."}`
- `POST consent.php` — registreert de hoofdgoedkeuring, leeftijdsbevestiging en accountveiligheidsbevestigingen
- `GET favorites_list.php?user_id=1`
- `POST favorites_add.php` — body: `{"user_id": 1, "item_type": "beer", "item_id": 5}`
- `POST favorites_remove.php` — body: `{"user_id": 1, "item_type": "beer", "item_id": 5}`

Alle endpoints geven JSON terug: `{"success": true, ...}` of `{"success": false, "error": "..."}`.
De favorites-endpoints zijn er alvast klaar voor, maar nog niet gekoppeld aan een scherm in de app — dat gebeurt zodra de bar/bier-data er is.

## In de Flutter-app

Zet in `lib/core/config/api_config.dart` de `baseUrl` op je domein, bv. `https://jouwdomein.nl/api`.
Zolang die leeg is, gebruikt de app een lokaal testaccount (zie `auth_service.dart`) zodat je de app al kunt testen zonder hosting.

Zodra je de echte `baseUrl` invult:
- Inloggen/registreren praat automatisch met `login.php`/`register.php`.
- Na inloggen/registreren wordt het account lokaal onthouden (`auth_storage.dart`), dus de gebruiker hoeft niet elke keer opnieuw in te loggen.
- De profielpagina toont automatisch de echte naam/e-mail en heeft een uitlogknop.
