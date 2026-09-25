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
    final response = await _supabase
        .from('events')
        .select()
        .eq('status', 'approved')
        .order('start_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchMyPendingEvents() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return [];

    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .order('start_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Pending events ophalen mislukt: $e');
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
      return eventDate != null && _sameDate(eventDate, date);
    });
  }

  List<Map<String, dynamic>> _eventsForDate(
    List<Map<String, dynamic>> events,
    DateTime date,
  ) {
    return events.where((event) {
      final eventDate = _getEventDate(event);
      return eventDate != null && _sameDate(eventDate, date);
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
      _selectedMonth = DateTime(now.year, now.month);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cardColor,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: textColor,
          ),
        ),
      ),
    );
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
          title: Text(
            'Evenement verwijderen?',
            style: GoogleFonts.playfairDisplay(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Weet je zeker dat je "$eventName" wilt verwijderen?',
            style: GoogleFonts.inter(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Annuleren',
                style: GoogleFonts.inter(
                  color: secondaryTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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

      if (mounted) {
        setState(() {});
      }

      _showMessage('Evenement verwijderd.');
    } catch (e) {
      _showMessage('Verwijderen mislukt.');
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
          title: Text(
            'Evenement laten vervallen?',
            style: GoogleFonts.playfairDisplay(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '"$eventName" wordt als vervallen gemarkeerd.',
            style: GoogleFonts.inter(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Annuleren',
                style: GoogleFonts.inter(
                  color: secondaryTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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
      _showMessage('Laten vervallen mislukt.');
    }
  }

  String _shareText(Map<String, dynamic> event) {
    final name = event['name']?.toString() ?? 'Evenement';
    final location = event['location_name']?.toString() ?? '';
    final city = event['city']?.toString() ?? '';

    return 'Kom je ook naar "$name"'
        '${location.isNotEmpty ? ' bij $location' : ''}'
        '${city.isNotEmpty ? ' in $city' : ''}? '
        'Bekijk het in BierKompas! 🍻';
  }

  Future<void> _shareViaUrl(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showMessage('Kon geen deelvenster openen.');
    }
  }

  void _openShareSheet(Map<String, dynamic> event) {
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
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(20),
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
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: beigeColor,
                  ),
                  title: Text(
                    'Deel met een Biervriend',
                    style: GoogleFonts.inter(
                      color: textColor,
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
                if (kIsWeb)
                  ListTile(
                    leading: const Icon(
                      Icons.chat,
                      color: Color(0xFF25D366),
                    ),
                    title: Text(
                      'WhatsApp',
                      style: GoogleFonts.inter(
                        color: textColor,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _shareViaUrl(
                        'https://wa.me/?text=${Uri.encodeComponent(_shareText(event))}',
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.copy_all_outlined,
                    color: beigeColor,
                  ),
                  title: Text(
                    'Tekst kopiëren',
                    style: GoogleFonts.inter(
                      color: textColor,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await Clipboard.setData(
                      ClipboardData(
                        text: _shareText(event),
                      ),
                    );

                    _showMessage('Tekst gekopieerd.');
                  },
                ),
                const SizedBox(height: 8),
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
      _showMessage('Vrienden ophalen mislukt: $e');
      return;
    }

    if (friends.isEmpty) {
      _showMessage('Je hebt nog geen Bier-vrienden.');
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
                  leading: CircleAvatar(
                    backgroundColor: backgroundColor,
                    backgroundImage: friend.avatarUrl != null
                        ? NetworkImage(friend.avatarUrl!)
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

      _showMessage('Gedeeld met ${picked.name}!');
    } on ChatException catch (e) {
      _showMessage('Delen mislukt: $e');
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

    final days = <Widget>[];

    for (int i = 1; i < firstDay.weekday; i++) {
      days.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        day,
      );

      final isSelected = _sameDate(date, _selectedDate);
      final isToday = _sameDate(date, DateTime.now());
      final hasEvent = _hasEventOnDate(events, date);

      days.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? beigeColor
                  : isToday
                      ? beigeColor.withOpacity(0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  width: 5,
                  height: 5,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
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
                      style: GoogleFonts.playfairDisplay(
                        color: textColor,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
          TextButton(
            onPressed: _goToToday,
            child: Text(
              'Vandaag',
              style: GoogleFonts.inter(
                color: beigeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
            physics: const NeverScrollableScrollPhysics(),
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
        Text(
          'Mijn evenementen',
          style: GoogleFonts.playfairDisplay(
            color: textColor,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
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
        ...pendingEvents.map(_buildPendingCard),
      ],
    );
  }

  Widget _buildPendingCard(
    Map<String, dynamic> event,
  ) {
    final eventId = event['id']?.toString() ?? '';
    final name = event['name']?.toString() ?? 'Naamloos';
    final date = _getEventDate(event);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_top,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_formatDate(date)} om ${_formatTime(event)}',
              style: GoogleFonts.inter(
                color: secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'In afwachting van goedkeuring',
            style: GoogleFonts.inter(
              color: Colors.orangeAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: eventId.isEmpty
                  ? null
                  : () => _deleteEvent(eventId, name),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Verwijderen'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
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
        _eventsForDate(events, _selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Text(
          _formatDate(_selectedDate),
          style: GoogleFonts.playfairDisplay(
            color: textColor,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        if (selectedEvents.isEmpty)
          _emptyDayCard()
        else
          ...selectedEvents.map(_buildEventCard),
      ],
    );
  }

  Widget _emptyDayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available,
            color: secondaryTextColor,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Geen evenementen',
            style: GoogleFonts.inter(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    Map<String, dynamic> event,
  ) {
    final eventId = event['id']?.toString() ?? '';
    final eventUserId = event['user_id']?.toString() ?? '';
    final currentUser = _supabase.auth.currentUser;

    final isOwner =
        currentUser != null &&
        eventUserId == currentUser.id;

    final name = event['name']?.toString() ?? 'Naamloos';

    final eventType =
        event['event_type']?.toString() ?? 'Festival';

    final city = event['city']?.toString() ?? '';

    final location =
        event['location_name']?.toString() ?? '';

    final imageUrl =
        event['image_asset']?.toString().trim();

    final hasImage =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl != 'null';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showEventDetails(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
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
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: backgroundColor,
                            child: const Icon(
                              Icons.local_bar,
                              color: beigeColor,
                              size: 45,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _shareButton(event),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.playfairDisplay(
                            color: textColor,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _eventTypeBadge(eventType),
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
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$location'
                            '${city.isNotEmpty ? ' · $city' : ''}',
                            style: GoogleFonts.inter(
                              color: beigeColor,
                              fontSize: 12,
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
                        Icons.schedule_outlined,
                        color: secondaryTextColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(event),
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Bekijk details',
                        style: GoogleFonts.inter(
                          color: beigeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (isOwner &&
                          eventId.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            final id =
                                int.tryParse(eventId);

                            if (id != null) {
                              _cancelEvent(
                                id,
                                name,
                              );
                            }
                          },
                          child: const Icon(
                            Icons.event_busy_outlined,
                            color: Colors.redAccent,
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
    );
  }

  Widget _eventTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: beigeColor.withOpacity(0.35),
        ),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.inter(
          color: beigeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _shareButton(
    Map<String, dynamic> event,
  ) {
    return Material(
      color: backgroundColor.withOpacity(0.9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openShareSheet(event),
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
    final eventId = int.tryParse(
      event['id']?.toString() ?? '',
    );

    final currentUser = _supabase.auth.currentUser;

    final isOwner =
        currentUser != null &&
        event['user_id']?.toString() == currentUser.id;

    final name =
        event['name']?.toString() ?? 'Naamloos';

    final eventType =
        event['event_type']?.toString() ?? '';

    final location =
        event['location_name']?.toString() ?? '';

    final city =
        event['city']?.toString() ?? '';

    final description =
        event['description']?.toString() ?? '';

    final openingHours =
        event['opening_hours']?.toString() ?? '';

    final street =
        event['street']?.toString() ?? '';

    final houseNumber =
        event['house_number']?.toString() ?? '';

    final postalCode =
        event['postal_code']?.toString() ?? '';

    final imageUrl =
        event['image_asset']?.toString().trim();

    final eventDate = _getEventDate(event);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.90,
          minChildSize: 0.55,
          maxChildSize: 0.97,
          builder: (
            context,
            scrollController,
          ) {
            return Container(
              decoration: const BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    children: [
                      if (imageUrl != null &&
                          imageUrl.isNotEmpty &&
                          imageUrl != 'null')
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                          child: Image.network(
                            imageUrl,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return _eventDetailPlaceholder();
                            },
                          ),
                        )
                      else
                        _eventDetailPlaceholder(),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.78),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Material(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius:
                              BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(sheetContext);
                            },
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Material(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius:
                              BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(12),
                            onTap: () {
                              _openShareSheet(event);
                            },
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.ios_share,
                                color: beigeColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (eventType.isNotEmpty)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: beigeColor,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  eventType.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: backgroundColor,
                                    fontSize: 9,
                                    fontWeight:
                                        FontWeight.bold,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 9),
                            Text(
                              name,
                              style:
                                  GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      20,
                      18,
                      35,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        if (eventDate != null)
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard(
                                  Icons.calendar_month_outlined,
                                  'DATUM',
                                  _formatDate(eventDate),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _infoCard(
                                  Icons.schedule_outlined,
                                  'START',
                                  _formatTime(event),
                                ),
                              ),
                            ],
                          ),
                        if (location.isNotEmpty ||
                            city.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _wideInfoCard(
                            Icons.location_on_outlined,
                            'LOCATIE',
                            [
                              if (location.isNotEmpty)
                                location,
                              if (city.isNotEmpty)
                                city,
                            ].join(' · '),
                          ),
                        ],
                        if (openingHours.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _wideInfoCard(
                            Icons.access_time_outlined,
                            'OPENINGSTIJDEN',
                            openingHours,
                          ),
                        ],
                        if (street.isNotEmpty ||
                            houseNumber.isNotEmpty ||
                            postalCode.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _wideInfoCard(
                            Icons.home_outlined,
                            'ADRES',
                            '$street $houseNumber\n'
                                '$postalCode $city',
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Text(
                            'Over dit evenement',
                            style:
                                GoogleFonts.playfairDisplay(
                              color: textColor,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius:
                                  BorderRadius.circular(16),
                              border: Border.all(
                                color: borderColor,
                              ),
                            ),
                            child: Text(
                              description,
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                        if (eventId != null && !isOwner) ...[
                          const SizedBox(height: 28),
                          Text(
                            'Aanmelden',
                            style:
                                GoogleFonts.playfairDisplay(
                              color: textColor,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _registrationButton(eventId),
                        ],
                        if (eventId != null && isOwner) ...[
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                color: borderColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            backgroundColor,
                                        borderRadius:
                                            BorderRadius
                                                .circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.people_outline,
                                        color: beigeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          'Deelnemers',
                                          style: GoogleFonts
                                              .playfairDisplay(
                                            color: textColor,
                                            fontSize: 21,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Beheer de aanmeldingen',
                                          style:
                                              GoogleFonts.inter(
                                            color:
                                                secondaryTextColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildOwnerRegistrations(
                                  eventId,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _eventDetailPlaceholder() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_bar,
          color: beigeColor,
          size: 65,
        ),
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: beigeColor,
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: secondaryTextColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideInfoCard(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: beigeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _registrationButton(int eventId) {
    return _RegistrationButton(
      supabase: _supabase,
      eventId: eventId,
    );
  }

  Widget _buildOwnerRegistrations(int eventId) {
    return _OwnerRegistrations(
      supabase: _supabase,
      eventId: eventId,
      onMessage: _showMessage,
    );
  }

  Widget _participantAvatar(
    String? avatarUrl,
  ) {
    final hasAvatar =
        avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl != 'null';

    return CircleAvatar(
      radius: 22,
      backgroundColor: cardColor,
      backgroundImage:
          hasAvatar
              ? NetworkImage(avatarUrl!)
              : null,
      child: !hasAvatar
          ? const Icon(
              Icons.person,
              color: secondaryTextColor,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(155),
        child: Container(
          decoration: const BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
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
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius:
                              BorderRadius.circular(13),
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
                          style:
                              GoogleFonts.playfairDisplay(
                            color: textColor,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isAdmin)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            right: 8,
                          ),
                          child: Material(
                            color:
                                const Color(0xFFD4A340),
                            borderRadius:
                                BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(12),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminEventsPage(),
                                  ),
                                );

                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              child: const Padding(
                                padding:
                                    EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                child: Icon(
                                  Icons
                                      .admin_panel_settings,
                                  color: backgroundColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.onProfileTap != null)
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
                    style:
                        GoogleFonts.playfairDisplay(
                      color: beigeColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ontdek bierproeverijen, festivals en meer.',
                    style: GoogleFonts.inter(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAllEventData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: beigeColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Evenementen konden niet worden geladen.',
                style: GoogleFonts.inter(
                  color: textColor,
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};

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
                const Duration(milliseconds: 300),
              );
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                100,
              ),
              children: [
                _buildCalendar(approvedEvents),
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
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const EventCreatePage(),
            ),
          );

          if (mounted) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RegistrationButton extends StatefulWidget {
  const _RegistrationButton({
    required this.supabase,
    required this.eventId,
  });

  final SupabaseClient supabase;
  final int eventId;

  @override
  State<_RegistrationButton> createState() =>
      _RegistrationButtonState();
}

class _RegistrationButtonState
    extends State<_RegistrationButton> {
  String? _status;
  String? _message;

  bool _loading = true;
  bool _actionLoading = false;

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color borderColor = Color(0xFF46372D);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = widget.supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      return;
    }

    try {
      final result = await widget.supabase
          .from('event_registrations')
          .select('status')
          .eq('event_id', widget.eventId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _status = result?['status']?.toString();
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Aanmeldstatus ophalen mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _message =
            'Aanmeldstatus kon niet worden opgehaald.';
      });
    }
  }

  Future<void> _register() async {
    final user = widget.supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _message =
            'Je moet ingelogd zijn om je aan te melden.';
      });
      return;
    }

    setState(() {
      _actionLoading = true;
      _message = null;
    });

    try {
      final existing = await widget.supabase
          .from('event_registrations')
          .select('id,status')
          .eq('event_id', widget.eventId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        final existingStatus =
            existing['status']?.toString();

        if (existingStatus == 'rejected') {
          await widget.supabase
              .from('event_registrations')
              .update({
                'status': 'pending',
              })
              .eq(
                'id',
                existing['id'],
              );

          if (!mounted) return;

          setState(() {
            _status = 'pending';
            _actionLoading = false;
            _message =
                'Aanmelding opnieuw verstuurd. Wacht op goedkeuring.';
          });

          return;
        }

        if (!mounted) return;

        setState(() {
          _status = existingStatus;
          _actionLoading = false;
          _message = existingStatus == 'pending'
              ? 'Je aanmelding wacht al op goedkeuring.'
              : 'Je bent al goedgekeurd voor dit evenement.';
        });

        return;
      }

      await widget.supabase
          .from('event_registrations')
          .insert({
        'event_id': widget.eventId,
        'user_id': user.id,
        'status': 'pending',
      });

      if (!mounted) return;

      setState(() {
        _status = 'pending';
        _actionLoading = false;
        _message =
            'Aanmelding verstuurd. Wacht op goedkeuring.';
      });
    } catch (e) {
      debugPrint(
        'Aanmelden mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _actionLoading = false;
        _message = 'Aanmelden mislukt.';
      });
    }
  }

  Future<void> _cancel() async {
    final user = widget.supabase.auth.currentUser;

    if (user == null) return;

    setState(() {
      _actionLoading = true;
      _message = null;
    });

    try {
      await widget.supabase
          .from('event_registrations')
          .delete()
          .eq(
            'event_id',
            widget.eventId,
          )
          .eq(
            'user_id',
            user.id,
          );

      if (!mounted) return;

      setState(() {
        _status = null;
        _actionLoading = false;
        _message = 'Je aanmelding is verwijderd.';
      });
    } catch (e) {
      debugPrint(
        'Afmelden mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _actionLoading = false;
        _message = 'Afmelden mislukt.';
      });
    }
  }

  Widget _messageWidget() {
    if (_message == null || _message!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isError =
        _message!.toLowerCase().contains('mislukt');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isError
            ? Colors.redAccent.withOpacity(0.08)
            : beigeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isError
              ? Colors.redAccent.withOpacity(0.25)
              : beigeColor.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : Icons.info_outline,
            color:
                isError ? Colors.redAccent : beigeColor,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _message!,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingButton() {
    return Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: beigeColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _approvedWidget() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.green.withOpacity(0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Je bent goedgekeurd',
                      style: GoogleFonts.inter(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Je kunt deelnemen aan dit evenement.',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _messageWidget(),
      ],
    );
  }

  Widget _pendingWidget() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.orangeAccent
                  .withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent
                      .withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wachten op goedkeuring',
                      style: GoogleFonts.inter(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'De organisator moet je aanmelding nog goedkeuren.',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _actionLoading
              ? null
              : _cancel,
          child: Text(
            'Aanmelding intrekken',
            style: GoogleFonts.inter(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _messageWidget(),
      ],
    );
  }

  Widget _rejectedWidget() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent
                      .withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Je aanmelding is afgewezen.',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                _actionLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: beigeColor,
              foregroundColor: backgroundColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Opnieuw aanmelden',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        _messageWidget(),
      ],
    );
  }

  Widget _defaultButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed:
                _actionLoading ? null : _register,
            icon: const Icon(Icons.how_to_reg),
            label: Text(
              'Aanmelden voor evenement',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: beigeColor,
              foregroundColor: backgroundColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        _messageWidget(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _loadingButton();
    }

    if (_actionLoading) {
      if (_status == 'pending') {
        return Column(
          children: [
            _pendingWidget(),
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              color: beigeColor,
              backgroundColor: cardColor,
            ),
          ],
        );
      }

      return _loadingButton();
    }

    if (_status == 'approved') {
      return _approvedWidget();
    }

    if (_status == 'pending') {
      return _pendingWidget();
    }

    if (_status == 'rejected') {
      return _rejectedWidget();
    }

    return _defaultButton();
  }
}

class _OwnerRegistrations extends StatefulWidget {
  const _OwnerRegistrations({
    required this.supabase,
    required this.eventId,
    required this.onMessage,
  });

  final SupabaseClient supabase;
  final int eventId;
  final void Function(String message) onMessage;

  @override
  State<_OwnerRegistrations> createState() =>
      _OwnerRegistrationsState();
}

class _OwnerRegistrationsState
    extends State<_OwnerRegistrations> {
  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color borderColor = Color(0xFF46372D);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];

  bool _loading = true;
  int? _updatingId;

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    try {
      final pendingResponse =
          await widget.supabase.rpc(
        'get_event_pending_registrations',
        params: {
          'p_event_id': widget.eventId,
        },
      );

      final approvedResponse =
          await widget.supabase.rpc(
        'get_event_approved_participants',
        params: {
          'p_event_id': widget.eventId,
        },
      );

      final pendingRows =
          List<Map<String, dynamic>>.from(
        (pendingResponse as List).map(
          (row) => Map<String, dynamic>.from(
            row as Map,
          ),
        ),
      );

      final pending = pendingRows.map((row) {
        return {
          'id': row['id'],
          'user_id': row['user_id'],
          'status': row['status'],
          'created_at': row['created_at'],
          'profile': {
            'id': row['user_id'],
            'name': row['name'],
            'avatar_url': row['avatar_url'],
          },
        };
      }).toList();

      final approved =
          List<Map<String, dynamic>>.from(
        (approvedResponse as List).map(
          (row) => Map<String, dynamic>.from(
            row as Map,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _pending = pending;
        _approved = approved;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Aanmeldingen ophalen mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _changeRegistrationStatus(
    Map<String, dynamic> registration,
    String status,
  ) async {
    final id = int.tryParse(
      registration['id']?.toString() ?? '',
    );

    if (id == null) return;

    setState(() {
      _updatingId = id;
    });

    try {
      await widget.supabase
          .from('event_registrations')
          .update({
        'status': status,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      final profile =
          registration['profile']
              as Map<String, dynamic>?;

      setState(() {
        _pending.removeWhere(
          (item) =>
              item['id']?.toString() ==
              registration['id']?.toString(),
        );

        if (status == 'approved' &&
            profile != null) {
          final alreadyExists = _approved.any(
            (participant) =>
                participant['id']?.toString() ==
                profile['id']?.toString(),
          );

          if (!alreadyExists) {
            _approved.add(
              Map<String, dynamic>.from(profile),
            );
          }
        }

        _updatingId = null;
      });

      widget.onMessage(
        status == 'approved'
            ? 'Aanmelding goedgekeurd.'
            : 'Aanmelding afgewezen.',
      );
    } catch (e) {
      debugPrint(
        'Status wijzigen mislukt: $e',
      );

      if (!mounted) return;

      setState(() {
        _updatingId = null;
      });

      widget.onMessage(
        'Status wijzigen mislukt.',
      );
    }
  }

  Widget _participantAvatar(
    String? avatarUrl,
  ) {
    final hasAvatar =
        avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl != 'null';

    return CircleAvatar(
      radius: 22,
      backgroundColor: cardColor,
      backgroundImage:
          hasAvatar
              ? NetworkImage(avatarUrl!)
              : null,
      child: !hasAvatar
          ? const Icon(
              Icons.person,
              color: secondaryTextColor,
            )
          : null,
    );
  }

  Widget _buildPendingRegistration(
    Map<String, dynamic> registration,
  ) {
    final profile =
        registration['profile']
            as Map<String, dynamic>?;

    final name =
        profile?['name']?.toString() ??
            'Onbekende gebruiker';

    final avatar =
        profile?['avatar_url']?.toString();

    final id = int.tryParse(
      registration['id']?.toString() ?? '',
    );

    final isUpdating =
        id != null && _updatingId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          _participantAvatar(avatar),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isUpdating)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: beigeColor,
                strokeWidth: 2,
              ),
            )
          else ...[
            Material(
              color:
                  Colors.redAccent.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(10),
              child: IconButton(
                tooltip: 'Afwijzen',
                onPressed: id == null
                    ? null
                    : () => _changeRegistrationStatus(
                          registration,
                          'rejected',
                        ),
                icon: const Icon(
                  Icons.close,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color:
                  Colors.greenAccent.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(10),
              child: IconButton(
                tooltip: 'Goedkeuren',
                onPressed: id == null
                    ? null
                    : () => _changeRegistrationStatus(
                          registration,
                          'approved',
                        ),
                icon: const Icon(
                  Icons.check,
                  color: Colors.greenAccent,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipant(
    Map<String, dynamic> profile,
  ) {
    final name =
        profile['name']?.toString() ??
            'Onbekende gebruiker';

    final avatar =
        profile['avatar_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          _participantAvatar(avatar),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.greenAccent,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: secondaryTextColor,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(15),
          child: CircularProgressIndicator(
            color: beigeColor,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Nieuwe aanmeldingen',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_pending.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent
                      .withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '${_pending.length}',
                  style: GoogleFonts.inter(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_pending.isEmpty)
          _emptyBox(
            'Geen nieuwe aanmeldingen.',
          )
        else
          ..._pending.map(
            _buildPendingRegistration,
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              'Goedgekeurde deelnemers',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_approved.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green
                      .withOpacity(0.10),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '${_approved.length}',
                  style: GoogleFonts.inter(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_approved.isEmpty)
          _emptyBox(
            'Nog geen goedgekeurde deelnemers.',
          )
        else
          ..._approved.map(
            _buildParticipant,
          ),
      ],
    );
  }
}