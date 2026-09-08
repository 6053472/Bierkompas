import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/home_page.dart';
import 'auth_service.dart';
import 'auth_storage.dart';

class ConsentPage extends StatefulWidget {
  final AppUser user;

  const ConsentPage({super.key, required this.user});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  final _authService = AuthService();
  bool _mainApproval = false;
  bool _ageConfirmed = false;
  bool _lawfulAlcoholUse = false;
  bool _accurateAccountData = false;
  bool _personalAccount = false;
  bool _credentialsSecure = false;
  bool _noImpersonation = false;
  bool _isSaving = false;
  String? _error;

  bool get _isComplete =>
      _mainApproval &&
      _ageConfirmed &&
      _lawfulAlcoholUse &&
      _accurateAccountData &&
      _personalAccount &&
      _credentialsSecure &&
      _noImpersonation;

  Future<void> _submit() async {
    if (!_isComplete) {
      setState(() => _error = 'Bevestig alle onderdelen om Bierkompas te gebruiken.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _authService.saveConsent(userId: widget.user.id);
      await AuthStorage.saveConsent();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Voordat je begint',
                    style: GoogleFonts.playfairDisplay(
                      color: cream,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lees de voorwaarden en bevestig de afspraken voor jouw account.',
                    style: GoogleFonts.inter(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _check(
                          value: _mainApproval,
                          title: 'Ik ga akkoord en wil Bierkompas gebruiken.',
                          subtitle: 'Ik heb de Algemene Voorwaarden, het Privacybeleid en de Communityrichtlijnen kunnen bekijken.',
                          onChanged: (value) => setState(() => _mainApproval = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                        const Divider(color: Color(0xFF49382E), height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Leeftijd en alcohol',
                            style: GoogleFonts.inter(color: gold, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _check(
                          value: _ageConfirmed,
                          title: 'Ik ben 18 jaar of ouder.',
                          onChanged: (value) => setState(() => _ageConfirmed = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                        _check(
                          value: _lawfulAlcoholUse,
                          title: 'Ik gebruik Bierkompas volgens de geldende wetgeving.',
                          onChanged: (value) => setState(() => _lawfulAlcoholUse = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                        const Divider(color: Color(0xFF49382E), height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Account en veiligheid',
                            style: GoogleFonts.inter(color: gold, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _check(
                          value: _accurateAccountData,
                          title: 'Ik verstrek juiste gegevens voor mijn account.',
                          onChanged: (value) => setState(() => _accurateAccountData = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                        _check(
                          value: _personalAccount,
                          title: 'Ik gebruik mijn account persoonlijk.',
                          onChanged: (value) => setState(() => _personalAccount = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                        _check(
                          value: _credentialsSecure,
                          title: 'Ik houd mijn inloggegevens veilig.',
                          onChanged: (value) => setState(() => _credentialsSecure = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                        _check(
                          value: _noImpersonation,
                          title: 'Ik gebruik geen valse identiteit of het account van iemand anders.',
                          onChanged: (value) => setState(() => _noImpersonation = value),
                          gold: gold,
                          cream: cream,
                          muted: muted,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF1E1712),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1E1712),
                              ),
                            )
                          : Text(
                              'Akkoord en doorgaan',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Voorwaardenversie $termsVersion · Privacyversie $privacyVersion',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _check({
    required bool value,
    required String title,
    String? subtitle,
    required ValueChanged<bool> onChanged,
    required Color gold,
    required Color cream,
    required Color muted,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (nextValue) => onChanged(nextValue ?? false),
      activeColor: gold,
      checkColor: const Color(0xFF1E1712),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: GoogleFonts.inter(color: cream, fontSize: 13)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: GoogleFonts.inter(color: muted, fontSize: 11)),
    );
  }
}
