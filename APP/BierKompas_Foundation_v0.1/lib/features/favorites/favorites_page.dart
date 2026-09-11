import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/feed_card.dart';
import '../feed/feed_service.dart';
import '../map/breweries.dart';
import 'beers.dart';
import 'favorites_service.dart';

// Kleuren uit het "Artisanal Draught" design system (DESIGN.md).
const _background = Color(0xFF1C110A);
const _primary = Color(0xFFFBB97B);
const _surfaceContainerHigh = Color(0xFF35271F);
const _onSurface = Color(0xFFF6DED1);
const _onSurfaceVariant = Color(0xFFD6C3B5);
const _outlineVariant = Color(0xFF51443A);
const _secondaryContainer = Color(0xFF5D4339);
const _glass = Color(0xB32C1810); // rgba(44, 24, 16, 0.7)

const _heroImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDknuVmwDTa5jB4wik1JsFZcg3HGHEguJ8tKYPIGvMOxeMgWo55nIZ92P0i_iTaZK5gCmhHDfSDDGd8HAgulU_Nt_waa4YIg1QNZCDQnGG9J70xbRh0XNaZFjxojqCPad3s7iiMSHzET5kRpj3GQcD9-hE4MuWtaKdUaP4Wkk6S1kxJhurPAITpPBmmuOIAnJ0_rU6wNjOB6JuYsppLKZZ370oFdfVTbvOpttwPVmC3aU02O1rJkSR2';

class _Event {
  final String title;
  final String price;
  final IconData icon;
  final String date;
  final String description;

  const _Event(this.title, this.price, this.icon, this.date, this.description);
}

