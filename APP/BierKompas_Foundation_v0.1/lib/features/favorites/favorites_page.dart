import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/feed_card.dart';
import '../feed/feed_service.dart';
import '../map/breweries.dart';
import 'beers.dart';
import 'favorites_service.dart';
import '../../shared/profile_avatar_button.dart';

// Kleuren uit het "Artisanal Draught" design system (DESIGN.md).
const _background = Color(0xFF1C110A);
const _primary = Color(0xFFFBB97B);
const _onSurface = Color(0xFFF6DED1);
const _onSurfaceVariant = Color(0xFFD6C3B5);
const _outlineVariant = Color(0xFF51443A);

/// Je favorieten in drie containers: bier, brouwerijen en gelikete posts.
/// Een like op een post over een bier of brouwerij komt bij dat bier of die brouwerij;
/// alle andere posts staan onder "Gelikete posts".
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.avatarUrl, this.onProfileTap});

  final String? avatarUrl;
  final VoidCallback? onProfileTap;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _favoritesService = FavoritesService();
  final _feedService = FeedService();
  final Set<int> _beerIds = {};
  final Set<int> _breweryIds = {};
  List<FeedItem> _posts = [];
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
      final postKeys = favorites
          .map((f) => FeedItem.keyForFavorite(f.itemType, f.itemId))
          .whereType<String>()
          .toList();
      final posts = postKeys.isEmpty ? <FeedItem>[] : await _feedService.fetchByKeys(postKeys);
      if (!mounted) return;
      setState(() {
        _beerIds
          ..clear()
          ..addAll(_idsOfType(favorites, beerItemType));
        _breweryIds
          ..clear()
          ..addAll(_idsOfType(favorites, breweryItemType));
        _posts = posts;
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

  // Verwijdert meteen uit de lijst en zet terug als het opslaan mislukt.
  Future<void> _removeId(Set<int> ids, String itemType, int itemId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => ids.remove(itemId));
    try {
      await _favoritesService.remove(userId: user.id, itemType: itemType, itemId: itemId);
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() => ids.add(itemId));
      _showRemoveError(e);
    }
  }

  Future<void> _removePost(FeedItem post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final previous = _posts;
    setState(() => _posts = _posts.where((p) => p.key != post.key).toList());
    try {
      await _favoritesService.remove(userId: user.id, itemType: post.favoriteType, itemId: post.favoriteId);
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() => _posts = previous);
      _showRemoveError(e);
    }
  }

  void _showRemoveError(FavoritesException e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Favoriet verwijderen mislukt: $e')),
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
                  final padding = constraints.maxWidth >= 768 ? 40.0 : 20.0;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(padding, 24, padding, 24),
                    children: [_buildFavorites()],
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
          if (widget.onProfileTap != null) ...[
            const SizedBox(width: 12),
            ProfileAvatarButton(onTap: widget.onProfileTap!, avatarUrl: widget.avatarUrl, size: 32),
          ],
        ],
      ),
    );
  }

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
          'Alles wat je met een hartje hebt geliked. Tik op een bier of brouwerij voor meer info.',
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
            emptyText: 'Nog geen bier. Like een review in de feed op Ontdek of het bier bij Nu Populair.',
            children: [for (final beer in likedBeers) _buildBeerFavorite(beer)],
          ),
          const SizedBox(height: 24),
          _favoriteContainer(
            icon: Icons.factory_outlined,
            title: 'Brouwerijen',
            count: likedBreweries.length,
            emptyText: 'Nog geen brouwerijen. Like een brouwerij op de Kaart, op Ontdek of in de feed.',
            children: [for (final brewery in likedBreweries) _buildBreweryFavorite(brewery)],
          ),
          const SizedBox(height: 24),
          _favoriteContainer(
            icon: Icons.bookmark_outline,
            title: 'Gelikete posts',
            count: _posts.length,
            emptyText: 'Nog geen gelikete posts. Tik op het hartje bij een tip, weetje of evenement in de feed.',
            children: [
              for (final post in _posts)
                FeedCard(
                  key: ValueKey(post.key),
                  item: post,
                  isFavorite: true,
                  onFavoriteTap: () => _removePost(post),
                ),
            ],
          ),
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
    final imageUrl = beer.imageUrl;
    final brewery = beer.brewery;
    return _expandableFavorite(
      key: ValueKey('beer-${beer.id}'),
      leading: imageUrl == null
          ? _iconTile(Icons.sports_bar_outlined)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 48, height: 48, child: _networkImage(imageUrl)),
            ),
      title: beer.name,
      subtitle: '${beer.style} • ${beer.abv}',
      onRemove: () => _removeId(_beerIds, beerItemType, beer.id),
      details: [
        _infoBlock('Wat is het', beer.description),
        _infoBlock('Hoe het gemaakt wordt', beer.howMade),
        _infoBlock('Soort bier', beer.styleInfo),
        if (brewery != null) _infoRow(Icons.factory_outlined, brewery),
      ],
    );
  }

  Widget _buildBreweryFavorite(Brewery brewery) {
    final founded = brewery.founded;
    return _expandableFavorite(
      key: ValueKey('brewery-${brewery.id}'),
      leading: _iconTile(Icons.factory_outlined),
      title: brewery.title,
      subtitle: '${brewery.location} • ★ ${brewery.rating}',
      onRemove: () => _removeId(_breweryIds, breweryItemType, brewery.id),
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

  Widget _iconTile(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _primary),
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

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      // Op web laden deze afbeeldingen via een <img>-element als CORS ze blokkeert.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => _iconTile(Icons.image_outlined),
    );
  }
}
