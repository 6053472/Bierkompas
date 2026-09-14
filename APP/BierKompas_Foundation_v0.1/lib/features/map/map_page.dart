import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../favorites/favorites_service.dart';
import 'breweries.dart';
import '../../shared/profile_avatar_button.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.avatarUrl, this.onProfileTap});

  final String? avatarUrl;
  final VoidCallback? onProfileTap;

  @override
  State<MapPage> createState() => _MapPageState();
}

class BreweryResult {
  final Brewery brewery;
  final double distance;

  const BreweryResult({required this.brewery, required this.distance});
}

// Model voor bekende steden met hun coördinaten, gebruikt om op te zoeken.
class CityLocation {
  final String name;
  final double latitude;
  final double longitude;

  const CityLocation({required this.name, required this.latitude, required this.longitude});
}

class _MapPageState extends State<MapPage> {
  final _favoritesService = FavoritesService();
  final _pageController = PageController(viewportFraction: 0.86);
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final Set<int> _favoriteIds = {};
  String _searchedLocation = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchedLocation = '';
  List<BreweryResult> _results = [];

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
    CityLocation(name: 'Westvleteren', latitude: 50.9020, longitude: 2.7150),
    CityLocation(name: 'Zaandijk', latitude: 52.4700, longitude: 4.8200),
    CityLocation(name: 'Bodegraven', latitude: 52.0850, longitude: 4.7460),
  ];

  @override
  void initState() {
    super.initState();
    _resetResults();
    _loadFavorites();
  }

  void _resetResults() {
    _results = breweries.map((brewery) => BreweryResult(brewery: brewery, distance: 0)).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final favorites = await _favoritesService.list(user.id);
      if (!mounted) return;
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(favorites.where((f) => f.itemType == breweryItemType).map((f) => f.itemId));
      });
    } on FavoritesException catch (e) {
      debugPrint('Fout bij ophalen favorieten: $e');
    }
  }

  Future<void> _toggleFavorite(Brewery brewery) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final wasFavorite = _favoriteIds.contains(brewery.id);
    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(brewery.id);
      } else {
        _favoriteIds.add(brewery.id);
      }
    });
    try {
      if (wasFavorite) {
        await _favoritesService.remove(userId: user.id, itemType: breweryItemType, itemId: brewery.id);
      } else {
        await _favoritesService.add(userId: user.id, itemType: breweryItemType, itemId: brewery.id);
      }
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteIds.add(brewery.id);
        } else {
          _favoriteIds.remove(brewery.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favoriet opslaan mislukt: $e')),
      );
    }
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  String _formatDistance(double distance) {
    if (distance < 1) return '${(distance * 1000).round()} m';
    return '${distance.toStringAsFixed(1)} km';
  }

  void _searchLocation() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchedLocation = '';
        _resetResults();
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    CityLocation? foundCity;
    for (final city in _cities) {
      if (city.name.toLowerCase().contains(query)) {
        foundCity = city;
        break;
      }
    }

    if (foundCity == null) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stad niet gevonden. Probeer bijv. Amsterdam, Utrecht, Groningen.')),
      );
      return;
    }

    _mapController.move(LatLng(foundCity.latitude, foundCity.longitude), 10);

    final newResults = breweries
        .map((brewery) => BreweryResult(
              brewery: brewery,
              distance: _calculateDistance(
                foundCity!.latitude,
                foundCity.longitude,
                brewery.latitude,
                brewery.longitude,
              ),
            ))
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    setState(() {
      _searchedLocation = foundCity!.name;
      _results = newResults;
      _isSearching = false;
    });

    if (_pageController.hasClients && newResults.isNotEmpty) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(52.0907, 5.1214),
              initialZoom: 8,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bierkompas',
              ),
              MarkerLayer(
                markers: _results.map((result) {
                  return Marker(
                    point: LatLng(result.brewery.latitude, result.brewery.longitude),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4B28C),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2C221C), width: 2),
                      ),
                      child: const Icon(Icons.sports_bar, color: Color(0xFF2C221C), size: 16),
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
                          Expanded(
                            child: Text(
                              'Kaart',
                              style: GoogleFonts.playfairDisplay(
                                color: const Color(0xFFEFE6DD),
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.onProfileTap != null)
                            ProfileAvatarButton(
                              onTap: widget.onProfileTap!,
                              avatarUrl: widget.avatarUrl,
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
                            ? 'Ontdek unieke brouwerijen en proeflokalen bij jou in de buurt, zorgvuldig geselecteerd op erfgoed en kwaliteit.'
                            : 'Resultaten vanaf $_searchedLocation (dichtstbijzijnde eerst).',
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
                    height: 42,
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
                        GestureDetector(
                          onTap: _isSearching ? null : _searchLocation,
                          child: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4B28C)),
                                )
                              : const Icon(Icons.search, color: Color(0xFF9E8A7D), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _searchLocation(),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            cursorColor: const Color(0xFFD4B28C),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Zoek brouwerijen of steden...',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF9E8A7D),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
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
                        if (_searchedLocation.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchedLocation = '';
                                _resetResults();
                              });
                            },
                            child: const Icon(Icons.close, color: Color(0xFF9E8A7D), size: 18),
                          )
                        else
                          const Icon(Icons.tune, color: Color(0xFF9E8A7D), size: 18),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      height: 380,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          for (final result in _results)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                              child: _buildBreweryCard(
                                title: result.brewery.title,
                                distance: _searchedLocation.isEmpty
                                    ? result.brewery.distance
                                    : '${_formatDistance(result.distance)} vanaf $_searchedLocation',
                                rating: result.brewery.rating,
                                tags: result.brewery.tags,
                                isFavorite: _favoriteIds.contains(result.brewery.id),
                                onFavoriteTap: () => _toggleFavorite(result.brewery),
                              ),
                            ),
                        ],
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
    required bool isFavorite,
    required VoidCallback onFavoriteTap,
  }) {
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
                child: GestureDetector(
                  onTap: onFavoriteTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? const Color(0xFFD4B28C) : Colors.white,
                      size: 18,
                    ),
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
                  children: tags.map((tag) {
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
