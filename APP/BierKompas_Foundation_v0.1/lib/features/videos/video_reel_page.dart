import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'video_player_page.dart';
import 'video_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);

/// "Brouwerij Highlights": korte video's van brouwerijen, tours en proeverijen.
/// Zie bierkompas paginas/brouwerij_highlights_reels voor het ontwerp.
/// Beheerders voegen video's toe via de admin-pagina (supabase/add_videos.sql);
/// zolang die leeg is toont de app een lege staat, geen verzonnen content.
class VideoReelPage extends StatefulWidget {
  const VideoReelPage({super.key});

  @override
  State<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends State<VideoReelPage> {
  final _service = VideoService();
  late Future<List<BierVideo>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _onSurface,
        iconTheme: const IconThemeData(color: _onSurface),
        elevation: 0,
        title: Text('Brouwerij Highlights', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<BierVideo>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Kon video\'s niet laden: ${snapshot.error}',
                    style: GoogleFonts.openSans(color: _onSurfaceVariant)),
              );
            }
            final videos = snapshot.data ?? const [];
            if (videos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, color: _onSurfaceVariant.withOpacity(0.5), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Er zijn nog geen video\'s toegevoegd.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(color: _onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) => _VideoTile(video: videos[index]),
            );
          },
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final BierVideo video;

  const _VideoTile({required this.video});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerPage(video: video)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              video.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _cardColor),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(video.category,
                    style: GoogleFonts.openSans(color: _onSurface, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
