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

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId);

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evenement verwijderd'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Fout bij verwijderen evenement: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij verwijderen: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String eventId,
    String eventName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Evenement verwijderen?',
            style: GoogleFonts.playfairDisplay(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Weet je zeker dat je "$eventName" wilt verwijderen?',
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Annuleren',
                style: GoogleFonts.inter(
                  color: secondaryTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Verwijderen',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteEvent(eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _supabase.auth.currentUser;

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
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_bar,
                        color: beigeColor,
                        size: 30,
                      ),
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
                    'Jouw overzicht van exclusieve bierproeverijen en festivals.',
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
              child: CircularProgressIndicator(
                color: beigeColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Fout bij het laden: ${snapshot.error}',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 14,
                  ),
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
                  const Icon(
                    Icons.event_busy,
                    color: secondaryTextColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Geen evenementen gevonden',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

                final eventId = event['id']?.toString() ?? '';
                final eventUserId = event['user_id']?.toString() ?? '';

                final isOwner =
                    currentUser != null &&
                    eventUserId == currentUser.id;

                final name = event['name'] ?? 'Naamloos';
                final eventType = event['event_type'] ?? 'Festival';
                final city = event['city'] ?? '';
                final locationName = event['location_name'] ?? '';
                final description = event['description'] ?? '';

                final imageAsset = event['image_asset'];
                final imageUrl = imageAsset?.toString().trim();

                final hasImage =
                    imageUrl != null &&
                    imageUrl.isNotEmpty &&
                    imageUrl != 'null';

                final isRegular = event['ticket_regular'] == true;
                final isBeer = event['ticket_beer'] == true;
                final isVip = event['ticket_vip'] == true;

                final List<String> tickets = [];

                if (isRegular) {
                  tickets.add('Regulier');
                }

                if (isBeer) {
                  tickets.add('Bier-ticket');
                }

                if (isVip) {
                  tickets.add('VIP');
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        if (hasImage)
                          Positioned.fill(
                            child: Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
                            ),
                          ),

                        if (hasImage)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.35),
                                    Colors.black.withOpacity(0.75),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // VERWIJDERKNOP RECHTSBOVEN
                        if (isOwner && eventId.isNotEmpty)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: backgroundColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(7),
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 21,
                                ),
                                onPressed: () {
                                  _confirmDelete(
                                    context,
                                    eventId,
                                    name.toString(),
                                  );
                                },
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 130),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          backgroundColor.withOpacity(0.9),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                        color:
                                            beigeColor.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      eventType
                                          .toString()
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: beigeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (city
                                      .toString()
                                      .isNotEmpty)
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            backgroundColor.withOpacity(0.9),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        city.toString(),
                                        style: GoogleFonts.inter(
                                          color: textColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text(
                                name.toString(),
                                style: GoogleFonts.playfairDisplay(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),

                              if (locationName
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  locationName.toString(),
                                  style: GoogleFonts.inter(
                                    color: beigeColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 8),

                              Text(
                                description.toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: textColor.withOpacity(0.9),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),

                              if (tickets.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  children: tickets.map((ticket) {
                                    return Chip(
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor:
                                          backgroundColor.withOpacity(0.9),
                                      labelStyle: GoogleFonts.inter(
                                        color: textColor,
                                        fontSize: 11,
                                      ),
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        side: const BorderSide(
                                          color: borderColor,
                                        ),
                                      ),
                                      label: Text(ticket),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EventCreatePage(),
            ),
          );

          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}