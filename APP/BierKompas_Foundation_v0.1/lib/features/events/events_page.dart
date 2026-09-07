import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EventPage extends StatelessWidget {
  const EventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header container met afgeronde onderkant
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
                      const Icon(Icons.menu, color: Color(0xFFEFE6DD)),
                      Text(
                        'Bier Agenda',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFEFE6DD),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, color: Color(0xFFEFE6DD)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PLANNING',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9E8A7D),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMonthChip('Okt', selected: true),
                        const SizedBox(width: 8),
                        _buildMonthChip('Nov'),
                        const SizedBox(width: 8),
                        _buildMonthChip('Dec'),
                        const SizedBox(width: 8),
                        _buildMonthChip('Jan 2027'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inhoud / Event kaarten lijst
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Grote uitgelichte event kaart
                  _buildFeaturedEventCard(
                    title: 'PINT Bokbierfestival',
                    category: 'LIEFHEBBERS FESTIVAL',
                    location: 'Beurs van Berlage, Amsterdam',
                    date: '25 - 27 oktober, 2026',
                    description:
                        'Het grootste bokbierfestival van Nederland keert terug naar de historische Beurs van Berlage. Proef meer dan 50 unieke bockbieren in een iconische architecturale setting.',
                    attendees: 'Marcus, Sandra +anderen gaan',
                  ),
                  const SizedBox(height: 16),

                  // Normale event kaarten
                  _buildStandardEventCard(
                    title: 'TAPT Festival Rotterdam',
                    category: 'OKT 2026',
                    description:
                        'Meer dan alleen bier. Proef de mix van spellen, dansen en de liefste lokale bieren in het hart van Rotterdam. De ultimate sociale craft ervaring.',
                    attendees: 'J.J. +anderen gaan',
                    location: 'tapt.nl',
                  ),
                  const SizedBox(height: 16),
                  _buildStandardEventCard(
                    title: 'Mout Nijmegen',
                    category: 'ZOMER 2026',
                    description:
                        'Een gastronomische reis langs internationale craft bieren. Ontdek verborgen parels uit heel Europa terwijl je geniet van live jazz en vinyl sets.',
                    attendees: 'S.V. +anderen gaan',
                    location: 'moutnijmegen.nl',
                  ),
                  const SizedBox(height: 16),
                  _buildStandardEventCard(
                    title: 'NL Bier Week',
                    category: 'MEI 2027',
                    description:
                        'Met de legendarische Nederlandse brouwerijendagen! Neem een kijkje achter de schermen bij de mooiste innovatieve brouwerijen van het land.',
                    attendees: 'Van der Veen +anderen gaan',
                    location: 'nlbierweek.nl',
                  ),
                  const SizedBox(height: 24),

                  // Onderste "Mis geen enkele druppel" card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C221C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis geen enkele druppel',
                          style: GoogleFonts.playfairDisplay(
                            color: const Color(0xFFEFE6DD),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ontvang exclusieve vroege toegang tot de grootste festivals en besloten brouwerijen direct in je inbox.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9E8A7D),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1712),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3C3028)),
                          ),
                          child: Text(
                            'jouw@email.adres',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildMonthChip(String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFD4B28C) : const Color(0xFF1E1712),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? const Color(0xFF1E1712) : const Color(0xFF9E8A7D),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFeaturedEventCard({
    required String title,
    required String category,
    required String location,
    required String date,
    required String description,
    required String attendees,
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
          // Afbeelding placeholder
          Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFF3C3028),
            child: const Center(
              child: Icon(Icons.image, color: Color(0xFF9E8A7D), size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4B28C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4B28C),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.bookmark_border, color: Color(0xFFD4B28C), size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFFD4B28C),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFFD4B28C), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEFE6DD),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFD4B28C), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      location,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEFE6DD),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.people, color: Color(0xFF9E8A7D), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      attendees,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9E8A7D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4B28C),
                          foregroundColor: const Color(0xFF1E1712),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Tickets',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD4B28C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Opslaan',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4B28C),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1712),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3C3028)),
                      ),
                      child: const Icon(Icons.share, color: Color(0xFFD4B28C), size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardEventCard({
    required String title,
    required String category,
    required String description,
    required String attendees,
    required String location,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            color: const Color(0xFF3C3028),
            child: const Center(
              child: Icon(Icons.image, color: Color(0xFF9E8A7D), size: 30),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4B28C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4B28C),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.share, color: Color(0xFFD4B28C), size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFFD4B28C),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: Color(0xFF9E8A7D), size: 12),
                        const SizedBox(width: 6),
                        Text(
                          attendees,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9E8A7D),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD4B28C)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Tickets',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4B28C),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}