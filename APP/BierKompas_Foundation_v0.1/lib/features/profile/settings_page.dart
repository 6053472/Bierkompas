import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_service.dart';
import '../auth/auth_storage.dart';
import 'profile_edit_page.dart';

class SettingsPage extends StatefulWidget {
  final AppUser? user;

  const SettingsPage({super.key, this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _emailUpdates = false;
<<<<<<< Updated upstream
  bool _deletingAccount = false;
  final _authService = AuthService();
=======
  late AppUser? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => ProfileEditPage(user: _user)),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }
>>>>>>> Stashed changes

  static const _bg = Color(0xFF1E1712);
  static const _card = Color(0xFF2C221C);
  static const _gold = Color(0xFFD4B28C);
  static const _cream = Color(0xFFEFE6DD);
  static const _muted = Color(0xFF9E8A7D);
  static const _divider = Color(0xFF49382E);

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Uitloggen', style: GoogleFonts.playfairDisplay(color: _cream, fontWeight: FontWeight.bold)),
        content: Text(
          'Weet je zeker dat je wilt uitloggen?',
          style: GoogleFonts.inter(color: _muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuleren', style: GoogleFonts.inter(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Uitloggen', style: GoogleFonts.inter(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Account verwijderen', style: GoogleFonts.playfairDisplay(color: _cream, fontWeight: FontWeight.bold)),
        content: Text(
          'Weet je zeker dat je je account wilt verwijderen? Al je gegevens worden permanent verwijderd. Dit kan niet ongedaan worden gemaakt.',
          style: GoogleFonts.inter(color: _muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuleren', style: GoogleFonts.inter(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Verwijderen', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await _authService.deleteAccount();
      await AuthStorage.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: _cream),
                ),
                Text(
                  'Instellingen',
                  style: GoogleFonts.playfairDisplay(
                    color: _cream,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _sectionTitle('Account'),
            _sectionCard([
              _infoTile(icon: Icons.person_outline, label: 'Naam', value: _user?.name ?? '-'),
              const Divider(color: _divider, height: 1),
              _infoTile(icon: Icons.mail_outline, label: 'E-mail', value: _user?.email ?? '-'),
              const Divider(color: _divider, height: 1),
              _navTile(
                icon: Icons.edit_outlined,
                title: 'Profiel bewerken',
                onTap: _editProfile,
              ),
            ]),
            const SizedBox(height: 24),

            _sectionTitle('Voorkeuren'),
            _sectionCard([
              _switchTile(
                icon: Icons.notifications_none,
                title: 'Pushmeldingen',
                subtitle: 'Ontvang meldingen over nieuwe bieren en badges.',
                value: _pushNotifications,
                onChanged: (value) => setState(() => _pushNotifications = value),
              ),
              const Divider(color: _divider, height: 1),
              _switchTile(
                icon: Icons.mark_email_unread_outlined,
                title: 'E-mailupdates',
                subtitle: 'Ontvang nieuws en aanbevelingen per e-mail.',
                value: _emailUpdates,
                onChanged: (value) => setState(() => _emailUpdates = value),
              ),
            ]),
            const SizedBox(height: 24),

            _sectionTitle('Privacy & Juridisch'),
            _sectionCard([
              _navTile(
                icon: Icons.description_outlined,
                title: 'Algemene Voorwaarden',
                onTap: () {},
              ),
              const Divider(color: _divider, height: 1),
              _navTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacybeleid',
                onTap: () {},
              ),
              const Divider(color: _divider, height: 1),
              _navTile(
                icon: Icons.verified_user_outlined,
                title: 'Voorwaardenversie $termsVersion · Privacyversie $privacyVersion',
                onTap: null,
              ),
            ]),
            const SizedBox(height: 24),

            _sectionTitle('Account acties'),
            _sectionCard([
              _navTile(
                icon: Icons.logout,
                title: 'Uitloggen',
                onTap: _confirmLogout,
              ),
              const Divider(color: _divider, height: 1),
              _navTile(
                icon: Icons.delete_outline,
                title: _deletingAccount ? 'Account verwijderen...' : 'Account verwijderen',
                titleColor: Colors.redAccent,
                onTap: _deletingAccount ? null : _confirmDeleteAccount,
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(color: _gold, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoTile({required IconData icon, required String label, required String value}) {
    return ListTile(
      leading: Icon(icon, color: _muted),
      title: Text(label, style: GoogleFonts.inter(color: _muted, fontSize: 12)),
      subtitle: Text(value, style: GoogleFonts.inter(color: _cream, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: _gold,
      secondary: Icon(icon, color: _muted),
      title: Text(title, style: GoogleFonts.inter(color: _cream, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(color: _muted, fontSize: 11)),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? _muted),
      title: Text(
        title,
        style: GoogleFonts.inter(color: titleColor ?? _cream, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: _muted),
      onTap: onTap,
    );
  }
}
