import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_service.dart';
import '../auth/auth_storage.dart';
import 'add_friend_page.dart';
import 'all_badges_page.dart';
import 'friends_service.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';
import 'stats_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _statsService = StatsService();
  final _friendsService = FriendsService();
  AppUser? _user;
  ProfileStats? _stats;
  List<Friend>? _friends;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
    _loadFriends();
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
    final stats = await _statsService.fetchStats(authUser.id);
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _loadFriends() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    try {
      final friends = await _friendsService.list(authUser.id);
      if (!mounted) return;
      setState(() => _friends = friends);
    } on FriendsException catch (e) {
      debugPrint('Fout bij ophalen vrienden: $e');
    }
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddFriendPage()),
    );
    if (added == true) {
      _loadFriends();
    }
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Even breed als het agenda-icoon rechts, zodat de titel gecentreerd blijft.
                  const SizedBox(width: 24),
                  Text(
                    'Craft Discoveries',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFEFE6DD),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, color: Color(0xFFEFE6DD)),
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
                      Text(
                        'Bekijk alle',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4B28C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildTastingNoteCard(
                    title: 'Zundert 8 Trappist',
                    note: 'Prachtige kastanjebruine kleur met een stevige...',
                    rating: 5,
                  ),
                  const SizedBox(height: 12),
                  _buildTastingNoteCard(
                    title: 'La Chouffe',
                    note: 'Fris en fruitig met een aangename hint van...',
                    rating: 4,
                  ),
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
                  _buildFavoriteBreweryCard(
                    title: 'Brouwerij De Halve Maan',
                    location: 'Brugge, België',
                    rating: 5,
                  ),
                  const SizedBox(height: 12),
                  _buildFavoriteBreweryCard(
                    title: 'Jongens van de Wit',
                    location: '’s-Hertogenbosch',
                    rating: 4,
                  ),
                  const SizedBox(height: 24),

                  // Sectie: Mijn Bier-vrienden
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mijn Bier-vrienden',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFEFE6DD),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _openAddFriend,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3C3028),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_add_alt_1, color: Color(0xFFD4B28C), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Toevoegen',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFD4B28C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_friends == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
                      ),
                    )
                  else if (_friends!.isEmpty)
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
                            'Je hebt nog geen Bier-vrienden.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tik op "Toevoegen" om iemand te zoeken.',
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
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: _friends!
                          .map((friend) => _BeerFriend(name: friend.name, avatarUrl: friend.avatarUrl))
                          .toList(),
                    ),
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
}

class _BeerFriend extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _BeerFriend({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3C3028),
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? const Center(
                    child: Icon(Icons.person, color: Color(0xFF9E8A7D), size: 24),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.inter(
              color: const Color(0xFFEFE6DD),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 90,
            height: 28,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4B28C),
                foregroundColor: const Color(0xFF1E1712),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Proost!',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}