import 'dart:async';
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

class SearchSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;

  const SearchSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final _favoritesService = FavoritesService();

  final _pageController = PageController(
    viewportFraction: 0.86,
  );

  final _mapController = MapController();

  final _searchController = TextEditingController();

  final Set<int> _favoriteIds = {};

  List<BreweryResult> _results = [];

  List<SearchSuggestion> _suggestions = [];

  Timer? _suggestionTimer;

  String _searchedLocation = '';

  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  // Toont alleen een klein "meer laden"-hintje; blokkeert de kaart niet meer,
  // want de publieke Overpass-servers kunnen tot een minuut per poging duren.
  bool _loadingMoreBreweries = false;

  // Zoomniveaus voor het selecteren van een brouwerij op de kaart.
  static const _zoomOverview = 8.0;
  static const _zoomSearch = 11.0;
  static const _zoomNearby = 14.0;
  static const _zoomFocused = 17.0;

  // null = nog geen bier-icoontje aangetikt: dan tonen we alleen de kaart met
  // pinnetjes, geen kaart-paneel eronder.
  int? _selectedIndex;
  AnimationController? _mapAnimController;

  @override
  void initState() {
    super.initState();

    // Toon de lokale lijst meteen, zodat de kaart niet minutenlang leeg/aan
    // het laden lijkt terwijl er op de online brouwerijen gewacht wordt.
    _results = breweries.map((brewery) => BreweryResult(brewery: brewery, distance: 0)).toList();

    _loadBreweries();
    _loadFavorites();

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _mapAnimController?.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // KAART-SELECTIE & ANIMATIE
  // ============================================================

  // Beweegt de kaart vloeiend naar een locatie/zoomniveau i.p.v. de
  // ongeanimeerde `_mapController.move()`.
  void _animatedMapMove(LatLng destination, double destZoom) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: destination.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destination.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    _mapAnimController?.dispose();
    final controller = AnimationController(duration: const Duration(milliseconds: 550), vsync: this);
    final animation = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
        if (identical(_mapAnimController, controller)) _mapAnimController = null;
      }
    });

    _mapAnimController = controller;
    controller.forward();
  }

  // Standaard Web Mercator-formule: hoeveel meter beslaat één pixel op het
  // scherm, op deze breedtegraad en dit zoomniveau.
  double _metersPerPixel(double latitudeDeg, double zoom) {
    return 156543.03392 * cos(latitudeDeg * pi / 180) / pow(2, zoom);
  }

  // Schuift een punt een aantal schermpixels naar het noorden (= omhoog),
  // zodat het bier-icoontje boven het kaart-paneel uit blijft steken i.p.v.
  // er precies achter te verdwijnen.
  LatLng _liftForPanel(LatLng point, double zoom) {
    final metersPerPixel = _metersPerPixel(point.latitude, zoom);
    final latShift = (150 * metersPerPixel) / 111320.0;
    return LatLng(point.latitude - latShift, point.longitude);
  }

  // Tikken op een bier-icoontje (of opnieuw op de al geselecteerde kaart):
  // toont het kaart-paneel voor die brouwerij en zoomt de kaart erop in.
  void _selectBrewery(int index, {bool zoomIn = false}) {
    if (index < 0 || index >= _results.length) return;
    final wasVisible = _selectedIndex != null;
    final brewery = _results[index].brewery;
    final zoom = zoomIn ? _zoomFocused : _zoomNearby;

    setState(() => _selectedIndex = index);
    _animatedMapMove(
      _liftForPanel(LatLng(brewery.latitude, brewery.longitude), zoom),
      zoom,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (wasVisible) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(index);
      }
    });
  }

  // Terug naar het overzicht: kaart-paneel verbergen, alleen pinnetjes tonen.
  void _deselectBrewery() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
    _animatedMapMove(
      const LatLng(52.1326, 5.2913),
      _searchedLocation.isEmpty ? _zoomOverview : _zoomSearch,
    );
  }

  // Swipen door de kaarten: volgt de kaart mee naar elke nieuwe brouwerij, op
  // een iets ruimer zoomniveau dan het "focused" niveau van een tik.
  void _onCardPageChanged(int index) {
    if (index < 0 || index >= _results.length) return;
    setState(() => _selectedIndex = index);
    final brewery = _results[index].brewery;
    _animatedMapMove(
      _liftForPanel(LatLng(brewery.latitude, brewery.longitude), _zoomNearby),
      _zoomNearby,
    );
  }

  // ============================================================
  // BROUWERIJEN
  // ============================================================

  // Haalt extra brouwerijen op via OpenStreetMap, ná het tonen van de lokale
  // lijst. Lukt dit niet (trage/overbelaste publieke server), dan blijft
  // gewoon de lokale lijst staan — de gebruiker hoeft daar niet op te wachten.
  Future<void> _loadBreweries() async {
    setState(() {
      _loadingMoreBreweries = true;
    });

    try {
      final onlineBreweries =
          await _fetchDutchBreweries();

      final allBreweries = [
        ...onlineBreweries,
        ...breweries,
      ];

      final unique = <String, Brewery>{};

      for (final brewery in allBreweries) {
        final key =
            '${brewery.title.toLowerCase()}_${brewery.latitude.toStringAsFixed(4)}_${brewery.longitude.toStringAsFixed(4)}';

        unique[key] = brewery;
      }

      final result = unique.values
          .map(
            (brewery) => BreweryResult(
              brewery: brewery,
              distance: 0,
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _results = result;
        _loadingMoreBreweries = false;
      });
    } catch (e) {
      debugPrint(
        'Online brouwerijen laden mislukt: $e',
      );

      // De lokale lijst staat al (gezet in initState); niets overschrijven.
      if (!mounted) return;

      setState(() {
        _loadingMoreBreweries = false;
      });
    }
  }

  Future<List<Brewery>> _fetchDutchBreweries() async {
    const query = '''
[out:json][timeout:60];

area["ISO3166-1"="NL"][admin_level=2]->.nl;

(
  nwr["craft"="brewery"](area.nl);
  nwr["brewery"](area.nl);
  nwr["industrial"="brewery"](area.nl);
  nwr["building"="brewery"](area.nl);
);

out center tags;
''';

    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    Object? lastError;

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: const {
                'User-Agent': 'BierKompas/1.0',
                'Content-Type':
                    'application/x-www-form-urlencoded',
              },
              body: {
                'data': query,
              },
            )
            .timeout(
              const Duration(seconds: 15),
            );

        if (response.statusCode != 200) {
          lastError = Exception(
            'Overpass ${response.statusCode}',
          );
          continue;
        }

        final decoded =
            jsonDecode(response.body);

        final elements =
            decoded['elements'];

        if (elements is! List) {
          continue;
        }

        final result = <Brewery>[];

        for (final element in elements) {
          final tags = element['tags'];

          if (tags is! Map) continue;

          final name =
              tags['name']?.toString().trim();

          if (name == null ||
              name.isEmpty) {
            continue;
          }

          double? latitude;
          double? longitude;

          if (element['type'] == 'node') {
            latitude =
                double.tryParse(
              element['lat'].toString(),
            );

            longitude =
                double.tryParse(
              element['lon'].toString(),
            );
          } else {
            final center =
                element['center'];

            if (center is Map) {
              latitude =
                  double.tryParse(
                center['lat'].toString(),
              );

              longitude =
                  double.tryParse(
                center['lon'].toString(),
              );
            }
          }

          if (latitude == null ||
              longitude == null) {
            continue;
          }

          final osmId =
              int.tryParse(
            element['id'].toString(),
          );

          if (osmId == null) continue;

          final breweryId =
              -osmId.abs();

          final city =
              tags['addr:city']?.toString() ??
                  'Nederland';

          final street =
              tags['addr:street']?.toString();

          final houseNumber =
              tags['addr:housenumber']
                  ?.toString();

          String location = city;

          if (street != null &&
              street.isNotEmpty) {
            location =
                houseNumber != null &&
                        houseNumber.isNotEmpty
                    ? '$street $houseNumber, $city'
                    : '$street, $city';
          }

          final website =
              tags['website']?.toString();

          result.add(
            Brewery(
              id: breweryId,
              title: name,
              distance:
                  'Brouwerij in $city',
              rating: '—',
              tags: const [
                'BROUWERIJ',
              ],
              location: location,
              founded:
                  tags['start_date']
                      ?.toString(),
              about:
                  'Nederlandse brouwerij.',
              facts: [
                if (street != null)
                  'Adres: $location',
                if (website != null)
                  'Website: $website',
              ],
              latitude: latitude,
              longitude: longitude,
            ),
          );
        }

        return result;
      } catch (e) {
        lastError = e;

        debugPrint(
          'Overpass endpoint mislukt: $endpoint',
        );
      }
    }

    throw Exception(
      'Geen Overpass-server beschikbaar: $lastError',
    );
  }

  // ============================================================
  // FAVORIETEN
  // ============================================================

  Future<void> _loadFavorites() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final favorites =
          await _favoritesService.list(
        user.id,
      );

      if (!mounted) return;

      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(
            favorites
                .where(
                  (favorite) =>
                      favorite.itemType ==
                      breweryItemType,
                )
                .map(
                  (favorite) =>
                      favorite.itemId,
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
        _favoriteIds.contains(
      brewery.id,
    );

    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(
          brewery.id,
        );
      } else {
        _favoriteIds.add(
          brewery.id,
        );
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
          _favoriteIds.add(
            brewery.id,
          );
        } else {
          _favoriteIds.remove(
            brewery.id,
          );
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

  // ============================================================
  // AUTOCOMPLETE
  // ============================================================

  void _onSearchChanged() {
    final query =
        _searchController.text.trim();

    _suggestionTimer?.cancel();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }

      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    _suggestionTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        _loadSuggestions(query);
      },
    );
  }

  Future<void> _loadSuggestions(
    String query,
  ) async {
    try {
      final encodedQuery =
          Uri.encodeQueryComponent(
        '$query, Nederland',
      );

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$encodedQuery'
        '&format=json'
        '&limit=5'
        '&countrycodes=nl'
        '&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'BierKompas/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Nominatim ${response.statusCode}',
        );
      }

      final List<dynamic> data =
          jsonDecode(response.body);

      final suggestions =
          <SearchSuggestion>[];

      for (final item in data) {
        final latitude =
            double.tryParse(
          item['lat'].toString(),
        );

        final longitude =
            double.tryParse(
          item['lon'].toString(),
        );

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        suggestions.add(
          SearchSuggestion(
            displayName:
                item['display_name']
                    .toString(),
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }

      if (!mounted) return;

      if (_searchController.text.trim() !=
          query) {
        return;
      }

      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      debugPrint(
        'Autocomplete mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _selectSuggestion(
    SearchSuggestion suggestion,
  ) async {
    FocusScope.of(context).unfocus();

    _searchController.text =
        _getShortLocationName(
      suggestion.displayName,
      suggestion.displayName,
    );

    setState(() {
      _suggestions = [];
      _isSearching = true;
    });

    await _applyLocation(
      SearchLocation(
        displayName:
            suggestion.displayName,
        latitude:
            suggestion.latitude,
        longitude:
            suggestion.longitude,
      ),
    );
  }

  // ============================================================
  // ZOEKEN
  // ============================================================

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
      headers: const {
        'User-Agent': 'BierKompas/1.0',
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

    final latitude =
        double.tryParse(
      result['lat'].toString(),
    );

    final longitude =
        double.tryParse(
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

  Future<void> _searchLocation() async {
    final query =
        _searchController.text.trim();

    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _suggestions = [];
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
              'Locatie niet gevonden.',
            ),
          ),
        );

        return;
      }

      await _applyLocation(
        location,
      );
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
            'Zoeken is tijdelijk niet beschikbaar.',
          ),
        ),
      );
    }
  }

  Future<void> _applyLocation(
    SearchLocation location,
  ) async {
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
        'deze locatie',
      );

      _results = sortedResults;
      _suggestions = [];
      _isSearching = false;
      // Een nieuwe zoekopdracht toont het overzicht, geen open kaart-paneel.
      _selectedIndex = null;
    });

    _animatedMapMove(
      LatLng(
        location.latitude,
        location.longitude,
      ),
      _zoomSearch,
    );
  }

  // ============================================================
  // AFSTAND
  // ============================================================

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
        sin(dLat / 2) *
                sin(dLat / 2) +
            cos(
                  _degreesToRadians(lat1),
                ) *
                cos(
                  _degreesToRadians(lat2),
                ) *
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

    return '${distance.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String _getShortLocationName(
    String displayName,
    String fallback,
  ) {
    final parts = displayName
        .split(',')
        .map(
          (part) => part.trim(),
        )
        .where(
          (part) => part.isNotEmpty,
        )
        .toList();

    if (parts.isNotEmpty) {
      return parts.first;
    }

    return fallback;
  }

  void _resetSearch() {
    _searchController.clear();

    final resetResults = breweries
        .map(
          (brewery) => BreweryResult(
            brewery: brewery,
            distance: 0,
          ),
        )
        .toList();

    setState(() {
      _searchedLocation = '';
      _suggestions = [];
      _results = resetResults;
      _selectedIndex = null;
    });

    _animatedMapMove(
      const LatLng(
        52.1326,
        5.2913,
      ),
      _zoomOverview,
    );
  }

  // ============================================================
  // UI
  // ============================================================

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
            options: MapOptions(
              initialCenter: const LatLng(
                52.1326,
                5.2913,
              ),
              initialZoom: 8,
              // Tikken op een leeg stuk kaart sluit het geopende kaart-paneel weer.
              onTap: (_, __) => _deselectBrewery(),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.bierkompas',
              ),
              MarkerLayer(
                markers: [
                  for (final entry in _results.asMap().entries)
                    Marker(
                      point: LatLng(
                        entry.value.brewery.latitude,
                        entry.value.brewery.longitude,
                      ),
                      width: entry.key == _selectedIndex ? 46 : 36,
                      height: entry.key == _selectedIndex ? 46 : 36,
                      child: GestureDetector(
                        onTap: () => _selectBrewery(
                          entry.key,
                          zoomIn: entry.key == _selectedIndex,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: entry.key == _selectedIndex
                                ? const Color(0xFFEFE6DD)
                                : const Color(0xFFD4B28C),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2C221C),
                              width: 2,
                            ),
                            boxShadow: entry.key == _selectedIndex
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD4B28C).withOpacity(0.6),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.sports_bar,
                            color: const Color(0xFF2C221C),
                            size: entry.key == _selectedIndex ? 20 : 16,
                          ),
                        ),
                      ),
                    ),
                ],
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
                          if (widget.onProfileTap !=
                              null)
                            ProfileAvatarButton(
                              onTap:
                                  widget.onProfileTap!,
                              avatarUrl:
                                  widget.avatarUrl,
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Brouwerijen in Nederland',
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
                            ? 'Zoek een stad, straat, postcode of provincie.'
                            : 'Brouwerijen vanaf $_searchedLocation, dichtstbijzijnde eerst.',
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
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    0,
                  ),
                  child: _buildSearchBox(),
                ),

                if (_loadingMoreBreweries)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4B28C)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Meer brouwerijen laden...',
                          style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            'Geen brouwerijen gevonden.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                            ),
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _selectedIndex == null
                              // Nog niets geselecteerd: alleen de kaart met
                              // pinnetjes, met een subtiel hintje.
                              ? Center(
                                  key: const ValueKey('map-hint'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C221C).withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sports_bar, color: Color(0xFFD4B28C), size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Tik op een bier-icoon voor details',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFEFE6DD),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              // Wel geselecteerd: het kaart-paneel, tik op de
                              // kaart om verder in te zoomen, swipe voor de
                              // volgende dichtbijzijnde brouwerij.
                              : Center(
                                  key: const ValueKey('brewery-cards'),
                                  child: SizedBox(
                                    height: 380,
                                    child: PageView(
                                      controller: _pageController,
                                      onPageChanged: _onCardPageChanged,
                                      children: [
                                        for (final entry in _results.asMap().entries)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => _selectBrewery(entry.key, zoomIn: true),
                                              child: _buildBreweryCard(
                                                brewery: entry.value.brewery,
                                                distance: entry.value.distance,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                ),

                const Padding(
                  padding:
                      EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      color: Color(
                        0xFF9E8A7D,
                      ),
                      fontSize: 10,
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

  Widget _buildSearchBox() {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          height: 46,
          decoration: BoxDecoration(
            color: const Color(
              0xFF2C221C,
            ),
            borderRadius:
                BorderRadius.circular(25),
            border: Border.all(
              color: const Color(
                0xFF3E312A,
              ),
            ),
          ),
          child: Row(
            children: [
              if (_isSearching ||
                  _isLoadingSuggestions)
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
                onPressed: _isSearching
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

              if (_searchController
                  .text
                  .isNotEmpty)
                GestureDetector(
                  onTap: _resetSearch,
                  child: const Icon(
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

        if (_suggestions.isNotEmpty)
          Container(
            margin:
                const EdgeInsets.only(
              top: 6,
            ),
            decoration:
                BoxDecoration(
              color: const Color(
                0xFF2C221C,
              ),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: const Color(
                  0xFF3E312A,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(
                    0.35,
                  ),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0;
                    i < _suggestions.length;
                    i++)
                  _buildSuggestion(
                    _suggestions[i],
                    i ==
                        _suggestions.length -
                            1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestion(
    SearchSuggestion suggestion,
    bool isLast,
  ) {
    final parts = suggestion.displayName
        .split(',')
        .map(
          (part) => part.trim(),
        )
        .where(
          (part) => part.isNotEmpty,
        )
        .toList();

    final title = parts.isNotEmpty
        ? parts.first
        : suggestion.displayName;

    final subtitle = parts.length > 1
        ? parts
            .skip(1)
            .take(2)
            .join(', ')
        : '';

    return InkWell(
      onTap: () =>
          _selectSuggestion(
        suggestion,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration:
            isLast
                ? null
                : const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(
                          0xFF3E312A,
                        ),
                      ),
                    ),
                  ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  const BoxDecoration(
                color: Color(
                  0xFF1E1712,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Color(
                  0xFFD4B28C,
                ),
                size: 18,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    const SizedBox(
                      height: 3,
                    ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          GoogleFonts.inter(
                        color:
                            const Color(
                          0xFF9E8A7D,
                        ),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            const Icon(
              Icons.north_west,
              color: Color(
                0xFF7A6355,
              ),
              size: 16,
            ),
          ],
        ),
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
        color: const Color(
          0xFF2C221C,
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: const Color(
            0xFF3E312A,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.4,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 4),
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
                  color: Color(
                    0xFF3E312A,
                  ),
                  borderRadius:
                      BorderRadius.vertical(
                    top: Radius.circular(
                      15,
                    ),
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
                        const EdgeInsets.all(
                      8,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.black
                          .withOpacity(
                        0.5,
                      ),
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
                          color:
                              Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          brewery.rating,
                          style:
                              GoogleFonts.inter(
                            color:
                                Colors.white,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(
                  height: 6,
                ),

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
                          color:
                              const Color(
                            0xFF9E8A7D,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 12,
                ),

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