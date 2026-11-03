import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/auth_service.dart';

const _bg = Color(0xFF1E1712);
const _card = Color(0xFF2C221C);
const _gold = Color(0xFFD4B28C);
const _cream = Color(0xFFEFE6DD);
const _muted = Color(0xFF9E8A7D);

/// Contactadres voor vragen over de voorwaarden en privacyverzoeken.
const legalContactEmail = 'joubierkompas@outlook.com';

enum LegalDocument { terms, privacy }

class _Section {
  final String title;
  final List<String> paragraphs;

  const _Section(this.title, this.paragraphs);
}

/// Algemene Voorwaarden (met communityrichtlijnen) of Privacybeleid. De
/// teksten beschrijven wat de app nu echt doet; bij een inhoudelijke wijziging
/// hoort ook een nieuwe [termsVersion] of [privacyVersion], zodat gebruikers
/// opnieuw akkoord geven.
class LegalPage extends StatelessWidget {
  final LegalDocument document;

  const LegalPage({super.key, required this.document});

  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalPage(document: document)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTerms = document == LegalDocument.terms;
    final title = isTerms ? 'Algemene Voorwaarden' : 'Privacybeleid';
    final version = isTerms ? 'Versie $termsVersion' : 'Versie $privacyVersion';
    final sections = isTerms ? _termsSections : _privacySections;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        iconTheme: const IconThemeData(color: _cream),
        title: Text(title, style: GoogleFonts.playfairDisplay(color: _cream, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(version, style: GoogleFonts.inter(color: _muted, fontSize: 12)),
            const SizedBox(height: 16),
            for (final section in sections) ...[
              Text(section.title, style: GoogleFonts.playfairDisplay(color: _gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(paragraph, style: GoogleFonts.inter(color: _cream, fontSize: 14, height: 1.5)),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

const _termsSections = [
  _Section('1. Over Bierkompas', [
    'Bierkompas is een app voor bierliefhebbers. Je ontdekt bieren, brouwerijen, horeca en evenementen, houdt bij welke bieren je hebt geproefd en deelt je ervaringen met andere bierliefhebbers.',
    'Door een account aan te maken en akkoord te geven ga je akkoord met deze voorwaarden en met het Privacybeleid.',
  ]),
  _Section('2. Leeftijd en verantwoord drinken', [
    'Bierkompas is alleen bedoeld voor personen van 18 jaar of ouder. Bij het aanmaken van je account bevestig je dat je 18 jaar of ouder bent.',
    'Bierkompas moedigt overmatig alcoholgebruik niet aan. Drink met mate, en nooit als je nog moet rijden. Badges en streaks zijn een spel; je hoeft er niet voor te drinken.',
  ]),
  _Section('3. Je account', [
    'Je account is persoonlijk. Vul juiste gegevens in, gebruik geen valse identiteit of het account van iemand anders, en houd je inloggegevens geheim.',
    'Je kunt je account op elk moment zelf verwijderen via Profiel > Instellingen > Account verwijderen. Dat is definitief.',
    'Bij misbruik of overtreding van deze voorwaarden kunnen wij content verwijderen of een account (tijdelijk) blokkeren.',
  ]),
  _Section('4. Wat je zelf toevoegt', [
    'Je kunt zelf posts, reacties, proefnotities, foto\'s, chatberichten, evenementen, brouwerijen, horeca en onbekende bieren toevoegen. Je blijft eigenaar van wat je toevoegt, maar geeft Bierkompas toestemming om dit in de app te tonen aan andere gebruikers, voor zover het daarvoor bedoeld is.',
    'Posts, evenementen, brouwerijen, horeca en aangemelde bieren worden eerst door een beheerder beoordeeld. Een beheerder kan een inzending afwijzen of later verwijderen, bijvoorbeeld als die onjuist is, dubbel is of in strijd is met deze voorwaarden.',
    'Voeg alleen content toe waar je zelf de rechten op hebt. Plaats geen foto\'s van andere mensen zonder hun toestemming.',
  ]),
  _Section('5. Communityrichtlijnen', [
    'Wees respectvol tegen andere bierliefhebbers. Niet toegestaan zijn onder meer: beledigen, intimideren of discrimineren; spam en reclame; misleidende of valse informatie; content die aanzet tot overmatig alcoholgebruik of drinken onder de 18; en illegale content.',
    'Je kunt alleen chatten met en een Proost sturen naar bevestigde vrienden. Wil je iemand niet meer als vriend, dan kun je die in de chat via het menu verwijderen.',
  ]),
  _Section('6. Informatie in de app', [
    'Gegevens over bieren, brouwerijen, horeca, evenementen en nieuws komen deels van externe bronnen en van gebruikers. Wij doen ons best om dit juist te houden, maar kunnen niet garanderen dat alles klopt of actueel is (bijvoorbeeld openingstijden, adressen of websites). Controleer belangrijke informatie bij de organisator of zaak zelf.',
    'Links naar websites, routeplanners, video\'s en sociale media openen diensten van derden. Daarop zijn hun eigen voorwaarden van toepassing.',
  ]),
  _Section('7. Beschikbaarheid en aansprakelijkheid', [
    'Wij streven naar een goed werkende app, maar kunnen niet garanderen dat Bierkompas altijd zonder storingen beschikbaar is. Functies kunnen worden aangepast of verwijderd.',
    'Bierkompas is niet aansprakelijk voor schade die ontstaat door het gebruik van de app of door content van andere gebruikers, behalve voor zover de wet dat verplicht.',
  ]),
  _Section('8. Wijzigingen en contact', [
    'Deze voorwaarden kunnen worden aangepast. Bij een belangrijke wijziging vragen wij je in de app opnieuw akkoord te geven.',
    'Op deze voorwaarden is Nederlands recht van toepassing.',
    'Vragen of een melding over content? Neem contact op via $legalContactEmail of via Support & FAQ in de app.',
  ]),
];

const _privacySections = [
  _Section('1. Wie zijn wij', [
    'Bierkompas is verantwoordelijk voor de verwerking van je persoonsgegevens in deze app. Voor vragen of verzoeken over je gegevens kun je mailen naar $legalContactEmail.',
    'Wij gaan zorgvuldig om met je gegevens en houden ons aan de Algemene Verordening Gegevensbescherming (AVG).',
  ]),
  _Section('2. Welke gegevens wij verwerken', [
    'Account: je naam, e-mailadres en wachtwoord (versleuteld opgeslagen). Log je in met Google of Outlook (Microsoft), dan ontvangen wij van Google of Microsoft je naam en e-mailadres, en bij Google ook je profielfoto.',
    'Profiel: je profielfoto en, als je die invult, je woonplaats en telefoonnummer.',
    'Akkoord: wanneer je akkoord gaf op de voorwaarden en het privacybeleid, en welke versie.',
    'Gebruik van de app: gescande en gelogde bieren (met eventuele foto), proefnotities, favorieten, badges, je Bier Streak en wanneer je voor het laatst actief was.',
    'Sociaal: vriendschapsverzoeken en vrienden, verstuurde Proosts, chatberichten en chatfoto\'s, posts en reacties in de Ontdek-feed, en aanmeldingen voor evenementen.',
    'Inzendingen: evenementen, brouwerijen, horeca en bieren die je aanmeldt, inclusief het adres en de foto die je daarbij opgeeft.',
    'Locatie: alleen als je de app toestemming geeft. Je locatie wordt gebruikt om afstanden op de kaart te tonen en wordt daarvoor niet opgeslagen. Zet je "Deel mijn locatie met vrienden" aan, dan wordt je laatste locatie wel opgeslagen en alleen getoond aan je bevestigde vrienden.',
  ]),
  _Section('3. Waarvoor wij je gegevens gebruiken', [
    'Om je account te maken en je te laten inloggen.',
    'Om de functies van de app te leveren: je Bier-Paspoort, badges en streaks, favorieten, de kaart, de agenda, de Ontdek-feed, vrienden, chat en Proosts.',
    'Om inzendingen door een beheerder te laten beoordelen en je daarover een bericht te sturen in de app.',
    'Om je berichten te sturen in het berichtencentrum van de app, bijvoorbeeld over je evenement of berichten van de beheerder (eventueel gericht op je woonplaats of favorieten).',
    'Om misbruik tegen te gaan en de app te beveiligen.',
    'Wij verkopen je gegevens niet en gebruiken ze niet voor advertenties van derden.',
  ]),
  _Section('4. Wie je gegevens kan zien', [
    'Andere gebruikers zien alleen je naam en profielfoto, bijvoorbeeld bij zoeken naar vrienden, je posts en reacties, en via je QR-code. Je e-mailadres is niet zichtbaar voor andere gebruikers.',
    'Alleen bevestigde vrienden kunnen met je chatten, je een Proost sturen, je online-status zien en, als je dat zelf aanzet, je locatie en telefoonnummer.',
    'Organisatoren van een evenement zien de naam en foto van wie zich voor dat evenement aanmeldt.',
    'Beheerders van Bierkompas kunnen inzendingen en de bijbehorende gegevens inzien om ze te beoordelen.',
  ]),
  _Section('5. Diensten van derden', [
    'Supabase: hier worden je account en de gegevens van de app opgeslagen (database, inloggen en bestanden).',
    'Microsoft: als je kiest voor inloggen met Outlook.',
    'Google: als je kiest voor inloggen met Google. Ook worden de logo\'s van brouwerijen en horeca via Google opgehaald op basis van hun website; daarbij worden geen gegevens over jou meegestuurd.',
    'OpenStreetMap en PDOK (Kadaster): voor de kaart en om een ingevuld adres of postcode om te zetten naar straat, plaats, provincie en coördinaten. Daarvoor wordt alleen het ingevulde adres verstuurd.',
    'YouTube, TikTok en Instagram: video\'s in de app worden afgespeeld met de spelers van deze platforms. Zij kunnen daarbij hun eigen cookies en gegevens gebruiken volgens hun eigen privacybeleid.',
    'Open je een link naar een website, routeplanner, WhatsApp of sociale media, dan verlaat je Bierkompas en geldt het privacybeleid van die dienst.',
  ]),
  _Section('6. Hoe lang wij je gegevens bewaren', [
    'Wij bewaren je gegevens zolang je een account hebt. Verwijder je je account via Profiel > Instellingen, dan worden je account en de daaraan gekoppelde gegevens direct verwijderd: je profiel, favorieten, gelogde bieren, proefnotities, posts en reacties, chatberichten, vrienden, locatie, telefoonnummer en de evenementen en inzendingen die je hebt aangemeld.',
  ]),
  _Section('7. Beveiliging', [
    'Je gegevens worden versleuteld verstuurd. In de database is per gegeven vastgelegd wie het mag zien of wijzigen, zodat andere gebruikers niet bij jouw gegevens kunnen.',
  ]),
  _Section('8. Je rechten', [
    'Je hebt het recht om je gegevens in te zien, te laten corrigeren of te laten verwijderen, om bezwaar te maken tegen de verwerking en om je gegevens over te laten dragen. Veel gegevens kun je zelf aanpassen in je profiel, en je kunt je account zelf verwijderen.',
    'Je kunt toestemming voor locatie, camera en foto\'s altijd intrekken in de instellingen van je telefoon, en het delen van je locatie of telefoonnummer uitzetten in de app.',
    'Voor een verzoek mail je naar $legalContactEmail. Wij reageren binnen een maand. Ben je het niet eens met hoe wij met je gegevens omgaan, dan kun je een klacht indienen bij de Autoriteit Persoonsgegevens.',
  ]),
  _Section('9. Wijzigingen', [
    'Dit privacybeleid kan worden aangepast. Bij een belangrijke wijziging vragen wij je in de app opnieuw akkoord te geven.',
  ]),
];
