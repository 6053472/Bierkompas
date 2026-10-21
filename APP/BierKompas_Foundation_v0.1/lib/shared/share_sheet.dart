import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kent de 'Bottle Share'-badge toe (zie supabase/add_remaining_badges.sql).
/// Niet-blokkerend: lukt dit niet (geen netwerk, migratie nog niet gedraaid),
/// dan mag dat het delen zelf niet verstoren.
void recordBadgeShareAction() {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  Supabase.instance.client.rpc('record_share_action', params: {'p_user_id': userId}).catchError((e) {
    debugPrint('Kon Bottle Share-badge niet bijwerken: $e');
    return null;
  });
}

// Zelfde kleurenpalet als de rest van de app.
const _background = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _borderColor = Color(0xFF3E312A);

/// Openbaar adres van de app, meegestuurd als link in elke deeltekst. In de
/// webapp is dat het adres waarop de app nu draait.
const appPublicUrl = 'https://bierkompas.staging.voryniq.com/';

String get appShareUrl => kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : appPublicUrl;

/// Herbruikbaar deelmenu: "Meer opties" (systeem-deelvenster), WhatsApp,
/// Facebook (deelt de link; Facebook staat geen voorgevulde tekst toe),
/// Instagram/TikTok (kopieer tekst + open de app, native only -- deze
/// platforms accepteren geen tekst via een link, daarvoor is het systeem-
/// deelvenster de juiste weg) en "Tekst kopiëren". Gebruikt door evenementen,
/// Bierfeed-posts en boeken, zodat delen overal hetzelfde werkt. De link
/// ([link], standaard [appShareUrl]) wordt altijd aan de tekst toegevoegd.
Future<void> showAppShareSheet(
  BuildContext context, {
  required String shareText,
  String? subject,
  String? link,
  String title = 'Delen',
  WidgetBuilder? extraOption,
  // Aangeroepen zodra er echt iets gedeeld is (niet bij "Tekst kopiëren"),
  // zodat de 'Bottle Share'-badge toegekend kan worden. Fouten hierin mogen
  // het delen zelf nooit blokkeren.
  VoidCallback? onShared,
}) {
  final shareLink = link ?? appShareUrl;
  if (!shareText.contains(shareLink)) shareText = '$shareText\n$shareLink';
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _borderColor, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (extraOption != null) extraOption(sheetContext),
              ListTile(
                leading: const Icon(Icons.ios_share, color: _primary),
                title: Text('Meer opties', style: GoogleFonts.inter(color: _onSurface)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await Share.share(shareText, subject: subject);
                    onShared?.call();
                  } catch (e) {
                    // Bijv. een desktopbrowser zonder deelfunctie: dan in elk
                    // geval de tekst klaarzetten i.p.v. stil niets te doen.
                    await Clipboard.setData(ClipboardData(text: shareText));
                    _showMessage(context, 'Deze browser kan niet direct delen. De tekst met link is gekopieerd.');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
                title: Text('WhatsApp', style: GoogleFonts.inter(color: _onSurface)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareViaUrl(context, 'https://wa.me/?text=${Uri.encodeComponent(shareText)}');
                  onShared?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                title: Text('Facebook', style: GoogleFonts.inter(color: _onSurface)),
                subtitle: Text(
                  'Deelt de link; de tekst staat klaar om te plakken',
                  style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Clipboard.setData(ClipboardData(text: shareText));
                  if (!context.mounted) return;
                  _shareViaUrl(context, 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(shareLink)}');
                  onShared?.call();
                },
              ),
              if (!kIsWeb) ...[
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFE1306C)),
                  title: Text('Instagram', style: GoogleFonts.inter(color: _onSurface)),
                  subtitle: Text(
                    'Kopieert de tekst en opent Instagram',
                    style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _copyAndOpenApp(
                      context,
                      shareText: shareText,
                      appUrls: const ['instagram://app', 'https://www.instagram.com'],
                      appName: 'Instagram',
                    );
                    onShared?.call();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined, color: Color(0xFF69C9D0)),
                  title: Text('TikTok', style: GoogleFonts.inter(color: _onSurface)),
                  subtitle: Text(
                    'Kopieert de tekst en opent TikTok',
                    style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _copyAndOpenApp(
                      context,
                      shareText: shareText,
                      appUrls: const ['tiktok://', 'https://www.tiktok.com'],
                      appName: 'TikTok',
                    );
                    onShared?.call();
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.copy_all_outlined, color: _primary),
                title: Text('Tekst kopiëren', style: GoogleFonts.inter(color: _onSurface)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Clipboard.setData(ClipboardData(text: shareText));
                  _showMessage(context, 'Tekst gekopieerd.');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _shareViaUrl(BuildContext context, String url) async {
  final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!opened) _showMessage(context, 'Kon geen deelvenster openen.');
}

Future<void> _copyAndOpenApp(
  BuildContext context, {
  required String shareText,
  required List<String> appUrls,
  required String appName,
}) async {
  await Clipboard.setData(ClipboardData(text: shareText));
  for (final appUrl in appUrls) {
    if (await launchUrl(Uri.parse(appUrl), mode: LaunchMode.externalApplication)) {
      _showMessage(context, "Tekst gekopieerd. Plak 'm in je $appName-post of -story!");
      return;
    }
  }
  _showMessage(context, 'Tekst gekopieerd, maar $appName kon niet geopend worden.');
}

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
