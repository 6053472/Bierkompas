import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'login_page.dart';

/// Getoond na registreren zolang Supabase e-mailbevestiging vereist, dus
/// vóórdat er een actieve sessie is om het goedkeuringsscherm te tonen.
class CheckEmailPage extends StatefulWidget {
  final String email;

  const CheckEmailPage({super.key, required this.email});

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  final _authService = AuthService();
  bool _isResending = false;
  String? _info;

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _info = null;
    });
    try {
      await _authService.resendConfirmationEmail(widget.email);
      if (!mounted) return;
      setState(() => _info = 'Bevestigingsmail opnieuw verstuurd.');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _info = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4B28C);
    const cream = Color(0xFFEFE6DD);
    const muted = Color(0xFF9E8A7D);
    const card = Color(0xFF2C221C);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.18),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, color: gold, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Check je e-mail',
                    style: GoogleFonts.playfairDisplay(
                      color: cream,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We hebben een bevestigingslink gestuurd naar\n${widget.email}.\nKlik op de link en log daarna in om verder te gaan.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: muted, fontSize: 13, height: 1.5),
                  ),
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: gold, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF1E1712),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Naar inloggen',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(
                      _isResending ? 'Versturen...' : 'Geen mail ontvangen? Opnieuw versturen',
                      style: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w600, fontSize: 13),
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
