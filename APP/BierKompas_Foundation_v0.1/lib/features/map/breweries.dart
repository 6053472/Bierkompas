/// Waarde van `item_type` in de Supabase-tabel `favorites` voor brouwerijen.
const breweryItemType = 'brewery';

/// Vaste brouwerijen zolang er nog geen brouwerij-tabel in Supabase is.
/// Het [id] wordt als `item_id` opgeslagen in de tabel `favorites`.
class Brewery {
  final int id;
  final String title;
  final String distance;
  final String rating;
  final List<String> tags;

  /// Plaats van de brouwerij.
  final String location;

  /// Jaar van oprichting, of null als dat (nog) niet bekend is.
  final String? founded;

  /// Korte beschrijving van de plek.
  final String about;
  final List<String> facts;

  /// Coördinaten, gebruikt voor de kaartmarkers en de stad-zoekfunctie.
  final double latitude;
  final double longitude;

  const Brewery({
    required this.id,
    required this.title,
    required this.distance,
    required this.rating,
    required this.tags,
    required this.location,
    required this.about,
    required this.facts,
    required this.latitude,
    required this.longitude,
    this.founded,
  });
}

/// Partner op de Ontdek-pagina; te liken via het hartje daar en op de Kaart.
const grutePierProeflokaal = Brewery(
  id: 4,
  title: 'Grutte Pier Proeflokaal',
  distance: '2.4 km bij jou vandaan',
  rating: '4.8',
  tags: ['BIER & SPIJS', 'PARTNER'],
  location: 'Leeuwarden',
  about: 'Een Friese brouwerij met proeflokaal, waar bier en eten samenkomen.',
  facts: [
    'Genoemd naar Grutte Pier (Pier Gerlofs Donia), een Friese volksheld uit de 16e eeuw.',
    'Bier & spijs: probeer het Dubbel stoofvlees.',
  ],
  latitude: 53.2012,
  longitude: 5.7999,
);

const breweries = [
  Brewery(
    id: 1,
    title: 'Brouwerij Hoop',
    distance: '0.8 km bij jou vandaan',
    rating: '4.8',
    tags: ['IPA', 'PROEFLOKAAL'],
    location: 'Zaandijk',
    about: 'Een brouwerij met eigen proeflokaal, waar je de bieren vers van de tap proeft.',
    facts: [
      "Staat vooral bekend om hoppige bieren zoals IPA's.",
      'Je kunt er terecht in het eigen proeflokaal.',
    ],
    latitude: 52.4700,
    longitude: 4.8200,
  ),
  Brewery(
    id: 2,
    title: 'Saint Sixtus',
    distance: '1.2 km bij jou vandaan',
    rating: '4.9',
    tags: ['TRAPPIST', 'BEPERKT'],
    location: 'Westvleteren, België',
    founded: '1831',
    about:
        'De Sint-Sixtusabdij is een trappistenabdij in West-Vlaanderen. De monniken brouwen er sinds 1838 bier.',
    facts: [
      'Het bier wordt gebrouwen door trappistenmonniken en is vrijwel alleen bij de abdij te koop.',
      'De Westvleteren 12 geldt als een van de meest gezochte bieren ter wereld.',
      'De flesjes hebben geen etiket; welk bier het is, zie je aan de kleur van de dop.',
    ],
    latitude: 50.9020,
    longitude: 2.7150,
  ),
  Brewery(
    id: 3,
    title: 'De Molen',
    distance: '3.5 km bij jou vandaan',
    rating: '4.7',
    tags: ['STOUTS', 'BARREL'],
    location: 'Bodegraven',
    founded: '2004',
    about:
        'Brouwerij De Molen begon in de historische korenmolen De Arkduif in Bodegraven en groeide uit tot een van de bekendste Nederlandse craftbrouwerijen.',
    facts: [
      'Bekend om zware stouts en op houten vaten gerijpte bieren.',
      'Organiseert jaarlijks het bierfestival Borefts.',
    ],
    latitude: 52.0850,
    longitude: 4.7460,
  ),
  grutePierProeflokaal,
];
