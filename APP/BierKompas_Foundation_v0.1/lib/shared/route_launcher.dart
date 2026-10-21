import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opent de routebeschrijving naar een plek: op iOS in Apple Maps, op Android
/// en web in Google Maps. Zonder coördinaten wordt naar [address] genavigeerd.
Future<void> openRoute({double? latitude, double? longitude, String? address}) async {
  final String destination;
  if (latitude != null && longitude != null) {
    destination = '$latitude,$longitude';
  } else if (address != null && address.trim().isNotEmpty) {
    destination = Uri.encodeComponent(address.trim());
  } else {
    return;
  }

  final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final uri = Uri.parse(isIos
      ? 'https://maps.apple.com/?daddr=$destination'
      : 'https://www.google.com/maps/dir/?api=1&destination=$destination');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Omlijnde "Route"-knop over de volle breedte, zoals in de detail-sheets.
class RouteButton extends StatelessWidget {
  const RouteButton({super.key, this.latitude, this.longitude, this.address, this.color = const Color(0xFFD4B28C)});

  final double? latitude;
  final double? longitude;
  final String? address;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => openRoute(latitude: latitude, longitude: longitude, address: address),
        icon: Icon(Icons.directions, color: color, size: 18),
        label: Text('Route', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
