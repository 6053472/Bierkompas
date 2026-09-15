import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodeert een geplukte foto en zet 'm om naar JPEG, zodat de app altijd
/// een universeel ondersteund formaat uploadt. Sommige galerij-apps (bijv.
/// Google Foto's) leveren WebP met een ingebed ICC-kleurprofiel dat
/// Flutter's beeld-decoder soms niet kan tekenen, waardoor de foto leeg/
/// zwart blijft in plaats van te tonen.
Uint8List normalizeToJpeg(Uint8List bytes, {int quality = 85}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
}
