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

  /// Foto van de locatie, alleen aanwezig bij brouwerijen die via "Brouwerij
  /// toevoegen" zijn aangemeld en door een beheerder goedgekeurd.
  final String? imageUrl;

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
    this.imageUrl,
  });
}

// Voorheen stond hier een handgeschreven lijst van 53 "voorbeeldbrouwerijen"
// met bestaande, herkenbare bedrijfsnamen (Brouwerij Het IJ, La Trappe, Brand
// Bierbrouwerij, ...) met verzonnen beoordelingen en beschrijvingen erbij.
// Die brouwerijen hebben daar nooit toestemming voor gegeven, dus is deze
// lijst verwijderd. De kaart toont voortaan alleen: (1) live OpenStreetMap-
// data (open, vrij te gebruiken kaartdata) en (2) brouwerijen die zelf zijn
// aangemeld en door een beheerder goedgekeurd (zie brewery_submission_service.dart).
const List<Brewery> breweries = [];
