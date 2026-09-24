import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../favorites/beers.dart';
import 'beer_scan_service.dart';
import 'web_camera_cleanup.dart';

// Zelfde kleurenpalet als de rest van de app (Profiel, Kaart, Agenda, Ontdek, ...).
const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);

/// Camera-scherm om de barcode van een flesje/blikje te scannen.
///
/// Herkent alleen bieren die in Bierkompas staan (zie [findBeerByBarcode]) --
/// een barcode van een ander soort product levert altijd "niet gevonden" op,
/// er wordt nooit teruggevallen op een algemene productdatabase.
class BeerScanPage extends StatefulWidget {
  const BeerScanPage({super.key});

  @override
  State<BeerScanPage> createState() => _BeerScanPageState();
}

class _BeerScanPageState extends State<BeerScanPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8]);
  final _scanService = BeerScanService();
  bool _handled = false;
  bool _torchOn = false;

  // null = nog aan het checken, true/false = resultaat van de permissiecheck.
  // Nodig omdat we anders alleen het generieke "!"-icoon van mobile_scanner
  // zien zonder duidelijke uitleg of een manier om het op te lossen.
  bool? _cameraPermissionGranted;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraPermissionGranted = status.isGranted;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // mobile_scanner geeft de camera op web niet altijd netjes vrij (bekende
    // bug in de "polling"-scanner) -- forceer het stoppen van elke nog actieve
    // cameratrack zodat het cameralampje in de browser ook echt uitgaat.
    stopAllCameraStreams();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (code == null) return;
    _handled = true;
    _controller.stop();

    // De barcode-koppeling staat in Supabase (tabel `bieren`, door een
    // beheerder ingesteld), niet meer hardcoded in de app.
    final beer = await _scanService.findBeerByBarcode(code);
    if (!mounted) return;
    if (beer == null) {
      _showNotABeerSheet();
    } else {
      _showBeerFoundSheet(beer);
    }
  }

  void _resumeScanning() {
    if (!mounted) return;
    setState(() => _handled = false);
    _controller.start();
  }

  Future<void> _showNotABeerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ResultSheet(
        icon: Icons.no_drinks_outlined,
        title: 'Geen bier uit Bierkompas',
        message:
            'Deze barcode hoort niet bij een bier dat we kennen in Bierkompas. We herkennen alleen bieren, geen andere producten.',
        primaryLabel: 'Opnieuw scannen',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    );
    _resumeScanning();
  }

  Future<void> _showBeerFoundSheet(Beer beer) async {
    final user = Supabase.instance.client.auth.currentUser;
    BeerScanLogResult? result;
    String? error;

    if (user != null) {
      try {
        result = await _scanService.logScan(userId: user.id, beerId: beer.id, brewery: beer.brewery);
      } on BeerScanException catch (e) {
        error = e.message;
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _BeerFoundSheet(beer: beer, result: result, error: error, loggedIn: user != null),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Nog aan het checken of camera-toestemming er is.
    if (_cameraPermissionGranted == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_cameraPermissionGranted == false) {
      return _buildPermissionDenied(context);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildCameraError(context, error),
          ),
          // Donkere overlay met uitgesneden zoekvenster.
          _ViewfinderOverlay(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const Spacer(),
                _buildInstructions(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined, color: _primary, size: 56),
              const SizedBox(height: 20),
              Text(
                'Geen cameratoegang',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                _permanentlyDenied
                    ? 'Bierkompas heeft geen toestemming voor de camera. Zet dit aan bij Instellingen om bieren te kunnen scannen.'
                    : 'Bierkompas heeft toegang tot je camera nodig om een barcode te kunnen scannen.',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _permanentlyDenied ? openAppSettings : _checkCameraPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: _onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _permanentlyDenied ? 'Open instellingen' : 'Toestemming geven',
                    style: GoogleFonts.openSans(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Sluiten', style: GoogleFonts.openSans(color: _onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _primary, size: 48),
              const SizedBox(height: 16),
              Text(
                'Camera kon niet starten',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                error.errorDetails?.message ?? error.errorCode.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _background.withOpacity(0.7),
              border: Border.all(color: _primary.withOpacity(0.4)),
            ),
            child: const Icon(Icons.qr_code_scanner, color: _primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Bier scannen',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Richt de camera op de barcode van het flesje of blikje.',
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: _primary, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Generieke resultaat-bottomsheet (gebruikt voor het "geen bier"-scenario).
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: _primary.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: _primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(primaryLabel, style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottomsheet die getoond wordt zodra een bekend bier gescand is: toont het
/// bier en, als het loggen lukte, de bijgewerkte paspoort-stats en eventuele
/// nieuw vrijgespeelde badges.
class _BeerFoundSheet extends StatelessWidget {
  const _BeerFoundSheet({
    required this.beer,
    required this.result,
    required this.error,
    required this.loggedIn,
  });

  final Beer beer;
  final BeerScanLogResult? result;
  final String? error;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (beer.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(beer.imageUrl!, width: 64, height: 64, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: _primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.sports_bar_outlined, color: _primary),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beer.name,
                        style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${beer.style} • ${beer.abv}',
                        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!loggedIn)
              _statusBanner(
                icon: Icons.info_outline,
                text: 'Log in om dit bier in je Bier-paspoort te loggen.',
              )
            else if (error != null)
              _statusBanner(icon: Icons.error_outline, text: error!)
            else if (result != null) ...[
              _statusBanner(
                icon: Icons.check_circle_outline,
                text: 'Gelogd! Je hebt nu ${result!.beersTasted} bieren geproefd.',
                color: Colors.greenAccent.shade400,
              ),
              if (result!.currentStreak > 0) ...[
                const SizedBox(height: 12),
                _statusBanner(
                  icon: Icons.local_fire_department_outlined,
                  text: 'Bier Streak: ${result!.currentStreak} dag${result!.currentStreak == 1 ? '' : 'en'} op rij!',
                  color: Colors.orangeAccent,
                ),
              ],
              if (result!.newlyEarnedBadgeIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                _statusBanner(
                  icon: Icons.military_tech_outlined,
                  text: 'Nieuwe badge${result!.newlyEarnedBadgeIds.length > 1 ? 's' : ''} vrijgespeeld!',
                  color: _primary,
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Sluiten', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner({required IconData icon, required String text, Color? color}) {
    final c = color ?? _onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13))),
        ],
      ),
    );
  }
}
