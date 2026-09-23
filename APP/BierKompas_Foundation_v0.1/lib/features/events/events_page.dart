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
  const EventsPage({
    super.key,
    this.avatarUrl,
    this.onProfileTap,
  });

  final String? avatarUrl;
  final VoidCallback? onProfileTap;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  final FriendsService _friendsService = FriendsService();

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color borderColor = Color(0xFF46372D);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

  bool _isAdmin = false;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _isAdmin = profile?['is_admin'] == true;
      });
    } catch (e) {
      debugPrint('Admin controleren mislukt: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchApprovedEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'approved')
          .order('start_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Fout bij goedgekeurde evenementen: $e');
      throw Exception('Kon evenementen niet laden.');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMyPendingEvents() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .order('start_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Fout bij mijn wachtende evenementen: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchAllEventData() async {
    final approved = await _fetchApprovedEvents();
    final pending = await _fetchMyPendingEvents();

    return {
      'approved': approved,
      'pending': pending,
    };
  }

  DateTime? _getEventDate(Map<String, dynamic> event) {
    final value = event['start_date'];

    if (value == null) return null;

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _hasEventOnDate(
    List<Map<String, dynamic>> events,
    DateTime date,
  ) {
    return events.any((event) {
      final eventDate = _getEventDate(event);

      if (eventDate == null) return false;

      return _sameDate(eventDate, date);
    });
  }

  List<Map<String, dynamic>> _eventsForDate(
    List<Map<String, dynamic>> events,
    DateTime date,
  ) {
    return events.where((event) {
      final eventDate = _getEventDate(event);

      if (eventDate == null) return false;

      return _sameDate(eventDate, date);
    }).toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      'januari',
      'februari',
      'maart',
      'april',
      'mei',
      'juni',
      'juli',
      'augustus',
      'september',
      'oktober',
      'november',
      'december',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maart',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Augustus',
      'September',
      'Oktober',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(Map<String, dynamic> event) {
    final eventDate = _getEventDate(event);

    if (eventDate == null) return '';

    return '${eventDate.hour.toString().padLeft(2, '0')}:'
        '${eventDate.minute.toString().padLeft(2, '0')}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );

      _selectedDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );

      _selectedDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();

    setState(() {
      _selectedMonth = DateTime(
        now.year,
        now.month,
      );

      _selectedDate = DateTime(
        now.year,
        now.month,
        now.day,
      );
    });
  }

  Future<void> _deleteEvent(
    String eventId,
    String eventName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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

    if (confirmed != true) return;

    try {
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evenement verwijderd.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verwijderen mislukt: $e',
          ),
        ),
      );
    }
  }

  Future<void> _cancelEvent(
    int eventId,
    String eventName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Evenement laten vervallen?',
            style: GoogleFonts.playfairDisplay(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '"$eventName" wordt als vervallen gemarkeerd.',
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
                'Laten vervallen',
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

    if (confirmed != true) return;

    try {
      await _supabase.rpc(
        'cancel_event',
        params: {
          'p_event_id': eventId,
        },
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Laten vervallen mislukt: $e',
          ),
        ),
      );
    }
  }

  String _shareText(Map<String, dynamic> event) {
    final name = event['name']?.toString() ?? 'Evenement';
    final location =
        event['location_name']?.toString() ?? '';
    final city = event['city']?.toString() ?? '';

    return 'Kom je ook naar "$name"'
        '${location.isNotEmpty ? ' bij $location' : ''}'
        '${city.isNotEmpty ? ' in $city' : ''}? '
        'Bekijk het in BierKompas! 🍻';
  }

  Future<void> _shareViaUrl(String url) async {
    final uri = Uri.parse(url);

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kon geen deelvenster openen.',
          ),
        ),
      );
    }
  }

  void _openShareSheet(
    Map<String, dynamic> event,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondaryTextColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Evenement delen',
                  style: GoogleFonts.playfairDisplay(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: beigeColor,
                  ),
                  title: Text(
                    'Deel met een Biervriend',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareWithFriend(event);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.ios_share,
                    color: beigeColor,
                  ),
                  title: Text(
                    'Meer opties',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    Share.share(
                      _shareText(event),
                      subject: event['name']?.toString(),
                    );
                  },
                ),
                if (kIsWeb) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.chat,
                      color: Color(0xFF25D366),
                    ),
                    title: Text(
                      'WhatsApp',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      _shareViaUrl(
                        'https://wa.me/?text='
                        '${Uri.encodeComponent(_shareText(event))}',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.facebook,
                      color: Color(0xFF1877F2),
                    ),
                    title: Text(
                      'Facebook',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      _shareViaUrl(
                        'https://www.facebook.com/sharer/sharer.php?quote='
                        '${Uri.encodeComponent(_shareText(event))}',
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(
                    Icons.copy_all_outlined,
                    color: beigeColor,
                  ),
                  title: Text(
                    'Tekst kopiëren',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await Clipboard.setData(
                      ClipboardData(
                        text: _shareText(event),
                      ),
                    );

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tekst gekopieerd.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareWithFriend(
    Map<String, dynamic> event,
  ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    List<Friend> friends;

    try {
      friends = await _friendsService.listFriends(user.id);
    } on FriendsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vrienden ophalen mislukt: $e',
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Je hebt nog geen Bier-vrienden.',
          ),
        ),
      );

      return;
    }

    final picked = await showModalBottomSheet<Friend>(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.of(sheetContext).size.height * 0.6,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: backgroundColor,
                    backgroundImage:
                        friend.avatarUrl != null
                            ? NetworkImage(
                                friend.avatarUrl!,
                              )
                            : null,
                    child: friend.avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            color: secondaryTextColor,
                          )
                        : null,
                  ),
                  title: Text(
                    friend.name,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      friend,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
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
        SnackBar(
          content: Text(
            'Gedeeld met ${picked.name}!',
          ),
        ),
      );
    } on ChatException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delen mislukt: $e',
          ),
        ),
      );
    }
  }

  Widget _buildCalendar(
    List<Map<String, dynamic>> events,
  ) {
    final firstDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;

    final List<Widget> days = [];

    for (int i = 1; i < firstDay.weekday; i++) {
      days.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        day,
      );

      final isSelected =
          _sameDate(date, _selectedDate);

      final isToday =
          _sameDate(date, DateTime.now());

      final hasEvent =
          _hasEventOnDate(events, date);

      days.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? beigeColor
                  : isToday
                      ? beigeColor.withOpacity(0.12)
                      : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(
                      color:
                          beigeColor.withOpacity(0.5),
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? backgroundColor
                        : textColor,
                    fontSize: 14,
                    fontWeight:
                        isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: hasEvent ? 6 : 4,
                  height: hasEvent ? 6 : 4,
                  decoration: BoxDecoration(
                    color: hasEvent
                        ? isSelected
                            ? backgroundColor
                            : beigeColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        16,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _calendarButton(
                icon: Icons.chevron_left,
                onTap: _previousMonth,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatMonth(_selectedMonth),
                      style:
                          GoogleFonts.playfairDisplay(
                        color: textColor,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selecteer een dag',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _calendarButton(
                icon: Icons.chevron_right,
                onTap: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _goToToday,
            child: Text(
              'Vandaag',
              style: GoogleFonts.inter(
                color: beigeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _weekday('MA'),
              _weekday('DI'),
              _weekday('WO'),
              _weekday('DO'),
              _weekday('VR'),
              _weekday('ZA'),
              _weekday('ZO'),
            ],
          ),
          const SizedBox(height: 7),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: days,
          ),
        ],
      ),
    );
  }

  Widget _calendarButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: beigeColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _weekday(String text) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: secondaryTextColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingEvents(
    List<Map<String, dynamic>> pendingEvents,
  ) {
    if (pendingEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            Container(
              width: 4,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                borderRadius:
                    BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mijn evenementen',
                style:
                    GoogleFonts.playfairDisplay(
                  color: textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.orangeAccent
                    .withOpacity(0.12),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                '${pendingEvents.length} wachtend',
                style: GoogleFonts.inter(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Deze evenementen wachten nog op goedkeuring.',
          style: GoogleFonts.inter(
            color: secondaryTextColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        ...pendingEvents.map(
          (event) => _buildPendingCard(event),
        ),
      ],
    );
  }

  Widget _buildPendingCard(
    Map<String, dynamic> event,
  ) {
    final eventId =
        event['id']?.toString() ?? '';

    final name =
        event['name']?.toString() ??
            'Naamloos';

    final eventType =
        event['event_type']?.toString() ??
            'Festival';

    final city =
        event['city']?.toString() ?? '';

    final location =
        event['location_name']?.toString() ?? '';

    final eventDate =
        _getEventDate(event);

    final imageUrl =
        event['image_asset']?.toString().trim();

    final hasImage =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl != 'null';

    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orangeAccent
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return Container(
                          color: backgroundColor,
                          child: const Icon(
                            Icons.local_bar,
                            color: beigeColor,
                            size: 40,
                          ),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black
                            .withOpacity(0.35),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _pendingBadge(),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (!hasImage)
                  Row(
                    children: [
                      _pendingBadge(),
                      const Spacer(),
                      _eventTypeBadge(
                        eventType,
                      ),
                    ],
                  ),
                if (!hasImage)
                  const SizedBox(height: 12),
                Text(
                  name,
                  style:
                      GoogleFonts.playfairDisplay(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (eventDate != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: beigeColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDate(eventDate)} om '
                        '${_formatTime(event)}',
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                if (location.isNotEmpty ||
                    city.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: beigeColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$location'
                          '${city.isNotEmpty ? ' · $city' : ''}',
                          style: GoogleFonts.inter(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent
                        .withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top,
                        color: Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'In afwachting van goedkeuring',
                          style: GoogleFonts.inter(
                            color:
                                Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: eventId.isEmpty
                        ? null
                        : () {
                            _deleteEvent(
                              eventId,
                              name,
                            );
                          },
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 17,
                    ),
                    label: Text(
                      'Verwijderen',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Colors.redAccent,
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

  Widget _pendingBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.orangeAccent
            .withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orangeAccent
              .withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top,
            color: Colors.orangeAccent,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            'IN AFWACHTING',
            style: GoogleFonts.inter(
              color: Colors.orangeAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayEvents(
    List<Map<String, dynamic>> events,
  ) {
    final selectedEvents =
        _eventsForDate(
      events,
      _selectedDate,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            Container(
              width: 4,
              height: 25,
              decoration: BoxDecoration(
                color: beigeColor,
                borderRadius:
                    BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                style:
                    GoogleFonts.playfairDisplay(
                  color: textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (selectedEvents.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: beigeColor
                      .withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '${selectedEvents.length} event'
                  '${selectedEvents.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    color: beigeColor,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (selectedEvents.isEmpty)
          _emptyDayCard()
        else
          ...selectedEvents.map(
            (event) =>
                _buildEventCard(event),
          ),
      ],
    );
  }

  Widget _emptyDayCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Icon(
              Icons.event_available,
              color: secondaryTextColor,
              size: 27,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Geen evenementen',
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Er staan geen goedgekeurde evenementen gepland op deze dag.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: secondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    Map<String, dynamic> event,
  ) {
    final eventId =
        event['id']?.toString() ?? '';

    final eventUserId =
        event['user_id']?.toString() ?? '';

    final currentUser =
        _supabase.auth.currentUser;

    final isOwner =
        currentUser != null &&
        eventUserId == currentUser.id;

    final name =
        event['name']?.toString() ??
            'Naamloos';

    final eventType =
        event['event_type']?.toString() ??
            'Festival';

    final city =
        event['city']?.toString() ?? '';

    final locationName =
        event['location_name']?.toString() ??
            '';

    final description =
        event['description']?.toString() ??
            '';

    final imageUrl =
        event['image_asset']?.toString().trim();

    final hasImage =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl != 'null';

    final List<String> tickets = [];

    if (event['ticket_regular'] == true) {
      tickets.add('Regulier');
    }

    if (event['ticket_beer'] == true) {
      tickets.add('Bier-ticket');
    }

    if (event['ticket_vip'] == true) {
      tickets.add('VIP');
    }

    return Container(
      margin:
          const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(18),
          onTap: () {
            _showEventDetails(event);
          },
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 175,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return Container(
                              color:
                                  backgroundColor,
                              child: const Icon(
                                Icons.local_bar,
                                color:
                                    beigeColor,
                                size: 45,
                              ),
                            );
                          },
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration:
                                BoxDecoration(
                              gradient:
                                  LinearGradient(
                                begin: Alignment
                                    .topCenter,
                                end: Alignment
                                    .bottomCenter,
                                colors: [
                                  Colors
                                      .transparent,
                                  Colors.black
                                      .withOpacity(
                                    0.7,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child:
                              _eventTypeBadge(
                            eventType,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child:
                              _shareButton(
                            event,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    0,
                  ),
                  child: Row(
                    children: [
                      _eventIcon(),
                      const Spacer(),
                      _eventTypeBadge(
                        eventType,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (!hasImage)
                      Align(
                        alignment:
                            Alignment.centerRight,
                        child:
                            _shareButton(event),
                      ),
                    if (!hasImage)
                      const SizedBox(height: 6),
                    Text(
                      name,
                      style:
                          GoogleFonts.playfairDisplay(
                        color: textColor,
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    if (locationName
                            .isNotEmpty ||
                        city.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_on_outlined,
                            color: beigeColor,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '$locationName'
                              '${city.isNotEmpty ? ' · $city' : ''}',
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  GoogleFonts.inter(
                                color:
                                    beigeColor,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .schedule_outlined,
                          color:
                              secondaryTextColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(event),
                          style:
                              GoogleFonts.inter(
                            color:
                                secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (description
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        description,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            GoogleFonts.inter(
                          color: textColor
                              .withOpacity(0.82),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (tickets.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            tickets.map(
                          (ticket) {
                            return Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    backgroundColor,
                                borderRadius:
                                    BorderRadius
                                        .circular(7),
                                border: Border.all(
                                  color:
                                      borderColor,
                                ),
                              ),
                              child: Text(
                                ticket,
                                style:
                                    GoogleFonts
                                        .inter(
                                  color:
                                      textColor,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ],
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Text(
                          'Bekijk details',
                          style:
                              GoogleFonts.inter(
                            color: beigeColor,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          color: beigeColor,
                          size: 14,
                        ),
                        const Spacer(),
                        if (isOwner &&
                            eventId.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              final id =
                                  int.tryParse(
                                eventId,
                              );

                              if (id != null) {
                                _cancelEvent(
                                  id,
                                  name,
                                );
                              }
                            },
                            child:
                                const Icon(
                              Icons
                                  .event_busy_outlined,
                              color:
                                  Colors.redAccent,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.local_bar,
        color: beigeColor,
        size: 25,
      ),
    );
  }

  Widget _eventTypeBadge(String type) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor
            .withOpacity(0.88),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              beigeColor.withOpacity(0.35),
        ),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.inter(
          color: beigeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _shareButton(
    Map<String, dynamic> event,
  ) {
    return Material(
      color:
          backgroundColor.withOpacity(0.9),
      borderRadius:
          BorderRadius.circular(10),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(10),
        onTap: () {
          _openShareSheet(event);
        },
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            Icons.ios_share,
            color: beigeColor,
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showEventDetails(
    Map<String, dynamic> event,
  ) {
    final eventDate =
        _getEventDate(event);

    final name =
        event['name']?.toString() ??
            'Naamloos';

    final eventType =
        event['event_type']?.toString() ??
            '';

    final location =
        event['location_name']?.toString() ??
            '';

    final city =
        event['city']?.toString() ?? '';

    final description =
        event['description']?.toString() ??
            '';

    final openingHours =
        event['opening_hours']?.toString() ??
            '';

    final street =
        event['street']?.toString() ?? '';

    final houseNumber =
        event['house_number']?.toString() ??
            '';

    final postalCode =
        event['postal_code']?.toString() ??
            '';

    final imageUrl =
        event['image_asset']?.toString().trim();

    final hasImage =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl != 'null';

    final tickets = <String>[];

    if (event['ticket_regular'] == true) {
      tickets.add('Regulier ticket');
    }

    if (event['ticket_beer'] == true) {
      tickets.add('Bier-ticket');
    }

    if (event['ticket_vip'] == true) {
      tickets.add('VIP-ticket');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (
              context,
              scrollController,
            ) {
              return ListView(
                controller:
                    scrollController,
                padding: EdgeInsets.zero,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius
                              .vertical(
                        top: Radius.circular(
                          26,
                        ),
                      ),
                      child: SizedBox(
                        height: 220,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration:
                                    BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                    begin:
                                        Alignment
                                            .topCenter,
                                    end:
                                        Alignment
                                            .bottomCenter,
                                    colors: [
                                      Colors
                                          .transparent,
                                      Colors.black
                                          .withOpacity(
                                        0.75,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              bottom: 18,
                              right: 20,
                              child: Text(
                                name,
                                style: GoogleFonts
                                    .playfairDisplay(
                                  color:
                                      Colors.white,
                                  fontSize: 28,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        if (!hasImage) ...[
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              decoration:
                                  BoxDecoration(
                                color:
                                    secondaryTextColor,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 22,
                          ),
                          Text(
                            name,
                            style: GoogleFonts
                                .playfairDisplay(
                              color: textColor,
                              fontSize: 28,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ],
                        if (eventType
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _eventTypeBadge(
                            eventType,
                          ),
                        ],
                        const SizedBox(
                          height: 22,
                        ),
                        if (eventDate != null)
                          _detailRow(
                            Icons
                                .calendar_month_outlined,
                            'Datum',
                            _formatDate(
                              eventDate,
                            ),
                          ),
                        if (eventDate != null)
                          _detailRow(
                            Icons
                                .schedule_outlined,
                            'Starttijd',
                            _formatTime(event),
                          ),
                        if (openingHours
                            .isNotEmpty)
                          _detailRow(
                            Icons
                                .access_time_outlined,
                            'Openingstijden',
                            openingHours,
                          ),
                        if (location
                            .isNotEmpty)
                          _detailRow(
                            Icons
                                .location_on_outlined,
                            'Locatie',
                            location,
                          ),
                        if (city.isNotEmpty)
                          _detailRow(
                            Icons
                                .location_city_outlined,
                            'Plaats',
                            city,
                          ),
                        if (street.isNotEmpty ||
                            houseNumber
                                .isNotEmpty ||
                            postalCode
                                .isNotEmpty)
                          _detailRow(
                            Icons.home_outlined,
                            'Adres',
                            '$street $houseNumber\n'
                                '$postalCode $city',
                          ),
                        if (description
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Over dit evenement',
                            style: GoogleFonts
                                .playfairDisplay(
                              color: beigeColor,
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            description,
                            style:
                                GoogleFonts.inter(
                              color: textColor,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ],
                        if (tickets
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 22,
                          ),
                          Text(
                            'Tickets',
                            style: GoogleFonts
                                .playfairDisplay(
                              color: beigeColor,
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                tickets.map(
                              (ticket) {
                                return Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        backgroundColor,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      9,
                                    ),
                                    border:
                                        Border.all(
                                      color:
                                          borderColor,
                                    ),
                                  ),
                                  child: Text(
                                    ticket,
                                    style: GoogleFonts
                                        .inter(
                                      color:
                                          textColor,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ],
                        const SizedBox(
                          height: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: beigeColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color:
                        secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize:
            const Size.fromHeight(155),
        child: Container(
          decoration:
              const BoxDecoration(
            color: cardColor,
            borderRadius:
                BorderRadius.only(
              bottomLeft:
                  Radius.circular(26),
              bottomRight:
                  Radius.circular(26),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                10,
                18,
                18,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration:
                            BoxDecoration(
                          color:
                              backgroundColor,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                        ),
                        child: const Icon(
                          Icons.sports_bar,
                          color: beigeColor,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Evenementen',
                          style: GoogleFonts
                              .playfairDisplay(
                            color: textColor,
                            fontSize: 27,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isAdmin)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            right: 8,
                          ),
                          child: Material(
                            color:
                                const Color(
                              0xFFD4A340,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              onTap: () async {
                                await Navigator
                                    .push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const AdminEventsPage(),
                                  ),
                                );

                                if (mounted) {
                                  setState(
                                      () {});
                                }
                              },
                              child:
                                  const Padding(
                                padding:
                                    EdgeInsets
                                        .symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                child: Icon(
                                  Icons
                                      .admin_panel_settings,
                                  color:
                                      backgroundColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.onProfileTap !=
                          null)
                        ProfileAvatarButton(
                          onTap:
                              widget.onProfileTap!,
                          avatarUrl:
                              widget.avatarUrl,
                        ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'De Moderne Events',
                    style: GoogleFonts
                        .playfairDisplay(
                      color: beigeColor,
                      fontSize: 24,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ontdek bierproeverijen, festivals en meer.',
                    style:
                        GoogleFonts.inter(
                      color:
                          secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<
          Map<String, dynamic>>(
        future: _fetchAllEventData(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color: beigeColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color:
                          Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(
                        height: 12),
                    Text(
                      'Evenementen konden niet worden geladen.',
                      textAlign:
                          TextAlign.center,
                      style:
                          GoogleFonts.inter(
                        color: textColor,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                        height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                      style:
                          GoogleFonts.inter(
                        color:
                            secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data =
              snapshot.data ?? {};

          final approvedEvents =
              List<Map<String, dynamic>>.from(
            data['approved'] ?? [],
          );

          final pendingEvents =
              List<Map<String, dynamic>>.from(
            data['pending'] ?? [],
          );

          return RefreshIndicator(
            color: beigeColor,
            backgroundColor: cardColor,
            onRefresh: () async {
              setState(() {});
              await Future.delayed(
                const Duration(
                  milliseconds: 300,
                ),
              );
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                100,
              ),
              children: [
                _buildCalendar(
                  approvedEvents,
                ),
                _buildSelectedDayEvents(
                  approvedEvents,
                ),
                _buildPendingEvents(
                  pendingEvents,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton(
        backgroundColor: beigeColor,
        foregroundColor: backgroundColor,
        elevation: 4,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const EventCreatePage(),
            ),
          );

          if (mounted) {
            setState(() {});
          }
        },
        child: const Icon(
          Icons.add,
          size: 27,
        ),
      ),
    );
  }
}