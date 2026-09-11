import 'package:flutter/material.dart';

/// Rond profielicoontje voor rechtsboven in de paginaheaders.
/// Toont de eigen profielfoto van de gebruiker, met een fallback-icoon
/// wanneer er nog geen avatar is ingesteld.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({
    super.key,
    required this.onTap,
    this.avatarUrl,
    this.size = 36,
    this.borderColor = const Color(0xFFD4B28C),
  });

  final VoidCallback onTap;
  final String? avatarUrl;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor.withOpacity(0.6), width: 1.5),
          color: const Color(0xFF3C3028),
          image: avatarUrl != null
              ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: avatarUrl == null
            ? Icon(Icons.person, color: borderColor, size: size * 0.55)
            : null,
      ),
    );
  }
}
