import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cheers_service.dart';

/// Toont de "Proost!"-kaart wanneer een vriend een digitale proost stuurt.
/// Geeft true terug als de gebruiker meteen "Proost terug" heeft gestuurd.
Future<void> showCheerOverlay(BuildContext context, Cheer cheer, CheersService service) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _CheerCard(cheer: cheer, service: service);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _CheerCard extends StatefulWidget {
  final Cheer cheer;
  final CheersService service;

  const _CheerCard({required this.cheer, required this.service});

  @override
  State<_CheerCard> createState() => _CheerCardState();
}

class _CheerCardState extends State<_CheerCard> {
  bool _busy = false;

  Future<void> _dismiss() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.service.markSeen(widget.cheer.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cheerBack() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.sendCheer(widget.cheer.senderId);
      await widget.service.markSeen(widget.cheer.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost terug verstuurd naar ${widget.cheer.senderName}!')),
      );
    } on CheersException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proost terug versturen mislukt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3C2A1D), Color(0xFF1E1712)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD4B28C).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C221C),
              ),
              child: const Icon(Icons.celebration, color: Color(0xFFD4B28C), size: 30),
            ),
            const SizedBox(height: 16),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3C3028),
                    border: Border.all(color: const Color(0xFFEFE6DD), width: 3),
                    image: widget.cheer.senderAvatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(widget.cheer.senderAvatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.cheer.senderAvatarUrl == null
                      ? const Center(
                          child: Icon(Icons.person, color: Color(0xFF9E8A7D), size: 36),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4B28C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Color(0xFF1E1712), size: 12),
                        const SizedBox(width: 3),
                        Text(
                          'VRIEND',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1E1712),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Proost!',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFEFE6DD),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(color: const Color(0xFFD8C9BD), fontSize: 15, height: 1.4),
                children: [
                  TextSpan(
                    text: widget.cheer.senderName,
                    style: const TextStyle(color: Color(0xFFD4B28C), fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' geeft je een digitale proost!'),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _cheerBack,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E1712)),
                      )
                    : const Icon(Icons.sports_bar, size: 18),
                label: Text(
                  'PROOST TERUG',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4B28C),
                  foregroundColor: const Color(0xFF1E1712),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _busy ? null : _dismiss,
              child: Text(
                'NIET NU',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9E8A7D),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
