import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cheers_service.dart';

/// Volledig scherm getoond wanneer een vriend "Proost terug" stuurt als
/// antwoord op jouw proost. Toont bewust géén "Proost terug"-knop meer —
/// dat voorkomt een oneindige heen-en-weer keten van meldingen.
class CheerConfirmationPage extends StatefulWidget {
  final Cheer cheer;
  final CheersService service;

  const CheerConfirmationPage({super.key, required this.cheer, required this.service});

  @override
  State<CheerConfirmationPage> createState() => _CheerConfirmationPageState();
}

class _CheerConfirmationPageState extends State<CheerConfirmationPage> {
  static const _bg = Color(0xFF1E1712);
  static const _card = Color(0xFF2C221C);
  static const _gold = Color(0xFFD4B28C);
  static const _cream = Color(0xFFEFE6DD);
  static const _muted = Color(0xFF9E8A7D);

  bool _closing = false;

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    await widget.service.markSeen(widget.cheer.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _card,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: _cream),
            onPressed: _closing ? null : _close,
          ),
          title: Text(
            'Bevestiging',
            style: GoogleFonts.playfairDisplay(
              color: _cream,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
                child: const Icon(Icons.sports_bar, color: _gold, size: 16),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _card,
                      border: Border.all(color: _gold, width: 3),
                      image: widget.cheer.senderAvatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.cheer.senderAvatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.cheer.senderAvatarUrl == null
                        ? const Center(child: Icon(Icons.person, color: _muted, size: 42))
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Icon(Icons.sports_bar, color: _gold, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Proost bevestigd!',
                    style: GoogleFonts.playfairDisplay(
                      color: _cream,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(color: _muted, fontSize: 15, height: 1.4),
                      children: [
                        TextSpan(
                          text: widget.cheer.senderName,
                          style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' heeft je proost beantwoord. Tot de volgende keer! \u{1F37B}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _closing ? null : _close,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _closing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _bg),
                            )
                          : Text(
                              'Sluiten',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
