import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'embed_view.dart';
import 'video_service.dart';

const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);

/// "SchuimKraag TV" (voorheen "Brouwerij Highlights") als verticale reel: omhoog/omlaag swipen naar de
/// volgende video, met nieuwe video's die in blokken bijgeladen worden zodra je
/// bijna onderaan bent. Eigen video's worden native afgespeeld en de volgende
/// video wordt alvast voorbereid; YouTube, TikTok en Instagram gaan via de
/// officiële embed-spelers. Zie bierkompas paginas/brouwerij_highlights_reels
/// voor het ontwerp.
class VideoReelPage extends StatefulWidget {
  const VideoReelPage({super.key});

  @override
  State<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends State<VideoReelPage> {
  final _service = VideoService();
  final _pageController = PageController();
  final List<BierVideo> _videos = [];
  // Voorbereide spelers voor eigen video's: de huidige en de buren.
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _failed = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _muted = false;
  String? _error;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    try {
      final page = await _service.fetchPage(0);
      if (!mounted) return;
      setState(() {
        _videos.addAll(page);
        _hasMore = page.length == VideoService.pageSize;
        _loading = false;
        _syncControllers();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final page = await _service.fetchPage(_videos.length);
      if (!mounted) return;
      setState(() {
        _videos.addAll(page);
        _hasMore = page.length == VideoService.pageSize;
        _syncControllers();
      });
    } catch (_) {
      // Bijladen mislukt: de reel blijft gewoon werken met wat er al is.
    } finally {
      _loadingMore = false;
    }
  }

  /// Houdt voor eigen video's alleen de huidige en de twee buren klaar (snel
  /// starten bij swipen, zonder het geheugen vol te zetten), en laat alleen de
  /// huidige afspelen.
  void _syncControllers() {
    final wanted = <int>{
      for (var i = _current - 1; i <= _current + 1; i++)
        if (i >= 0 && i < _videos.length && _videos[i].isHosted) i,
    };

    for (final index in _controllers.keys.toList()) {
      if (!wanted.contains(index)) {
        final old = _controllers.remove(index)!;
        // Pas na dit beeld weggooien, zodat de speler niet meer getekend wordt.
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    }

    for (final index in wanted) {
      if (_controllers.containsKey(index)) continue;
      final url = _videos[index].videoUrl;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        formatHint: url.toLowerCase().contains('.m3u8') ? VideoFormat.hls : null,
      );
      _controllers[index] = controller;
      controller.setLooping(true);
      controller.initialize().then((_) {
        if (!mounted || _controllers[index] != controller) return;
        controller.setVolume(_muted ? 0 : 1);
        if (index == _current) controller.play();
        setState(() {});
      }).catchError((_) {
        if (mounted && _controllers[index] == controller) setState(() => _failed.add(index));
      });
    }

    _controllers.forEach((index, controller) {
      if (!controller.value.isInitialized) return;
      if (index == _current) {
        controller.play();
      } else {
        controller.pause();
        controller.seekTo(Duration.zero);
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _current = index;
      _syncControllers();
    });
    if (index >= _videos.length - 3) _loadMore();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized) controller.setVolume(_muted ? 0 : 1);
    }
  }

  void _go(int delta) {
    final target = _current + delta;
    if (target < 0 || target >= _videos.length) return;
    _pageController.animateToPage(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null) {
      return _centered(Icons.error_outline, 'Kon de video\'s niet laden: $_error');
    }
    if (_videos.isEmpty) {
      return _centered(Icons.play_circle_outline, 'Er zijn nog geen video\'s toegevoegd.');
    }

    return Stack(
      children: [
        ScrollConfiguration(
          // Ook met de muis (web/desktop) te slepen, niet alleen met een vinger.
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
          ),
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: _videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _ReelPage(
              video: _videos[index],
              isActive: index == _current,
              muted: _muted,
              controller: _controllers[index],
              failed: _failed.contains(index),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.topLeft,
              child: _RoundButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).maybePop()),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundButton(icon: Icons.keyboard_arrow_up, onTap: _current > 0 ? () => _go(-1) : null),
                  const SizedBox(height: 10),
                  if (_videos[_current].source == VideoSource.hosted || _videos[_current].source == VideoSource.youtube) ...[
                    _RoundButton(icon: _muted ? Icons.volume_off : Icons.volume_up, onTap: _toggleMute),
                    const SizedBox(height: 10),
                  ],
                  _RoundButton(icon: Icons.keyboard_arrow_down, onTap: _current < _videos.length - 1 ? () => _go(1) : null),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _centered(IconData icon, String message) {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _onSurfaceVariant.withOpacity(0.6), size: 48),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: GoogleFonts.openSans(color: _onSurfaceVariant)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _RoundButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).maybePop()),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: Colors.black.withOpacity(onTap == null ? 0.25 : 0.55), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white.withOpacity(onTap == null ? 0.35 : 1), size: 24),
      ),
    );
  }
}

