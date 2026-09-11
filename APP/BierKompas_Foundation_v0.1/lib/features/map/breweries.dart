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

  const Brewery({
    required this.id,
    required this.title,
    required this.distance,
    required this.rating,
    required this.tags,
  });
}

const breweries = [
  Brewery(
    id: 1,
    title: 'Brouwerij Hoop',
    distance: '0.8 km bij jou vandaan',
    rating: '4.8',
    tags: ['IPA', 'PROEFLOKAAL'],
  ),
  Brewery(
    id: 2,
    title: 'Saint Sixtus',
    distance: '1.2 km bij jou vandaan',
    rating: '4.9',
    tags: ['TRAPPIST', 'BEPERKT'],
  ),
  Brewery(
    id: 3,
    title: 'De Molen',
    distance: '3.5 km bij jou vandaan',
    rating: '4.7',
    tags: ['STOUTS', 'BARREL'],
  ),
];
