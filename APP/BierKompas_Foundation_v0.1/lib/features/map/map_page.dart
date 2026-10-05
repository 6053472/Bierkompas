import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../favorites/favorites_service.dart';
import '../profile/cheers_service.dart';
import 'breweries.dart';
import 'brewery_submission_page.dart';
import 'brewery_submission_service.dart';
import 'event_map_service.dart';
import 'friend_location_service.dart';
import 'horeca.dart';
import 'horeca_submission_page.dart';
import 'horeca_submission_service.dart';
import '../../shared/profile_avatar_button.dart';

/// De weergaven van de kaart: alles samen, of per soort.
enum _MapTab { all, breweries, horeca, events, nearby }

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

class HorecaResult {
  final HorecaVenue venue;
  final double distance;

  const HorecaResult({
    required this.venue,
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
  final _brewerySubmissionService = BrewerySubmissionService();
  final _horecaSubmissionService = HorecaSubmissionService();
  final _eventMapService = EventMapService();
  final _friendLocationService = FriendLocationService();
  final _cheersService = CheersService();

  late final TabController _tabController;

  _MapTab get _activeTab => _MapTab.values[_tabController.index];

  List<EventPin> _events = [];
  // null = alle types tonen.
  String? _selectedEventType;
  static const _eventTypeFilters = [
    'Festival',
    'Proeverij',
    'Brouwersmarkt',
    'Lezing',
    'Bokbiertocht',
    'Bierwandeltocht',
  ];

  final _mapController = MapController();

  final _searchController = TextEditingController();

  final Set<int> _favoriteIds = {};
  final Set<int> _favoriteHorecaIds = {};

  List<BreweryResult> _results = [];
  List<HorecaResult> _horecaResults = [];
  List<NearbyFriend> _nearbyFriends = [];
  bool _locationSharingEnabled = false;
  Timer? _nearbyRefreshTimer;

  List<SearchSuggestion> _suggestions = [];

  Timer? _suggestionTimer;

  String _searchedLocation = '';

  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  // Toont alleen een klein "meer laden"-hintje; blokkeert de kaart niet meer,
  // want de publieke servers kunnen traag zijn.
  bool _loadingMoreBreweries = false;
  bool _loadingHoreca = false;
  bool _loadingNearby = false;
  // true als de lijst niet opgehaald kon worden -- dan tonen we een
  // duidelijke foutmelding met een "Opnieuw proberen"-knop i.p.v. stil een
  // lege kaart te laten zien.
  bool _breweriesLoadFailed = false;
  bool _horecaLoadFailed = false;

  // Zoomniveaus voor het selecteren van een pin op de kaart.
  static const _zoomOverview = 8.0;
  static const _zoomSearch = 11.0;
  static const _zoomNearby = 14.0;
  static const _zoomFocused = 17.0;

  // Maximale hoogte van het compacte lijstje bovenaan (onder de zoekbalk);
  // korter als er weinig items zijn, scrollbaar als er meer zijn. De rest van
  // de kaart blijft zo vrij voor knijp-zoomen.
  static const _maxPanelHeight = 230.0;

  // De lijst onder de zoekbalk verschijnt pas na een tik op de knop, zodat
  // de kaart standaard meer ruimte krijgt.
  bool _showPanel = false;

  // Zodra bekend (met toestemming): sorteert brouwerijen/horeca automatisch
  // op afstand, i.p.v. de willekeurige volgorde uit de datalijst te tonen.
  Position? _myPosition;

  // Highlight van het aangetikte item (lijst + pin).
  int? _selectedIndex;
  int? _selectedHorecaIndex;
  AnimationController? _mapAnimController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 5, vsync: this)..addListener(_onTabChanged);

    // Toon de lokale lijst meteen, zodat de kaart niet minutenlang leeg/aan
    // het laden lijkt terwijl er op de online data gewacht wordt.
    _results = breweries.map((brewery) => BreweryResult(brewery: brewery, distance: 0)).toList();

    _loadBreweries();
    _loadHoreca();
    _loadFavorites();
    _loadEvents();
    _startNearbyRefresh();
    _tryUseCurrentLocation();

    _searchController.addListener(_onSearchChanged);
  }

  // Herberekent de afstand van elk resultaat tot [_myPosition] en sorteert
  // van dichtbij naar ver. Zonder bekende locatie blijft de lijst ongewijzigd
  // (dan staat de volgorde uit de databron, zie _tryUseCurrentLocation).
  List<BreweryResult> _sortedBreweryResults(List<BreweryResult> results) {
    final pos = _myPosition;
    if (pos == null) return results;
    return results
        .map((r) => BreweryResult(
              brewery: r.brewery,
              distance: _calculateDistance(pos.latitude, pos.longitude, r.brewery.latitude, r.brewery.longitude),
            ))
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
  }

  List<HorecaResult> _sortedHorecaResults(List<HorecaResult> results) {
    final pos = _myPosition;
    if (pos == null) return results;
    return results
        .map((r) => HorecaResult(
              venue: r.venue,
              distance: _calculateDistance(pos.latitude, pos.longitude, r.venue.latitude, r.venue.longitude),
            ))
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
  }

