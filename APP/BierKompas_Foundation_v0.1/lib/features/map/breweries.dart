/// Waarde van `item_type` in de Supabase-tabel `favorites`.
const breweryItemType = 'brewery';

class Brewery {
  final int id;
  final String title;
  final String distance;
  final String rating;
  final List<String> tags;
  final String location;
  final String? founded;
  final String about;
  final List<String> facts;
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

/// Partner op de Ontdek-pagina.
const grutePierProeflokaal = Brewery(
  id: 4,
  title: 'Grutte Pier Proeflokaal',
  distance: '2.4 km bij jou vandaan',
  rating: '4.8',
  tags: ['BIER & SPIJS', 'PARTNER'],
  location: 'Leeuwarden',
  about:
      'Een Friese brouwerij met proeflokaal, waar bier en eten samenkomen.',
  facts: [
    'Genoemd naar Grutte Pier, een Friese volksheld uit de 16e eeuw.',
    'Bier & spijs: probeer het Dubbel stoofvlees.',
  ],
  latitude: 53.2012,
  longitude: 5.7999,
);

/// Lokale brouwerijen die altijd beschikbaar blijven
/// als de online kaart tijdelijk niet werkt.
const breweries = [
  Brewery(
    id: 1,
    title: 'Brouwerij Hoop',
    distance: '0.8 km bij jou vandaan',
    rating: '4.8',
    tags: ['IPA', 'PROEFLOKAAL'],
    location: 'Zaandijk',
    about:
        'Een brouwerij met eigen proeflokaal, waar je de bieren vers van de tap proeft.',
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
        'De Sint-Sixtusabdij is een trappistenabdij in West-Vlaanderen.',
    facts: [
      'Het bier wordt gebrouwen door trappistenmonniken.',
      'Westvleteren 12 is wereldwijd bekend.',
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
        'Brouwerij De Molen begon in de historische korenmolen De Arkduif in Bodegraven.',
    facts: [
      'Bekend om zware stouts.',
      'Organiseert jaarlijks het bierfestival Borefts.',
    ],
    latitude: 52.0850,
    longitude: 4.7460,
  ),
  grutePierProeflokaal,
];