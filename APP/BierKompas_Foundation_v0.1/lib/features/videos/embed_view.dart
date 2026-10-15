// Toont een officiële embed-pagina (TikTok/Instagram) in een iframe (web) of
// WebView (Android/iOS). Welke variant wordt gebruikt hangt af van het platform.
export 'embed_view_mobile.dart' if (dart.library.js_interop) 'embed_view_web.dart';
