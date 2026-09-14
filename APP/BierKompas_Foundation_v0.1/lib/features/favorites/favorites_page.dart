import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero, // Randen laten aansluiten voor de header container
          children: [
            // Header met afgeronde hoeken aan de onderkant
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
                      Row(
                        children: [
                          const Icon(Icons.sports_bar, color: Color(0xFFD4B28C), size: 30, ),
                          const SizedBox(width: 8),
                          Text(
                            'De Moderne Speakeasy',
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFEFE6DD),
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.search, color: Color(0xFFEFE6DD)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Gecureerde Selecties',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFD4B28C),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jouw persoonlijke collectie van ambachtelijke bieren, met de hand geselecteerd op basis van hun uitzonderlijke profiel en erfgoed.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9E8A7D),
                      fontSize: 13,
                     
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Kaarten met padding aan de zijkanten
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildFavoriteCard(
                    title: 'Westvleteren 12',
                    brewery: 'Brouwerij De Sint-Sixtusabdij',
                    abv: '10.2% ABV',
                    rating: 5.0,
                    tag: 'TRAPPIST ALE',
                  ),
                  const SizedBox(height: 20),
                  _buildFavoriteCard(
                    title: 'Citrus Haze DIPA',
                    brewery: 'Cloudwater Brew Co.',
                    abv: '8.5% ABV',
                    rating: 4.5,
                    tag: 'HAZY DIPA',
                  ),
                  const SizedBox(height: 20),
                  _buildFavoriteCard(
                    title: 'Double Barrel Vanilla',
                    brewery: 'Side Project Brewing',
                    abv: '14.0% ABV',
                    rating: 5.0,
                    tag: 'IMPERIAL STOUT',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard({
    required String title,
    required String brewery,
    required String abv,
    required double rating,
    required String tag,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(16),
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
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                color: const Color(0xFF4A3B32),
                child: const Center(
                  child: Icon(Icons.image, color: Color(0xFF8C7365), size: 48),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1712).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD4B28C),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1712).withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Color(0xFFD4B28C), size: 18),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      abv,
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
                  brewery,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.floor() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C3028),
                      foregroundColor: const Color(0xFFEFE6DD),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Bekijk Proefnotities',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
}