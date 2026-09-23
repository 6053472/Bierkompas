import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/add_friend_page.dart';
import '../profile/chat_page.dart';
import '../profile/friends_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// "Gezelligheid & Social": mijn Bier-vrienden en suggesties voor nieuwe
/// vrienden (Snapchat-achtige "Snel toevoegen"), op één plek.
class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final _friendsService = FriendsService();

  List<Friend> _friends = [];
  bool _friendsLoading = true;
  String? _friendsError;

  List<FriendSuggestion> _suggestions = [];
  bool _suggestionsLoading = true;
  String? _suggestionsError;
  final Set<String> _sentSuggestionIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadSuggestions();
  }

  Future<void> _loadFriends() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() {
      _friendsLoading = true;
      _friendsError = null;
    });
    try {
      final friends = await _friendsService.listFriends(user.id);
      if (!mounted) return;
      setState(() {
        _friends = friends;
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
              _sectionLabel('Mijn Bier-vrienden'),
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

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.openSans(color: _primary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 2),
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
        'Je hebt nog geen Bier-vrienden. Gebruik de zoekknop rechtsboven om iemand toe te voegen.',
        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
      );
    }
    return Column(
      children: _friends.map((friend) => _buildFriendTile(friend)).toList(),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ChatPage(friend: friend)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    _avatar(friend.name, friend.avatarUrl),
                    if (friend.online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(color: _cardColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    friend.name,
                    style: GoogleFonts.openSans(color: _onSurface, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chat_bubble_outline, color: _onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
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
