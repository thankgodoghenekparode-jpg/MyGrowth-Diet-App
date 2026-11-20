import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_back_button.dart';
import 'epub_book.dart';

/// Reads an EPUB by parsing the archive and rendering its chapters as text.
///
/// The WebView-based epub.js viewer shows a blank page for the programme's
/// EPUB 3 books on the web, so this reader keeps the content visible on every
/// platform without an iframe or remote script.
class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({
    super.key,
    required this.title,
    required this.url,
    this.epubBytes,
  });

  final String title;
  final String url;

  /// Optional preloaded bytes, used by tests and by callers that already
  /// downloaded the book. When null the file is downloaded from [url].
  final Uint8List? epubBytes;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  EpubBook? _book;
  Object? _error;
  bool _loading = true;
  int _chapterIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Uint8List bytes;
      if (widget.epubBytes != null) {
        bytes = widget.epubBytes!;
      } else {
        final uri = Uri.parse(widget.url);
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('Download failed (HTTP ${response.statusCode})');
        }
        bytes = response.bodyBytes;
      }
      final book = parseEpub(bytes);
      if (!mounted) return;
      setState(() {
        _book = book;
        _chapterIndex = 0;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _showChapter(int index) {
    final book = _book;
    if (book == null) return;
    if (index < 0 || index >= book.chapters.length) return;
    setState(() => _chapterIndex = index);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    Navigator.of(context).maybePop();
  }

  void _openTableOfContents() {
    final book = _book;
    if (book == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Contents',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: book.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = book.chapters[index];
                    final selected = index == _chapterIndex;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: selected
                            ? AppColors.navy700
                            : AppColors.surfaceMuted,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        chapter.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: selected,
                      onTap: () => _showChapter(index),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = _book;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (book != null)
            IconButton(
              tooltip: 'Contents',
              icon: const Icon(Icons.list_rounded),
              onPressed: _openTableOfContents,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || book == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'This book could not be opened. Check your internet '
                      'connection and try again.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildBook(theme, book),
    );
  }

  Widget _buildBook(ThemeData theme, EpubBook book) {
    final chapter = book.chapters[_chapterIndex];
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(chapter.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              for (final paragraph in chapter.paragraphs) ...[
                SelectableText(
                  paragraph,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: Divider.createBorderSide(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous chapter',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _chapterIndex > 0
                        ? () => _showChapter(_chapterIndex - 1)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      '${_chapterIndex + 1} / ${book.chapters.length}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next chapter',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _chapterIndex < book.chapters.length - 1
                        ? () => _showChapter(_chapterIndex + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
