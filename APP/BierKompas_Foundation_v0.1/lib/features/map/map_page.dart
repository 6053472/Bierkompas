import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class Brewery {
  final String title;
  final double latitude;
  final double longitude;
  final String rating;
  final List<String> tags;

  const Brewery({
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.tags,
  });
}

class BreweryResult {
  final Brewery brewery;
  final double distance;

  const BreweryResult({
    required this.brewery,
    required this.distance,
  });
}

// Model voor bekende steden met hun coördinaten
class CityLocation {
  final String name;
  final double latitude;
  final double longitude;

  const CityLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.86);

  bool _isSearching = false;
  String _searchedLocation = '';

  // Landelijke database met bekende steden in Nederland
  final List<CityLocation> _cities = const [
    CityLocation(name: 'Amsterdam', latitude: 52.3676, longitude: 4.9041),
    CityLocation(name: 'Rotterdam', latitude: 51.9244, longitude: 4.4777),
    CityLocation(name: 'Utrecht', latitude: 52.0907, longitude: 5.1214),
    CityLocation(name: 'Den Haag', latitude: 52.0705, longitude: 4.3007),
    CityLocation(name: 'Eindhoven', latitude: 51.4416, longitude: 5.4697),
    CityLocation(name: 'Groningen', latitude: 53.2194, longitude: 6.5665),
    CityLocation(name: 'Maastricht', latitude: 50.8513, longitude: 5.6909),
    CityLocation(name: 'Haarlem', latitude: 52.3874, longitude: 4.6462),
    CityLocation(name: 'Arnhem', latitude: 51.9851, longitude: 5.8987),
    CityLocation(name: 'Zwolle', latitude: 52.5168, longitude: 6.0830),
    CityLocation(name: 'Leeuwarden', latitude: 53.2012, longitude: 5.7999),
    CityLocation(name: 'Assen', latitude: 52.9926, longitude: 6.5642),
    CityLocation(name: 'Middelburg', latitude: 51.4988, longitude: 3.6108),
    CityLocation(name: 'Lelystad', latitude: 52.5185, longitude: 5.4714),
    CityLocation(name: ''
        's-Hertogenbosch', latitude: 51.6992, longitude: 5.3037),
    CityLocation(name: 'Breda', latitude: 51.5719, longitude: 4.7683),
    CityLocation(name: 'Tilburg', latitude: 51.5555, longitude: 5.0913),
    CityLocation(name: 'Enschede', latitude: 52.2215, longitude: 6.8937),
    CityLocation(name: 'Delft', latitude: 52.0116, longitude: 4.3571),
    CityLocation(name: 'Leiden', latitude: 52.1601, longitude: 4.4970),
    CityLocation(name: 'Nijmegen', latitude: 51.8126, longitude: 5.8372),
  ];

  // Landelijke database met brouwerijen door heel Nederland
  final List<Brewery> _breweries = const [
    // Groningen
    Brewery(title: 'Baxbier', latitude: 53.2250, longitude: 6.5700, rating: '4.7', tags: ['MODERN', 'IPA']),
    Brewery(title: 'Stadsbrouwerij Groningen', latitude: 53.2194, longitude: 6.5665, rating: '4.4', tags: ['STAD', 'BLOND']),
    Brewery(title: 'Rebelse Moed', latitude: 53.2120, longitude: 6.5600, rating: '4.5', tags: ['CRAFT', 'ORGANIC']),

    // Friesland
    Brewery(title: 'US Heit Bier', latitude: 53.0450, longitude: 5.6580, rating: '4.4', tags: ['FRISSIAN', 'WISKY']),
    Brewery(title: 'Brouwerij Dockum', latitude: 53.3262, longitude: 5.9995, rating: '4.5', tags: ['LOCAL', 'CRAFT']),
    Brewery(title: 'Grutte Pier Brewery', latitude: 53.1500, longitude: 5.4300, rating: '4.6', tags: ['TRIPLE', 'BLOND']),

    // Drenthe
    Brewery(title: 'Maallust', latitude: 53.0290, longitude: 6.3050, rating: '4.7', tags: ['HISTORISCH', 'MATERIAAL']),
    Brewery(title: 'Brouwerij & Proeflokaal Beilen', latitude: 52.8550, longitude: 6.5120, rating: '4.3', tags: ['PROEFLOKAAL']),
    Brewery(title: 'Salie & Zware Jongens', latitude: 52.9800, longitude: 6.5600, rating: '4.4', tags: ['LOCAL']),

    // Overijssel
    Brewery(title: 'Dolle Mina', latitude: 52.5010, longitude: 6.0830, rating: '4.3', tags: ['LOCAL']),
    Brewery(title: 'Mommeriete', latitude: 52.6100, longitude: 6.7150, rating: '4.5', tags: ['STOUT', 'BOCK']),
    Brewery(title: 'Eanske Bier', latitude: 52.2215, longitude: 6.8937, rating: '4.6', tags: ['ENSCHEDE', 'IPA']),
    Brewery(title: 'Brouwerij Huttenkloas', latitude: 52.3400, longitude: 6.8100, rating: '4.5', tags: ['TWENTE', 'CRAFT']),

    // Flevoland
    Brewery(title: 'Stadsbrouwerij Zeewolde', latitude: 52.3330, longitude: 5.5350, rating: '4.3', tags: ['LOCAL']),
    Brewery(title: 'Compaan Flevoland', latitude: 52.5120, longitude: 5.4710, rating: '4.4', tags: ['CRAFT']),

    // Gelderland
    Brewery(title: 'Oersoep', latitude: 51.8426, longitude: 5.8584, rating: '4.6', tags: ['SOUR', 'EXPERIMENTAL']),
    Brewery(title: 'Gajes Bier', latitude: 52.2112, longitude: 5.9699, rating: '4.4', tags: ['BLOND', 'TRIPLE']),
    Brewery(title: 'Bronckhorster Brewing Company', latitude: 52.0510, longitude: 6.2300, rating: '4.6', tags: ['CRAFT', 'WOOD']),
    Brewery(title: 'Stadsbrouwerij Wageningen', latitude: 51.9692, longitude: 5.6657, rating: '4.4', tags: ['ORGANIC']),
    Brewery(title: 'AXL Brewery', latitude: 52.1326, longitude: 5.9140, rating: '4.5', tags: ['APELDOORN']),
    Brewery(title: 'Pantsers Bier', latitude: 51.9850, longitude: 5.9100, rating: '4.3', tags: ['ARNHEM']),

    // Utrecht
    Brewery(title: 'Uiltje Brewing Company', latitude: 52.3874, longitude: 4.6462, rating: '4.7', tags: ['IPA', 'MODERN']),
    Brewery(title: 'Brouwerij De Leckere', latitude: 52.0313, longitude: 5.0997, rating: '4.3', tags: ['BIOLOGISCH', 'LOCAL']),
    Brewery(title: 'Brewpub De Kromme Haring', latitude: 52.0780, longitude: 5.1320, rating: '4.6', tags: ['WILD', 'SOUR']),
    Brewery(title: 'Brouwerij Maximus', latitude: 52.0910, longitude: 5.0350, rating: '4.5', tags: ['TERRAS', 'DUBBEL']),
    Brewery(title: 'VandeStreek Bier', latitude: 52.1100, longitude: 5.0700, rating: '4.6', tags: ['IPA', 'ZERO']),

    // Noord-Holland
    Brewery(title: 'Brouwerij Het IJ', latitude: 52.3667, longitude: 4.9306, rating: '4.6', tags: ['IPA', 'BLOND']),
    Brewery(title: 'Poesiat & Kater', latitude: 52.3565, longitude: 4.9312, rating: '4.5', tags: ['CRAFT', 'TERRAS']),
    Brewery(title: 'Brouwerij Troost', latitude: 52.3533, longitude: 4.8805, rating: '4.4', tags: ['BURGER', 'BIER']),
    Brewery(title: 'Jopenkerk', latitude: 52.3810, longitude: 4.6362, rating: '4.5', tags: ['HAARLEM', 'PROEFLOKAAL']),
    Brewery(title: 'Egmondse Bierbrouwerij', latitude: 52.6170, longitude: 4.6300, rating: '4.4', tags: ['ABDIJ', 'SAINT']),
    Brewery(title: 'Brouwerij Homeland', latitude: 52.3730, longitude: 4.9150, rating: '4.5', tags: ['AMSTERDAM', 'NAVY']),

    // Zuid-Holland
    Brewery(title: 'Brouwerij De Molen', latitude: 52.1258, longitude: 4.6589, rating: '4.7', tags: ['STOUTS', 'BARREL']),
    Brewery(title: 'Brouwerij Hoop', latitude: 52.0789, longitude: 4.3116, rating: '4.8', tags: ['IPA', 'PROEFLOKAAL']),
    Brewery(title: 'Brouwerij Noordt', latitude: 51.9310, longitude: 4.4750, rating: '4.5', tags: ['IPA', 'LAGER']),
    Brewery(title: 'Kaapse Brouwers', latitude: 51.9073, longitude: 4.8566, rating: '4.6', tags: ['CRAFT', 'IPA']),
    Brewery(title: 'Stadsbrouwerij De Pelgrim', latitude: 51.9244, longitude: 4.4777, rating: '4.4', tags: ['HISTORISCH', 'BLOND']),
    Brewery(title: 'Delftse Brouwers', latitude: 52.0116, longitude: 4.3571, rating: '4.4', tags: ['DELFT', 'LOCAL']),

    // Zeeland
    Brewery(title: 'Emelisse', latitude: 51.5210, longitude: 3.5680, rating: '4.6', tags: ['BLACK', 'IPA']),
    Brewery(title: 'Stadsbrouwerij Middelburg', latitude: 51.4988, longitude: 3.6108, rating: '4.4', tags: ['LOCAL']),
    Brewery(title: 'Dutch Bargain', latitude: 51.3500, longitude: 3.5000, rating: '4.5', tags: ['BORDER', 'CRAFT']),

    // Noord-Brabant
    Brewery(title: 'Brouwerij Frontaal', latitude: 51.5900, longitude: 4.7750, rating: '4.7', tags: ['IPA', 'CRAFT']),
    Brewery(title: 'La Trappe (Trappistenbrouwerij)', latitude: 51.5372, longitude: 5.0315, rating: '4.8', tags: ['TRAPPIST', 'KLASSIEK']),
    Brewery(title: 'Stadsbrouwerij Eindhoven', latitude: 51.4416, longitude: 5.4697, rating: '4.5', tags: ['STAD', 'PROEFLOKAAL']),
    Brewery(title: 'Brouwerij 75', latitude: 51.6920, longitude: 5.3030, rating: '4.4', tags: ['CRAFT']),
    Brewery(title: 'Brouwerij Van Vollenhoven', latitude: 51.6900, longitude: 5.3000, rating: '4.3', tags: ['TRADITIONAL']),
    Brewery(title: 'Stadsbrouwerij Tilburg', latitude: 51.5550, longitude: 5.0910, rating: '4.5', tags: ['TILburg']),

    // Limburg
    Brewery(title: 'Brand Bierbrouwerij', latitude: 51.6310, longitude: 5.9180, rating: '4.5', tags: ['LIMBURG', 'PILSNER']),
    Brewery(title: 'Stadsbrouwerij Maastricht', latitude: 50.8483, longitude: 5.6889, rating: '4.6', tags: ['HISTORISCH', 'PROEFLOKAAL']),
    Brewery(title: 'Gulpener Bierbrouwerij', latitude: 50.8250, longitude: 5.8970, rating: '4.7', tags: ['BIOLOGISCH', 'LOCAL']),
    Brewery(title: 'Lindeboom Bierbrouwerij', latitude: 51.4800, longitude: 5.9300, rating: '4.4', tags: ['NEER', 'FAMILY']),
  ];

  List<BreweryResult> _results = [];

  @override
  void initState() {
    super.initState();
    _resetResults();
  }

  void _resetResults() {
    _results = _breweries
        .map(
          (brewery) => BreweryResult(
            brewery: brewery,
            distance: 0,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  double _calculateDistance(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const double earthRadius = 6371;

    final double dLatitude = _degreesToRadians(latitude2 - latitude1);
    final double dLongitude = _degreesToRadians(longitude2 - longitude1);

    final double a = sin(dLatitude / 2) * sin(dLatitude / 2) +
        cos(_degreesToRadians(latitude1)) *
            cos(_degreesToRadians(latitude2)) *
            sin(dLongitude / 2) *
            sin(dLongitude / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _searchLocation() {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
    });

    try {
      // Zoek de stad op in de ingebouwde lijst (case-insensitive)
      CityLocation? foundCity;
      for (var city in _cities) {
        if (city.name.toLowerCase().contains(query)) {
          foundCity = city;
          break;
        }
      }

      if (foundCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stad niet gevonden in de lijst. Probeer bijv. Amsterdam, Utrecht, Groningen.'),
          ),
        );
        setState(() {
          _isSearching = false;
        });
        return;
      }

      // Verplaats de kaart naar de gevonden stad
      _mapController.move(
        LatLng(foundCity.latitude, foundCity.longitude),
        11,
      );

      // Bereken de afstand voor ALLE brouwerijen t.o.v. deze stad
      final List<BreweryResult> newResults = _breweries.map((brewery) {
        final double distance = _calculateDistance(
          foundCity!.latitude,
          foundCity.longitude,
          brewery.latitude,
          brewery.longitude,
        );

        return BreweryResult(
          brewery: brewery,
          distance: distance,
        );
      }).toList();

      // Sorteer direct van dichtbij naar ver weg
      newResults.sort(
        (a, b) => a.distance.compareTo(b.distance),
      );

      setState(() {
        _searchedLocation = foundCity!.name;
        _results = newResults;
        _isSearching = false;
      });

      if (_pageController.hasClients && newResults.isNotEmpty) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Er ging iets mis met zoeken'),
        ),
      );
      setState(() {
        _isSearching = false;
      });
    }
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final safeResults = _results;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(52.0907, 5.1214),
              initialZoom: 9,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bierkompas',
              ),
              MarkerLayer(
                markers: safeResults.map((result) {
                  return Marker(
                    point: LatLng(
                      result.brewery.latitude,
                      result.brewery.longitude,
                    ),
                    width: 38,
                    height: 38,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4B28C),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF2C221C),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.sports_bar,
                        color: Color(0xFF2C221C),
                        size: 18,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C221C),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4B28C).withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_bar,
                            color: Color(0xFFD4B28C),
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'BierKompas',
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFEFE6DD),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Dichtstbijzijnde Brouwerij',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFD4B28C),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchedLocation.isEmpty
                            ? 'Typ een stad in (bijv. Amsterdam, Utrecht, Maastricht).'
                            : 'Resultaten vanaf $_searchedLocation (dichtstbijzijnde eerst)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9E8A7D),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C221C),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: const Color(0xFF3E312A),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _isSearching ? null : _searchLocation,
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD4B28C),
                                  ),
                                )
                              : const Icon(
                                  Icons.search,
                                  color: Color(0xFF9E8A7D),
                                  size: 20,
                                ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _searchLocation(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            cursorColor: const Color(0xFFD4B28C),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Zoek stad (bijv. Utrecht, Groningen)...',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF9E8A7D),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSearching ? null : _searchLocation,
                          icon: const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFFD4B28C),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: safeResults.isEmpty
                      ? Center(
                          child: Text(
                            'Geen brouwerijen gevonden',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Center(
                          child: SizedBox(
                            height: 380,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: safeResults.length,
                              itemBuilder: (context, index) {
                                final BreweryResult result = safeResults[index];

                                final String distanceText =
                                    _searchedLocation.isEmpty
                                        ? 'Zoek een stad om de afstand te zien'
                                        : '${_formatDistance(result.distance)} van $_searchedLocation';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: _buildBreweryCard(
                                    title: result.brewery.title,
                                    distance: distanceText,
                                    rating: result.brewery.rating,
                                    tags: result.brewery.tags,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreweryCard({
    required String title,
    required String distance,
    required String rating,
    required List<String> tags,
  }) {
    final safeTags = tags;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3E312A),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 210,
                decoration: const BoxDecoration(
                  color: Color(0xFF3E312A),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_bar,
                    color: Color(0xFF7A6355),
                    size: 48,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.navigation,
                      color: Color(0xFF9E8A7D),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        distance,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9E8A7D),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: safeTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1712),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF3E312A),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFC4A482),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}