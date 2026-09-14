import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../favorites/favorites_service.dart';
import 'breweries.dart';
import '../../shared/profile_avatar_button.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.avatarUrl,
    this.onProfileTap,
  });

  final String? avatarUrl;
  final VoidCallback? onProfileTap;

  @override
  State<MapPage> createState() => _MapPageState();
}

class BreweryResult {
  final Brewery brewery;
  final double distance;

  const BreweryResult({
    required this.brewery,
    required this.distance,
  });
}

class SearchLocation {
  final String displayName;
  final double latitude;
  final double longitude;

  const SearchLocation({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

class _MapPageState extends State<MapPage> {
  final _favoritesService = FavoritesService();
  final _pageController = PageController(viewportFraction: 0.86);
  final _mapController = MapController();
  final _searchController = TextEditingController();

  final Set<int> _favoriteIds = {};

  String _searchedLocation = '';

  bool _isSearching = false;
  bool _isLoadingBreweries = false;

  List<BreweryResult> _results = [];

  @override
  void initState() {
    super.initState();

    _loadBreweries();
    _loadFavorites();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBreweries() async {
    setState(() {
      _isLoadingBreweries = true;
    });

    try {
      final breweriesFromOsm =
          await _getBreweriesFromOpenStreetMap();

      if (!mounted) return;

      setState(() {
        _results = breweriesFromOsm
            .map(
              (brewery) => BreweryResult(
                brewery: brewery,
                distance: 0,
              ),
            )
            .toList();

        _isLoadingBreweries = false;
      });
    } catch (e) {
      debugPrint('Fout bij ophalen brouwerijen: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingBreweries = false;

        // Als OpenStreetMap niet werkt,
        // gebruiken we de bestaande brouwerijen.
        _results = breweries
            .map(
              (brewery) => BreweryResult(
                brewery: brewery,
                distance: 0,
              ),
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Online brouwerijen konden niet worden geladen. '
            'De standaard brouwerijen worden getoond.',
          ),
        ),
      );
    }
  }

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final favorites =
          await _favoritesService.list(user.id);

      if (!mounted) return;

      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(
            favorites
                .where(
                  (f) => f.itemType == breweryItemType,
                )
                .map(
                  (f) => f.itemId,
                ),
          );
      });
    } on FavoritesException catch (e) {
      debugPrint(
        'Fout bij ophalen favorieten: $e',
      );
    }
  }

  Future<void> _toggleFavorite(
    Brewery brewery,
  ) async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Je moet ingelogd zijn om favorieten te gebruiken.',
          ),
        ),
      );
      return;
    }

    final wasFavorite =
        _favoriteIds.contains(brewery.id);

    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(brewery.id);
      } else {
        _favoriteIds.add(brewery.id);
      }
    });

    try {
      if (wasFavorite) {
        await _favoritesService.remove(
          userId: user.id,
          itemType: breweryItemType,
          itemId: brewery.id,
        );
      } else {
        await _favoritesService.add(
          userId: user.id,
          itemType: breweryItemType,
          itemId: brewery.id,
        );
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
        SnackBar(
          content: Text(
            'Favoriet opslaan mislukt: $e',
          ),
        ),
      );
    }
  }

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees * pi / 180;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;

    final dLat = _degreesToRadians(
      lat2 - lat1,
    );

    final dLon = _degreesToRadians(
      lon2 - lon1,
    );

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 *
        atan2(
          sqrt(a),
          sqrt(1 - a),
        );

    return earthRadius * c;
  }

  String _formatDistance(
    double distance,
  ) {
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  Future<SearchLocation?> _geocodeLocation(
    String query,
  ) async {
    final encodedQuery =
        Uri.encodeQueryComponent(
      '$query, Nederland',
    );

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$encodedQuery'
      '&format=json'
      '&limit=1'
      '&countrycodes=nl'
      '&addressdetails=1',
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'BierKompas/1.0 (Flutter app)',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Nominatim fout: ${response.statusCode}',
      );
    }

    final List<dynamic> data =
        jsonDecode(response.body);

    if (data.isEmpty) {
      return null;
    }

    final result = data.first;

    final latitude = double.tryParse(
      result['lat'].toString(),
    );

    final longitude = double.tryParse(
      result['lon'].toString(),
    );

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    return SearchLocation(
      displayName:
          result['display_name'].toString(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<Brewery>>
      _getBreweriesFromOpenStreetMap() async {
    const overpassQuery = '''
[out:json][timeout:60];

area["ISO3166-1"="NL"][admin_level=2]->.searchArea;

(
  nwr["craft"="brewery"](area.searchArea);
  nwr["brewery"="yes"](area.searchArea);
);

out center tags;
''';

    final encodedQuery =
        Uri.encodeQueryComponent(
      overpassQuery,
    );

    final uri = Uri.parse(
      'https://overpass-api.de/api/interpreter'
      '?data=$encodedQuery',
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'BierKompas/1.0 (Flutter app)',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Overpass fout: ${response.statusCode}',
      );
    }

    final data = jsonDecode(
      response.body,
    );

    final elements =
        data['elements'] as List<dynamic>;

    final List<Brewery> result = [];

    int idCounter = 100000;

    for (final element in elements) {
      final tags =
          element['tags'] as Map<String, dynamic>?;

      if (tags == null) continue;

      double? latitude;
      double? longitude;

      if (element['lat'] != null &&
          element['lon'] != null) {
        latitude = double.tryParse(
          element['lat'].toString(),
        );

        longitude = double.tryParse(
          element['lon'].toString(),
        );
      } else if (element['center'] != null) {
        latitude = double.tryParse(
          element['center']['lat'].toString(),
        );

        longitude = double.tryParse(
          element['center']['lon'].toString(),
        );
      }

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      final name =
          tags['name']?.toString().trim();

      if (name == null || name.isEmpty) {
        continue;
      }

      final city =
          tags['addr:city']?.toString() ??
          tags['place']?.toString() ??
          '';

      final street =
          tags['addr:street']?.toString() ??
          '';

      final location = street.isNotEmpty &&
              city.isNotEmpty
          ? '$street, $city'
          : city.isNotEmpty
              ? city
              : 'Nederland';

      final website =
          tags['website']?.toString();

      final founded =
          tags['start_date']?.toString();

      final about = website != null
          ? 'Brouwerij gevonden via OpenStreetMap. Website: $website'
          : 'Brouwerij gevonden via OpenStreetMap.';

      result.add(
        Brewery(
          id: idCounter++,
          title: name,
          distance: '',
          rating: '—',
          tags: const [
            'BROUWERIJ',
          ],
          location: location,
          founded: founded,
          about: about,
          facts: const [],
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    // Dubbele brouwerijen verwijderen.
    final Map<String, Brewery> unique = {};

    for (final brewery in result) {
      final key =
          '${brewery.title.toLowerCase()}'
          '_${brewery.latitude.toStringAsFixed(4)}'
          '_${brewery.longitude.toStringAsFixed(4)}';

      unique[key] = brewery;
    }

    return unique.values.toList();
  }

  Future<void> _searchLocation() async {
    final query =
        _searchController.text.trim();

    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
    });

    try {
      final location =
          await _geocodeLocation(query);

      if (location == null) {
        if (!mounted) return;

        setState(() {
          _isSearching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Locatie niet gevonden. Probeer bijvoorbeeld Gouda, Utrecht, een postcode of straat.',
            ),
          ),
        );

        return;
      }

      final sortedResults =
          _results.map((result) {
        final distance =
            _calculateDistance(
          location.latitude,
          location.longitude,
          result.brewery.latitude,
          result.brewery.longitude,
        );

        return BreweryResult(
          brewery: result.brewery,
          distance: distance,
        );
      }).toList();

      sortedResults.sort(
        (a, b) =>
            a.distance.compareTo(
          b.distance,
        ),
      );

      if (!mounted) return;

      setState(() {
        _searchedLocation =
            _getShortLocationName(
          location.displayName,
          query,
        );

        _results = sortedResults;

        _isSearching = false;
      });

      _mapController.move(
        LatLng(
          location.latitude,
          location.longitude,
        ),
        10,
      );

      if (_pageController.hasClients &&
          sortedResults.isNotEmpty) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      debugPrint(
        'Zoeken mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Er ging iets mis tijdens het zoeken.',
          ),
        ),
      );
    }
  }

  String _getShortLocationName(
    String displayName,
    String fallback,
  ) {
    final parts = displayName
        .split(',')
        .map(
          (e) => e.trim(),
        )
        .where(
          (e) => e.isNotEmpty,
        )
        .toList();

    if (parts.isNotEmpty) {
      return parts.first;
    }

    return fallback;
  }

  void _resetSearch() {
    _searchController.clear();

    setState(() {
      _searchedLocation = '';

      _results = _results
          .map(
            (result) => BreweryResult(
              brewery: result.brewery,
              distance: 0,
            ),
          )
          .toList();
    });

    _mapController.move(
      const LatLng(
        52.1326,
        5.2913,
      ),
      8,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF1E1712),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(
                52.1326,
                5.2913,
              ),
              initialZoom: 8,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.bierkompas',
              ),

              MarkerLayer(
                markers: _results.map(
                  (result) {
                    return Marker(
                      point: LatLng(
                        result.brewery.latitude,
                        result.brewery.longitude,
                      ),
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration:
                            BoxDecoration(
                          color: const Color(
                            0xFFD4B28C,
                          ),
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color: const Color(
                              0xFF2C221C,
                            ),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.sports_bar,
                          color: Color(
                            0xFF2C221C,
                          ),
                          size: 16,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ],
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16,
                  ),
                  decoration:
                      const BoxDecoration(
                    color: Color(0xFF2C221C),
                    borderRadius:
                        BorderRadius.only(
                      bottomLeft:
                          Radius.circular(24),
                      bottomRight:
                          Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_bar,
                            color: Color(
                              0xFFD4B28C,
                            ),
                            size: 30,
                          ),
                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              'Kaart',
                              style:
                                  GoogleFonts.playfairDisplay(
                                color: const Color(
                                  0xFFEFE6DD,
                                ),
                                fontSize: 28,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          if (widget
                                  .onProfileTap !=
                              null)
                            ProfileAvatarButton(
                              onTap: widget
                                  .onProfileTap!,
                              avatarUrl:
                                  widget.avatarUrl,
                            ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      Text(
                        'Dichtstbijzijnde Brouwerij',
                        style:
                            GoogleFonts.playfairDisplay(
                          color: const Color(
                            0xFFD4B28C,
                          ),
                          fontSize: 24,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _searchedLocation.isEmpty
                            ? 'Ontdek brouwerijen in heel Nederland en zoek naar brouwerijen bij jou in de buurt.'
                            : 'Brouwerijen vanaf $_searchedLocation, gesorteerd op afstand.',
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            GoogleFonts.inter(
                          color: const Color(
                            0xFF9E8A7D,
                          ),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    height: 46,
                    decoration:
                        BoxDecoration(
                      color: const Color(
                        0xFF2C221C,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        25,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFF3E312A,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_isSearching)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(
                                0xFFD4B28C,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.search,
                            color: Color(
                              0xFF9E8A7D,
                            ),
                            size: 19,
                          ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: TextField(
                            controller:
                                _searchController,
                            onSubmitted: (_) =>
                                _searchLocation(),
                            style:
                                GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            cursorColor:
                                const Color(
                              0xFFD4B28C,
                            ),
                            textInputAction:
                                TextInputAction.search,
                            decoration:
                                InputDecoration(
                              hintText:
                                  'Zoek stad, straat, postcode...',
                              hintStyle:
                                  GoogleFonts.inter(
                                color: const Color(
                                  0xFF9E8A7D,
                                ),
                                fontSize: 13,
                              ),
                              border:
                                  InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.zero,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed:
                              _isSearching
                                  ? null
                                  : _searchLocation,
                          icon: const Icon(
                            Icons.arrow_forward,
                            color: Color(
                              0xFFD4B28C,
                            ),
                            size: 20,
                          ),
                          padding:
                              EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),

                        if (_searchedLocation
                            .isNotEmpty)
                          GestureDetector(
                            onTap:
                                _resetSearch,
                            child:
                                const Icon(
                              Icons.close,
                              color: Color(
                                0xFF9E8A7D,
                              ),
                              size: 18,
                            ),
                          )
                        else
                          const Icon(
                            Icons.tune,
                            color: Color(
                              0xFF9E8A7D,
                            ),
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),

                if (_isLoadingBreweries)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top: 10,
                    ),
                    child:
                        CircularProgressIndicator(
                      color: Color(
                        0xFFD4B28C,
                      ),
                    ),
                  ),

                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            'Geen brouwerijen gevonden.',
                            style:
                                GoogleFonts.inter(
                              color:
                                  const Color(
                                0xFF9E8A7D,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: SizedBox(
                            height: 380,
                            child: PageView(
                              controller:
                                  _pageController,
                              children: [
                                for (final result
                                    in _results)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child:
                                        _buildBreweryCard(
                                      brewery:
                                          result.brewery,
                                      distance:
                                          result.distance,
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
    required Brewery brewery,
    required double distance,
  }) {
    final isFavorite =
        _favoriteIds.contains(
      brewery.id,
    );

    final distanceText =
        _searchedLocation.isEmpty
            ? brewery.location
            : '${_formatDistance(distance)} vanaf $_searchedLocation';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3E312A),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 210,
                decoration:
                    const BoxDecoration(
                  color: Color(0xFF3E312A),
                  borderRadius:
                      BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_bar,
                    color: Color(
                      0xFF7A6355,
                    ),
                    size: 48,
                  ),
                ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () =>
                      _toggleFavorite(
                    brewery,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.all(8),
                    decoration:
                        BoxDecoration(
                      color: Colors.black
                          .withOpacity(0.5),
                      shape:
                          BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: isFavorite
                          ? const Color(
                              0xFFD4B28C,
                            )
                          : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        brewery.title,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
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
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          brewery.rating,
                          style:
                              GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.bold,
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
                      color: Color(
                        0xFF9E8A7D,
                      ),
                      size: 12,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Expanded(
                      child: Text(
                        distanceText,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            GoogleFonts.inter(
                          color: const Color(
                            0xFF9E8A7D,
                          ),
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
                  children:
                      brewery.tags.map(
                    (tag) {
                      return Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color: const Color(
                            0xFF1E1712,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            4,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFF3E312A,
                            ),
                          ),
                        ),
                        child: Text(
                          tag,
                          style:
                              GoogleFonts.inter(
                            color:
                                const Color(
                              0xFFC4A482,
                            ),
                            fontSize: 10,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}