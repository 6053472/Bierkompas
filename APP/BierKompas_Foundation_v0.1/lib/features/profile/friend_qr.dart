import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'friends_service.dart';

// Zelfde kleurenpalet als het profiel.
const _background = Color(0xFF1E1712);
const _card = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);

final _uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

const _qrPrefix = 'bierkompas://vriend/';

/// Inhoud van iemands persoonlijke QR-code: `bierkompas://vriend/<id>`.
/// Wordt alleen door de scanner in de app gelezen (Vrienden toevoegen ->
/// Scan QR-code); er wordt niet naar een website genavigeerd.
String friendQrPayload(String userId) => '$_qrPrefix$userId';

/// Haalt het gebruikers-id uit een gescande code. Null als het geen
/// Bierkompas-vriendcode is.
String? parseFriendQr(String raw) {
  final text = raw.trim();
  final id = text.startsWith(_qrPrefix) ? text.substring(_qrPrefix.length) : text;
  return _uuidPattern.hasMatch(id) ? id : null;
}

/// Toont mijn persoonlijke QR-code.
Future<void> showMyFriendQr(BuildContext context) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3E312A), borderRadius: BorderRadius.circular(20)),
            ),
            const SizedBox(height: 18),
            Text('Mijn QR-code', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Laat een Bier-vriend deze code scannen via Vrienden toevoegen → Scan QR-code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: friendQrPayload(userId),
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _background),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _background),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Camera-scherm dat een vriend-QR-code scant en daarna het profiel toont.
class ScanFriendQrPage extends StatefulWidget {
  const ScanFriendQrPage({super.key});

  @override
  State<ScanFriendQrPage> createState() => _ScanFriendQrPageState();
}

class _ScanFriendQrPageState extends State<ScanFriendQrPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    final userId = parseFriendQr(raw);
    if (userId == null) {
      _handled = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dit is geen Bierkompas-vriendcode.')),
      );
      await Future.delayed(const Duration(seconds: 2));
      _handled = false;
      return;
    }
    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    await showFriendProfileSheet(context, userId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _onSurface,
        elevation: 0,
        title: Text('Scan QR-code', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: _primary, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              'Richt de camera op de QR-code in het profiel van je Bier-vriend.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toont het profiel van [userId] met een knop om hem als vriend toe te voegen
/// (of zijn openstaande verzoek te accepteren).
Future<void> showFriendProfileSheet(BuildContext context, String userId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _FriendProfileSheet(userId: userId),
  );
}

class _FriendProfileSheet extends StatefulWidget {
  const _FriendProfileSheet({required this.userId});

  final String userId;

  @override
  State<_FriendProfileSheet> createState() => _FriendProfileSheetState();
}

class _FriendProfileSheetState extends State<_FriendProfileSheet> {
  final _service = FriendsService();
  FriendSearchResult? _profile;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  bool get _isMe => widget.userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.getProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = profile == null ? 'Deze gebruiker bestaat niet (meer).' : null;
        _loading = false;
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Profiel laden mislukt: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addFriend() async {
    final profile = _profile!;
    setState(() => _busy = true);
    try {
      if (profile.status == FriendStatus.requestReceived) {
        await _service.respondToRequest(requesterId: profile.id, accept: true);
      } else {
        await _service.sendRequest(profile.id);
      }
      if (!mounted) return;
      final accepted = profile.status == FriendStatus.requestReceived;
      setState(() {
        _busy = false;
        _profile = FriendSearchResult(
          id: profile.id,
          name: profile.name,
          avatarUrl: profile.avatarUrl,
          status: accepted ? FriendStatus.friends : FriendStatus.requestSent,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accepted
            ? 'Je bent nu Bier-vrienden met ${profile.name}.'
            : 'Vriendschapsverzoek verstuurd naar ${profile.name}.'),
      ));
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Versturen mislukt: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: _loading
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: _primary)))
            : _error != null
                ? SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 14)),
                    ),
                  )
                : _buildProfile(),
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    final (label, enabled) = _isMe
        ? ('Dit ben jij', false)
        : switch (profile.status) {
            FriendStatus.friends => ('Al Bier-vrienden', false),
            FriendStatus.requestSent => ('Verzoek verstuurd', false),
            FriendStatus.requestReceived => ('Verzoek accepteren', true),
            FriendStatus.none => ('Vriend toevoegen', true),
          };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: const Color(0xFF3C3028),
          backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          child: profile.avatarUrl == null ? const Icon(Icons.person, color: _onSurfaceVariant, size: 40) : null,
        ),
        const SizedBox(height: 14),
        Text(profile.name, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Bierkompas-lid', style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: enabled && !_busy ? _addFriend : null,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _background))
                : Icon(enabled ? Icons.person_add_alt_1 : Icons.check, size: 18),
            label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _background,
              disabledBackgroundColor: const Color(0xFF3C3028),
              disabledForegroundColor: _onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