  // Vraagt (stil, zonder foutmeldingen) de locatie van het toestel op zodat
  // brouwerijen/horeca standaard op afstand gesorteerd staan i.p.v. in de
  // willekeurige volgorde van de databron. Lukt dit niet (geen toestemming,
  // locatievoorziening uit, geen GPS-fix), dan blijft de lijst gewoon
  // ongesorteerd -- dit mag de kaart nooit blokkeren of een foutmelding geven.
  Future<void> _tryUseCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;

      setState(() {
        _myPosition = position;
        _results = _sortedBreweryResults(_results);
        _horecaResults = _sortedHorecaResults(_horecaResults);
        if (_searchedLocation.isEmpty) _searchedLocation = 'jouw locatie';
      });
    } catch (e) {
      debugPrint('Locatie ophalen voor kaart-sortering mislukt: $e');
    }
  }

  // Vrienden-locaties zijn zichtbaar op de "Alles"- en "Bierliefhebbers"-tab.
  void _startNearbyRefresh() {
    _loadNearbyFriends();
    _nearbyRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadNearbyFriends());
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _selectedIndex = null;
      _selectedHorecaIndex = null;
    });
    _nearbyRefreshTimer?.cancel();
    if (_activeTab == _MapTab.nearby || _activeTab == _MapTab.all) {
      _loadNearbyFriends();
      _nearbyRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadNearbyFriends());
    }
  }

  Future<void> _loadEvents() async {
    final events = await _eventMapService.fetchApprovedWithCoordinates();
    if (!mounted) return;
    setState(() => _events = events);
  }

  List<EventPin> get _visibleEvents {
    return _selectedEventType == null
        ? _events
        : _events.where((e) => e.eventType == _selectedEventType).toList();
  }

  IconData _iconForEventType(String type) {
    switch (type) {
      case 'Proeverij':
        return Icons.local_bar;
      case 'Brouwersmarkt':
        return Icons.storefront;
      case 'Lezing':
        return Icons.menu_book;
      case 'Bokbiertocht':
      case 'Bierwandeltocht':
        return Icons.directions_walk;
      case 'Festival':
      default:
        return Icons.celebration;
    }
  }

  Future<void> _openEventDetail(EventPin event) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C221C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _EventDetailSheet(event: event),
    );
  }

  Future<void> _openBreweryDetail(Brewery brewery) async {
    final isFavorite = _favoriteIds.contains(brewery.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C221C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _BreweryDetailSheet(
        brewery: brewery,
        isFavorite: isFavorite,
        onFavoriteTap: () => _toggleFavorite(brewery),
      ),
    );
  }

  Future<void> _openHorecaDetail(HorecaVenue venue) async {
    final isFavorite = _favoriteHorecaIds.contains(venue.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C221C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _HorecaDetailSheet(
        venue: venue,
        isFavorite: isFavorite,
        onFavoriteTap: () => _toggleHorecaFavorite(venue),
      ),
    );
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _nearbyRefreshTimer?.cancel();
    _mapAnimController?.dispose();
    _searchController.dispose();
    _tabController.dispose();
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

  void _selectBrewery(int index, {bool zoomIn = false}) {
    if (index < 0 || index >= _results.length) return;
    final brewery = _results[index].brewery;
    setState(() => _selectedIndex = index);
    _animatedMapMove(LatLng(brewery.latitude, brewery.longitude), zoomIn ? _zoomFocused : _zoomNearby);
  }

  void _deselectBrewery() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
  }

  void _selectHoreca(int index, {bool zoomIn = false}) {
    if (index < 0 || index >= _horecaResults.length) return;
    final venue = _horecaResults[index].venue;
    setState(() => _selectedHorecaIndex = index);
    _animatedMapMove(LatLng(venue.latitude, venue.longitude), zoomIn ? _zoomFocused : _zoomNearby);
  }

  void _deselectHoreca() {
    if (_selectedHorecaIndex == null) return;
    setState(() => _selectedHorecaIndex = null);
  }

  void _deselectOnMapTap() {
    _deselectBrewery();
    _deselectHoreca();
  }

  // ============================================================
  // BROUWERIJEN
  // ============================================================

  // Haalt brouwerijen op: alleen zelf aangemelde en door een beheerder
  // goedgekeurde brouwerijen (zie brewery_submission_service.dart). Er wordt
  // bewust geen automatische externe brouwerij-databron (meer) gebruikt.
  Future<void> _loadBreweries() async {
    setState(() {
      _loadingMoreBreweries = true;
      _breweriesLoadFailed = false;
    });

    try {
      final submittedBreweries = await _brewerySubmissionService.fetchApproved();

      final allBreweries = [...breweries, ...submittedBreweries];

      final unique = <String, Brewery>{};
      for (final brewery in allBreweries) {
        final key = '${brewery.title.toLowerCase()}_${brewery.latitude.toStringAsFixed(4)}_${brewery.longitude.toStringAsFixed(4)}';
        unique[key] = brewery;
      }

      final result = _sortedBreweryResults(unique.values.map((brewery) => BreweryResult(brewery: brewery, distance: 0)).toList());

      if (!mounted) return;
      setState(() {
        _results = result;
        _loadingMoreBreweries = false;
        _breweriesLoadFailed = false;
      });
    } catch (e) {
      debugPrint('Brouwerijen laden mislukt: $e');
      if (!mounted) return;
      setState(() {
        _loadingMoreBreweries = false;
        _breweriesLoadFailed = _results.isEmpty;
      });
    }
  }

  // ============================================================
  // HORECA
  // ============================================================

  // Haalt horecagelegenheden op: alleen zelf aangemelde en door een
  // beheerder goedgekeurde gelegenheden (zie horeca_submission_service.dart).
  Future<void> _loadHoreca() async {
    setState(() {
      _loadingHoreca = true;
      _horecaLoadFailed = false;
    });

    try {
      final venues = await _horecaSubmissionService.fetchApproved();
      final result = _sortedHorecaResults(venues.map((venue) => HorecaResult(venue: venue, distance: 0)).toList());

      if (!mounted) return;
      setState(() {
        _horecaResults = result;
        _loadingHoreca = false;
        _horecaLoadFailed = false;
      });
    } catch (e) {
      debugPrint('Horeca laden mislukt: $e');
      if (!mounted) return;
      setState(() {
        _loadingHoreca = false;
        _horecaLoadFailed = _horecaResults.isEmpty;
      });
    }
  }

  Future<void> _openHorecaSubmission() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HorecaSubmissionPage()),
    );
    // Na terugkomen niets vernieuwen: de aanmelding moet eerst door een
    // beheerder goedgekeurd worden voordat hij op de kaart verschijnt.
  }

  // ============================================================
  // BIERLIEFHEBBERS IN DE BUURT
  // ============================================================

  Future<void> _loadNearbyFriends() async {
    setState(() => _loadingNearby = true);
    try {
      final sharing = await _friendLocationService.isSharingEnabled();
      if (sharing) {
        await _friendLocationService.pushCurrentLocation();
      }
      final nearby = await _friendLocationService.fetchNearby();
      if (!mounted) return;
      setState(() {
        _locationSharingEnabled = sharing;
        _nearbyFriends = nearby;
        _loadingNearby = false;
      });
    } catch (e) {
      debugPrint('Bierliefhebbers laden mislukt: $e');
      if (!mounted) return;
      setState(() => _loadingNearby = false);
    }
  }

  Future<void> _sendCheer(NearbyFriend friend) async {
    try {
      await _cheersService.sendCheer(friend.friendId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost verstuurd naar ${friend.name}! \u{1F37B}')),
      );
    } on CheersException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proost versturen mislukt: $e')));
    }
  }

  void _focusNearbyFriend(NearbyFriend friend) {
    _animatedMapMove(LatLng(friend.latitude, friend.longitude), _zoomFocused);
  }

  // ============================================================
  // FAVORIETEN
  // ============================================================

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final favorites = await _favoritesService.list(user.id);
      if (!mounted) return;
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(
            favorites.where((favorite) => favorite.itemType == breweryItemType).map((favorite) => favorite.itemId),
          );
        _favoriteHorecaIds
          ..clear()
          ..addAll(
            favorites.where((favorite) => favorite.itemType == horecaItemType).map((favorite) => favorite.itemId),
          );
      });
    } on FavoritesException catch (e) {
      debugPrint('Fout bij ophalen favorieten: $e');
    }
  }

  Future<void> _toggleHorecaFavorite(HorecaVenue venue) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je moet ingelogd zijn om favorieten te gebruiken.')),
      );
      return;
    }

    final wasFavorite = _favoriteHorecaIds.contains(venue.id);

    setState(() {
      if (wasFavorite) {
        _favoriteHorecaIds.remove(venue.id);
      } else {
        _favoriteHorecaIds.add(venue.id);
      }
    });

    try {
      if (wasFavorite) {
        await _favoritesService.remove(userId: user.id, itemType: horecaItemType, itemId: venue.id);
      } else {
        await _favoritesService.add(userId: user.id, itemType: horecaItemType, itemId: venue.id);
      }
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteHorecaIds.add(venue.id);
        } else {
          _favoriteHorecaIds.remove(venue.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favoriet opslaan mislukt: $e')));
    }
  }

  Future<void> _toggleFavorite(Brewery brewery) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je moet ingelogd zijn om favorieten te gebruiken.')),
      );
      return;
    }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favoriet opslaan mislukt: $e')));
    }
  }

  // ============================================================
  // AUTOCOMPLETE
  // ============================================================

  void _onSearchChanged() {
    final query = _searchController.text.trim();
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

    setState(() => _isLoadingSuggestions = true);
    _suggestionTimer = Timer(const Duration(milliseconds: 500), () => _loadSuggestions(query));
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent('$query, Nederland');
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$encodedQuery&format=json&limit=5&countrycodes=nl&addressdetails=1',
      );

      final response = await http.get(uri, headers: const {'User-Agent': 'BierKompas/1.0'});
      if (response.statusCode != 200) {
        throw Exception('Nominatim ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      final suggestions = <SearchSuggestion>[];

      for (final item in data) {
        final latitude = double.tryParse(item['lat'].toString());
        final longitude = double.tryParse(item['lon'].toString());
        if (latitude == null || longitude == null) continue;

        suggestions.add(SearchSuggestion(
          displayName: item['display_name'].toString(),
          latitude: latitude,
          longitude: longitude,
        ));
      }

      if (!mounted) return;
      if (_searchController.text.trim() != query) return;

      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      debugPrint('Autocomplete mislukt: $e');
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _selectSuggestion(SearchSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _searchController.text = _getShortLocationName(suggestion.displayName, suggestion.displayName);

    setState(() {
      _suggestions = [];
      _isSearching = true;
    });

    await _applyLocation(SearchLocation(
      displayName: suggestion.displayName,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
    ));
  }

  // ============================================================
  // ZOEKEN
  // ============================================================

  Future<SearchLocation?> _geocodeLocation(String query) async {
    final encodedQuery = Uri.encodeQueryComponent('$query, Nederland');
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$encodedQuery&format=json&limit=1&countrycodes=nl&addressdetails=1',
    );

    final response = await http.get(uri, headers: const {'User-Agent': 'BierKompas/1.0'});
    if (response.statusCode != 200) {
      throw Exception('Nominatim fout: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    if (data.isEmpty) return null;

    final result = data.first;
    final latitude = double.tryParse(result['lat'].toString());
    final longitude = double.tryParse(result['lon'].toString());
    if (latitude == null || longitude == null) return null;

    return SearchLocation(displayName: result['display_name'].toString(), latitude: latitude, longitude: longitude);
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _isSearching = true;
    });

    try {
      final location = await _geocodeLocation(query);
      if (location == null) {
        if (!mounted) return;
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Locatie niet gevonden.')));
        return;
      }
      await _applyLocation(location);
    } catch (e) {
      debugPrint('Zoeken mislukt: $e');
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zoeken is tijdelijk niet beschikbaar.')));
    }
  }

  Future<void> _applyLocation(SearchLocation location) async {
    final sortedResults = _results.map((result) {
      final distance = _calculateDistance(location.latitude, location.longitude, result.brewery.latitude, result.brewery.longitude);
      return BreweryResult(brewery: result.brewery, distance: distance);
    }).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    final sortedHoreca = _horecaResults.map((result) {
      final distance = _calculateDistance(location.latitude, location.longitude, result.venue.latitude, result.venue.longitude);
      return HorecaResult(venue: result.venue, distance: distance);
    }).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (!mounted) return;

    setState(() {
      _searchedLocation = _getShortLocationName(location.displayName, 'deze locatie');
      _results = sortedResults;
      _horecaResults = sortedHoreca;
      _suggestions = [];
      _isSearching = false;
      // Een nieuwe zoekopdracht toont het overzicht, geen open kaart-paneel.
      _selectedIndex = null;
      _selectedHorecaIndex = null;
    });

    _animatedMapMove(LatLng(location.latitude, location.longitude), _zoomSearch);
  }

  // ============================================================
  // AFSTAND
  // ============================================================

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
    return '${distance.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String _formatUpdatedAgo(DateTime updatedAt) {
    final diff = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (diff.inMinutes < 1) return 'zojuist';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${diff.inDays} dagen geleden';
  }

  String _getShortLocationName(String displayName, String fallback) {
    final parts = displayName.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.first;
    return fallback;
  }

  void _resetSearch() {
    _searchController.clear();

    final resetResults = _sortedBreweryResults(breweries.map((brewery) => BreweryResult(brewery: brewery, distance: 0)).toList());
    final resetHoreca = _sortedHorecaResults(_horecaResults.map((result) => HorecaResult(venue: result.venue, distance: 0)).toList());

    setState(() {
      _searchedLocation = _myPosition != null ? 'jouw locatie' : '';
      _suggestions = [];
      _results = resetResults;
      _horecaResults = resetHoreca;
      _selectedIndex = null;
      _selectedHorecaIndex = null;
    });

    _animatedMapMove(const LatLng(52.1326, 5.2913), _zoomOverview);
  }

  Future<void> _openBrewerySubmission() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrewerySubmissionPage()));
    // Na terugkomen niets vernieuwen: de aanmelding moet eerst door een
    // beheerder goedgekeurd worden voordat hij op de kaart verschijnt.
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(52.1326, 5.2913),
              initialZoom: 8,
              // Tikken op een leeg stuk kaart sluit het geopende kaart-paneel weer.
              onTap: (_, __) => _deselectOnMapTap(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bierkompas',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C221C),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sports_bar, color: Color(0xFFD4B28C), size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kaart',
                              style: GoogleFonts.playfairDisplay(color: const Color(0xFFEFE6DD), fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (widget.onProfileTap != null)
                            ProfileAvatarButton(onTap: widget.onProfileTap!, avatarUrl: widget.avatarUrl),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchedLocation.isEmpty
                            ? 'Ontdek de biercultuur bij jou in de buurt.'
                            : 'Resultaten vanaf $_searchedLocation, dichtstbijzijnde eerst.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: const Color(0xFFD4B28C),
                        labelColor: const Color(0xFFD4B28C),
                        unselectedLabelColor: const Color(0xFF9E8A7D),
                        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                        tabAlignment: TabAlignment.start,
                        // Emoji i.p.v. Material-icons: die renderden in de
                        // release-build voor Horeca/Bierliefhebbers leeg.
                        tabs: const [
                          Tab(icon: Text('\u{1F5FA}\u{FE0F}', style: TextStyle(fontSize: 18)), text: 'Alles'),
                          Tab(icon: Text('\u{1F37A}', style: TextStyle(fontSize: 18)), text: 'Brouwerijen'),
                          Tab(icon: Text('\u{1F37D}\u{FE0F}', style: TextStyle(fontSize: 18)), text: 'Horeca'),
                          Tab(icon: Text('\u{1F4C5}', style: TextStyle(fontSize: 18)), text: 'Activiteiten'),
                          Tab(icon: Text('\u{1F37B}', style: TextStyle(fontSize: 18)), text: 'Bierliefhebbers'),
                        ],
                      ),
                    ],
                  ),
                ),

                if ((_activeTab == _MapTab.events || _activeTab == _MapTab.all) && _events.isNotEmpty) _buildEventTypeFilters(),

                if (_activeTab != _MapTab.nearby)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildSearchBox(),
                  ),

                if ((_activeTab == _MapTab.breweries || _activeTab == _MapTab.all) && _loadingMoreBreweries) _buildLoadingHint('Brouwerijen laden...'),
                if ((_activeTab == _MapTab.horeca || _activeTab == _MapTab.all) && _loadingHoreca) _buildLoadingHint('Horeca laden...'),
                if (_activeTab == _MapTab.nearby && _loadingNearby) _buildLoadingHint('Bierliefhebbers zoeken...'),

                // De lijst blijft ingeklapt tot de gebruiker er zelf om vraagt,
                // zodat de kaart standaard zoveel mogelijk ruimte krijgt.
                if (!_showPanel)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildShowPanelButton(),
                  )
                else
                  // Compact lijstje direct onder de zoekbalk; alleen zo hoog als
                  // nodig. Horizontaal vegen erop wisselt van tab. Geen
                  // TabBarView/Expanded: dat claimt de hele kaart als veeggebied
                  // en blokkeert het knijp-zoomen.
                  GestureDetector(
                    onHorizontalDragEnd: _onPanelSwipe,
                    behavior: HitTestBehavior.deferToChild,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: _maxPanelHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHidePanelButton(),
                          Flexible(child: _buildActivePanel()),
                        ],
                      ),
                    ),
                  ),

                const Spacer(),

                const Padding(
                  padding: EdgeInsets.only(bottom: 8, top: 4),
                  child: Text('© OpenStreetMap contributors', style: TextStyle(color: Color(0xFF9E8A7D), fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    switch (_activeTab) {
      case _MapTab.breweries:
        return FloatingActionButton.extended(
          onPressed: _openBrewerySubmission,
          backgroundColor: const Color(0xFFD4B28C),
          foregroundColor: const Color(0xFF1E1712),
          icon: const Icon(Icons.add),
          label: const Text('Brouwerij toevoegen'),
        );
      case _MapTab.horeca:
        return FloatingActionButton.extended(
          onPressed: _openHorecaSubmission,
          backgroundColor: const Color(0xFFD4B28C),
          foregroundColor: const Color(0xFF1E1712),
          icon: const Icon(Icons.add),
          label: const Text('Horeca toevoegen'),
        );
      case _MapTab.all:
      case _MapTab.events:
      case _MapTab.nearby:
        return null;
    }
  }

  String _panelToggleLabel() {
    switch (_activeTab) {
      case _MapTab.all:
        return 'Toon overzicht';
      case _MapTab.breweries:
        return 'Brouwerijen in de buurt';
      case _MapTab.horeca:
        return 'Horeca in de buurt';
      case _MapTab.events:
        return 'Evenementen bekijken';
      case _MapTab.nearby:
        return 'Bierliefhebbers bekijken';
    }
  }

  Widget _buildShowPanelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _showPanel = true),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD4B28C),
          side: const BorderSide(color: Color(0xFF3E312A)),
          backgroundColor: const Color(0xFF2C221C),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.list),
        label: Text(_panelToggleLabel(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildHidePanelButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_panelToggleLabel(),
              style: GoogleFonts.inter(color: const Color(0xFFEFE6DD), fontWeight: FontWeight.bold, fontSize: 13)),
          TextButton.icon(
            onPressed: () => setState(() => _showPanel = false),
            icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF9E8A7D), size: 18),
            label: Text('Verbergen', style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHint(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4B28C))),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 12)),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    switch (_activeTab) {
      case _MapTab.all:
        return [..._breweryMarkers(), ..._horecaMarkers(), ..._eventMarkers(), ..._friendMarkers()];
      case _MapTab.breweries:
        return _breweryMarkers();
      case _MapTab.horeca:
        return _horecaMarkers();
      case _MapTab.events:
        return _eventMarkers();
      case _MapTab.nearby:
        return _friendMarkers();
    }
  }

  List<Marker> _breweryMarkers() {
        return [
          for (final entry in _results.asMap().entries)
            Marker(
              point: LatLng(entry.value.brewery.latitude, entry.value.brewery.longitude),
              width: entry.key == _selectedIndex ? 46 : 36,
              height: entry.key == _selectedIndex ? 46 : 36,
              child: GestureDetector(
                onTap: () {
                  _selectBrewery(entry.key, zoomIn: entry.key == _selectedIndex);
                  _openBreweryDetail(entry.value.brewery);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: entry.key == _selectedIndex ? const Color(0xFFEFE6DD) : const Color(0xFFD4B28C),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2C221C), width: 2),
                    boxShadow: entry.key == _selectedIndex
                        ? [BoxShadow(color: const Color(0xFFD4B28C).withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]
                        : null,
                  ),
                  child: Icon(Icons.sports_bar, color: const Color(0xFF2C221C), size: entry.key == _selectedIndex ? 20 : 16),
                ),
              ),
            ),
        ];
  }

  List<Marker> _horecaMarkers() {
        return [
          for (final entry in _horecaResults.asMap().entries)
            Marker(
              point: LatLng(entry.value.venue.latitude, entry.value.venue.longitude),
              width: entry.key == _selectedHorecaIndex ? 46 : 36,
              height: entry.key == _selectedHorecaIndex ? 46 : 36,
              child: GestureDetector(
                onTap: () {
                  _selectHoreca(entry.key, zoomIn: entry.key == _selectedHorecaIndex);
                  _openHorecaDetail(entry.value.venue);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: entry.key == _selectedHorecaIndex ? const Color(0xFFEFE6DD) : const Color(0xFFD4B28C),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2C221C), width: 2),
                    boxShadow: entry.key == _selectedHorecaIndex
                        ? [BoxShadow(color: const Color(0xFFD4B28C).withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]
                        : null,
                  ),
                  child: Center(child: Text('\u{1F37D}\u{FE0F}', style: TextStyle(fontSize: entry.key == _selectedHorecaIndex ? 20 : 16))),
                ),
              ),
            ),
        ];
  }

  List<Marker> _eventMarkers() {
        return [
          for (final event in _visibleEvents)
            Marker(
              point: LatLng(event.latitude, event.longitude),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => _openEventDetail(event),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4B28C),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2C221C), width: 2),
                  ),
                  child: Icon(_iconForEventType(event.eventType), color: const Color(0xFF2C221C), size: 16),
                ),
              ),
            ),
        ];
  }

  List<Marker> _friendMarkers() {
        return [
          for (final friend in _nearbyFriends)
            Marker(
              point: LatLng(friend.latitude, friend.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _focusNearbyFriend(friend),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD4B28C), width: 2),
                    color: const Color(0xFF2C221C),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: friend.avatarUrl != null
                      ? Image.network(
                          friend.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFFD4B28C)),
                        )
                      : const Icon(Icons.person, color: Color(0xFFD4B28C)),
                ),
              ),
            ),
        ];
  }

  Widget _buildEventTypeFilters() {
    final types = ['Alle types', ..._eventTypeFilters];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: types.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final type = types[index];
            final isAll = type == 'Alle types';
            final selected = isAll ? _selectedEventType == null : _selectedEventType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedEventType = isAll ? null : type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFD4B28C) : const Color(0xFF2C221C).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    type.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: selected ? const Color(0xFF1E1712) : const Color(0xFFEFE6DD),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // PANELEN PER TAB
  // ============================================================

  void _onPanelSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return;
    final next = _tabController.index + (velocity < 0 ? 1 : -1);
    if (next < 0 || next >= _tabController.length) return;
    _tabController.animateTo(next);
  }

  Widget _buildActivePanel() {
    switch (_activeTab) {
      case _MapTab.all:
        return _buildAllPanel();
      case _MapTab.breweries:
        return _buildBreweryPanel();
      case _MapTab.horeca:
        return _buildHorecaPanel();
      case _MapTab.events:
        return _buildEventsPanel();
      case _MapTab.nearby:
        return _buildNearbyPanel();
    }
  }

  Widget _buildEmptyState({required String emoji, required String message, bool showRetry = false, VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C221C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3E312A)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: const Color(0xFFEFE6DD), fontSize: 12, height: 1.4),
              ),
            ),
            if (showRetry)
              TextButton(
                onPressed: onRetry,
                child: Text('Opnieuw', style: GoogleFonts.inter(color: const Color(0xFFD4B28C), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactList({required int itemCount, required IndexedWidgetBuilder itemBuilder}) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: itemBuilder,
    );
  }

  Widget _buildAllPanel() {
    final events = _visibleEvents;
    final tiles = <Widget>[
      for (var i = 0; i < _results.length; i++) _buildBreweryTile(i, _results[i]),
      for (var i = 0; i < _horecaResults.length; i++) _buildHorecaTile(i, _horecaResults[i]),
      for (final event in events) _buildEventTile(event),
      if (_locationSharingEnabled) for (final friend in _nearbyFriends) _buildNearbyFriendTile(friend),
    ];

    if (tiles.isEmpty) {
      return _buildEmptyState(
        emoji: '\u{1F5FA}\u{FE0F}',
        message: 'Nog niets gevonden. Meld een brouwerij of horeca aan, of maak een evenement aan via de Agenda!',
      );
    }

    return _buildCompactList(itemCount: tiles.length, itemBuilder: (context, index) => tiles[index]);
  }

  Widget _buildBreweryPanel() {
    if (_breweriesLoadFailed) {
      return _buildEmptyState(
        emoji: '\u{1F4E1}',
        message: 'Kon brouwerijen niet laden. Controleer je internetverbinding.',
        showRetry: true,
        onRetry: _loadingMoreBreweries ? null : _loadBreweries,
      );
    }
    if (_results.isEmpty) {
      return _buildEmptyState(
        emoji: '\u{1F37A}',
        message: 'Nog geen brouwerijen gevonden. Meld de eerste aan met de knop "Brouwerij toevoegen" hieronder!',
      );
    }

    return _buildCompactList(
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildBreweryTile(index, _results[index]),
    );
  }

  Widget _buildHorecaPanel() {
    if (_horecaLoadFailed) {
      return _buildEmptyState(
        emoji: '\u{1F4E1}',
        message: 'Kon horeca niet laden. Controleer je internetverbinding.',
        showRetry: true,
        onRetry: _loadingHoreca ? null : _loadHoreca,
      );
    }
    if (_horecaResults.isEmpty) {
      return _buildEmptyState(
        emoji: '\u{1F37D}\u{FE0F}',
        message: 'Nog geen horeca gevonden. Meld de eerste aan met de knop "Horeca toevoegen" hieronder!',
      );
    }

    return _buildCompactList(
      itemCount: _horecaResults.length,
      itemBuilder: (context, index) => _buildHorecaTile(index, _horecaResults[index]),
    );
  }

  Widget _buildEventsPanel() {
    final events = _visibleEvents;
    if (events.isEmpty) {
      return _buildEmptyState(
        emoji: '\u{1F4C5}',
        message: 'Nog geen evenementen gevonden. Maak er een aan via de "+"-knop op de Agenda-pagina!',
      );
    }

    return _buildCompactList(
      itemCount: events.length,
      itemBuilder: (context, index) => _buildEventTile(events[index]),
    );
  }

  Widget _buildNearbyPanel() {
    if (_loadingNearby) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4B28C)),
        ),
      );
    }
    if (!_locationSharingEnabled) {
      return _buildEmptyState(
        emoji: '\u{1F4CD}',
        message:
            'Zet "Deel mijn locatie met vrienden" aan bij Instellingen > Voorkeuren om te zien welke vrienden dichtbij zijn.',
      );
    }
    if (_nearbyFriends.isEmpty) {
      return _buildEmptyState(
        emoji: '\u{1F37B}',
        message: 'Nog geen vrienden die hun locatie delen dichtbij.',
      );
    }

    return _buildCompactList(
      itemCount: _nearbyFriends.length,
      itemBuilder: (context, index) => _buildNearbyFriendTile(_nearbyFriends[index]),
    );
  }

  Widget _buildBreweryTile(int index, BreweryResult result) {
    final brewery = result.brewery;
    final isFavorite = _favoriteIds.contains(brewery.id);
    final selected = index == _selectedIndex;
    final subtitle = _searchedLocation.isEmpty ? brewery.location : '${_formatDistance(result.distance)} vanaf $_searchedLocation';

    return InkWell(
      onTap: () {
        _selectBrewery(index, zoomIn: true);
        _openBreweryDetail(brewery);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C221C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFFD4B28C) : const Color(0xFF3E312A)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFF1E1712), borderRadius: BorderRadius.circular(10)),
              clipBehavior: Clip.antiAlias,
              child: brewery.imageUrl != null
                  ? Image.network(
                      brewery.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Text('\u{1F37A}', style: TextStyle(fontSize: 20))),
                    )
                  : const Center(child: Text('\u{1F37A}', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brewery.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 12)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _toggleFavorite(brewery),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? const Color(0xFFD4B28C) : const Color(0xFF9E8A7D), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorecaTile(int index, HorecaResult result) {
    final venue = result.venue;
    final selected = index == _selectedHorecaIndex;
    final subtitle = _searchedLocation.isEmpty ? venue.location : '${_formatDistance(result.distance)} vanaf $_searchedLocation';

    return InkWell(
      onTap: () {
        _selectHoreca(index, zoomIn: true);
        _openHorecaDetail(venue);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C221C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFFD4B28C) : const Color(0xFF3E312A)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFF1E1712), borderRadius: BorderRadius.circular(10)),
              clipBehavior: Clip.antiAlias,
              child: venue.imageUrl != null
                  ? Image.network(
                      venue.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Text('\u{1F37D}\u{FE0F}', style: TextStyle(fontSize: 20))),
                    )
                  : const Center(child: Text('\u{1F37D}\u{FE0F}', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(EventPin event) {
    return InkWell(
      onTap: () => _openEventDetail(event),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C221C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3E312A)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: Color(0xFF1E1712), shape: BoxShape.circle),
              child: Icon(_iconForEventType(event.eventType), color: const Color(0xFFD4B28C), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    event.city != null ? '${event.eventType} • ${event.city}' : event.eventType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9E8A7D)),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyFriendTile(NearbyFriend friend) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3E312A)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _focusNearbyFriend(friend),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1E1712),
              backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
              child: friend.avatarUrl == null ? const Icon(Icons.person, color: Color(0xFFD4B28C)) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Locatie bijgewerkt: ${_formatUpdatedAgo(friend.updatedAt)}', style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 11)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _sendCheer(friend),
            icon: const Text('\u{1F37B}', style: TextStyle(fontSize: 14)),
            label: Text('Proost', style: GoogleFonts.inter(color: const Color(0xFFD4B28C), fontWeight: FontWeight.bold, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD4B28C)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF2C221C),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFF3E312A)),
          ),
          child: Row(
            children: [
              if (_isSearching || _isLoadingSuggestions)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4B28C)))
              else
                const Icon(Icons.search, color: Color(0xFF9E8A7D), size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _searchLocation(),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  cursorColor: const Color(0xFFD4B28C),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Zoek stad, straat, postcode...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSearching ? null : _searchLocation,
                icon: const Icon(Icons.arrow_forward, color: Color(0xFFD4B28C), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: _resetSearch,
                  child: const Icon(Icons.close, color: Color(0xFF9E8A7D), size: 18),
                ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2C221C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3E312A)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                for (int i = 0; i < _suggestions.length; i++) _buildSuggestion(_suggestions[i], i == _suggestions.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestion(SearchSuggestion suggestion, bool isLast) {
    final parts = suggestion.displayName.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    final title = parts.isNotEmpty ? parts.first : suggestion.displayName;
    final subtitle = parts.length > 1 ? parts.skip(1).take(2).join(', ') : '';

    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF3E312A)))),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Color(0xFF1E1712), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_outlined, color: Color(0xFFD4B28C), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) const SizedBox(height: 3),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.north_west, color: Color(0xFF7A6355), size: 16),
          ],
        ),
      ),
    );
  }
}

