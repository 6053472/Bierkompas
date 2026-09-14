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
  final _favoritesService = FavoritesService();
  final _pageController = PageController(viewportFraction: 0.86);
  final Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  // Het hartje wisselt meteen; mislukt het opslaan, dan wordt het teruggezet.
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
                  child: Center(
                    child: SizedBox(
                      height: 380,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          for (final brewery in breweries)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                              child: _buildBreweryCard(
                                title: brewery.title,
                                distance: brewery.distance,
                                rating: brewery.rating,
                                tags: brewery.tags,
                                isFavorite: _favoriteIds.contains(brewery.id),
                                onFavoriteTap: () => _toggleFavorite(brewery),
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