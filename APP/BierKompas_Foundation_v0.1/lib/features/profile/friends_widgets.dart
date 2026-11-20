import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Gedeelde onderdelen van de vriendenlijst ("Mijn Bier-vrienden"), gebruikt op
// "Gezelligheid & Social" (de vaste plek voor vrienden) en op het profiel.
// Verplaatst uit profile_page.dart; uiterlijk ongewijzigd.

// ---------- Mijn Bier-vrienden ----------

const _friendsCard = Color(0xFF2C221C);
const _friendsDivider = Color(0xFF3C3028);
const _friendsPrimary = Color(0xFFD4B28C);
const _friendsOnSurface = Color(0xFFEFE6DD);
const _friendsMuted = Color(0xFF9E8A7D);
const _friendsOnline = Color(0xFF4CAF50);

/// Ronde profielfoto met (optioneel) een groen online-bolletje.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, this.avatarUrl, this.online = false, this.size = 44});

  final String? avatarUrl;
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _friendsDivider,
            image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover) : null,
          ),
          child: avatarUrl == null ? Icon(Icons.person, color: _friendsMuted, size: size * 0.5) : null,
        ),
        if (online)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _friendsOnline,
                border: Border.all(color: _friendsCard, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Knop over de halve breedte boven de vriendenlijst ("Vriend toevoegen",
/// "Mijn QR-code").
class FriendsActionButton extends StatelessWidget {
  const FriendsActionButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? const Color(0xFF1E1712) : _friendsPrimary;
    return Material(
      color: filled ? _friendsPrimary : _friendsCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: _friendsPrimary.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: foreground, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Binnengekomen vriendschapsverzoek met Accepteren/Weigeren.
class FriendRequestRow extends StatelessWidget {
  const FriendRequestRow({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          FriendAvatar(avatarUrl: avatarUrl, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: _friendsOnSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Wil Bier-vrienden worden', style: GoogleFonts.inter(color: _friendsMuted, fontSize: 12)),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _friendsPrimary))
          else ...[
            IconButton(
              onPressed: onDecline,
              tooltip: 'Weigeren',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: _friendsDivider),
              icon: const Icon(Icons.close, size: 18, color: _friendsMuted),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _friendsPrimary,
                  foregroundColor: const Color(0xFF1E1712),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Accepteren', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Eén Bier-vriend: tik om te chatten, "Proost!" om te proosten.
class FriendRow extends StatelessWidget {
  const FriendRow({
    super.key,
    required this.name,
    this.avatarUrl,
    this.online = false,
    this.onTap,
    this.onProost,
    this.sending = false,
  });

  final String name;
  final String? avatarUrl;
  final bool online;
  final VoidCallback? onTap;
  final VoidCallback? onProost;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            FriendAvatar(avatarUrl: avatarUrl, online: online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: _friendsOnSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: GoogleFonts.inter(color: online ? _friendsOnline : _friendsMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              tooltip: 'Chatten',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chat_bubble_outline, size: 20, color: _friendsMuted),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                onPressed: sending ? null : onProost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _friendsPrimary,
                  foregroundColor: const Color(0xFF1E1712),
                  disabledBackgroundColor: _friendsDivider,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: sending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _friendsPrimary))
                    : const Icon(Icons.sports_bar, size: 16),
                label: Text('Proost!', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