const _events = [
  _Event('Herfst Bock Proeverij', '€22,50', Icons.calendar_today_outlined, '12 November 2024',
      'Ontdek onze nieuwste bockbieren gecombineerd met ambachtelijke hapjes.'),
  _Event('Brouwerij Tour & Diner', '€45,00', Icons.event_repeat_outlined, 'Elke Vrijdag',
      'Een exclusieve kijk achter de schermen gevolgd door een 3-gangen keuzemenu.'),
];

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _favoritesService = FavoritesService();
  final _feedService = FeedService();
  final Set<int> _beerIds = {};
  final Set<int> _breweryIds = {};
  List<FeedItem> _feedItems = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    try {
      final favorites = user == null ? <FavoriteItem>[] : await _favoritesService.list(user.id);
      final feedKeys = favorites
          .map((f) => FeedItem.keyForFavorite(f.itemType, f.itemId))
          .whereType<String>()
          .toList();
      final feedItems = feedKeys.isEmpty ? <FeedItem>[] : await _feedService.fetchByKeys(feedKeys);
      if (!mounted) return;
      setState(() {
        _beerIds
          ..clear()
          ..addAll(_idsOfType(favorites, beerItemType));
        _breweryIds
          ..clear()
          ..addAll(_idsOfType(favorites, breweryItemType));
        _feedItems = feedItems;
        _loading = false;
      });
    } on FavoritesException catch (e) {
      _showLoadError(e.message);
    } on FeedException catch (e) {
      _showLoadError(e.message);
    }
  }

  static Iterable<int> _idsOfType(List<FavoriteItem> favorites, String itemType) =>
      favorites.where((f) => f.itemType == itemType).map((f) => f.itemId);

  void _showLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadFavorites();
  }

  // Zelfde gedrag als de andere hartjes: meteen wisselen, terugzetten als opslaan mislukt.
  Future<void> _toggleFavorite(Set<int> ids, String itemType, int itemId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final wasFavorite = ids.contains(itemId);
    setState(() {
      if (wasFavorite) {
        ids.remove(itemId);
      } else {
        ids.add(itemId);
      }
    });
    try {
      if (wasFavorite) {
        await _favoritesService.remove(userId: user.id, itemType: itemType, itemId: itemId);
      } else {
        await _favoritesService.add(userId: user.id, itemType: itemType, itemId: itemId);
      }
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          ids.add(itemId);
        } else {
          ids.remove(itemId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favoriet opslaan mislukt: $e')),
      );
    }
  }

  void _toggleBeer(Beer beer) => _toggleFavorite(_beerIds, beerItemType, beer.id);

  void _toggleBrewery(Brewery brewery) => _toggleFavorite(_breweryIds, breweryItemType, brewery.id);

  Future<void> _removeFeedItem(FeedItem item) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final previous = _feedItems;
    setState(() => _feedItems = _feedItems.where((i) => i.key != item.key).toList());
    try {
      await _favoritesService.remove(userId: user.id, itemType: item.favoriteType, itemId: item.favoriteId);
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() => _feedItems = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favoriet verwijderen mislukt: $e')),
      );
    }
  }

  /// "Mijn Favorieten": een container voor bier en een voor brouwerijen, met per
  /// favoriet een kaart die openklapt met meer info.
  Widget _buildFavorites() {
    final likedBeers = beers.where((b) => _beerIds.contains(b.id)).toList();
    final likedBreweries = breweries.where((b) => _breweryIds.contains(b.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mijn Favorieten',
          style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 36, height: 40 / 36),
        ),
        const SizedBox(height: 8),
        Text(
          'Je gelikete bieren en brouwerijen. Tik op een favoriet voor meer info.',
          style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: _primary))
        else if (_error != null)
          Column(
            children: [
              Text(
                'Kon favorieten niet laden: $_error',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _retry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                ),
                child: const Text('Opnieuw proberen'),
              ),
            ],
          )
        else ...[
          _favoriteContainer(
            icon: Icons.sports_bar_outlined,
            title: 'Bier',
            count: likedBeers.length,
            emptyText: 'Nog geen bier. Tik op het hartje bij een bier in het Assortiment hieronder.',
            children: [for (final beer in likedBeers) _buildBeerFavorite(beer)],
          ),
          const SizedBox(height: 24),
          _favoriteContainer(
            icon: Icons.factory_outlined,
            title: 'Brouwerijen',
            count: likedBreweries.length,
            emptyText:
                'Nog geen brouwerijen. Tik op het hartje bij een brouwerij op de Kaart of bij Grutte Pier op Ontdek.',
            children: [for (final brewery in likedBreweries) _buildBreweryFavorite(brewery)],
          ),
          if (_feedItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            _favoriteContainer(
              icon: Icons.bookmark_outline,
              title: 'Opgeslagen berichten',
              count: _feedItems.length,
              emptyText: '',
              children: [
                for (final item in _feedItems)
                  FeedCard(
                    key: ValueKey(item.key),
                    item: item,
                    isFavorite: true,
                    onFavoriteTap: () => _removeFeedItem(item),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _favoriteContainer({
    required IconData icon,
    required String title,
    required int count,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 24)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.openSans(color: _primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (children.isEmpty)
            Text(emptyText, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5))
          else
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
        ],
      ),
    );
  }

  Widget _buildBeerFavorite(Beer beer) {
    return _expandableFavorite(
      key: ValueKey('beer-${beer.id}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 48, height: 48, child: _networkImage(beer.imageUrl)),
      ),
      title: beer.name,
      subtitle: '${beer.style} • ${beer.abv}',
      onRemove: () => _toggleBeer(beer),
      details: [
        _infoBlock('Wat is het', beer.description),
        _infoBlock('Hoe het gemaakt wordt', beer.howMade),
        _infoBlock('Soort bier', beer.styleInfo),
        _infoRow(Icons.factory_outlined, beer.brewery),
      ],
    );
  }

  Widget _buildBreweryFavorite(Brewery brewery) {
    final founded = brewery.founded;
    return _expandableFavorite(
      key: ValueKey('brewery-${brewery.id}'),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.factory_outlined, color: _primary),
      ),
      title: brewery.title,
      subtitle: '${brewery.location} • ★ ${brewery.rating}',
      onRemove: () => _toggleBrewery(brewery),
      details: [
        _infoBlock('Over de plek', brewery.about),
        _infoRow(Icons.location_on_outlined, brewery.location),
        if (founded != null) _infoRow(Icons.history_edu_outlined, 'Sinds $founded'),
        const SizedBox(height: 8),
        _infoLabel('Weetjes'),
        for (final fact in brewery.facts) _bullet(fact),
      ],
    );
  }

  Widget _expandableFavorite({
    required Key key,
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onRemove,
    required List<Widget> details,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: _primary,
        collapsedIconColor: _onSurfaceVariant,
        leading: leading,
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13)),
        children: [
          ...details,
          TextButton.icon(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: _primary, padding: EdgeInsets.zero),
            icon: const Icon(Icons.favorite, size: 18),
            label: Text('Verwijder uit favorieten', style: GoogleFonts.openSans(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _infoLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.openSans(
          color: _primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoLabel(label),
          Text(text, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.openSans(color: _onSurface, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: GoogleFonts.openSans(color: _primary, fontSize: 14, height: 1.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final padding = width >= 768 ? 40.0 : 20.0;
                  final contentWidth = width - padding * 2;
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(padding, 24, padding, 48),
                        child: _buildFavorites(),
                      ),
                      _buildHero(width, padding),
                      // Stats schuiven 32px over de hero heen (-mt-8 in het ontwerp).
                      Transform.translate(
                        offset: const Offset(0, -32),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: padding),
                          child: _buildStats(width, contentWidth),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAssortiment(width, contentWidth),
                            const SizedBox(height: 48),
                            _buildEvents(width, contentWidth),
                            const SizedBox(height: 48),
                            _buildLocations(width),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _outlineVariant.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, color: _primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Artisanal Draught',
              style: GoogleFonts.playfairDisplay(
                color: _primary,
                fontSize: 16,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const Icon(Icons.search, color: _onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildHero(double width, double padding) {
    return SizedBox(
      height: 530,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _networkImage(_heroImage),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x001C110A), _background],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, 20, padding, 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 896),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        'FEATURED CRAFT BREWERY',
                        style: GoogleFonts.openSans(
                          color: _primary,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Brouwerij 't IJ",
                      style: GoogleFonts.playfairDisplay(
                        color: _onSurface,
                        fontSize: width >= 768 ? 60 : 36,
                        height: width >= 768 ? 1 : 40 / 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 672),
                      child: Text(
                        "Sinds 1985 brouwt 't IJ eigenzinnig Amsterdams speciaalbier. Gevestigd in het voormalige Funenbad, naast de grootste houten molen van Nederland, de Gooyer.",
                        style: GoogleFonts.openSans(
                          color: _onSurfaceVariant,
                          fontSize: 18,
                          height: 28 / 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(double width, double contentWidth) {
    Widget statCard(IconData icon, String title, String subtitle) {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _primary, size: 30),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.playfairDisplay(color: _primary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(subtitle, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 16)),
          ],
        ),
      );
    }

    return _grid(
      width: contentWidth,
      columns: width >= 768 ? 3 : 1,
      spacing: 16,
      children: [
        statCard(Icons.location_on_outlined, 'Amsterdam, NL', 'Funenkade 7, 1018 AL'),
        statCard(Icons.history_edu_outlined, 'Established', 'Artisanal Tradition since 1985'),
        statCard(Icons.verified_user_outlined, 'Brewery Status', 'Certified Master Craft'),
      ],
    );
  }

  Widget _buildAssortiment(double width, double contentWidth) {
    Widget roundButton(IconData icon) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _outlineVariant),
        ),
        child: Icon(icon, color: _onSurface),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Assortiment')),
            roundButton(Icons.filter_list),
            const SizedBox(width: 8),
            roundButton(Icons.grid_view),
          ],
        ),
        const SizedBox(height: 24),
        _grid(
          width: contentWidth,
          columns: width >= 1024 ? 4 : (width >= 640 ? 2 : 1),
          spacing: 24,
          children: [for (final beer in beers) _buildBeerCard(beer)],
        ),
      ],
    );
  }

  Widget _buildBeerCard(Beer beer) {
    final isFavorite = _beerIds.contains(beer.id);
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: 3 / 4, child: _networkImage(beer.imageUrl)),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _toggleBeer(beer),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? _primary : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_background, _surfaceContainerHigh, _surfaceContainerHigh.withOpacity(0)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beer.style.toUpperCase(),
                  style: GoogleFonts.openSans(color: _primary, fontSize: 10, letterSpacing: 1),
                ),
                Text(
                  beer.name,
                  style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        beer.abv,
                        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 16),
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: _primary, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvents(double width, double contentWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Evenementen & Proeverijen'),
        const SizedBox(height: 24),
        _grid(
          width: contentWidth,
          columns: width >= 768 ? 2 : 1,
          spacing: 24,
          children: [for (final event in _events) _buildEventCard(event)],
        ),
      ],
    );
  }

  Widget _buildEventCard(_Event event) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  event.price,
                  style: GoogleFonts.openSans(color: _primary, fontSize: 12, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(event.icon, color: _primary, size: 14),
              const SizedBox(width: 8),
              Text(event.date, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'RESERVEER',
              style: GoogleFonts.openSans(fontSize: 14, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocations(double width) {
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _secondaryContainer.withOpacity(0.2),
              border: const Border(
                left: BorderSide(color: _primary, width: 4),
                top: BorderSide(color: _primary),
                right: BorderSide(color: _primary),
                bottom: BorderSide(color: _primary),
              ),
            ),
            child: _locationContent(
              'Proeflokaal de Molen',
              'Funenkade 7, 1018 AL Amsterdam',
              showOpenNow: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _glassCard(
          borderColor: _outlineVariant.withOpacity(0.3),
          child: _locationContent("'t Blauwe Theehuis", 'Vondelpark 5, 1071 AA Amsterdam'),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Locaties'),
        const SizedBox(height: 24),
        if (width >= 1024)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: list),
              const SizedBox(width: 16),
              const Expanded(flex: 2, child: _LocationMap()),
            ],
          )
        else ...[
          list,
          const SizedBox(height: 16),
          const _LocationMap(),
        ],
      ],
    );
  }

  Widget _locationContent(String name, String address, {bool showOpenNow = false}) {
    Widget action(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 16),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.openSans(color: _primary, fontSize: 14)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 16)),
        const SizedBox(height: 4),
        Text(address, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            action(Icons.directions_outlined, 'Directions'),
            if (showOpenNow) action(Icons.schedule_outlined, 'Open Now'),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _primary, width: 4)),
      ),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 30, height: 1.2),
      ),
    );
  }

  Widget _glassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor ?? _primary.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Verdeelt [children] over [columns] kolommen, zoals de Tailwind-grids in het ontwerp.
  Widget _grid({
    required double width,
    required int columns,
    required double spacing,
    required List<Widget> children,
  }) {
    final itemWidth = ((width - spacing * (columns - 1)) / columns).floorToDouble();
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
    );
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      // Op web laden deze afbeeldingen via een <img>-element als CORS ze blokkeert.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => Container(
        color: _surfaceContainerHigh,
        child: Center(
          child: Icon(Icons.image_outlined, color: _onSurfaceVariant.withOpacity(0.4), size: 40),
        ),
      ),
    );
  }
}

class _LocationMap extends StatelessWidget {
  const _LocationMap();

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: ColorFiltered(
                colorFilter: _greyscale,
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(52.3667, 4.9265), // Funenkade 7, Amsterdam
                    initialZoom: 14.0,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bierkompas',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primary.withOpacity(0.1), _primary.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),
          const Center(child: _BouncingMarker()),
        ],
      ),
    );
  }
}

class _BouncingMarker extends StatefulWidget {
  const _BouncingMarker();

  @override
  State<_BouncingMarker> createState() => _BouncingMarkerState();
}

class _BouncingMarkerState extends State<_BouncingMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Zelfde beweging als Tailwind's animate-bounce: 25% omhoog, valt naar 0 en veert terug.
  double _offset(double t) {
    if (t < 0.5) return -10 * (1 - const Cubic(0.8, 0, 1, 1).transform(t * 2));
    return -10 * const Cubic(0, 0, 0.2, 1).transform((t - 0.5) * 2);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _offset(_controller.value)),
            child: child,
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 25,
                  spreadRadius: -5,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: const Icon(Icons.sports_bar_outlined, color: _background),
          ),
        ),
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
