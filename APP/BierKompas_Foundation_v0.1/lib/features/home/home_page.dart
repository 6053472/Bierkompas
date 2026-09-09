import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../favorites/favorites_page.dart';
import '../map/map_page.dart';
import '../profile/profile_page.dart';
import '../profile/stats_service.dart';
import '../events/events_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _statsService = StatsService();
  int _currentIndex = 0;
  int _currentStreak = 0;

    final List<Widget> _pages = [
    const DiscoveryContentPage(), // Index 0: Ontdek
    const EventsPage(), // Index 1: Agenda
    const FavoritesPage(),       
    const MapPage(),              
    const ProfilePage(),         
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: _pages[_currentIndex],
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

class DiscoveryContentPage extends StatelessWidget {
  final int streak;

  const DiscoveryContentPage({super.key, this.streak = 0});

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Brouwerij Restaurants',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFEFE6DD),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (streak > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4B28C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFD4B28C).withOpacity(0.4)),
                              ),
                              child: Text(
                                '🔥 $streak',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFD4B28C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          const Icon(Icons.search, color: Color(0xFFEFE6DD)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ambachtelijk Dineren',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFD4B28C),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ontdek waar de kunst van het brouwen en culinaire perfectie samenkomen. Verken onze zorgvuldig geselecteerde brouwerijen met hoogwaardige keukens op locatie.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9E8A7D),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('Alle Locaties', selected: true),
                      _buildChip('Gastropub'),
                      _buildChip('Fine Dining'),
                      _buildChip('Van Boer naar Bord'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildCard(
                    title: 'The Amber Vault',
                    subtitle: 'Gastropub • 1.2km',
                    rating: '4.9 (124 recensies)',
                    imageHeight: 180,
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    title: 'Copper Kettle Kitchen',
                    subtitle: 'FINE DINING • 3.5KM',
                    rating: '4.7',
                    badge: 'AANRADER',
                    badgeText: 'In stout gestoofde short ribs',
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    title: 'Copper Kettle Kitchen',
                    subtitle: 'FINE DINING • 3.5KM',
                    rating: '4.7',
                    badge: 'AANRADER',
                    badgeText: 'In stout gestoofde short ribs',
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    title: 'Copper Kettle Kitchen',
                    subtitle: 'FINE DINING • 3.5KM',
                    rating: '4.7',
                    badge: 'AANRADER',
                    badgeText: 'In stout gestoofde short ribs',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFD4B28C).withOpacity(0.2) : const Color(0xFF1E1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? const Color(0xFFD4B28C) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? const Color(0xFFD4B28C) : const Color(0xFF9E8A7D),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required String rating,
    String? badge,
    String? badgeText,
    double imageHeight = 140,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4B28C).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: imageHeight,
            width: double.infinity,
            color: const Color(0xFF3C3028),
            child: const Center(
              child: Icon(Icons.image, color: Color(0xFF9E8A7D), size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFFD4B28C),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      rating,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4B28C),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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