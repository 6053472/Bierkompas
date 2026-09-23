import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../favorites/beers.dart';
import '../../shared/image_utils.dart';
import 'chat_service.dart';
import 'friends_service.dart';

const _bg = Color(0xFF1E1712);
const _card = Color(0xFF2C221C);
const _gold = Color(0xFFD4B28C);
const _cream = Color(0xFFEFE6DD);
const _muted = Color(0xFF9E8A7D);
const _outgoingBubble = Color(0xFF5A4438);

class ChatPage extends StatefulWidget {
  final Friend friend;

  const ChatPage({super.key, required this.friend});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage>? _messages;
  bool _sending = false;
  bool _sendingPhoto = false;
  RealtimeChannel? _channel;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _loadMessages();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.listMessages(widget.friend.id);
      if (!mounted) return;
      setState(() => _messages = messages);
      _chatService.markRead(widget.friend.id);
      _scrollToBottom();
    } on ChatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berichten ophalen mislukt: $e')),
      );
    }
  }

  void _subscribe() {
    if (_myId == null) return;
    _channel = Supabase.instance.client
        .channel('messages_${_myId}_${widget.friend.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: _myId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row['sender_id'] != widget.friend.id) return;
            final message = ChatMessage.fromRow(row);
            if (!mounted) return;
            setState(() => _messages = [...?_messages, message]);
            _chatService.markRead(widget.friend.id);
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send({
    required String body,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    if (body.trim().isEmpty && type == MessageType.text) return;
    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        receiverId: widget.friend.id,
        body: body,
        type: type,
        metadata: metadata,
      );
      _textController.clear();
      await _loadMessages();
    } on ChatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Versturen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature komt binnenkort beschikbaar.')),
    );
  }

  Future<void> _pickAndSendPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _sendingPhoto = true);
    try {
      final rawBytes = await picked.readAsBytes();
      final bytes = normalizeToJpeg(rawBytes);
      final url = await _chatService.uploadImage(bytes: bytes, fileExt: 'jpg');
      await _chatService.sendMessage(
        receiverId: widget.friend.id,
        body: '',
        type: MessageType.image,
        metadata: {'image_url': url},
      );
      await _loadMessages();
    } on ChatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto versturen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingPhoto = false);
    }
  }

  Future<void> _openShareSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: _muted, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.sports_bar, color: _gold),
              title: Text('Deel een bier', style: GoogleFonts.inter(color: _cream, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(context).pop();
                _openBeerPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: _gold),
              title: Text('Deel een proeverij', style: GoogleFonts.inter(color: _cream, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(context).pop();
                _openEventPicker();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openBeerPicker() async {
    final beer = await showModalBottomSheet<Beer>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: beers.length,
            itemBuilder: (context, index) {
              final beer = beers[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                    image: beer.imageUrl != null
                        ? DecorationImage(image: NetworkImage(beer.imageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: beer.imageUrl == null
                      ? const Icon(Icons.sports_bar, color: _gold, size: 18)
                      : null,
                ),
                title: Text(beer.name, style: GoogleFonts.inter(color: _cream, fontWeight: FontWeight.w600)),
                subtitle: Text(beer.style, style: GoogleFonts.inter(color: _muted, fontSize: 12)),
                onTap: () => Navigator.of(context).pop(beer),
              );
            },
          ),
        ),
      ),
    );
    if (beer == null) return;
    await _send(
      body: 'Heb je deze al eens geprobeerd?',
      type: MessageType.beerShare,
      metadata: {
        'id': beer.id,
        'name': beer.name,
        'style': beer.style,
        'abv': beer.abv,
        'image_url': beer.imageUrl,
      },
    );
  }

  Future<void> _openEventPicker() async {
    List<Map<String, dynamic>> events = [];
    try {
      final rows = await Supabase.instance.client
          .from('events')
          .select('id, name, start_date, location_name')
          .order('start_date')
          .limit(30);
      events = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // negeren: lege lijst tonen
    }
    if (!mounted) return;
    if (events.isEmpty) {
      _comingSoon('Er zijn nog geen evenementen om te delen');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                leading: const Icon(Icons.event, color: _gold),
                title: Text(
                  event['name'] as String? ?? 'Naamloos evenement',
                  style: GoogleFonts.inter(color: _cream, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  event['location_name'] as String? ?? '',
                  style: GoogleFonts.inter(color: _muted, fontSize: 12),
                ),
                onTap: () => Navigator.of(context).pop(event),
              );
            },
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _send(
      body: 'Zullen we hier samen naartoe gaan?',
      type: MessageType.eventInvite,
      metadata: {
        'id': picked['id'],
        'name': picked['name'],
        'start_date': picked['start_date'],
        'location_name': picked['location_name'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        iconTheme: const IconThemeData(color: _cream),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _bg,
                    image: widget.friend.avatarUrl != null
                        ? DecorationImage(image: NetworkImage(widget.friend.avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: widget.friend.avatarUrl == null
                      ? const Icon(Icons.person, color: _muted, size: 20)
                      : null,
                ),
                if (widget.friend.online)
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4CAF50),
                        border: Border.all(color: _card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.friend.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      color: _cream,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.friend.online ? 'Online' : 'Offline',
                    style: GoogleFonts.inter(
                      color: widget.friend.online ? const Color(0xFF4CAF50) : _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: _gold),
            onPressed: () => _comingSoon('Bellen'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: _cream),
            onPressed: () => _comingSoon('Meer opties'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final messages = _messages;
    if (messages == null) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Begin het gesprek met ${widget.friend.name}!',
          style: GoogleFonts.inter(color: _muted, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final showDateDivider = previous == null || !_isSameDay(previous.createdAt, message.createdAt);
        final isMe = message.senderId == _myId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateDivider) _buildDateDivider(message.createdAt),
            _buildBubble(message, isMe),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'VANDAAG';
    if (diff == 1) return 'GISTEREN';
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _dateLabel(date),
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe ? _outgoingBubble : _card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: GoogleFonts.inter(color: _cream, fontSize: 14, height: 1.4),
              ),
            if (message.type == MessageType.beerShare) ...[
              if (message.body.isNotEmpty) const SizedBox(height: 10),
              _buildBeerCard(message.metadata),
            ],
            if (message.type == MessageType.eventInvite) ...[
              if (message.body.isNotEmpty) const SizedBox(height: 10),
              _buildEventCard(message, isMe),
            ],
            if (message.type == MessageType.image) ...[
              if (message.body.isNotEmpty) const SizedBox(height: 10),
              _buildImageBubble(message.metadata),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message.createdAt),
                  style: GoogleFonts.inter(color: _muted, fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: message.readAt != null ? _gold : _muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBubble(Map<String, dynamic>? metadata) {
    final url = metadata?['image_url'] as String?;
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _openFullscreenImage(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: 220,
          height: 220,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _gold,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: 220,
            height: 220,
            color: _bg,
            child: const Icon(Icons.broken_image_outlined, color: _muted),
          ),
        ),
      ),
    );
  }

  void _openFullscreenImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: _cream),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeerCard(Map<String, dynamic>? metadata) {
    if (metadata == null) return const SizedBox.shrink();
    final name = metadata['name'] as String? ?? 'Onbekend bier';
    final style = metadata['style'] as String? ?? '';
    final imageUrl = metadata['image_url'] as String?;
    return GestureDetector(
      onTap: () => _comingSoon('Bierdetails'),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(8),
                image: imageUrl != null
                    ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null ? const Icon(Icons.sports_bar, color: _gold, size: 20) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(color: _gold, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (style.isNotEmpty)
                    Text(
                      style,
                      style: GoogleFonts.inter(color: _muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(ChatMessage message, bool isMe) {
    final metadata = message.metadata;
    if (metadata == null) return const SizedBox.shrink();
    final name = metadata['name'] as String? ?? 'Evenement';
    final location = metadata['location_name'] as String? ?? '';
    String when = '';
    final startDateRaw = metadata['start_date'] as String?;
    if (startDateRaw != null) {
      final parsed = DateTime.tryParse(startDateRaw);
      if (parsed != null) {
        when = '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}, '
            '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.5), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today, color: _gold, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _cream, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            [when, location].where((s) => s.isNotEmpty).join(' • '),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, fontSize: 12),
          ),
          if (!isMe) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: _sending ? null : () => _send(body: '✅ Ik ga mee naar "$name"!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Accepteren', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: _sending ? null : () => _send(body: '🤔 Misschien bij "$name"'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _gold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Misschien',
                        style: GoogleFonts.inter(color: _gold, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: Color(0xFF3E312A))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: _gold),
            onPressed: _sending ? null : _openShareSheet,
          ),
          IconButton(
            icon: _sendingPhoto
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                  )
                : const Icon(Icons.camera_alt_outlined, color: _muted),
            onPressed: _sendingPhoto ? null : _pickAndSendPhoto,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _send(body: value),
                style: GoogleFonts.inter(color: _cream, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Schrijf een bericht...',
                  hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Color.fromARGB(255, 255, 255, 255)),
                    onPressed: () => _send(body: _textController.text),
                  ),
                ),
        ],
      ),
    );
  }
}
