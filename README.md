# Bierkompas – broncode

Bierkompas bestaat uit drie delen:

| Map | Wat |
|---|---|
| `APP/BierKompas_Foundation_v0.1/` | De app (Flutter): Android, iOS en web |
| `admin/` | Het beheerpaneel: één HTML-pagina (`index.html`) die rechtstreeks met Supabase praat |
| `supabase/` | De database-inrichting (SQL) |

## De app starten

Vereist: Flutter (getest met Flutter 3.47, stable).

```
cd APP/BierKompas_Foundation_v0.1
flutter pub get
flutter run            # telefoon of emulator
flutter run -d chrome  # in de browser
```

`flutter pub get` maakt de mappen `.dart_tool/` en `build/` zelf aan; die zitten
daarom niet in de broncode. Zolang `flutter pub get` niet gedraaid is, kleurt de
editor vrijwel alle code rood.

Bouwen:

```
flutter build apk        # Android
flutter build ios        # iOS (op een Mac)
flutter build web        # webversie, uitvoer in build/web
```

Android/iOS-pakketnaam: `com.bierkompas.bierkompas`. Inloggen met Google en
Outlook komt terug in de app via de link `bierkompas://login-callback`.

## Supabase (database en inloggen)

De app en het beheerpaneel gebruiken het Supabase-project
`https://dxuyftojqavpnfnvwhvt.supabase.co`. Adres en publieke sleutel staan in
`APP/BierKompas_Foundation_v0.1/lib/core/config/supabase_config.dart` en
bovenin `admin/index.html`. Die publieke sleutel mag in de app staan; de
gegevens zijn afgeschermd met Row Level Security in de database.

Database (opnieuw) inrichten: Supabase-dashboard → SQL Editor → plak
`supabase/setup_alles_in_een.sql` → Run. Dit bestand kan veilig opnieuw
gedraaid worden. Daarna in het beheerpaneel → Data-imports de bierdatabase,
agenda, horeca en nieuws importeren.

`supabase/hulpscripts/` bevat scripts die gegevens **wissen** (testdata,
evenementen). Alleen gebruiken als dat echt de bedoeling is.

### Inloggen met Google en Outlook

Ingesteld in Supabase → Authentication → Sign In / Providers:

- **Google**: staat aan.
- **Azure (Outlook)**: staat aan. In de Azure Portal moet bij de
  app-registratie de Redirect URI
  `https://dxuyftojqavpnfnvwhvt.supabase.co/auth/v1/callback` staan, en
  "Supported account types" op "Accounts in any organizational directory and
  personal Microsoft accounts".
  Het client secret verloopt na een vaste tijd (zie Azure → Certificates &
  secrets). Zet dan een nieuw secret in Supabase, anders werkt de
  Outlook-login niet meer.

Onder Authentication → URL Configuration → Redirect URLs moeten
`bierkompas://login-callback` en het adres van de webapp staan.

## Beheerpaneel

Open `admin/index.html` in de browser (of zet de map `admin/` op een
webserver) en log in met hetzelfde e-mailadres en wachtwoord als in de app.
Alleen accounts met `is_admin = true` in de tabel `profiles` komen erin; een
beheerder toevoegen doe je in Supabase → Table Editor → `profiles`. Hier worden aanmeldingen goedgekeurd en locaties, evenementen,
nieuws en imports beheerd. De importbestanden staan in `admin/data/`.
