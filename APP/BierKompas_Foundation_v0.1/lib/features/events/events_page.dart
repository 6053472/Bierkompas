import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_create.dart';
import '../../shared/profile_avatar_button.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, this.avatarUrl, this.onProfileTap});

  final String? avatarUrl;
  final VoidCallback? onProfileTap;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color borderColor = Color(0xFF3C3028);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

  // Future om evenementen op te halen uit Supabase
  Future<List<Map<String, dynamic>>> _fetchEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Fout bij ophalen evenementen: $e');
      throw 'Kon evenementen niet laden: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160),
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            color: cardColor,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_bar, color: beigeColor, size: 30),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Evenementen',
                          style: GoogleFonts.playfairDisplay(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.onProfileTap != null)
                        ProfileAvatarButton(
                          onTap: widget.onProfileTap!,
                          avatarUrl: widget.avatarUrl,
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'De Moderne Events',
                    style: GoogleFonts.playfairDisplay(
                      color: beigeColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jouw overzicht van exclusieve bierproeverijen en festivals, met de hand geselecteerd op basis van hun uitzonderlijke profiel en erfgoed.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: secondaryTextColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: beigeColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Fout bij het laden: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, color: secondaryTextColor, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Geen evenementen gevonden',
                    style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Voeg als eerste een smaakvol evenement toe!',
                    style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: beigeColor,
            backgroundColor: cardColor,
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                
                final name = event['name'] ?? 'Naamloos evenement';
                final eventType = event['event_type'] ?? 'Festival';
                final city = event['city'] ?? '';
                final locationName = event['location_name'] ?? '';
                final description = event['description'] ?? '';
                
                final isRegular = event['ticket_regular'] == true;
                final isBeer = event['ticket_beer'] == true;
                final isVip = event['ticket_vip'] == true;

                List<String> tickets = [];
                if (isRegular) tickets.add('Regulier');
                if (isBeer) tickets.add('Bier-ticket');
                if (isVip) tickets.add('VIP');

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4B28C).withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: beigeColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              eventType.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: beigeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (city.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: secondaryTextColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  city,
                                  style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 12),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: GoogleFonts.playfairDisplay(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (locationName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          locationName,
                          style: GoogleFonts.inter(color: beigeColor, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      if (tickets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: tickets.map((t) {
                            return Chip(
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: backgroundColor,
                              labelStyle: GoogleFonts.inter(color: textColor, fontSize: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: const BorderSide(color: borderColor),
                              ),
                              label: Text(t),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: beigeColor,
        foregroundColor: backgroundColor,
        elevation: 0,
        onPressed: () async {
          // Open aanmaakpagina en ververs de lijst zodra je terugkomt
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EventCreatePage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}