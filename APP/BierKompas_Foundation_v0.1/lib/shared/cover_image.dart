import 'package:flutter/material.dart';

/// Cover van een nummer of boek: een meegeleverde afbeelding (asset) of, voor
/// door een beheerder toegevoegde items, een afbeeldings-URL.
class CoverImage extends StatelessWidget {
  final String asset;
  final String? url;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit fit;

  const CoverImage({
    super.key,
    required this.asset,
    this.url,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final networkUrl = url;
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: const Color(0xFF2C221C),
        child: const Icon(Icons.image_outlined, color: Color(0xFF9E8A7D)),
      );
}
