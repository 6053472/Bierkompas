import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_service.dart';
import '../auth/auth_storage.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('name, email')
        .eq('id', authUser.id)
        .maybeSingle();
    if (!mounted) return;
    setState(() => _user = AppUser(
          id: authUser.id,
          name: profile?['name'] as String? ?? '',
          email: profile?['email'] as String? ?? authUser.email ?? '',
        ));
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
                  const Icon(Icons.menu, color: Color(0xFFEFE6DD)),
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
                              ),
                              child: const Center(
                                child: Icon(Icons.person, color: Color(0xFF9E8A7D), size: 50),
                              ),
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
                          '🏆 Master Taster - Level 4',
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
                            onPressed: () {},
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
                      _buildStatCard('124', 'GEPROEFD'),
                      const SizedBox(width: 10),
                      _buildStatCard('18', 'BROUWERIJEN'),
                      const SizedBox(width: 10),
                      _buildStatCard('12', 'BADGES'),
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
                      Text(
                        'Bekijk alles',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4B28C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Paspoort Grid (2x2)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildPassportCard('Brewery Explorer', Icons.shield),
                      _buildPassportCard('Weizen Lover', Icons.local_florist),
                      _buildPassportCard('Local Regular', Icons.sports_bar),
                      _buildPassportCard('Heritage Keeper', Icons.bookmark),
                    ],
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

  // Hulpwidget voor paspoort items
  Widget _buildPassportCard(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF3C3028),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFD4B28C), size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFFEFE6DD),
              fontSize: 13,
              fontWeight: FontWeight.w600,
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