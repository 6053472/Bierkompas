import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _background = Color(0xFF1E1712);
const _primary = Color(0xFFD4B28C);
const _card = Color(0xFF2C221C);
const _text = Color(0xFFEFE6DD);
const _secondary = Color(0xFF9E8A7D);
const _border = Color(0xFF46372D);

class NewsArticlePage extends StatefulWidget {
  const NewsArticlePage({super.key});

  @override
  State<NewsArticlePage> createState() => _NewsArticlePageState();
}

class _NewsArticlePageState extends State<NewsArticlePage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _supabase
          .from('news_articles')
          .select()
          .eq('status', 'gepubliceerd')
          .order('gepubliceerd_op', ascending: false);

      if (!mounted) return;

      setState(() {
        _articles = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openArticle(Map<String, dynamic> article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NewsDetailPage(article: article),
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';

    final date = DateTime.tryParse(value);
    if (date == null) return '';

    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        title: Text(
          'Nieuws',
          style: GoogleFonts.playfairDisplay(
            color: _text,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primary,
        backgroundColor: _card,
        onRefresh: _loadNews,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Nieuws kon niet worden geladen.',
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(
              color: _text,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(
              color: _secondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: _loadNews,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
              ),
              child: const Text('Opnieuw proberen'),
            ),
          ),
        ],
      );
    }

    if (_articles.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.newspaper_outlined,
            color: _secondary,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'Nog geen nieuws',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: _text,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nieuwe bierberichten verschijnen hier zodra ze gepubliceerd zijn.',
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(
              color: _secondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    final featured = _articles.first;
    final rest = _articles.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        Text(
          'NIEUWS VAN DE DAG',
          style: GoogleFonts.openSans(
            color: _primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeaturedCard(featured),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            'MEER NIEUWS',
            style: GoogleFonts.openSans(
              color: _primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          ...rest.map(_buildNewsCard),
        ],
      ],
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> article) {
    final image = article['foto_url'] as String?;

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              Image.network(
                image,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imagePlaceholder(),
              )
            else
              _imagePlaceholder(height: 210),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(article['gepubliceerd_op']),
                    style: GoogleFonts.openSans(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article['titel'] ?? '',
                    style: GoogleFonts.playfairDisplay(
                      color: _text,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article['samenvatting'] ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.openSans(
                      color: _secondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Lees het volledige artikel',
                        style: GoogleFonts.openSans(
                          color: _primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward,
                        color: _primary,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> article) {
    final image = article['foto_url'] as String?;

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              Image.network(
                image,
                width: 115,
                height: 135,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imagePlaceholder(
                  width: 115,
                  height: 135,
                ),
              )
            else
              _imagePlaceholder(
                width: 115,
                height: 135,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(article['gepubliceerd_op']),
                      style: GoogleFonts.openSans(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['titel'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['samenvatting'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.openSans(
                        color: _secondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder({
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height ?? 180,
      color: _surfaceColor,
      child: const Center(
        child: Icon(
          Icons.newspaper_outlined,
          color: _secondary,
          size: 38,
        ),
      ),
    );
  }

  Color get _surfaceColor => const Color(0xFF3C3028);
}

class _NewsDetailPage extends StatelessWidget {
  final Map<String, dynamic> article;

  const _NewsDetailPage({
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    final image = article['foto_url'] as String?;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  image,
                  width: double.infinity,
                  height: 230,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'BIERNIEUWS',
              style: GoogleFonts.openSans(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article['titel'] ?? '',
              style: GoogleFonts.playfairDisplay(
                color: _text,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              article['gepubliceerd_op'] ?? '',
              style: GoogleFonts.openSans(
                color: _secondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              article['samenvatting'] ?? '',
              style: GoogleFonts.openSans(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              article['inhoud'] ?? '',
              style: GoogleFonts.openSans(
                color: _secondary,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}