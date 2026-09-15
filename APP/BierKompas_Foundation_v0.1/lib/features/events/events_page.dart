import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/chat_service.dart';
import '../profile/friends_service.dart';
import 'admin_events_page.dart';
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
  final _chatService = ChatService();
  final _friendsService = FriendsService();

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color borderColor = Color(0xFF3C3028);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _supabase.from('profiles').select('is_admin').eq('id', user.id).maybeSingle();
      if (!mounted) return;
      setState(() => _isAdmin = profile?['is_admin'] == true);
    } catch (_) {
      // Geen beheerder: gewoon negeren, knop blijft verborgen.
    }
  }

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

  // Een al gepubliceerd (goedgekeurd) evenement laat de maker vervallen
  // i.p.v. het te verwijderen: het blijft zichtbaar met een "Vervallen"-stempel.
  Future<void> _cancelEvent(int eventId, String eventName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          'Evenement laten vervallen?',
          style: GoogleFonts.playfairDisplay(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"$eventName" blijft zichtbaar in de agenda, maar met een "Vervallen"-stempel.',
          style: GoogleFonts.inter(color: textColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Annuleren', style: GoogleFonts.inter(color: secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Laten vervallen', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabase.rpc('cancel_event', params: {'p_event_id': eventId});
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laten vervallen mislukt: $e')),
      );
    }
  }

  // Op een echte iOS/Android-app toont het systeemdeelmenu (Share.share)
  // zelf al Facebook/Instagram/TikTok/WhatsApp e.d. — daar hoeven we geen
  // eigen weblinks voor te bouwen. Die handmatige links zijn alleen een
  // noodgreep voor web, waar Share.share() geen bruikbaar menu heeft.
  void _openShareSheet(Map<String, dynamic> event) {
    if (!kIsWeb) {
      showModalBottomSheet(
        context: context,
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: secondaryTextColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person, color: beigeColor),
                title: Text('Deel met een Biervriend', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareWithFriend(event);
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share, color: beigeColor),
                title: Text(
                  'Meer opties (Facebook, Instagram, TikTok, ...)',
                  style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Share.share(_shareText(event), subject: event['name']?.toString());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: secondaryTextColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person, color: beigeColor),
              title: Text('Deel met een Biervriend', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareWithFriend(event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: Text('WhatsApp', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareViaUrl('https://wa.me/?text=${Uri.encodeComponent(_shareText(event))}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
              title: Text('Facebook', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareViaUrl(
                  'https://www.facebook.com/sharer/sharer.php?quote=${Uri.encodeComponent(_shareText(event))}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag, color: beigeColor),
              title: Text('X (Twitter)', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareViaUrl('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareText(event))}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined, color: beigeColor),
              title: Text('Kopieer tekst (voor Instagram/TikTok)', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Instagram en TikTok bieden geen kant-en-klare deel-link; plak de tekst zelf in je verhaal of bio.',
                style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: _shareText(event)));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tekst gekopieerd naar klembord.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share, color: beigeColor),
              title: Text('Systeemdeelmenu', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Op een telefoon (iOS/Android) opent dit alle geïnstalleerde apps; in een desktopbrowser is dit vaak beperkt.',
                style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Share.share(_shareText(event), subject: event['name']?.toString());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _shareText(Map<String, dynamic> event) {
    final name = event['name']?.toString() ?? 'Evenement';
    final location = event['location_name']?.toString() ?? '';
    final city = event['city']?.toString() ?? '';
    return 'Kom je ook naar "$name"${location.isNotEmpty ? ' bij $location' : ''}'
        '${city.isNotEmpty ? ' in $city' : ''}? Bekijk het in BierKompas! 🍻';
  }

  Future<void> _shareViaUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon geen deelvenster openen.')),
      );
    }
  }

  Future<void> _shareWithFriend(Map<String, dynamic> event) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    List<Friend> friends;
    try {
      friends = await _friendsService.listFriends(user.id);
    } on FriendsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vrienden ophalen mislukt: $e')));
      return;
    }

    if (!mounted) return;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je hebt nog geen Bier-vrienden om mee te delen.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<Friend>(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.6,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    image: friend.avatarUrl != null
                        ? DecorationImage(image: NetworkImage(friend.avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: friend.avatarUrl == null
                      ? const Icon(Icons.person, color: secondaryTextColor, size: 18)
                      : null,
                ),
                title: Text(friend.name, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(sheetContext, friend),
              );
            },
          ),
        ),
      ),
    );
    if (picked == null) return;

    try {
      await _chatService.sendMessage(
        receiverId: picked.id,
        body: 'Zullen we hier samen naartoe gaan?',
        type: MessageType.eventInvite,
        metadata: {
          'id': event['id'],
          'name': event['name'],
          'start_date': event['start_date'],
          'location_name': event['location_name'],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evenement gedeeld met ${picked.name}!')),
      );
    } on ChatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delen mislukt: $e')),
      );
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
                      if (_isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Material(
                            color: const Color(0xFFD4A340),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AdminEventsPage()),
                                );
                                if (mounted) setState(() {});
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: Color(0xFF1E1712), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Beheer',
                                      style: TextStyle(
                                        color: Color(0xFF1E1712),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

                final status = event['status']?.toString() ?? 'approved';
                final isPending = status == 'pending';
                final isCancelled = status == 'cancelled';

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

                        // ACTIEKNOPPEN RECHTSBOVEN: verwijderen (nog niet
                        // goedgekeurd) of laten vervallen (al gepubliceerd).
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
                                icon: isPending
                                    ? const Icon(Icons.delete_outline, color: Colors.redAccent, size: 21)
                                    : const Icon(Icons.event_busy_outlined, color: Colors.redAccent, size: 21),
                                onPressed: isCancelled
                                    ? null
                                    : () {
                                        if (isPending) {
                                          _confirmDelete(context, eventId, name.toString());
                                        } else {
                                          _cancelEvent(int.parse(eventId), name.toString());
                                        }
                                      },
                              ),
                            ),
                          ),

                        // DEELKNOP LINKSBOVEN: alleen voor gepubliceerde evenementen.
                        if (status == 'approved' && eventId.isNotEmpty)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: backgroundColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(7),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.ios_share, color: beigeColor, size: 19),
                                onPressed: () => _openShareSheet(event),
                              ),
                            ),
                          ),

                        // "VERVALLEN"-STEMPEL
                        if (isCancelled)
                          Positioned(
                            top: 44,
                            right: -32,
                            child: Transform.rotate(
                              angle: 0.5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                                color: Colors.redAccent.withOpacity(0.9),
                                child: Text(
                                  'VERVALLEN',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
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

                              if (isPending) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: beigeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: beigeColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    'IN AFWACHTING VAN GOEDKEURING',
                                    style: GoogleFonts.inter(color: beigeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],

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