import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: SafeArea(
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C221C),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4B28C).withOpacity(0.12),
                    blurRadius: 12,
                    spreadRadius: 6,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sports_bar, color: Color(0xFFD4B28C)),
                          const SizedBox(width: 8),
                          Text(
                            'Bierkompas',
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFEFE6DD),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.search, color: Color(0xFFEFE6DD)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E241E),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF9E8A7D), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Zoek brouwerijen of steden...',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(Icons.tune, color: Color(0xFF9E8A7D), size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sectie titel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Brouwerijen in de buurt',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFEFE6DD),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Alles bekijken →',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD4B28C),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Center(
                child: SizedBox(
                  height: 400, 
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      _buildBreweryCard(
                        title: 'Brouwerij Hoop',
                        distance: '0.8 km bij jou vandaan',
                        rating: '4.8',
                        tags: ['IPA', 'PROEFLOKAAL'],
                      ),
                      const SizedBox(width: 16),
                      _buildBreweryCard(
                        title: 'Saint Sixtus',
                        distance: '1.2 km bij jou vandaan',
                        rating: '4.9',
                        tags: ['TRAPPIST', 'BEPERKT'],
                      ),
                      const SizedBox(width: 16),
                      _buildBreweryCard(
                        title: 'De Molen',
                        distance: '3.5 km bij jou vandaan',
                        rating: '4.7',
                        tags: ['STOUTS', 'BARREL'],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBreweryCard({
    required String title,
    required String distance,
    required String rating,
    required List<String> tags,
  }) {
    return Container(
      width: 300, // Vergrote breedte van de kaart
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4B28C).withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 165, // Vergrote hoogte van de afbeelding/placeholder
            decoration: const BoxDecoration(
              color: Color(0xFF4A3B32),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Center(
              child: Icon(Icons.image, color: Color(0xFF8C7365), size: 48),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
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
                          fontSize: 18, // Iets groter lettertype voor de titel
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.navigation, color: Color(0xFF9E8A7D), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        distance,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9E8A7D),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1712),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFC4A482),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}