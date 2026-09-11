import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_storage.dart';
import '../favorites/favorites_page.dart';
import '../favorites/favorites_service.dart';
import '../feed/feed_card.dart';
import '../feed/feed_service.dart';
import '../map/breweries.dart';
import '../map/map_page.dart';
import '../profile/profile_page.dart';
import '../profile/settings_page.dart';
import '../profile/stats_service.dart';
import '../events/events_page.dart';
import '../../shared/profile_avatar_button.dart';

// Tab-indexen van de onderste navigatiebalk.
const _tabAgenda = 1;
const _tabFavorites = 2;
const _tabMap = 3;
const _tabProfile = 4;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _statsService = StatsService();
  int _currentIndex = 0;
  int _currentStreak = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    if (!mounted) return;
    setState(() => _avatarUrl = profile?['avatar_url'] as String?);
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final goToProfile = () => _goToTab(_tabProfile);
    final pages = [
      DiscoveryContentPage(onNavigate: _goToTab, avatarUrl: _avatarUrl), // Index 0: Ontdek
      EventsPage(avatarUrl: _avatarUrl, onProfileTap: goToProfile), // Index 1: Agenda
      FavoritesPage(avatarUrl: _avatarUrl, onProfileTap: goToProfile),
      MapPage(avatarUrl: _avatarUrl, onProfileTap: goToProfile),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        color: const Color(0xFF16100D),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.explore,
                  label: 'ONTDEK',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _BottomNavItem(
                  icon: Icons.calendar_today,
                  label: 'AGENDA',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _BottomNavItem(
                  icon: Icons.favorite_border,
                  label: 'FAVORIETEN',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _BottomNavItem(
                  icon: Icons.map_outlined,
                  label: 'KAART',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline,
                  label: 'PROFIEL',
                  isSelected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Kleuren uit het "Artisanal Draught" design system (DESIGN.md).
const _background = Color(0xFF1C110A);
const _primary = Color(0xFFFBB97B);
const _onPrimary = Color(0xFF4B2800);
const _primaryContainer = Color(0xFFD4975C);
const _onPrimaryContainer = Color(0xFF583000);
const _secondary = Color(0xFFE3BFB2);
const _onSecondary = Color(0xFF422B22);
const _secondaryContainer = Color(0xFF5D4339);
const _surfaceContainerLow = Color(0xFF251911);
const _surfaceContainer = Color(0xFF291D15);
const _onSurface = Color(0xFFF6DED1);
const _onSurfaceVariant = Color(0xFFD6C3B5);
const _outlineVariant = Color(0xFF51443A);

const _logoImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBM580LJgGSlvZ-vRLbR8gR8YgCyscQpi9v23krIsU1Guv5lOfaBskJ9JU0mAQfjQ1lLx2JpEin-c8CRLQUKrrp2h9_rlhwvsXtUzKB82_sN9jqFo8KaIZ4p0n6lW7t7-a9ZBD17gqjKLyg7VthIMxzX5MEI8ErfqOXJhOV6IVqqi21Eo84uNNaBkkMfh3dS6SoiH87ofeiFMlfb7V-RoAaWbx94fXBu2zBenGe_GMOUk2P_--GMBAnIrE35R6aGf-bZA';
const _popularImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuANIbUEodWyxyWEqbHFoWd_APYDtoiXgTOVbAJ5TIOp9PKG4baeF5XYwf34634GW-PHvDpk4FhxpB1XlsZEFAl3BsWVxT8Gq-KlOZ01ggozbCfeF3fRoufrH8N5tDetdyMY9uKUxDAadw9wON36RlMvSHNjV30Ol5XjZ06tnPRARXfPUGTEFIa5xw_1m7rvTyggDsC2HvYxMuo3GNidOYo-3ypVQq14WiAoZWsApQQMn_T-2VSeoFN7';
const _partnerImage =
    'https://lh3.googleusercontent.com/aida/AP1WRLvi8Zj598SlngHlPQofwL5eYRc3MWYFpw3q0uSxb7KHaatHvGFYih0mFHKiXgYpGD89u_tyS1o_Z-D8liFFV3vILgmLQ2B-62H7Kw3W71EdDCPKNBIdxCPSF2XAzQe0l51bqlHGvMUWnC96SsViQwlrVrdGlB93UeNGY657gJrtotMDVSkxt3ffWswZIsI3OM0wKkfthjWOFv1o1b-zqfn3YAaJ5uRGzluZ0svUF-FP31saG_v6yWa0kTQ';
const _avatarImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCaOSCJ0mEWtW6_caNgki6zyfvVSrPqtkTpUrPppdu2rofpmmEcReN07EJPVlPTYjmOrr5NstInEm4jgiQSklqnEXHQluDL7LF0u10cC7t7OzlE_i44wmNPD0C2rv0102xkvOzrW5-KkHpgAKnJQwrLCHaxg4SmIMjsZ6m8NCBLH6dbp8p-hp38o_88n0NygSuPoepqZoN-DmOq-YrFdsK2tdqn_AE_-lOCRLbcu9HM1dXqMg0xRh8b';

class DiscoveryContentPage extends StatefulWidget {
  final int streak;
  final String? avatarUrl;

  /// Springt naar een tab in de onderste navigatiebalk van [HomePage].
  final ValueChanged<int>? onNavigate;

  const DiscoveryContentPage({super.key, this.streak = 0, this.onNavigate, this.avatarUrl});

  @override
  State<DiscoveryContentPage> createState() => _DiscoveryContentPageState();
}

class _DiscoveryContentPageState extends State<DiscoveryContentPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _favoritesService = FavoritesService();
  bool _partnerIsFavorite = false;

  final _feedService = FeedService();
  final List<FeedItem> _feedItems = [];
  final Set<String> _likedFeedKeys = {};
  bool _feedLoading = false;
  bool _feedHasMore = true;
  String? _feedError;

  // Zoveel items voor het einde van de geladen lijst start de volgende batch
  // (bij batches van 15 dus zodra de gebruiker bij item 10 is).
  static const _feedPrefetchDistance = 5;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _scheduleNextFeedPage();
  }

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final favorites = await _favoritesService.list(user.id);
      if (!mounted) return;
      setState(() {
        _partnerIsFavorite = favorites.any(
          (f) => f.itemType == breweryItemType && f.itemId == grutePierProeflokaal.id,
        );
        _likedFeedKeys
          ..clear()
          ..addAll(favorites
              .map((f) => FeedItem.keyForFavorite(f.itemType, f.itemId))
              .whereType<String>());
      });
    } on FavoritesException catch (e) {
      debugPrint('Fout bij ophalen favorieten: $e');
    }
  }

  // Zelfde gedrag als het hartje op de Kaart: meteen wisselen, terugzetten als opslaan mislukt.
  Future<void> _togglePartnerFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final wasFavorite = _partnerIsFavorite;
    setState(() => _partnerIsFavorite = !wasFavorite);
    try {
      if (wasFavorite) {
        await _favoritesService.remove(
            userId: user.id, itemType: breweryItemType, itemId: grutePierProeflokaal.id);
      } else {
        await _favoritesService.add(
            userId: user.id, itemType: breweryItemType, itemId: grutePierProeflokaal.id);
      }
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() => _partnerIsFavorite = wasFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favoriet opslaan mislukt: $e')),
      );
    }
  }

  Future<void> _loadNextFeedPage() async {
    if (_feedLoading || !_feedHasMore) return;
    setState(() {
      _feedLoading = true;
      _feedError = null;
    });
    try {
      final page = await _feedService.fetchPage(_feedItems.length);
      if (!mounted) return;
      // Afbeeldingen van de nieuwe batch alvast op de achtergrond in de cache laden,
      // zodat ze klaarstaan voordat de kaart in beeld scrolt.
      for (final item in page) {
        final url = item.imageUrl;
        if (url != null) {
          precacheImage(CachedNetworkImageProvider(url), context, onError: (_, __) {});
        }
      }
      setState(() {
        _feedItems.addAll(page);
        _feedHasMore = page.length == FeedService.pageSize;
        _feedLoading = false;
      });
    } on FeedException catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.message;
        _feedLoading = false;
      });
    }
  }

  // Wordt tijdens het bouwen van de lijst aangeroepen; setState mag daar niet, dus na het frame.
  void _scheduleNextFeedPage() {
    if (_feedLoading || !_feedHasMore || _feedError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNextFeedPage();
    });
  }

  /// De Ontdek-pagina als één lijst: eerst de vaste secties, daarna de eindeloze feed.
  Widget _buildFeedList({required List<Widget> header}) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: header.length + _feedItems.length + 1,
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        final feedIndex = index - header.length;
        if (feedIndex == _feedItems.length) return _buildFeedFooter();
        if (feedIndex >= _feedItems.length - _feedPrefetchDistance) _scheduleNextFeedPage();
        final item = _feedItems[feedIndex];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FeedCard(
            item: item,
            onTap: item.type == FeedItemType.evenement ? () => _goTo(_tabAgenda) : null,
            isFavorite: _likedFeedKeys.contains(item.key),
            onFavoriteTap: () => _toggleFeedFavorite(item),
          ),
        );
      },
    );
  }

  Widget _buildFeedFooter() {
    final style = GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14);
    if (_feedError != null) {
      return Column(
        children: [
          Text('Kon de feed niet laden: $_feedError', textAlign: TextAlign.center, style: style),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadNextFeedPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
            ),
            child: const Text('Opnieuw proberen'),
          ),
        ],
      );
    }
    if (_feedHasMore) {
      _scheduleNextFeedPage();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        _feedItems.isEmpty ? 'Nog geen berichten in de feed.' : 'Je bent helemaal bij! 🍺',
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  // Zelfde gedrag als de andere hartjes: meteen wisselen, terugzetten als opslaan mislukt.
  Future<void> _toggleFeedFavorite(FeedItem item) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final wasFavorite = _likedFeedKeys.contains(item.key);
    setState(() {
      if (wasFavorite) {
        _likedFeedKeys.remove(item.key);
      } else {
        _likedFeedKeys.add(item.key);
      }
    });
    try {
      if (wasFavorite) {
        await _favoritesService.remove(userId: user.id, itemType: item.favoriteType, itemId: item.favoriteId);
      } else {
        await _favoritesService.add(userId: user.id, itemType: item.favoriteType, itemId: item.favoriteId);
      }
    } on FavoritesException catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _likedFeedKeys.add(item.key);
        } else {
          _likedFeedKeys.remove(item.key);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favoriet opslaan mislukt: $e')),
      );
    }
  }

  void _goTo(int tab) => widget.onNavigate?.call(tab);

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gezelligheid & Social komt binnenkort.')),
    );
  }

  Future<void> _logout() async {
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: _buildDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildFeedList(
                header: [
                  _buildWelcome(),
                  const SizedBox(height: 48),
                  _buildActionGrid(),
                  const SizedBox(height: 48),
                  _sectionLabel('Nu Populair'),
                  _buildFeaturedCard(
                    imageUrl: _popularImage,
                    badge: 'Vandaag Getapt',
                    badgeColor: _primary,
                    badgeTextColor: _onPrimary,
                    title: 'Koperen Nacht Tripel',
                    subtitle: 'Intens, kruidig met tonen van karamel.',
                    onTap: () => _goTo(_tabFavorites),
                  ),
                  const SizedBox(height: 48),
                  _sectionLabel('Partner in de Kijker'),
                  _buildFeaturedCard(
                    imageUrl: _partnerImage,
                    badge: 'Aanbevolen',
                    badgeColor: _secondary,
                    badgeTextColor: _onSecondary,
                    title: grutePierProeflokaal.title,
                    subtitle: 'Bier & Spijs specialiteiten: Probeer ons Dubbel stoofvlees.',
                    onTap: () => _goTo(_tabMap),
                    topRight: GestureDetector(
                      onTap: _togglePartnerFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _partnerIsFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _partnerIsFavorite ? _primary : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  _sectionLabel('Snelkoppelingen'),
                  _buildShortcut(Icons.bookmarks_outlined, 'Mijn Favorieten', () => _goTo(_tabFavorites)),
                  const SizedBox(height: 12),
                  _buildShortcut(Icons.restaurant_outlined, 'Tafeltje Reserveren', () => _goTo(_tabFavorites)),
                  const SizedBox(height: 48),
                  _sectionLabel('Bierfeed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: _primary),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                height: 40,
                child: _networkImage(
                  _logoImage,
                  fit: BoxFit.contain,
                  fallback: Center(
                    child: Text(
                      'BIERKOMPAS',
                      style: GoogleFonts.playfairDisplay(
                        color: _primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withOpacity(0.4)),
              ),
              child: Text(
                '🔥 ${widget.streak}',
                style: GoogleFonts.openSans(color: _primary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ProfileAvatarButton(
            onTap: () => _goTo(_tabProfile),
            avatarUrl: widget.avatarUrl,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welkom, Bierliefhebber!',
          style: GoogleFonts.playfairDisplay(
            color: _onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 40 / 32,
            letterSpacing: -0.32,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Ontdek de fijnste brouwsels en de meest exclusieve proeverijen in de buurt.',
            style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 16, height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _goTo(_tabFavorites),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _speakeasyDecoration(
              borderColor: _primary.withOpacity(0.3),
              borderWidth: 2,
              glow: true,
            ),
            child: Text(
              '❤️ WIE NEEM JIJ VANDAAG MEE VOOR EEN PROEFMOMENTJE',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: _primary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 28 / 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid() {
    final tiles = [
      _buildActionTile(Icons.explore_outlined, Icons.local_drink_outlined, 'Vinden & Proeven',
          'ONTDEK BIEREN', () => _goTo(_tabFavorites)),
      _buildActionTile(Icons.map_outlined, Icons.location_on_outlined, 'Kaart & Locaties',
          'BROUWERIJ KAART', () => _goTo(_tabMap)),
      _buildActionTile(Icons.event_outlined, Icons.celebration_outlined, 'Feestjes & Agenda',
          'BIER AGENDA', () => _goTo(_tabAgenda)),
      _buildActionTile(Icons.group_outlined, Icons.forum_outlined, 'Gezelligheid & Social',
          'GEMEENSCHAP', _showComingSoon),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 16),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 16),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    IconData icon,
    IconData backgroundIcon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: _speakeasyDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(backgroundIcon, size: 96, color: _onSurface.withOpacity(0.1)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: _primary, size: 30),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.playfairDisplay(
                            color: _onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.openSans(
                            color: _onSurfaceVariant,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.openSans(
          color: _primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.8,
        ),
      ),
    );
  }

  Widget _buildFeaturedCard({
    required String imageUrl,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? topRight,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 192,
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primary.withOpacity(0.2)),
          boxShadow: [_amberGlow],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _networkImage(imageUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_background, Color(0x001C110A)],
                  stops: [0, 0.5],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: GoogleFonts.openSans(
                        color: badgeTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      color: _onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 32 / 24,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 20 / 14),
                  ),
                ],
              ),
            ),
            if (topRight != null) Positioned(top: 12, right: 12, child: topRight),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcut(IconData icon, String label, VoidCallback onTap) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: _outlineVariant.withOpacity(0.3)),
    );
    return Material(
      color: _surfaceContainerLow,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _secondaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _secondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: GoogleFonts.openSans(color: _onSurface, fontSize: 16)),
              ),
              const Icon(Icons.chevron_right, color: _onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 320,
      backgroundColor: _surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primary, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _networkImage(
                        _avatarImage,
                        fallback: const Icon(Icons.person, color: _onSurfaceVariant, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meester Proever',
                          style: GoogleFonts.playfairDisplay(
                            color: _primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Goud Niveau',
                          style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _drawerItem(Icons.person_outline, 'Mijn Profiel', () => _goTo(_tabProfile),
                        highlighted: true),
                    const SizedBox(height: 8),
                    _drawerItem(Icons.bookmarks_outlined, 'Favoriete Bieren', () => _goTo(_tabFavorites)),
                    const SizedBox(height: 8),
                    _drawerItem(Icons.local_drink_outlined, 'Brouwerij Bezoeken', () => _goTo(_tabMap)),
                    const SizedBox(height: 8),
                    _drawerItem(
                      Icons.settings_outlined,
                      'Instellingen',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _drawerItem(Icons.logout, 'Uitloggen', _logout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menu-item in de drawer: sluit eerst de drawer en voert daarna [action] uit.
  Widget _drawerItem(IconData icon, String label, VoidCallback action, {bool highlighted = false}) {
    final color = highlighted ? _onPrimaryContainer : _onSurfaceVariant;
    return Material(
      color: highlighted ? _primaryContainer : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          Navigator.of(context).pop();
          action();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.openSans(
                  color: color,
                  fontSize: 16,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxShadow get _amberGlow => BoxShadow(color: _primary.withOpacity(0.1), blurRadius: 25);

  /// De ".speakeasy-card" uit het ontwerp: bruin verloop met een dunne amberrand.
  BoxDecoration _speakeasyDecoration({Color? borderColor, double borderWidth = 1, bool glow = false}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment(-0.57, -0.82), // 145deg zoals in de CSS
        end: Alignment(0.57, 0.82),
        colors: [Color(0xFF2C1810), _background],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? _primary.withOpacity(0.1), width: borderWidth),
      boxShadow: glow ? [_amberGlow] : null,
    );
  }

  Widget _networkImage(String url, {BoxFit fit = BoxFit.cover, Widget? fallback}) {
    return Image.network(
      url,
      fit: fit,
      // Op web laden deze afbeeldingen via een <img>-element als CORS ze blokkeert.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => fallback ?? Container(color: _surfaceContainer),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFD4B28C) : const Color(0xFF9E8A7D);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
