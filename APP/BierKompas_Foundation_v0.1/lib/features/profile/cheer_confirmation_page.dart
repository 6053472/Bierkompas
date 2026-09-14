import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_page.dart';
import 'cheers_service.dart';
import 'friends_service.dart';

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
    try {
      await widget.service.markSeen(widget.cheer.id);
    } on CheersException {
      // negeren: het scherm sluit sowieso, anders blijft de gebruiker vast zitten.
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature komt binnenkort beschikbaar.')),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          friend: Friend(
            id: widget.cheer.senderId,
            name: widget.cheer.senderName,
            avatarUrl: widget.cheer.senderAvatarUrl,
          ),
        ),
      ),
    );
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Feestelijke banner i.p.v. een echte foto (die hebben we niet).
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 190,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4A3221), Color(0xFF1E1712)],
                        ),
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: -0.35,
                              child: const Icon(Icons.sports_bar, color: _gold, size: 64),
                            ),
                            Transform.translate(
                              offset: const Offset(28, 0),
                              child: Transform.rotate(
                                angle: 0.35,
                                child: Icon(Icons.sports_bar, color: _gold.withOpacity(0.85), size: 64),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _bg.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _gold.withOpacity(0.6)),
                        ),
                        child: Text(
                          'PROOST!',
                          style: GoogleFonts.inter(
                            color: _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: _card, shape: BoxShape.circle),
                        child: const Icon(Icons.sports_bar, color: _gold, size: 30),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${widget.cheer.senderName} heeft je Proost-verzoek geaccepteerd!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          color: _cream,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '"Samen een eentje proosten, gezellig"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _openChat,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            'STUUR BERICHT',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _bg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _comingSoon('Profielen bekijken'),
                          icon: const Icon(Icons.person_outline, size: 18, color: _gold),
                          label: Text(
                            'BEKIJK PROFIEL',
                            style: GoogleFonts.inter(
                              color: _gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
