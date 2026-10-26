import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_service.dart';
import '../auth/auth_storage.dart';
import '../favorites/favorites_service.dart';
import '../map/breweries.dart';
import '../support/faq_page.dart';
import 'add_friend_page.dart';
import 'all_badges_page.dart';
import 'all_tasting_notes_page.dart';
import 'chat_page.dart';
import 'cheers_service.dart';
import 'create_tasting_note_page.dart';
import 'friends_service.dart';
import 'friend_qr.dart';
import 'notifications_page.dart';
import 'notifications_service.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';
import 'stats_service.dart';
import 'tasting_notes_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _statsService = StatsService();
  final _friendsService = FriendsService();
  final _cheersService = CheersService();
  final _favoritesService = FavoritesService();
  final _tastingNotesService = TastingNotesService();
  final _notificationsService = NotificationsService();
  int _unreadNotifications = 0;
  AppUser? _user;
  ProfileStats? _stats;
  List<Brewery>? _favoriteBreweries;
  List<TastingNote>? _tastingNotes;
  List<Friend>? _friends;
  List<FriendRequest>? _incomingRequests;
  final Set<String> _pendingRequestActions = {};
  final Set<String> _sendingCheerIds = {};
  RealtimeChannel? _friendsChannel;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
    _loadFavoriteBreweries();
    _loadTastingNotes();
    _loadFriends();
    _subscribeToFriendUpdates();
    _loadUnreadNotifications();
  }

  Future<void> _loadUnreadNotifications() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    final count = await _notificationsService.fetchUnreadCount(authUser.id);
    if (!mounted) return;
    setState(() => _unreadNotifications = count);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    _loadUnreadNotifications();
  }

  @override
  void dispose() {
    _friendsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('name, email, avatar_url')
        .eq('id', authUser.id)
        .maybeSingle();
    if (!mounted) return;
    setState(() => _user = AppUser(
          id: authUser.id,
          name: profile?['name'] as String? ?? '',
          email: profile?['email'] as String? ?? authUser.email ?? '',
          avatarUrl: profile?['avatar_url'] as String?,
        ));
  }

  Future<void> _loadStats() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    try {
      final stats = await _statsService.fetchStats(authUser.id);
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      // Zonder deze try/catch bleef _stats bij een fout stil op null staan
      // (streak/badges tonen dan altijd 0), zonder enige foutmelding.
      debugPrint('Fout bij ophalen stats/streak: $e');
    }
  }

  Future<void> _loadFavoriteBreweries() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    try {
      final favorites = await _favoritesService.list(authUser.id);
      final breweryIds = favorites
          .where((f) => f.itemType == breweryItemType)
          .map((f) => f.itemId)
          .toSet();
      final favoriteBreweries = breweries.where((b) => breweryIds.contains(b.id)).toList();
      if (!mounted) return;
      setState(() => _favoriteBreweries = favoriteBreweries);
    } on FavoritesException catch (e) {
      debugPrint('Fout bij ophalen favoriete brouwerijen: $e');
    }
  }

  Future<void> _loadTastingNotes() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    try {
      final notes = await _tastingNotesService.fetchAll(authUser.id);
      if (!mounted) return;
      setState(() => _tastingNotes = notes);
    } on TastingNoteException catch (e) {
      debugPrint('Fout bij ophalen proefnotities: $e');
      if (!mounted) return;
      setState(() => _tastingNotes = []);
    }
  }

  Future<void> _addTastingNote() async {
    final created = await Navigator.of(context).push<TastingNote>(
      MaterialPageRoute(builder: (_) => const CreateTastingNotePage()),
    );
    if (created == null || !mounted) return;
    setState(() => _tastingNotes = [created, ...?_tastingNotes]);
    // Een proefnotitie kan de Bier Streak en badges bijwerken.
    _loadStats();
  }

  Future<void> _openAllTastingNotes() async {
    final updated = await Navigator.of(context).push<List<TastingNote>>(
      MaterialPageRoute(builder: (_) => AllTastingNotesPage(notes: _tastingNotes ?? [])),
    );
    if (updated == null || !mounted) return;
    setState(() => _tastingNotes = updated);
    _loadStats();
  }

  Future<void> _loadFriends() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    try {
      final results = await Future.wait([
        _friendsService.listFriends(authUser.id),
        _friendsService.listIncomingRequests(authUser.id),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<Friend>;
        _incomingRequests = results[1] as List<FriendRequest>;
      });
    } on FriendsException catch (e) {
      debugPrint('Fout bij ophalen vrienden: $e');
    }
  }

  // Houdt de vriendenlijst live: zodra iemand een verzoek stuurt, accepteert
  // of weigert, komt dat via Supabase Realtime meteen binnen, zonder dat de
  // gebruiker de pagina hoeft te verversen.
  void _subscribeToFriendUpdates() {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    _friendsChannel = Supabase.instance.client
        .channel('friend_requests_${authUser.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: authUser.id,
          ),
          callback: (_) => _loadFriends(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'requester_id',
            value: authUser.id,
          ),
          callback: (_) => _loadFriends(),
        )
        .subscribe();
  }

  Future<void> _openAddFriend() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddFriendPage()),
    );
    if (sent == true) {
      _loadFriends();
    }
  }

  Future<void> _respondToRequest(FriendRequest request, bool accept) async {
    setState(() => _pendingRequestActions.add(request.requesterId));
    try {
      await _friendsService.respondToRequest(requesterId: request.requesterId, accept: accept);
      if (!mounted) return;
      setState(() {
        _pendingRequestActions.remove(request.requesterId);
        _incomingRequests?.removeWhere((r) => r.requesterId == request.requesterId);
        if (accept) {
          _friends = [
            ...?_friends,
            Friend(id: request.requesterId, name: request.name, avatarUrl: request.avatarUrl),
          ];
        }
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() => _pendingRequestActions.remove(request.requesterId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reageren mislukt: $e')),
      );
    }
  }

  Future<void> _sendCheer(Friend friend) async {
    setState(() => _sendingCheerIds.add(friend.id));
    try {
      await _cheersService.sendCheer(friend.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost verstuurd naar ${friend.name}!')),
      );
    } on CheersException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost versturen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingCheerIds.remove(friend.id));
    }
  }

  void _openChat(Friend friend) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatPage(friend: friend)),
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
      backgroundColor: const Color(0xFF1E1712),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Color(0xFF2C221C),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  if ((_stats?.currentStreak ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4B28C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFD4B28C).withOpacity(0.4)),
                        ),
                        child: Text(
                          '🔥 ${_stats!.currentStreak}',
                          maxLines: 1,
                          softWrap: false,
                          style: GoogleFonts.inter(color: const Color(0xFFD4B28C), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'Profiel',
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFFEFE6DD),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C221C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [

                        Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF3C3028),
                                border: Border.all(
                                  color: const Color(0xFFD4B28C).withOpacity(0.5),
                                  width: 2,
                                ),
                                image: _user?.avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_user!.avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _user?.avatarUrl == null
                                  ? const Center(
                                      child: Icon(Icons.person, color: Color(0xFF9E8A7D), size: 50),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD4B28C),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Color(0xFF1E1712),
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _user?.name ?? 'Gast',
                          style: GoogleFonts.playfairDisplay(
                            color: const Color(0xFFEFE6DD),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.mail_outline, color: Color(0xFF9E8A7D), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _user?.email ?? '-',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9E8A7D),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (_stats?.currentStreak ?? 0) > 0
                              ? '🔥 ${_stats!.currentStreak} dagen op rij'
                              : '🔥 Begin vandaag je streak',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4B28C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final updated = await Navigator.of(context).push<AppUser>(
                                MaterialPageRoute(
                                  builder: (_) => ProfileEditPage(user: _user),
                                ),
                              );
                              if (updated != null && mounted) {
                                setState(() => _user = updated);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4B28C),
                              foregroundColor: const Color(0xFF1E1712),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Bewerk Profiel',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _openNotifications,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD4B28C)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Berichten',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFD4B28C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_unreadNotifications > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4B28C),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$_unreadNotifications',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF1E1712),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SettingsPage(user: _user)),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD4B28C)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Instellingen',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD4B28C),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const FaqPage()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD4B28C)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Help & FAQ',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD4B28C),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: Color(0xFF9E8A7D), size: 18),
                            label: Text(
                              'Uitloggen',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9E8A7D),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      _buildStatCard('${_stats?.beersTasted ?? 0}', 'GEPROEFD'),
                      const SizedBox(width: 10),
                      _buildStatCard('${_stats?.breweriesExplored ?? 0}', 'BROUWERIJEN'),
                      const SizedBox(width: 10),
                      _buildStatCard('${_stats?.earnedBadgeCount ?? 0}', 'BADGES'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sectie: Mijn Bier-Paspoort
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mijn Bier-Paspoort',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFEFE6DD),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _stats == null
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AllBadgesPage(badges: _stats!.badges),
                                  ),
                                ),
                        child: Text(
                          'Bekijk alles',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4B28C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Paspoort Grid: preview van een paar badges, de rest zie je via "Bekijk alles".
                  if (_stats == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
                      ),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: _stats!.badges
                          .take(4)
                          .map((badge) => _buildPassportCard(
                                badge.title,
                                badge.icon,
                                badge.earned,
                                imageAsset: badge.imageAsset,
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 24),

                  // Sectie: Mijn Proefnotities
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mijn Proefnotities',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFEFE6DD),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _addTastingNote,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.add_circle_outline, color: Color(0xFFD4B28C), size: 20),
                            ),
                          ),
                          GestureDetector(
                            onTap: _tastingNotes == null ? null : _openAllTastingNotes,
                            child: Text(
                              'Bekijk alle',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD4B28C),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_tastingNotes == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
                      ),
                    )
                  else if (_tastingNotes!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C221C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Nog geen proefnotities. Tik op + om je eerste bier te noteren.',
                        style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 13),
                      ),
                    )
                  else
                    for (final note in _tastingNotes!.take(2)) ...[
                      _buildTastingNoteCard(
                        title: note.beerName,
                        note: note.note,
                        rating: note.rating,
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Favoriete Brouwerijen',
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFFEFE6DD),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Favoriete Brouwerij Kaarten
                  if (_favoriteBreweries == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
                      ),
                    )
                  else if (_favoriteBreweries!.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C221C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Je hebt nog geen favoriete brouwerijen.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tik op het hartje bij een brouwerij op de Kaart om hem toe te voegen.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (int i = 0; i < _favoriteBreweries!.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildFavoriteBreweryCard(
                        title: _favoriteBreweries![i].title,
                        location: _favoriteBreweries![i].location,
                        rating: double.tryParse(_favoriteBreweries![i].rating)?.round() ?? 5,
                      ),
                    ],
                  const SizedBox(height: 24),

                  // Sectie: Mijn Bier-vrienden
                  _buildFriendsSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C221C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFD4B28C),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF9E8A7D),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hulpwidget voor paspoort items. Vergrendelde badges tonen gedimd.
  Widget _buildPassportCard(String title, IconData icon, bool earned, {String? imageAsset}) {
    final accent = earned ? const Color(0xFFD4B28C) : const Color(0xFF6B5D50);
    final textColor = earned ? const Color(0xFFEFE6DD) : const Color(0xFF9E8A7D);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageAsset != null)
            Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: earned
                      ? Image.asset(
                          'assets/badges/$imageAsset.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                          child: Opacity(
                            opacity: 0.5,
                            child: Image.asset(
                              'assets/badges/$imageAsset.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
                if (!earned)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: Color(0xFFEFE6DD), size: 20),
                  ),
              ],
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3C3028),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                if (!earned)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: Color(0xFFEFE6DD), size: 20),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTastingNoteCard({
    required String title,
    required String note,
    required int rating,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3C3028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.sports_bar, color: Color(0xFF9E8A7D), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFEFE6DD),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFD4B28C),
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteBreweryCard({
    required String title,
    required String location,
    required int rating,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3C3028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.image, color: Color(0xFF9E8A7D), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFFD4B28C),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFD4B28C),
                      size: 14,
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

  Widget _buildFriendsSection() {
    final friends = _friends == null
        ? null
        : ([..._friends!]..sort((a, b) {
            if (a.online != b.online) return a.online ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }));
    final requests = _incomingRequests;
    final onlineCount = friends?.where((f) => f.online).length ?? 0;

    Widget card(List<Widget> rows, {bool highlight = false}) => Container(
          decoration: BoxDecoration(
            color: _friendsCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: highlight ? _friendsPrimary.withOpacity(0.45) : _friendsDivider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, color: _friendsDivider, indent: 70),
                rows[i],
              ],
            ],
          ),
        );

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(text, style: GoogleFonts.inter(color: _friendsPrimary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Mijn Bier-vrienden',
                style: GoogleFonts.playfairDisplay(color: _friendsOnSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (friends != null && friends.isNotEmpty)
              Text(
                '${friends.length} ${friends.length == 1 ? 'vriend' : 'vrienden'}'
                '${onlineCount > 0 ? ' · $onlineCount online' : ''}',
                style: GoogleFonts.inter(color: _friendsMuted, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FriendsActionButton(
                icon: Icons.person_add_alt_1,
                label: 'Vriend toevoegen',
                filled: true,
                onTap: _openAddFriend,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FriendsActionButton(
                icon: Icons.qr_code_2,
                label: 'Mijn QR-code',
                onTap: () => showMyFriendQr(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (friends == null || requests == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: _friendsPrimary)),
          )
        else ...[
          if (requests.isNotEmpty) ...[
            label('VRIENDSCHAPSVERZOEKEN (${requests.length})'),
            card(
              [
                for (final request in requests)
                  _FriendRequestRow(
                    name: request.name,
                    avatarUrl: request.avatarUrl,
                    busy: _pendingRequestActions.contains(request.requesterId),
                    onAccept: () => _respondToRequest(request, true),
                    onDecline: () => _respondToRequest(request, false),
                  ),
              ],
              highlight: true,
            ),
            const SizedBox(height: 16),
          ],
          if (friends.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: _friendsCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _friendsDivider),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: _friendsPrimary.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.group_outlined, color: _friendsPrimary, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text('Nog geen Bier-vrienden', style: GoogleFonts.inter(color: _friendsOnSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Zoek vrienden op naam of laat ze je QR-code scannen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: _friendsMuted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            )
          else ...[
            label('VRIENDEN'),
            card([
              for (final friend in friends)
                _FriendRow(
                  name: friend.name,
                  avatarUrl: friend.avatarUrl,
                  online: friend.online,
                  sending: _sendingCheerIds.contains(friend.id),
                  onProost: () => _sendCheer(friend),
                  onTap: () => _openChat(friend),
                ),
            ]),
          ],
        ],
      ],
    );
  }
}

// ---------- Mijn Bier-vrienden ----------

const _friendsCard = Color(0xFF2C221C);
const _friendsDivider = Color(0xFF3C3028);
const _friendsPrimary = Color(0xFFD4B28C);
const _friendsOnSurface = Color(0xFFEFE6DD);
const _friendsMuted = Color(0xFF9E8A7D);
const _friendsOnline = Color(0xFF4CAF50);

/// Ronde profielfoto met (optioneel) een groen online-bolletje.
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({this.avatarUrl, this.online = false, this.size = 44});

  final String? avatarUrl;
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _friendsDivider,
            image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover) : null,
          ),
          child: avatarUrl == null ? Icon(Icons.person, color: _friendsMuted, size: size * 0.5) : null,
        ),
        if (online)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _friendsOnline,
                border: Border.all(color: _friendsCard, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Knop over de halve breedte boven de vriendenlijst ("Vriend toevoegen",
/// "Mijn QR-code").
class _FriendsActionButton extends StatelessWidget {
  const _FriendsActionButton({required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? const Color(0xFF1E1712) : _friendsPrimary;
    return Material(
      color: filled ? _friendsPrimary : _friendsCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: _friendsPrimary.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: foreground, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Binnengekomen vriendschapsverzoek met Accepteren/Weigeren.
class _FriendRequestRow extends StatelessWidget {
  const _FriendRequestRow({
    required this.name,
    this.avatarUrl,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _FriendAvatar(avatarUrl: avatarUrl, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: _friendsOnSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Wil Bier-vrienden worden', style: GoogleFonts.inter(color: _friendsMuted, fontSize: 12)),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _friendsPrimary))
          else ...[
            IconButton(
              onPressed: onDecline,
              tooltip: 'Weigeren',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: _friendsDivider),
              icon: const Icon(Icons.close, size: 18, color: _friendsMuted),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _friendsPrimary,
                  foregroundColor: const Color(0xFF1E1712),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Accepteren', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Eén Bier-vriend: tik om te chatten, "Proost!" om te proosten.
class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.name,
    this.avatarUrl,
    this.online = false,
    this.onTap,
    this.onProost,
    this.sending = false,
  });

  final String name;
  final String? avatarUrl;
  final bool online;
  final VoidCallback? onTap;
  final VoidCallback? onProost;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _FriendAvatar(avatarUrl: avatarUrl, online: online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: _friendsOnSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: GoogleFonts.inter(color: online ? _friendsOnline : _friendsMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              tooltip: 'Chatten',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chat_bubble_outline, size: 20, color: _friendsMuted),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                onPressed: sending ? null : onProost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _friendsPrimary,
                  foregroundColor: const Color(0xFF1E1712),
                  disabledBackgroundColor: _friendsDivider,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: sending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _friendsPrimary))
                    : const Icon(Icons.sports_bar, size: 16),
                label: Text('Proost!', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