/// Eén video op volledig scherm, met titel en categorie eronder.
class _ReelPage extends StatelessWidget {
  final BierVideo video;
  final bool isActive;
  final bool muted;
  final VideoPlayerController? controller;
  final bool failed;

  const _ReelPage({
    required this.video,
    required this.isActive,
    required this.muted,
    required this.controller,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPlayer(),
        // Verloop onderaan zodat de tekst leesbaar blijft.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 72,
          bottom: 28,
          child: IgnorePointer(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _cardColor.withOpacity(0.85), borderRadius: BorderRadius.circular(999)),
                    child: Text(video.category,
                        style: GoogleFonts.openSans(color: _primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    switch (video.source) {
      case VideoSource.hosted:
        return _HostedPlayer(video: video, controller: controller, failed: failed);
      case VideoSource.youtube:
        return _YoutubePlayerPage(video: video, isActive: isActive, muted: muted);
      case VideoSource.tiktok:
      case VideoSource.instagram:
        return _EmbedPlayerPage(video: video, isActive: isActive);
    }
  }
}

Widget _previewBackground(BierVideo video) {
  final image = video.previewImage;
  if (image == null) return Container(color: const Color(0xFF16100D));
  return Image.network(
    image,
    fit: BoxFit.cover,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF16100D)),
  );
}

/// Eigen video, native afgespeeld. Tik om te pauzeren/hervatten.
class _HostedPlayer extends StatelessWidget {
  final BierVideo video;
  final VideoPlayerController? controller;
  final bool failed;

  const _HostedPlayer({required this.video, required this.controller, required this.failed});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (failed) {
      return Stack(fit: StackFit.expand, children: [
        _previewBackground(video),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Deze video kan op dit apparaat niet worden afgespeeld.',
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(color: _onSurface, fontSize: 13),
            ),
          ),
        ),
      ]);
    }
    if (c == null || !c.value.isInitialized) {
      return Stack(fit: StackFit.expand, children: [
        _previewBackground(video),
        const Center(child: CircularProgressIndicator(color: _primary)),
      ]);
    }

    final size = c.value.size;
    final landscape = size.width > size.height;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => c.value.isPlaying ? c.pause() : c.play(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          ClipRect(
            child: FittedBox(
              fit: landscape ? BoxFit.contain : BoxFit.cover,
              child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(c)),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (_, value, __) => value.isPlaying
                ? const SizedBox.shrink()
                : Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 44),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// YouTube via de officiële IFrame Player API. De speler wordt alleen gemaakt
/// zolang de video in beeld is; daarbuiten staat alleen de thumbnail.
class _YoutubePlayerPage extends StatefulWidget {
  final BierVideo video;
  final bool isActive;
  final bool muted;

  const _YoutubePlayerPage({required this.video, required this.isActive, required this.muted});

  @override
  State<_YoutubePlayerPage> createState() => _YoutubePlayerPageState();
}

class _YoutubePlayerPageState extends State<_YoutubePlayerPage> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _createController();
  }

  @override
  void didUpdateWidget(covariant _YoutubePlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && _controller == null) {
      _createController();
    } else if (!widget.isActive && _controller != null) {
      _controller!.close();
      _controller = null;
    } else if (_controller != null && widget.muted != oldWidget.muted) {
      widget.muted ? _controller!.mute() : _controller!.unMute();
    }
  }

  void _createController() {
    final id = widget.video.externalId;
    if (id == null || id.isEmpty) return;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: YoutubePlayerParams(
        showFullscreenButton: false,
        loop: true,
        mute: widget.muted,
        playsInline: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Stack(fit: StackFit.expand, children: [
        _previewBackground(widget.video),
        const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 56)),
      ]);
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
    );
  }
}

/// TikTok en Instagram via hun officiële embed-pagina. Net als bij YouTube
/// bestaat de embed alleen zolang de video in beeld is.
class _EmbedPlayerPage extends StatelessWidget {
  final BierVideo video;
  final bool isActive;

  const _EmbedPlayerPage({required this.video, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final url = video.embedUrl;
    if (isActive && url != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.only(top: 56, bottom: 96, left: 12, right: 64),
        child: EmbedView(url: url),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      _previewBackground(video),
      Center(
        child: Icon(
          video.source == VideoSource.tiktok ? Icons.music_note : Icons.camera_alt_outlined,
          color: Colors.white70,
          size: 48,
        ),
      ),
    ]);
  }
}
