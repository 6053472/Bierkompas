import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../favorites/favorites_page.dart';
import '../favorites/favorites_service.dart';
import '../feed/feed_card.dart';
import '../feed/feed_service.dart';
import '../map/map_page.dart';
import '../profile/cheer_confirmation_page.dart';
import '../profile/cheer_overlay.dart';
import '../profile/cheers_service.dart';
import '../profile/friends_service.dart';
import '../profile/profile_page.dart';
import '../profile/stats_service.dart';
import '../scan/beer_scan_page.dart';
import '../events/events_page.dart';
import '../pairing/pairing_hub_page.dart';
import '../videos/video_reel_page.dart';
import '../../shared/profile_avatar_button.dart';
import 'social_page.dart';
import 'vinden_proeven_page.dart';
import '../feed/create_post_page.dart';
import '../news/news_article_page.dart';

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
  final _cheersService = CheersService();
  final _friendsService = FriendsService();

  int _currentIndex = 0;
  int _currentStreak = 0;
  String? _avatarUrl;

  RealtimeChannel? _cheersChannel;
  bool _showingCheer = false;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();

    _loadAvatar();
    _loadStreak();
    _checkPendingCheers();
    _subscribeToCheers();

    _friendsService.touchPresence();

    _presenceTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _friendsService.touchPresence(),
    );
  }

  Future<void> _loadStreak() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final streak = await _statsService.fetchCurrentStreak(user.id);

      if (!mounted) return;

      setState(() {
        _currentStreak = streak;
      });
    } catch (e) {
      debugPrint('Fout bij ophalen streak: $e');
    }
  }

  @override
  void dispose() {
    _cheersChannel?.unsubscribe();
    _presenceTimer?.cancel();
    super.dispose();
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

    setState(() {
      _avatarUrl = profile?['avatar_url'] as String?;
    });
  }

  Future<void> _checkPendingCheers() async {
    try {
      final unseen = await _cheersService.listUnseen();

      for (final cheer in unseen) {
        await _showCheer(cheer);
      }
    } on CheersException catch (e) {
      debugPrint('Fout bij ophalen proosts: $e');
    }
  }

  Future<void> _showCheer(Cheer cheer) async {
    if (!mounted || _showingCheer) return;

    _showingCheer = true;

    if (cheer.isReply) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheerConfirmationPage(
            cheer: cheer,
            service: _cheersService,
          ),
        ),
      );
    } else {
      await showCheerOverlay(
        context,
        cheer,
        _cheersService,
      );
    }

    _showingCheer = false;
  }

  void _subscribeToCheers() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _cheersChannel = Supabase.instance.client
        .channel('cheers_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'cheers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: user.id,
          ),
          callback: (_) => _checkPendingCheers(),
        )
        .subscribe();
  }

  void _goToTab(int index) {
    setState(() {
      _currentIndex = index;
    });

    _loadStreak();
  }

  @override
  Widget build(BuildContext context) {
    final goToProfile = () => _goToTab(_tabProfile);

    final pages = [
      DiscoveryContentPage(
        onNavigate: _goToTab,
        avatarUrl: _avatarUrl,
        streak: _currentStreak,
        onActivityRecorded: _loadStreak,
      ),
      EventsPage(
        avatarUrl: _avatarUrl,
        onProfileTap: goToProfile,
      ),
      FavoritesPage(
        avatarUrl: _avatarUrl,
        onProfileTap: goToProfile,
      ),
      MapPage(
        avatarUrl: _avatarUrl,
        onProfileTap: goToProfile,
      ),
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
                  onTap: () => _goToTab(0),
                ),
                _BottomNavItem(
                  icon: Icons.calendar_today,
                  label: 'AGENDA',
                  isSelected: _currentIndex == 1,
                  onTap: () => _goToTab(1),
                ),
                _BottomNavItem(
                  icon: Icons.favorite_border,
                  label: 'FAVORIETEN',
                  isSelected: _currentIndex == 2,
                  onTap: () => _goToTab(2),
                ),
                _BottomNavItem(
                  icon: Icons.map_outlined,
                  label: 'KAART',
                  isSelected: _currentIndex == 3,
                  onTap: () => _goToTab(3),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline,
                  label: 'PROFIEL',
                  isSelected: _currentIndex == 4,
                  onTap: () => _goToTab(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _background = Color(0xFF1E1712);
const _primary = Color(0xFFD4B28C);
const _secondary = Color(0xFFD4B28C);
const _secondaryContainer = Color(0xFF3C3028);
const _surfaceContainerLow = Color(0xFF2C221C);
const _surfaceContainer = Color(0xFF2C221C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

const _logoImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBM580LJgGSlvZ-vRLbR8gR8YgCyscQpi9v23krIsU1Guv5lOfaBskJ9JU0mAQfjQ1lLx2JpEin-c8CRLQUKrrp2h9_rlhwvsXtUzKB82_sN9jqFo8KaIZ4p0n6lW7t7-a9ZBD17gqjKLyg7VthIMxzX5MEI8ErfqOXJhOV6IVqqi21Eo84uNNaBkkMfh3dS6SoiH87ofeiFMlfb7V-RoAaWbx94fXBu2zBenGe_GMOUk2P_--GMBAnIrE35R6aGf-bZA';

class DiscoveryContentPage extends StatefulWidget {
  final int streak;
  final String? avatarUrl;
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onActivityRecorded;

  const DiscoveryContentPage({
    super.key,
    this.streak = 0,
    this.onNavigate,
    this.avatarUrl,
    this.onActivityRecorded,
  });

  @override
  State<DiscoveryContentPage> createState() => _DiscoveryContentPageState();
}

class _DiscoveryContentPageState extends State<DiscoveryContentPage> {
  final _favoritesService = FavoritesService();
  final _statsService = StatsService();

  final Set<String> _likedKeys = {};

  final _feedService = FeedService();
  final List<FeedItem> _feedItems = [];

  bool _feedLoading = false;
  bool _feedHasMore = true;
  String? _feedError;

  static const _feedPrefetchDistance = 5;

  // NIEUWS
  final List<Map<String, dynamic>> _newsArticles = [];
  bool _newsLoading = true;

  @override
  void initState() {
    super.initState();

    _loadFavorites();
    _scheduleNextFeedPage();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      final data = await Supabase.instance.client
          .from('news_articles')
          .select(
            'id, titel, samenvatting, inhoud, foto_url, gepubliceerd_op, status',
          )
          .eq('status', 'gepubliceerd')
          .order('gepubliceerd_op', ascending: false)
          .limit(3);

      if (!mounted) return;

      setState(() {
        _newsArticles
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(data));

        _newsLoading = false;
      });
    } catch (e) {
      debugPrint('Fout bij ophalen nieuws: $e');

      if (!mounted) return;

      setState(() {
        _newsLoading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final favorites = await _favoritesService.list(user.id);

      if (!mounted) return;

      setState(() {
        _likedKeys
          ..clear()
          ..addAll(
            favorites.map(
              (f) => FeedItem.favoriteKeyOf(
                f.itemType,
                f.itemId,
              ),
            ),
          );
      });
    } on FavoritesException catch (e) {
      debugPrint('Fout bij ophalen favorieten: $e');
    }
  }

  bool _isLiked(String itemType, int itemId) =>
      _likedKeys.contains(
        FeedItem.favoriteKeyOf(itemType, itemId),
      );

  Future<void> _toggleLike(
    String itemType,
    int itemId,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final key = FeedItem.favoriteKeyOf(itemType, itemId);
    final wasLiked = _likedKeys.contains(key);

    setState(() {
      if (wasLiked) {
        _likedKeys.remove(key);
      } else {
        _likedKeys.add(key);
      }
    });

    try {
      if (wasLiked) {
        await _favoritesService.remove(
          userId: user.id,
          itemType: itemType,
          itemId: itemId,
        );
      } else {
        await _favoritesService.add(
          userId: user.id,
          itemType: itemType,
          itemId: itemId,
        );

        await _recordStreakActivity();
      }
    } on FavoritesException catch (e) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          _likedKeys.add(key);
        } else {
          _likedKeys.remove(key);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favoriet opslaan mislukt: $e'),
        ),
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
      final page = await _feedService.fetchPage(
        _feedItems.length,
      );

      if (!mounted) return;

      for (final item in page) {
        final url = item.imageUrl;

        if (url != null) {
          precacheImage(
            NetworkImage(url),
            context,
            onError: (_, __) {},
          );
        }
      }

      setState(() {
        _feedItems.addAll(page);
        _feedHasMore =
            page.length == FeedService.pageSize;
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

  void _scheduleNextFeedPage() {
    if (_feedLoading ||
        !_feedHasMore ||
        _feedError != null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadNextFeedPage();
      }
    });
  }

  Widget _buildFeedList({
    required List<Widget> header,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        24,
      ),
      itemCount:
          header.length + _feedItems.length + 1,
      itemBuilder: (context, index) {
        if (index < header.length) {
          return header[index];
        }

        final feedIndex =
            index - header.length;

        if (feedIndex == _feedItems.length) {
          return _buildFeedFooter();
        }

        if (feedIndex >=
            _feedItems.length -
                _feedPrefetchDistance) {
          _scheduleNextFeedPage();
        }

        final item = _feedItems[feedIndex];

        final isOwnPost =
            item.type == FeedItemType.post &&
            item.authorId != null &&
            item.authorId ==
                Supabase.instance.client.auth.currentUser?.id;

        return Padding(
          padding:
              const EdgeInsets.only(bottom: 16),
          child: FeedCard(
            item: item,
            onTap: switch (item.type) {
              FeedItemType.evenement =>
                () => _goTo(_tabAgenda),
              FeedItemType.brouwerij =>
                () => _goTo(_tabMap),
              _ => null,
            },
            isFavorite: _isLiked(
              item.favoriteType,
              item.favoriteId,
            ),
            onFavoriteTap: () => _toggleLike(
              item.favoriteType,
              item.favoriteId,
            ),
            onDeleteTap:
                isOwnPost
                    ? () => _deletePost(item)
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildFeedFooter() {
    final style = GoogleFonts.openSans(
      color: _onSurfaceVariant,
      fontSize: 14,
    );

    if (_feedError != null) {
      return Column(
        children: [
          Text(
            'Kon de feed niet laden: $_feedError',
            textAlign: TextAlign.center,
            style: style,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadNextFeedPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(
                color: _primary,
              ),
            ),
            child: const Text(
              'Opnieuw proberen',
            ),
          ),
        ],
      );
    }

    if (_feedHasMore) {
      _scheduleNextFeedPage();

      return const Padding(
        padding:
            EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(
            color: _primary,
          ),
        ),
      );
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        _feedItems.isEmpty
            ? 'Nog geen berichten in de feed.'
            : 'Je bent helemaal bij! 🍺',
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  void _goTo(int tab) {
    widget.onNavigate?.call(tab);
  }

  Future<void> _openCreatePost() async {
    final posted =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            const CreatePostPage(),
      ),
    );

    if (posted != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Je post is verstuurd en wordt binnenkort beoordeeld.',
        ),
      ),
    );

    await _recordStreakActivity();
  }

  Future<void> _recordStreakActivity() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final result =
          await _statsService.recordDailyActivity(
        user.id,
      );

      widget.onActivityRecorded?.call();

      if (result
              .newlyEarnedBadgeTitles
              .isNotEmpty &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nieuwe badge ontgrendeld: '
              '${result.newlyEarnedBadgeTitles.join(", ")} 🏅',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Fout bij bijwerken Bier Streak: $e',
      );
    }
  }

  Future<void> _deletePost(
    FeedItem item,
  ) async {
    final index =
        _feedItems.indexWhere(
      (f) => f.key == item.key,
    );

    if (index == -1) return;

    setState(() {
      _feedItems.removeAt(index);
    });

    try {
      await _feedService.deletePost(
        item.key,
      );
    } on FeedException catch (e) {
      if (!mounted) return;

      setState(() {
        _feedItems.insert(index, item);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verwijderen mislukt: $e',
          ),
        ),
      );
    }
  }

  void _openSocial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const SocialPage(),
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
            _buildHeader(),
            Expanded(
              child: _buildFeedList(
                header: [
                  _buildWelcome(),

                  const SizedBox(height: 48),

                  _buildActionGrid(),

                  const SizedBox(height: 40),

                  _buildNewsSection(),

                  const SizedBox(height: 48),

                  _sectionLabel(
                    'Snelkoppelingen',
                  ),

                  _buildShortcut(
                    Icons.bookmarks_outlined,
                    'Mijn Favorieten',
                    () => _goTo(
                      _tabFavorites,
                    ),
                  ),

                  const SizedBox(height: 48),

                  _sectionLabel(
                    'Bierfeed',
                  ),

                  const SizedBox(height: 12),

                  _buildNewPostButton(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // NIEUWSRUBRIEK
  // =========================

  Widget _buildNewsSection() {
    if (_newsLoading) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionLabel('Nieuws'),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: _outlineVariant,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: _primary,
              ),
            ),
          ),
        ],
      );
    }

    if (_newsArticles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionLabel('Nieuws'),

        if (_newsArticles.isNotEmpty)
          _buildFeaturedNewsCard(
            _newsArticles.first,
          ),

        if (_newsArticles.length > 1) ...[
          const SizedBox(height: 12),
          ..._newsArticles
              .skip(1)
              .map(_buildSmallNewsCard),
        ],

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const NewsArticlePage(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color:
                  _primary.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color:
                    _primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bekijk al het nieuws',
                    style:
                        GoogleFonts.openSans(
                      color: _primary,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: _primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedNewsCard(
    Map<String, dynamic> article,
  ) {
    final image =
        article['foto_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const NewsArticlePage(),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                _primary.withOpacity(0.25),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (image != null &&
                image.isNotEmpty)
              Image.network(
                image,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                webHtmlElementStrategy:
                    WebHtmlElementStrategy
                        .fallback,
                errorBuilder:
                    (_, __, ___) =>
                        _newsImagePlaceholder(),
              )
            else
              _newsImagePlaceholder(),

            Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIEUWS VAN DE DAG',
                    style:
                        GoogleFonts.openSans(
                      color: _primary,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    article['titel'] ?? '',
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.playfairDisplay(
                      color: _onSurface,
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w700,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    article['samenvatting'] ??
                        '',
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.openSans(
                      color:
                          _onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text(
                        'Lees meer',
                        style:
                            GoogleFonts.openSans(
                          color: _primary,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: _primary,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallNewsCard(
    Map<String, dynamic> article,
  ) {
    final image =
        article['foto_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const NewsArticlePage(),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: _outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            if (image != null &&
                image.isNotEmpty)
              Image.network(
                image,
                width: 100,
                height: 110,
                fit: BoxFit.cover,
                webHtmlElementStrategy:
                    WebHtmlElementStrategy
                        .fallback,
                errorBuilder:
                    (_, __, ___) =>
                        _smallNewsPlaceholder(),
              )
            else
              _smallNewsPlaceholder(),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIERNIEUWS',
                      style:
                          GoogleFonts.openSans(
                        color: _primary,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      article['titel'] ?? '',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          GoogleFonts.playfairDisplay(
                        color: _onSurface,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w700,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      article['samenvatting'] ??
                          '',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          GoogleFonts.openSans(
                        color:
                            _onSurfaceVariant,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newsImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      color: _secondaryContainer,
      child: const Center(
        child: Icon(
          Icons.newspaper_outlined,
          color: _onSurfaceVariant,
          size: 40,
        ),
      ),
    );
  }

  Widget _smallNewsPlaceholder() {
    return Container(
      width: 100,
      height: 110,
      color: _secondaryContainer,
      child: const Center(
        child: Icon(
          Icons.newspaper_outlined,
          color: _onSurfaceVariant,
          size: 30,
        ),
      ),
    );
  }

  // =========================
  // HEADER
  // =========================

  Widget _buildHeader() {
    return Container(
      color: _background,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Align(
              alignment:
                  Alignment.centerLeft,
              child: widget.streak > 0
                  ? Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color: _primary
                            .withOpacity(0.15),
                        borderRadius:
                            BorderRadius
                                .circular(20),
                        border: Border.all(
                          color: _primary
                              .withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        '🔥 ${widget.streak}',
                        maxLines: 1,
                        softWrap: false,
                        style:
                            GoogleFonts.openSans(
                          color: _primary,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),

          Expanded(
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: _networkImage(
                _logoImage,
                fit: BoxFit.contain,
                fallback: Center(
                  child: Text(
                    'BIERKOMPAS',
                    style:
                        GoogleFonts.playfairDisplay(
                      color: _primary,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(
            width: 72,
            child: Align(
              alignment:
                  Alignment.centerRight,
              child: ProfileAvatarButton(
                onTap: () =>
                    _goTo(_tabProfile),
                avatarUrl: widget.avatarUrl,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Welkom, Bierliefhebber!',
          style:
              GoogleFonts.playfairDisplay(
            color: _onSurface,
            fontSize: 32,
            fontWeight:
                FontWeight.w700,
            height: 40 / 32,
            letterSpacing: -0.32,
          ),
        ),

        const SizedBox(height: 8),

        ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 320,
          ),
          child: Text(
            'Ontdek de fijnste brouwsels en de meest exclusieve proeverijen in de buurt.',
            style: GoogleFonts.openSans(
              color:
                  _onSurfaceVariant,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: () =>
              _goTo(_tabFavorites),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(24),
            decoration:
                _speakeasyDecoration(
              borderColor:
                  _primary.withOpacity(0.3),
              borderWidth: 2,
              glow: true,
            ),
            child: Text(
              '❤️ WIE NEEM JIJ VANDAAG MEE VOOR EEN PROEFMOMENTJE',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.playfairDisplay(
                color: _primary,
                fontSize: 20,
                fontWeight:
                    FontWeight.w600,
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
      _buildActionTile(
        Icons.explore_outlined,
        Icons.local_drink_outlined,
        'Vinden & Proeven',
        'ONTDEK BIEREN',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const VindenProevenPage(),
          ),
        ),
        cornerAction: _buildScanButton(),
      ),
      _buildActionTile(
        Icons.map_outlined,
        Icons.location_on_outlined,
        'Kaart & Locaties',
        'BROUWERIJ KAART',
        () => _goTo(_tabMap),
      ),
      _buildActionTile(
        Icons.event_outlined,
        Icons.celebration_outlined,
        'Feestjes & Agenda',
        'BIER AGENDA',
        () => _goTo(_tabAgenda),
      ),
      _buildActionTile(
        Icons.group_outlined,
        Icons.forum_outlined,
        'Gezelligheid & Social',
        'GEMEENSCHAP',
        _openSocial,
      ),
      _buildActionTile(
        Icons.restaurant_menu,
        Icons.local_dining_outlined,
        'Bier & Spijs',
        'FOODPAIRING HUB',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const PairingHubPage(),
          ),
        ),
      ),
      _buildActionTile(
        Icons.play_circle_outline,
        Icons.movie_creation_outlined,
        'Brouwerij Highlights',
        'VIDEO\'S BEKIJKEN',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const VideoReelPage(),
          ),
        ),
      ),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: tiles[4]),
            const SizedBox(width: 16),
            Expanded(child: tiles[5]),
          ],
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const BeerScanPage(),
        ),
      ),
      child: Container(
        padding:
            const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              _background.withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color:
                _primary.withOpacity(0.3),
          ),
        ),
        child: const Icon(
          Icons.qr_code_scanner,
          color: _primary,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    IconData backgroundIcon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Widget? cornerAction,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration:
              _speakeasyDecoration(),
          clipBehavior:
              Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(
                  backgroundIcon,
                  size: 96,
                  color: _onSurface
                      .withOpacity(0.1),
                ),
              ),

              if (cornerAction != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: cornerAction,
                ),

              Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(
                        color: _primary
                            .withOpacity(0.1),
                        shape:
                            BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: _primary,
                        size: 30,
                      ),
                    ),

                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style:
                              GoogleFonts.playfairDisplay(
                            color:
                                _onSurface,
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          subtitle,
                          style:
                              GoogleFonts.openSans(
                            color:
                                _onSurfaceVariant,
                            fontSize: 10,
                            letterSpacing:
                                0.5,
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
      padding:
          const EdgeInsets.only(
        bottom: 16,
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.openSans(
          color: _primary,
          fontSize: 14,
          fontWeight:
              FontWeight.w600,
          letterSpacing: 2.8,
        ),
      ),
    );
  }

  Widget _buildNewPostButton() {
    final shape =
        RoundedRectangleBorder(
      borderRadius:
          BorderRadius.circular(12),
      side: BorderSide(
        color:
            _primary.withOpacity(0.4),
      ),
    );

    return Material(
      color:
          _primary.withOpacity(0.08),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: _openCreatePost,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: _primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Deel iets met de gemeenschap',
                  style:
                      GoogleFonts.openSans(
                    color: _onSurface,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: _primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcut(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final shape =
        RoundedRectangleBorder(
      borderRadius:
          BorderRadius.circular(12),
      side: BorderSide(
        color:
            _outlineVariant.withOpacity(
          0.3,
        ),
      ),
    );

    return Material(
      color: _surfaceContainerLow,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color:
                      _secondaryContainer
                          .withOpacity(0.3),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: _secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style:
                      GoogleFonts.openSans(
                    color: _onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color:
                    _onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxShadow get _amberGlow =>
      BoxShadow(
        color:
            _primary.withOpacity(0.1),
        blurRadius: 25,
      );

  BoxDecoration _speakeasyDecoration({
    Color? borderColor,
    double borderWidth = 1,
    bool glow = false,
  }) {
    return BoxDecoration(
      gradient:
          const LinearGradient(
        begin: Alignment(
          -0.57,
          -0.82,
        ),
        end: Alignment(
          0.57,
          0.82,
        ),
        colors: [
          Color(0xFF2C221C),
          _background,
        ],
      ),
      borderRadius:
          BorderRadius.circular(12),
      border: Border.all(
        color:
            borderColor ??
                _primary.withOpacity(0.1),
        width: borderWidth,
      ),
      boxShadow:
          glow ? [_amberGlow] : null,
    );
  }

  Widget _networkImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    Widget? fallback,
  }) {
    return Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy:
          WebHtmlElementStrategy.fallback,
      errorBuilder:
          (context, error, stackTrace) =>
              fallback ??
              Container(
                color:
                    _surfaceContainer,
              ),
    );
  }
}

class _BottomNavItem
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    final color = isSelected
        ? const Color(0xFFD4B28C)
        : const Color(0xFF9E8A7D);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
