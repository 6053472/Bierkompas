import '../favorites/beers.dart';
import 'feed_service.dart';

const _tripelImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuANIbUEodWyxyWEqbHFoWd_APYDtoiXgTOVbAJ5TIOp9PKG4baeF5XYwf34634GW-PHvDpk4FhxpB1XlsZEFAl3BsWVxT8Gq-KlOZ01ggozbCfeF3fRoufrH8N5tDetdyMY9uKUxDAadw9wON36RlMvSHNjV30Ol5XjZ06tnPRARXfPUGTEFIa5xw_1m7rvTyggDsC2HvYxMuo3GNidOYo-3ypVQq14WiAoZWsApQQMn_T-2VSeoFN7';
const _witbierImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDQhKscA00YiHmLOCdFOnKCDnUdAW9kZbBWb69ou6CZYBeHe2q_KbKtwlHDL0lQkAPAzsuvqmU8pVUmGHnRg0EWpY5Ik6FPaApETd4GFJ8GNjNmCAwJ6UFY300bVAFedalKlJ4kScOIAVCDoLzrV9zFMfi2_qs893DP-Tb2j9J-xeHYZerm49wZU1lpqFBiWmJnNAe65PEpi4vsS5PdJhcm0R7KwgjTuk-DTrYbqCMr6frfIMKx7qQK';
const _breweryImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDknuVmwDTa5jB4wik1JsFZcg3HGHEguJ8tKYPIGvMOxeMgWo55nIZ92P0i_iTaZK5gCmhHDfSDDGd8HAgulU_Nt_waa4YIg1QNZCDQnGG9J70xbRh0XNaZFjxojqCPad3s7iiMSHzET5kRpj3GQcD9-hE4MuWtaKdUaP4Wkk6S1kxJhurPAITpPBmmuOIAnJ0_rU6wNjOB6JuYsppLKZZ370oFdfVTbvOpttwPVmC3aU02O1rJkSR2';
const _paleAleImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDzhnMA6a-cCYnZ4dSjHCbGFUCvVBqXUZ9Mjk381yzhl0FoUiVgLmBWOKSPR3dEAVnnWVP1ViPRMKTviMaubvedPJI8ZXYMKr2bHJp9kjDRoEAO6A3vh371Km-kVjS9517tTWX1sD4_SpqLSWD2-RUMkSVP5qWL233CRvFNvB207EKaTmWkQClVLTqYIyOY1ub3PvqQO7wKkKnn-D4nvwFWeRXl3ZPDG8Oz-xe3t4BW9-cK5h3r3pSO';

/// Voorbeeldcontent voor de Bierfeed, gebruikt zolang de Supabase-view `feed` nog niet
/// bestaat. supabase/add_feed.sql voegt dezelfde items in dezelfde volgorde toe, dus
/// `item-1` hier is ook id 1 in de tabel en favorieten blijven daarna kloppen.
final List<FeedItem> sampleFeedItems = _buildSamples();

