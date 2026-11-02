import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/profile/chat_service.dart';
import '../features/profile/friends_service.dart';

const _card = Color(0xFF2C221C);
const _background = Color(0xFF1E1712);
const _gold = Color(0xFFD4B28C);
const _cream = Color(0xFFEFE6DD);
const _muted = Color(0xFF9E8A7D);

/// "Deel met een Biervriend"-regel voor het deelmenu ([showAppShareSheet]'s
/// extraOption): kiest een vriend en stuurt het bericht naar diens chat.
Widget shareWithFriendOption(
  BuildContext sheetContext, {
  required BuildContext context,
  required String body,
  MessageType type = MessageType.text,
  Map<String, dynamic>? metadata,
}) {
  return ListTile(
    leading: const Icon(Icons.person_outline, color: _gold),
    title: Text('Deel met een Biervriend', style: GoogleFonts.inter(color: _cream, fontWeight: FontWeight.w600)),
    onTap: () {
      Navigator.pop(sheetContext);
      shareWithFriend(context, body: body, type: type, metadata: metadata);
    },
  );
}

/// Laat de gebruiker een bevestigde vriend kiezen en stuurt [body] (met
/// eventueel een bier- of evenementkaartje via [type]/[metadata]) naar de chat.
Future<void> shareWithFriend(
  BuildContext context, {
  required String body,
  MessageType type = MessageType.text,
  Map<String, dynamic>? metadata,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final messenger = ScaffoldMessenger.of(context);
  if (user == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Log in om te delen met een Biervriend.')));
    return;
  }

  List<Friend> friends;
  try {
    friends = await FriendsService().listFriends(user.id);
  } on FriendsException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Vrienden ophalen mislukt: $e')));
    return;
  }
  if (friends.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Je hebt nog geen Bier-vrienden.')));
    return;
  }
  if (!context.mounted) return;

  final picked = await showModalBottomSheet<Friend>(
    context: context,
    backgroundColor: _card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.6,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: friends.length,
          itemBuilder: (_, index) {
            final friend = friends[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: _background,
                backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                child: friend.avatarUrl == null ? const Icon(Icons.person, color: _muted) : null,
              ),
              title: Text(friend.name, style: GoogleFonts.inter(color: _cream, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: _muted),
              onTap: () => Navigator.pop(sheetContext, friend),
            );
          },
        ),
      ),
    ),
  );
  if (picked == null) return;

  try {
    await ChatService().sendMessage(receiverId: picked.id, body: body, type: type, metadata: metadata);
    messenger.showSnackBar(SnackBar(content: Text('Gedeeld met ${picked.name}!')));
  } on ChatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Delen mislukt: $e')));
  }
}
