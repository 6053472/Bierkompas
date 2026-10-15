import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_comments_service.dart';
import 'feed_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

Future<void> showFeedCommentsSheet(BuildContext context, {required int feedItemId, required FeedItemType itemType}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _FeedCommentsSheet(feedItemId: feedItemId, itemType: itemType),
  );
}

class _FeedCommentsSheet extends StatefulWidget {
  final int feedItemId;
  final FeedItemType itemType;

  const _FeedCommentsSheet({required this.feedItemId, required this.itemType});

  @override
  State<_FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<_FeedCommentsSheet> {
  final _service = FeedCommentsService();
  final _bodyController = TextEditingController();
  late Future<List<FeedComment>> _future;
  int _rating = 0;
  bool _sending = false;

  // Alleen bij een mini-review (proeverij) heeft een beoordeling erbij geven zin.
  bool get _canRate => widget.itemType == FeedItemType.review;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchComments(widget.feedItemId);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = _service.fetchComments(widget.feedItemId));
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.postComment(
        feedItemId: widget.feedItemId,
        body: body,
        rating: _canRate && _rating > 0 ? _rating.toDouble() : null,
      );
      _bodyController.clear();
      setState(() => _rating = 0);
      await _reload();
    } on FeedCommentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reactie plaatsen mislukt: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _outlineVariant, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 16),
              Text(
                _canRate ? 'Reacties & proefnotities' : 'Reacties',
                style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<List<FeedComment>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: _primary)),
                      );
                    }
                    final comments = snapshot.data ?? const [];
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _canRate
                              ? 'Nog geen reacties. Laat als eerste een proefnotitie achter!'
                              : 'Nog geen reacties.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(color: _onSurfaceVariant),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildComment(comments[index], myUserId),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_canRate) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      onPressed: () => setState(() => _rating = _rating == starIndex ? 0 : starIndex),
                      icon: Icon(
                        starIndex <= _rating ? Icons.star : Icons.star_border,
                        color: _primary,
                        size: 24,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _outlineVariant),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _bodyController,
                        style: GoogleFonts.openSans(color: _onSurface, fontSize: 14),
                        cursorColor: _primary,
                        decoration: InputDecoration(
                          hintText: _canRate ? 'Schrijf je proefnotitie...' : 'Schrijf een reactie...',
                          hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                        : const Icon(Icons.send, color: _primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComment(FeedComment comment, String? myUserId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _cardColor,
          backgroundImage: comment.avatarUrl != null ? NetworkImage(comment.avatarUrl!) : null,
          child: comment.avatarUrl == null ? const Icon(Icons.person, color: _onSurfaceVariant, size: 16) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment.author, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (comment.rating != null) ...[
                    const SizedBox(width: 8),
                    for (var i = 1; i <= 5; i++)
                      Icon(i <= comment.rating! ? Icons.star : Icons.star_border, color: _primary, size: 12),
                  ],
                  if (comment.userId != null && comment.userId == myUserId) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await _service.deleteComment(comment.id);
                        await _reload();
                      },
                      child: const Icon(Icons.delete_outline, color: _onSurfaceVariant, size: 16),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(comment.body, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
