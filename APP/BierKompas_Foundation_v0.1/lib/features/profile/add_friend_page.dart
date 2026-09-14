import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'friends_service.dart';

/// Zoek- en toevoegscherm voor Bier-vrienden, geopend via de knop op het profiel.
class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _friendsService = FriendsService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<FriendSearchResult>? _results;
  bool _searching = false;
  String? _error;
  final Set<String> _pendingIds = {};
  bool _friendsAdded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _friendsService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(FriendSearchResult person) async {
    setState(() => _pendingIds.add(person.id));
    try {
      await _friendsService.sendRequest(person.id);
      if (!mounted) return;
      _friendsAdded = true;
      setState(() {
        _pendingIds.remove(person.id);
        _results = _results
            ?.map((r) => r.id == person.id
                ? FriendSearchResult(
                    id: r.id,
                    name: r.name,
                    avatarUrl: r.avatarUrl,
                    status: FriendStatus.requestSent,
                  )
                : r)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vriendschapsverzoek verstuurd naar ${person.name}.')),
      );
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() => _pendingIds.remove(person.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Versturen mislukt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_friendsAdded);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1712),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C221C),
          foregroundColor: const Color(0xFFEFE6DD),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_friendsAdded),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vrienden Toevoegen',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFFEFE6DD),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Zoek een naam om iemand toe te voegen als Bier-vriend.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E8A7D),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C221C),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFF3E312A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF9E8A7D), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onQueryChanged,
                          autofocus: true,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          cursorColor: const Color(0xFFD4B28C),
                          decoration: InputDecoration(
                            hintText: 'Zoek op naam...',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF9E8A7D),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Zoeken mislukt: $_error',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 13),
        ),
      );
    }
    if (_results == null) {
      return Center(
        child: Text(
          'Typ een naam om te beginnen met zoeken.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 13),
        ),
      );
    }
    if (_results!.isEmpty) {
      return Center(
        child: Text(
          'Geen gebruikers gevonden.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF9E8A7D), fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final person = _results![index];
        final isPending = _pendingIds.contains(person.id);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2C221C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3C3028),
                  image: person.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(person.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: person.avatarUrl == null
                    ? const Center(
                        child: Icon(Icons.person, color: Color(0xFF9E8A7D), size: 22),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  person.name,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEFE6DD),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: person.status != FriendStatus.none || isPending
                      ? null
                      : () => _sendRequest(person),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4B28C),
                    foregroundColor: const Color(0xFF1E1712),
                    disabledBackgroundColor: const Color(0xFF3C3028),
                    disabledForegroundColor: const Color(0xFF9E8A7D),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: isPending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E1712)),
                        )
                      : Text(
                          switch (person.status) {
                            FriendStatus.friends => 'Vrienden',
                            FriendStatus.requestSent => 'Aangevraagd',
                            FriendStatus.requestReceived => 'Nodigt jou uit',
                            FriendStatus.none => 'Toevoegen',
                          },
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
