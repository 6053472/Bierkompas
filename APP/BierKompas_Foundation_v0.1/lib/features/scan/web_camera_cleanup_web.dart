import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Work-around voor een bug in mobile_scanner op web: de "polling"-scanner
/// (gebruikt in browsers zonder native BarcodeDetector-API, o.a. de meeste
/// desktopbrowsers) zet bij het stoppen alleen de eigen Dart-referentie naar
/// de MediaStream op null, zonder ooit `track.stop()` aan te roepen. Daardoor
/// blijft het cameralampje van de browser aan staan nadat je de scanpagina
/// verlaat. Dit stopt elke camera-track die nog aan een <video>-element in de
/// pagina hangt, ongeacht welke interne reader mobile_scanner gebruikte.
void stopAllCameraStreams() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final element = videos.item(i);
    if (element == null) continue;
    final video = element as web.HTMLVideoElement;
    final stream = video.srcObject;
    if (stream == null) continue;
    for (final track in (stream as web.MediaStream).getTracks().toDart) {
      track.stop();
    }
    video.srcObject = null;
  }
}
