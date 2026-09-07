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

Beide geven JSON terug: `{"success": true, "user": {...}}` of `{"success": false, "error": "..."}`.

## In de Flutter-app

Zet in `lib/core/config/api_config.dart` de `baseUrl` op je domein, bv. `https://jouwdomein.nl/api`.
Zolang die leeg is, gebruikt de app een lokaal testaccount (zie `auth_service.dart`) zodat je de app al kunt testen zonder hosting.
