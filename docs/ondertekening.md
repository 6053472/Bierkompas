# Ondertekening Android-app (signing & keystore)

De Android-app wordt voor de Google Play Store ondertekend met een eigen
**upload-sleutel**. Google Play gebruikt daarnaast **Play App Signing**: Google
bewaart de definitieve app-sleutel en ondertekent de app opnieuw voordat
gebruikers hem downloaden. Onze upload-sleutel bewijst alleen dat een upload van
ons komt.

## Gegevens van de sleutel

| Onderdeel | Waarde |
|---|---|
| Bestand | `bierkompas-upload.jks` |
| Type | JKS, RSA 2048 bit |
| Alias | `upload` |
| Geldig | 10.000 dagen (tot 2054) |
| Eigenaar | `CN=Bierkompas, O=Bierkompas, C=NL` |
| SHA-256 | `55:5A:B9:71:70:11:89:30:C3:26:8B:D3:6F:EC:3A:F8:9B:B1:1B:7A:6A:93:42:F4:5A:75:78:64:E2:9E:A4:F6` |

## Waar staat wat

- **Keystore en wachtwoorden staan nooit in git.** `android/.gitignore` sluit
  `key.properties`, `*.jks` en `*.keystore` uit.
- Op de ontwikkelcomputer staan ze in `C:\Eldikit\Bierkompas\keystore\`
  (buiten de repository), met een reservekopie van `key.properties`.
- `APP/BierKompas_Foundation_v0.1/android/key.properties` verwijst naar de
  keystore en bevat het wachtwoord:

  ```properties
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=C:/Eldikit/Bierkompas/keystore/bierkompas-upload.jks
  ```

- Bewaar de keystore en het wachtwoord ook op een tweede, veilige plek
  (bijvoorbeeld een wachtwoordmanager). Zonder deze gegevens kan geen update
  worden geüpload. Raakt de upload-sleutel toch kwijt, dan kan de eigenaar van
  het Play Console-account bij Google een nieuwe upload-sleutel aanvragen.

## Hoe de ondertekening werkt

`android/app/build.gradle.kts` leest `android/key.properties` en ondertekent de
release-build daarmee. Ontbreekt dat bestand (bijv. op een andere computer), dan
valt de build terug op de debug-sleutel; zo'n bestand weigert Google Play.

## Een nieuwe versie bouwen

1. Verhoog het versienummer in `pubspec.yaml` (nu `version: 1.0.0+11`; het getal na
   de `+` moet bij elke upload hoger zijn).
2. Bouw het bestand:

   ```
   flutter build appbundle --release --no-tree-shake-icons
   ```

3. Het bestand staat in
   `build/app/outputs/bundle/release/app-release.aab` en kan in de Play Console
   worden geüpload.

Meldt Flutter aan het eind *"failed to strip debug symbols"*, dan is het AAB
wel gemaakt: Flutter kan de controle niet uitvoeren omdat de Android
command-line tools ontbreken (installeren via Android Studio > SDK Manager >
SDK Tools > Android SDK Command-line Tools).