/// Bottomsheet met brouwerij-details, geopend vanaf een pin of lijstrij.
class _BreweryDetailSheet extends StatelessWidget {
  const _BreweryDetailSheet({required this.brewery, required this.isFavorite, required this.onFavoriteTap});

  final Brewery brewery;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  static const _primary = Color(0xFFD4B28C);
  static const _onSurface = Color(0xFFEFE6DD);
  static const _onSurfaceVariant = Color(0xFF9E8A7D);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: brewery.imageUrl != null
                        ? Image.network(
                            brewery.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Text('\u{1F37A}', style: TextStyle(fontSize: 48))),
                          )
                        : const ColoredBox(color: Color(0xFF3E312A), child: Center(child: Text('\u{1F37A}', style: TextStyle(fontSize: 48)))),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? _primary : Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brewery.title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: _onSurfaceVariant, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(brewery.location, style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13))),
                      if (brewery.founded != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.history_edu_outlined, color: _onSurfaceVariant, size: 16),
                        const SizedBox(width: 4),
                        Text('Sinds ${brewery.founded}', style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13)),
                      ],
                    ],
                  ),
                  if (brewery.about.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(brewery.about, style: GoogleFonts.inter(color: _onSurface, fontSize: 14, height: 1.5)),
                  ],
                  if (brewery.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: brewery.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: const Color(0xFF1E1712), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF3E312A))),
                                child: Text(tag, style: GoogleFonts.inter(color: _primary, fontSize: 11, fontWeight: FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (brewery.facts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('WEETJES', style: GoogleFonts.inter(color: _primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    for (final fact in brewery.facts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: _primary)),
                            Expanded(child: Text(fact, style: GoogleFonts.inter(color: _onSurface, fontSize: 13, height: 1.4))),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottomsheet met horeca-details, geopend vanaf een pin of lijstrij.
class _HorecaDetailSheet extends StatelessWidget {
  const _HorecaDetailSheet({required this.venue, required this.isFavorite, required this.onFavoriteTap});

  final HorecaVenue venue;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  static const _primary = Color(0xFFD4B28C);
  static const _onSurface = Color(0xFFEFE6DD);
  static const _onSurfaceVariant = Color(0xFF9E8A7D);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: venue.imageUrl != null
                        ? Image.network(
                            venue.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Text('\u{1F37D}\u{FE0F}', style: TextStyle(fontSize: 48))),
                          )
                        : const ColoredBox(color: Color(0xFF3E312A), child: Center(child: Text('\u{1F37D}\u{FE0F}', style: TextStyle(fontSize: 48)))),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? _primary : Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
                  if (venue.location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: _onSurfaceVariant, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(venue.location, style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13))),
                      ],
                    ),
                  ],
                  if (venue.about.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(venue.about, style: GoogleFonts.inter(color: _onSurface, fontSize: 14, height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottomsheet met evenement-details, geopend vanaf een pin op de kaart.
class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({required this.event});

  final EventPin event;

  static const _primary = Color(0xFFD4B28C);
  static const _onSurface = Color(0xFFEFE6DD);
  static const _onSurfaceVariant = Color(0xFF9E8A7D);

  Future<void> _openRoute() async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(DateTime date) {
    const months = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day} ${months[date.month - 1]} • $time';
  }

  @override
  Widget build(BuildContext context) {
    final prices = <String>[
      if (event.ticketRegular != null) 'Regulier €${event.ticketRegular!.toStringAsFixed(2)}',
      if (event.ticketBeer != null) 'Bierpakket €${event.ticketBeer!.toStringAsFixed(2)}',
      if (event.ticketVip != null) 'VIP €${event.ticketVip!.toStringAsFixed(2)}',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _primary.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(event.eventType.toUpperCase(), style: GoogleFonts.inter(color: _primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text(event.name, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${_formatDate(event.startDate)}${event.city != null ? ' • ${event.city}' : ''}', style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13)),
            if (event.locationName != null && event.locationName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(event.locationName!, style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13)),
            ],
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(event.description!, maxLines: 4, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: _onSurface, fontSize: 14, height: 1.4)),
            ],
            if (prices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prices
                    .map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF3C3028), borderRadius: BorderRadius.circular(8)),
                          child: Text(p, style: GoogleFonts.inter(color: _onSurface, fontSize: 12)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openRoute,
                icon: const Icon(Icons.directions, color: _primary, size: 18),
                label: Text('Route (Google)', style: GoogleFonts.inter(color: _primary, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