List<FeedItem> _buildSamples() {
  const rows = <(FeedItemType, String, String, String?, String?, double?)>[
    (FeedItemType.review, 'Koperen Nacht Tripel', 'Goudkoper van kleur met een romige schuimkraag. Kruidig, tonen van karamel en een warme afdronk. Gevaarlijk doordrinkbaar.', _tripelImage, 'Sanne', 4.5),
    (FeedItemType.tip, 'Spoel je glas eerst koud om', 'Een koud gespoeld glas zorgt voor een mooiere schuimkraag en voorkomt dat je bier te snel opwarmt.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Waarom heet het trappist?', 'Een bier mag het logo "Authentic Trappist Product" alleen dragen als het onder toezicht van monniken binnen een trappistenabdij wordt gebrouwen.', null, null, null),
    (FeedItemType.review, 'Amber Kompas IPA', 'Fris bitter met grapefruit en dennen, maar de moutbasis houdt alles mooi in balans. Een perfect terrasbier.', null, 'Joris', 4.0),
    (FeedItemType.tip, 'Schenk schuin, eindig recht', 'Houd het glas schuin tijdens het inschenken en zet het halverwege rechtop. Zo krijg je een kraag van ongeveer twee vingers.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Bock komt uit Einbeck', 'De naam bockbier is waarschijnlijk een verbastering van Einbeck, een Duitse stad die in de middeleeuwen bekend was om zijn sterke bier.', null, null, null),
    (FeedItemType.review, 'Donkere Molen Stout', 'Koffie, pure chocolade en een fluweelzachte mondvulling. Laat hem iets opwarmen, dan komt de vanille los.', null, 'Fatima', 4.5),
    (FeedItemType.tip, 'Niet elk bier hoort ijskoud', 'Pils smaakt het best rond 3 tot 5 graden, maar dubbels, tripels en stouts komen pas echt tot hun recht rond 8 tot 12 graden.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Hop is familie van hennep', 'Hop en hennep horen allebei bij de plantenfamilie Cannabaceae. Hop geeft bier bitterheid, aroma en een langere houdbaarheid.', null, null, null),
    (FeedItemType.review, 'Zomerhaven Witbier', 'Troebel, met citrus en koriander. Iets te zoet naar mijn smaak, maar heerlijk als het buiten 25 graden is.', _witbierImage, 'Daan', 3.5),
    (FeedItemType.tip, 'Bewaar flessen rechtop', 'Rechtop, koel en donker bewaard blijft bier langer goed. Licht kan zorgen voor een onaangename, muffe smaak.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Spontane vergisting', 'Lambiek wordt spontaan vergist met wilde gisten en bacteriën uit de lucht, traditioneel in de regio rond Brussel.', _breweryImage, null, null),
    (FeedItemType.review, 'Oude Sluis Dubbel', 'Rozijnen, bruine suiker en een vleugje drop. Een klassieke dubbel zonder poespas.', null, 'Emma', 4.0),
    (FeedItemType.tip, 'Stout bij chocolade', 'De geroosterde tonen van een stout versterken een chocoladedessert. Probeer het eens met een brownie.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Gueuze is een blend', 'Gueuze ontstaat door jonge en oude lambiek te mengen en op fles na te laten gisten. Daardoor krijgt het zijn bruisende, zure karakter.', null, null, null),
    (FeedItemType.review, 'Veldkers Saison', 'Droog, peperig en licht fruitig. Elke slok maakt dorst naar de volgende.', null, 'Luuk', 4.5),
    (FeedItemType.tip, 'Witbier bij vis en mosselen', "De citrus- en korianderaroma's van witbier passen perfect bij vis, mosselen en frisse salades.", null, 'BierKompas', null),
    (FeedItemType.weetje, 'Het Reinheitsgebot', 'In 1516 bepaalde Beieren dat bier alleen van water, gerst en hop gemaakt mocht worden. Gist werd pas later ontdekt en toegevoegd.', null, null, null),
    (FeedItemType.review, 'Koperen Nacht Blond', 'Honingzoet begin en een licht bittere finish. Toegankelijk, maar het mist wat karakter.', null, 'Noor', 3.0),
    (FeedItemType.tip, 'Proef van licht naar zwaar', 'Begin een proeverij met lichte, frisse bieren en werk toe naar zware en zure bieren, zodat je smaakpapillen niet overweldigd raken.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Donker is niet sterker', 'De kleur van bier komt van de mout, niet van het alcoholpercentage. Een donkere stout kan lichter zijn dan een blonde tripel.', null, null, null),
    (FeedItemType.review, 'Winterlicht Bock', 'Karamel en geroosterd brood: precies wat je wilt als het buiten stormt.', null, 'Milan', 4.0),
    (FeedItemType.tip, 'Ruik voordat je proeft', 'Een groot deel van wat je proeft is eigenlijk geur. Houd het glas even onder je neus voor de eerste slok.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Kölsch is een beschermde naam', 'Volgens de Kölsch-Konvention mag alleen bier dat in en rond Keulen wordt gebrouwen zich Kölsch noemen.', null, null, null),
    (FeedItemType.review, 'Havenmeester Pale Ale', 'Mooi helder, bloemige hop en een droge afdronk. Een echte allrounder.', _paleAleImage, 'Lotte', 4.0),
    (FeedItemType.tip, 'Kies het juiste glas', 'Een tulpglas houdt het aroma van speciaalbier vast; een smal pilsglas houdt het koolzuur langer vast.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'Witbier kwam terug dankzij een melkboer', 'Nadat witbier in België was verdwenen, bracht melkboer Pierre Celis de stijl in 1966 terug in Hoegaarden.', null, null, null),
    (FeedItemType.review, 'Kelderzuur Kriek', 'Zuur, kersen en een tikje amandel. Niet voor iedereen, wel voor mij.', null, 'Yara', 5.0),
    (FeedItemType.tip, 'Laat de gist in de fles', 'Bij bieren met nagisting op fles zit gistbezinksel onderin. Schenk rustig en laat het laatste bodempje staan.', null, 'BierKompas', null),
    (FeedItemType.weetje, 'De kraag doet ertoe', "De schuimkraag houdt aroma's vast, zodat je neus meeproeft. Zonder kraag verliest bier sneller zijn geur.", null, null, null),
  ];

  // Posts over een brouwerij uit breweries.dart: (titel, tekst, brouwerij-id, uren geleden).
  const breweryPosts = <(String, String, int, double)>[
    ('Op bezoek bij De Molen', 'In Bodegraven begon Brouwerij De Molen in de historische korenmolen De Arkduif. Inmiddels is het een van de bekendste craftbrouwerijen van Nederland.', 3, 2.5),
    ('Trappisten van Sint-Sixtus', 'In de Sint-Sixtusabdij in Westvleteren brouwen monniken sinds 1838 bier. Het is vrijwel alleen bij de abdij zelf te koop.', 2, 8.5),
    ('Proeflokaal Brouwerij Hoop', 'Zin in een vers getapte IPA? Bij Brouwerij Hoop proef je de bieren direct in het eigen proeflokaal.', 1, 14.5),
    ('Grutte Pier: bier & spijs', 'Het proeflokaal van Grutte Pier combineert Friese bieren met eten. Probeer het Dubbel stoofvlees.', 4, 20.5),
  ];

  // Reviews gaan over een bier uit beers.dart met dezelfde naam.
  final beerIdByName = {for (final beer in beers) beer.name: beer.id};
  final now = DateTime.now();
  final items = [
    for (var i = 0; i < rows.length; i++)
      FeedItem(
        key: 'item-${i + 1}',
        type: rows[i].$1,
        title: rows[i].$2,
        body: rows[i].$3,
        imageUrl: rows[i].$4,
        author: rows[i].$5,
        rating: rows[i].$6,
        beerId: rows[i].$1 == FeedItemType.review ? beerIdByName[rows[i].$2] : null,
        createdAt: now.subtract(Duration(hours: i + 1)),
      ),
    for (var i = 0; i < breweryPosts.length; i++)
      FeedItem(
        key: 'item-${rows.length + i + 1}',
        type: FeedItemType.brouwerij,
        title: breweryPosts[i].$1,
        body: breweryPosts[i].$2,
        author: 'BierKompas',
        breweryId: breweryPosts[i].$3,
        createdAt: now.subtract(Duration(minutes: (breweryPosts[i].$4 * 60).round())),
      ),
  ];
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
}
