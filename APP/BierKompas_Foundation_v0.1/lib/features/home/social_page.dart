import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/add_friend_page.dart';
import '../profile/chat_page.dart';
import '../profile/cheers_service.dart';
import '../profile/friend_qr.dart';
import '../profile/friends_service.dart';
import '../profile/friends_widgets.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);
const _divider = Color(0xFF3C3028);

/// "Gezelligheid & Social": de vaste plek voor alles rond Bier-vrienden.
/// Vriend toevoegen en de eigen QR-code, binnengekomen vriendschapsverzoeken
/// (accepteren/weigeren), de vriendenlijst (chatten en "Proost!") en
/// suggesties voor nieuwe vrienden (Snapchat-achtige "Snel toevoegen").
/// Het profiel toont alleen een samenvatting die hiernaartoe linkt.
class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final _friendsService = FriendsService();
  final _cheersService = CheersService();

  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  bool _friendsLoading = true;
  String? _friendsError;
  final Set<String> _pendingRequestActions = {};
  final Set<String> _sendingCheerIds = {};
  RealtimeChannel? _friendsChannel;

  List<FriendSuggestion> _suggestions = [];
  bool _suggestionsLoading = true;
  String? _suggestionsError;
  final Set<String> _sentSuggestionIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadSuggestions();
    _subscribeToFriendUpdates();
  }

  @override
  void dispose() {
    _friendsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _friendsLoading = false);
      return;
    }
    setState(() {
      _friendsLoading = _friends.isEmpty && _requests.isEmpty;
      _friendsError = null;
    });
    try {
      final results = await Future.wait([
        _friendsService.listFriends(user.id),
        _friendsService.listIncomingRequests(user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<Friend>;
        _requests = results[1] as List<FriendRequest>;
        _friendsLoading = false;
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() {
        _friendsError = e.message;
        _friendsLoading = false;
      });
    }
  }

  // Live bijwerken: een nieuw, geaccepteerd of geweigerd verzoek komt via
  // Supabase Realtime meteen binnen (zelfde aanpak als eerder op het profiel).
  void _subscribeToFriendUpdates() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _friendsChannel = Supabase.instance.client
        .channel('social_friend_requests_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'addressee_id', value: user.id),
          callback: (_) => _loadFriends(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'requester_id', value: user.id),
          callback: (_) => _loadFriends(),
        )
        .subscribe();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _suggestionsLoading = true;
      _suggestionsError = null;
    });
    try {
      final suggestions = await _friendsService.suggestFriends();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _suggestionsLoading = false;
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = e.message;
        _suggestionsLoading = false;
      });
    }
  }

  Future<void> _addSuggestedFriend(FriendSuggestion suggestion) async {
    setState(() => _sentSuggestionIds.add(suggestion.id));
    try {
      await _friendsService.sendRequest(suggestion.id);
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() => _sentSuggestionIds.remove(suggestion.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verzoek versturen mislukt: $e')),
      );
    }
  }

  Future<void> _respondToRequest(FriendRequest request, bool accept) async {
    setState(() => _pendingRequestActions.add(request.requesterId));
    try {
      await _friendsService.respondToRequest(requesterId: request.requesterId, accept: accept);
      if (!mounted) return;
      setState(() {
        _pendingRequestActions.remove(request.requesterId);
        _requests.removeWhere((r) => r.requesterId == request.requesterId);
        if (accept && !_friends.any((f) => f.id == request.requesterId)) {
          _friends = [
            ..._friends,
            Friend(id: request.requesterId, name: request.name, avatarUrl: request.avatarUrl),
          ];
        }
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() => _pendingRequestActions.remove(request.requesterId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reageren mislukt: $e')),
      );
    }
  }

  Future<void> _sendCheer(Friend friend) async {
    setState(() => _sendingCheerIds.add(friend.id));
    try {
      await _cheersService.sendCheer(friend.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost verstuurd naar ${friend.name}!')),
      );
    } on CheersException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost versturen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingCheerIds.remove(friend.id));
    }
  }

  void _openChat(Friend friend) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ChatPage(friend: friend)),
    );
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddFriendPage()),
    );
    if (added == true) {
      _loadFriends();
      _loadSuggestions();
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadFriends(), _loadSuggestions()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _onSurface,
        iconTheme: const IconThemeData(color: _onSurface),
        elevation: 0,
        title: Text('Gezelligheid & Social', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Vrienden zoeken',
            onPressed: _openAddFriend,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FriendsActionButton(
                      icon: Icons.person_add_alt_1,
                      label: 'Vriend toevoegen',
                      filled: true,
                      onTap: _openAddFriend,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FriendsActionButton(
                      icon: Icons.qr_code_2,
                      label: 'Mijn QR-code',
                      onTap: () => showMyFriendQr(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_requests.isNotEmpty) ...[
                _sectionLabel('Vriendschapsverzoeken (${_requests.length})'),
                const SizedBox(height: 12),
                _card(
                  [
                    for (final request in _requests)
                      FriendRequestRow(
                        name: request.name,
                        avatarUrl: request.avatarUrl,
                        busy: _pendingRequestActions.contains(request.requesterId),
                        onAccept: () => _respondToRequest(request, true),
                        onDecline: () => _respondToRequest(request, false),
                      ),
                  ],
                  highlight: true,
                ),
                const SizedBox(height: 28),
              ],
              _sectionLabel(_friendsHeader()),
              const SizedBox(height: 12),
              _buildFriendsSection(),
              const SizedBox(height: 36),
              _sectionLabel('Snel toevoegen'),
              const SizedBox(height: 12),
              _buildSuggestionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  String _friendsHeader() {
    if (_friends.isEmpty) return 'Mijn Bier-vrienden';
    final online = _friends.where((f) => f.online).length;
    return 'Mijn Bier-vrienden (${_friends.length}${online > 0 ? ' · $online online' : ''})';
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.openSans(color: _primary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 2),
    );
  }

  Widget _card(List<Widget> rows, {bool highlight = false}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? _primary.withOpacity(0.45) : _divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: _divider, indent: 70),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildFriendsSection() {
    if (_friendsLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: _primary),
      ));
    }
    if (_friendsError != null) {
      return _errorBlock('Kon vrienden niet laden: $_friendsError', _loadFriends);
    }
    if (_friends.isEmpty) {
      return Text(
        'Je hebt nog geen Bier-vrienden. Voeg iemand toe op naam of laat je QR-code scannen.',
        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
      );
    }
    final friends = [..._friends]..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return _card([
      for (final friend in friends)
        FriendRow(
          name: friend.name,
          avatarUrl: friend.avatarUrl,
          online: friend.online,
          sending: _sendingCheerIds.contains(friend.id),
          onProost: () => _sendCheer(friend),
          onTap: () => _openChat(friend),
        ),
    ]);
  }

  Widget _buildSuggestionsSection() {
    if (_suggestionsLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: _primary),
      ));
    }
    if (_suggestionsError != null) {
      return _errorBlock('Kon suggesties niet laden: $_suggestionsError', _loadSuggestions);
    }
    if (_suggestions.isEmpty) {
      return Text(
        'Geen suggesties op dit moment.',
        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
      );
    }
    return Column(
      children: _suggestions.map((s) => _buildSuggestionTile(s)).toList(),
    );
  }

  Widget _buildSuggestionTile(FriendSuggestion suggestion) {
    final sent = _sentSuggestionIds.contains(suggestion.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _avatar(suggestion.name, suggestion.avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  suggestion.name,
                  style: GoogleFonts.openSans(color: _onSurface, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              sent
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Verzonden',
                        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _addSuggestedFriend(suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Toevoegen',
                          style: GoogleFonts.openSans(color: _onPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, String? avatarUrl) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _outlineVariant,
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.playfairDisplay(color: _primary, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  Widget _errorBlock(String message, VoidCallback onRetry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(foregroundColor: _primary, side: const BorderSide(color: _primary)),
          child: const Text('Opnieuw proberen'),
        ),
      ],
    );
  }
}
