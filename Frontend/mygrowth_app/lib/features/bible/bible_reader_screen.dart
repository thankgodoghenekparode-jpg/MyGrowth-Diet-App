import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum _BibleView { reader, search, bookmarks }

class _BibleBook {
  const _BibleBook({
    required this.code,
    required this.name,
    required this.chapters,
  });

  final String code;
  final String name;
  final List<List<String?>> chapters;

  factory _BibleBook.fromJson(Map<String, dynamic> json) => _BibleBook(
    code: json['code'] as String,
    name: json['name'] as String,
    chapters: (json['chapters'] as List<dynamic>)
        .map(
          (chapter) => (chapter as List<dynamic>)
              .map((verse) => verse as String?)
              .toList(growable: false),
        )
        .toList(growable: false),
  );
}

class _BibleTranslation {
  const _BibleTranslation({
    required this.id,
    required this.name,
    required this.file,
    required this.credit,
  });

  final String id;
  final String name;
  final String file;
  final String credit;
}

const _bibleTranslations = [
  _BibleTranslation(
    id: 'KJV',
    name: 'King James Version',
    file: 'kjv.json',
    credit: 'KJV - Public domain',
  ),
  _BibleTranslation(
    id: 'NLT',
    name: 'New Living Translation',
    file: 'nlt.json',
    credit: 'NLT - New Living Translation',
  ),
  _BibleTranslation(
    id: 'AMP',
    name: 'Amplified Bible Classic',
    file: 'amp.json',
    credit: 'AMP - Amplified Bible Classic Edition',
  ),
  _BibleTranslation(
    id: 'TPT',
    name: 'The Passion Translation',
    file: 'tpt.json',
    credit: 'TPT - The Passion Translation',
  ),
  _BibleTranslation(
    id: 'WEB',
    name: 'World English Bible',
    file: 'web.json',
    credit: 'WEB - Public domain',
  ),
  _BibleTranslation(
    id: 'BSB',
    name: 'Berean Standard Bible',
    file: 'bsb.json',
    credit: 'BSB - Public domain',
  ),
];

class _BibleSession {
  const _BibleSession({
    required this.translation,
    required this.books,
    required this.preferences,
    required this.bookmarks,
    required this.lastReadKey,
    required this.bookmarksKey,
    required this.bookIndex,
    required this.chapterIndex,
  });

  final _BibleTranslation translation;
  final List<_BibleBook> books;
  final SharedPreferences preferences;
  final Set<String> bookmarks;
  final String lastReadKey;
  final String bookmarksKey;
  final int bookIndex;
  final int chapterIndex;
}

class _VerseHit {
  const _VerseHit({
    required this.bookIndex,
    required this.chapterIndex,
    required this.verseNumber,
    required this.text,
  });

  final int bookIndex;
  final int chapterIndex;
  final int verseNumber;
  final String text;

  String reference(List<_BibleBook> books) =>
      '${books[bookIndex].name} ${chapterIndex + 1}:$verseNumber';

  String get key => '${bookIndex}_${chapterIndex}_$verseNumber';
}

/// Offline Bible reader with selectable WEB, BSB, and KJV translations.
class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  static const _translationKey = 'mgdp.bible.translation';
  static const _pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 12);

  late Future<_BibleSession> _session;
  final _searchController = TextEditingController();
  final _verseScrollController = ScrollController();
  Timer? _searchDebounce;

  _BibleView _view = _BibleView.reader;
  int _bookIndex = 0;
  int _chapterIndex = 0;
  String _searchQuery = '';
  List<_VerseHit> _searchHits = const [];
  String? _highlightedVerse;

  @override
  void initState() {
    super.initState();
    _session = _loadSession();
  }

  Future<_BibleSession> _loadSession([String? requestedTranslation]) async {
    final preferences = await SharedPreferences.getInstance();
    final storedId =
        requestedTranslation ?? preferences.getString(_translationKey) ?? 'WEB';
    final translation = _bibleTranslations.firstWhere(
      (item) => item.id == storedId,
      orElse: () => _bibleTranslations.first,
    );
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/bible/${translation.file}'),
    ) as Map<String, dynamic>;
    final books = (decoded['books'] as List<dynamic>)
        .map((book) => _BibleBook.fromJson(book as Map<String, dynamic>))
        .toList(growable: false);
    final lastReadKey = 'mgdp.bible.${translation.id}.lastRead';
    final bookmarksKey = 'mgdp.bible.${translation.id}.bookmarks';
    final oldWebLastRead = translation.id == 'WEB'
        ? preferences.getString('mgdp.bible.lastRead')
        : null;
    final oldWebBookmarks = translation.id == 'WEB'
        ? preferences.getStringList('mgdp.bible.bookmarks')
        : null;
    final lastRead =
        (preferences.getString(lastReadKey) ?? oldWebLastRead)?.split('|') ??
        [];
    var bookIndex = books.indexWhere(
      (book) => book.code == (lastRead.isEmpty ? null : lastRead[0]),
    );
    if (bookIndex < 0) bookIndex = 0;
    var chapterIndex =
        int.tryParse(lastRead.length > 1 ? lastRead[1] : '') ?? 1;
    chapterIndex = (chapterIndex - 1)
        .clamp(0, books[bookIndex].chapters.length - 1)
        .toInt();
    return _BibleSession(
      translation: translation,
      books: books,
      preferences: preferences,
      bookmarks:
          (preferences.getStringList(bookmarksKey) ?? oldWebBookmarks)
              ?.toSet() ??
          {},
      lastReadKey: lastReadKey,
      bookmarksKey: bookmarksKey,
      bookIndex: bookIndex,
      chapterIndex: chapterIndex,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _verseScrollController.dispose();
    super.dispose();
  }

  void _selectLocation(_BibleSession session, int bookIndex, int chapterIndex) {
    setState(() {
      _bookIndex = bookIndex;
      _chapterIndex = chapterIndex;
      _view = _BibleView.reader;
      _highlightedVerse = null;
    });
    if (_verseScrollController.hasClients) {
      _verseScrollController.jumpTo(0);
    }
    final book = session.books[bookIndex];
    session.preferences.setString(
      session.lastReadKey,
      '${book.code}|${chapterIndex + 1}',
    );
  }

  void _selectTranslation(_BibleSession session, String translationId) {
    if (translationId == session.translation.id) return;
    unawaited(session.preferences.setString(_translationKey, translationId));
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_verseScrollController.hasClients) _verseScrollController.jumpTo(0);
    setState(() {
      _bookIndex = 0;
      _chapterIndex = 0;
      _view = _BibleView.reader;
      _searchQuery = '';
      _searchHits = const [];
      _highlightedVerse = null;
      _session = _loadSession(translationId);
    });
  }

  void _changeChapter(_BibleSession session, int change) {
    var bookIndex = _bookIndex;
    var chapterIndex = _chapterIndex + change;
    if (chapterIndex < 0 && bookIndex > 0) {
      bookIndex -= 1;
      chapterIndex = session.books[bookIndex].chapters.length - 1;
    } else if (chapterIndex >= session.books[bookIndex].chapters.length &&
        bookIndex < session.books.length - 1) {
      bookIndex += 1;
      chapterIndex = 0;
    }
    if (chapterIndex < 0 ||
        chapterIndex >= session.books[bookIndex].chapters.length) {
      return;
    }
    _selectLocation(session, bookIndex, chapterIndex);
  }

  Future<void> _chooseChapter(
    BuildContext context,
    _BibleSession session,
  ) async {
    final chapters = session.books[_bookIndex].chapters.length;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Choose a chapter',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: chapters,
                  itemBuilder: (context, index) => OutlinedButton(
                    onPressed: () => Navigator.pop(context, index),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: index == _chapterIndex
                          ? AppColors.brandSurface
                          : null,
                      foregroundColor: index == _chapterIndex
                          ? Colors.white
                          : AppColors.brandText,
                    ),
                    child: Text('${index + 1}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      _selectLocation(session, _bookIndex, picked);
    }
  }

  void _setSearchQuery(String value, _BibleSession session) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final query = value.trim().toLowerCase();
      final hits = <_VerseHit>[];
      if (query.length >= 2) {
        for (
          var bookIndex = 0;
          bookIndex < session.books.length && hits.length < 100;
          bookIndex++
        ) {
          final book = session.books[bookIndex];
          for (
            var chapterIndex = 0;
            chapterIndex < book.chapters.length && hits.length < 100;
            chapterIndex++
          ) {
            final verses = book.chapters[chapterIndex];
            for (
              var verseIndex = 0;
              verseIndex < verses.length && hits.length < 100;
              verseIndex++
            ) {
              final verse = verses[verseIndex];
              if (verse != null && verse.toLowerCase().contains(query)) {
                hits.add(
                  _VerseHit(
                    bookIndex: bookIndex,
                    chapterIndex: chapterIndex,
                    verseNumber: verseIndex + 1,
                    text: verse,
                  ),
                );
              }
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _searchQuery = query;
          _searchHits = hits;
        });
      }
    });
  }

  List<_VerseHit> _bookmarkedHits(_BibleSession session) {
    final hits = <_VerseHit>[];
    for (var bookIndex = 0; bookIndex < session.books.length; bookIndex++) {
      final book = session.books[bookIndex];
      for (
        var chapterIndex = 0;
        chapterIndex < book.chapters.length;
        chapterIndex++
      ) {
        final verses = book.chapters[chapterIndex];
        for (var verseIndex = 0; verseIndex < verses.length; verseIndex++) {
          final text = verses[verseIndex];
          final hit = _VerseHit(
            bookIndex: bookIndex,
            chapterIndex: chapterIndex,
            verseNumber: verseIndex + 1,
            text: text ?? '',
          );
          if (text != null && session.bookmarks.contains(hit.key)) {
            hits.add(hit);
          }
        }
      }
    }
    return hits;
  }

  void _openHit(_BibleSession session, _VerseHit hit) {
    _selectLocation(session, hit.bookIndex, hit.chapterIndex);
    setState(() => _highlightedVerse = hit.key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_verseScrollController.hasClients) return;
      final roughOffset = ((hit.verseNumber - 1) * 70.0).clamp(
        0.0,
        _verseScrollController.position.maxScrollExtent,
      );
      _verseScrollController.jumpTo(roughOffset);
    });
    Future<void>.delayed(const Duration(seconds: 2)).then((_) {
      if (mounted && _highlightedVerse == hit.key) {
        setState(() => _highlightedVerse = null);
      }
    });
  }

  Future<void> _toggleBookmark(_BibleSession session, _VerseHit hit) async {
    setState(() {
      if (!session.bookmarks.add(hit.key)) session.bookmarks.remove(hit.key);
    });
    await session.preferences.setStringList(
      session.bookmarksKey,
      session.bookmarks.toList()..sort(),
    );
  }

  Future<void> _copyVerse(_BibleSession session, _VerseHit hit) async {
    final reference = hit.reference(session.books);
    final text = '$reference (${session.translation.id})\n${hit.text}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $reference'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyChapter(_BibleSession session) async {
    final book = session.books[_bookIndex];
    final verses = book.chapters[_chapterIndex];
    final buffer = StringBuffer('${book.name} ${_chapterIndex + 1} (${session.translation.id})\n\n');
    for (var i = 0; i < verses.length; i++) {
      final text = verses[i];
      if (text != null) {
        buffer.writeln('${i + 1}. $text');
        buffer.writeln();
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied chapter'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAudioBible(_BibleSession session) async {
    final book = session.books[_bookIndex];
    final chapter = _chapterIndex + 1;
    // Use BibleGateway audio or YouVersion style links as fallback
    final uri = Uri.parse('https://www.biblegateway.com/audio/mclean/kjv/${_getBibleGatewayBook(book.name)}/$chapter');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final uri2 = Uri.parse('https://www.bible.com/bible/1/${_getYouVersionBook(book.name)}.$chapter.KJV');
      if (await canLaunchUrl(uri2)) {
        await launchUrl(uri2, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _getBibleGatewayBook(String name) {
    final map = {
      'Genesis': 'Gen', 'Exodus': 'Exod', 'Leviticus': 'Lev', 'Numbers': 'Num',
      'Deuteronomy': 'Deut', 'Joshua': 'Josh', 'Judges': 'Judg', 'Ruth': 'Ruth',
      '1 Samuel': '1Sam', '2 Samuel': '2Sam', '1 Kings': '1Kgs', '2 Kings': '2Kgs',
      '1 Chronicles': '1Chr', '2 Chronicles': '2Chr', 'Ezra': 'Ezra', 'Nehemiah': 'Neh',
      'Esther': 'Est', 'Job': 'Job', 'Psalms': 'Ps', 'Proverbs': 'Prov',
      'Ecclesiastes': 'Eccl', 'Song of Solomon': 'Song', 'Isaiah': 'Isa', 'Jeremiah': 'Jer',
      'Lamentations': 'Lam', 'Ezekiel': 'Ezek', 'Daniel': 'Dan', 'Hosea': 'Hos',
      'Joel': 'Joel', 'Amos': 'Amos', 'Obadiah': 'Obad', 'Jonah': 'Jonah',
      'Micah': 'Mic', 'Nahum': 'Nah', 'Habakkuk': 'Hab', 'Zephaniah': 'Zeph',
      'Haggai': 'Hag', 'Zechariah': 'Zech', 'Malachi': 'Mal',
      'Matthew': 'Matt', 'Mark': 'Mark', 'Luke': 'Luke', 'John': 'John',
      'Acts': 'Acts', 'Romans': 'Rom', '1 Corinthians': '1Cor', '2 Corinthians': '2Cor',
      'Galatians': 'Gal', 'Ephesians': 'Eph', 'Philippians': 'Phil', 'Colossians': 'Col',
      '1 Thessalonians': '1Thess', '2 Thessalonians': '2Thess', '1 Timothy': '1Tim', '2 Timothy': '2Tim',
      'Titus': 'Titus', 'Philemon': 'Phlm', 'Hebrews': 'Heb', 'James': 'James',
      '1 Peter': '1Pet', '2 Peter': '2Pet', '1 John': '1John', '2 John': '2John',
      '3 John': '3John', 'Jude': 'Jude', 'Revelation': 'Rev',
    };
    return map[name] ?? name.replaceAll(' ', '');
  }

  String _getYouVersionBook(String name) {
    final map = {
      'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM',
      'Deuteronomy': 'DEU', 'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT',
      '1 Samuel': '1SA', '2 Samuel': '2SA', '1 Kings': '1KI', '2 Kings': '2KI',
      '1 Chronicles': '1CH', '2 Chronicles': '2CH', 'Ezra': 'EZR', 'Nehemiah': 'NEH',
      'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'PSA', 'Proverbs': 'PRO',
      'Ecclesiastes': 'ECC', 'Song of Solomon': 'SNG', 'Isaiah': 'ISA', 'Jeremiah': 'JER',
      'Lamentations': 'LAM', 'Ezekiel': 'EZK', 'Daniel': 'DAN', 'Hosea': 'HOS',
      'Joel': 'JOL', 'Amos': 'AMO', 'Obadiah': 'OBA', 'Jonah': 'JON',
      'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB', 'Zephaniah': 'ZEP',
      'Haggai': 'HAG', 'Zechariah': 'ZEC', 'Malachi': 'MAL',
      'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN',
      'Acts': 'ACT', 'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO',
      'Galatians': 'GAL', 'Ephesians': 'EPH', 'Philippians': 'PHP', 'Colossians': 'COL',
      '1 Thessalonians': '1TH', '2 Thessalonians': '2TH', '1 Timothy': '1TI', '2 Timothy': '2TI',
      'Titus': 'TIT', 'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS',
      '1 Peter': '1PE', '2 Peter': '2PE', '1 John': '1JN', '2 John': '2JN',
      '3 John': '3JN', 'Jude': 'JUD', 'Revelation': 'REV',
    };
    return map[name] ?? name.substring(0,3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BibleSession>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load the Bible: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final session = snapshot.data!;
        if (_bookIndex == 0 && _chapterIndex == 0) {
          _bookIndex = session.bookIndex;
          _chapterIndex = session.chapterIndex;
        }
        return Column(
          children: [
            _buildToolbar(context, session),
            if (_view == _BibleView.reader)
              _buildChapterHeading(context, session),
            const Divider(height: 1),
            Expanded(child: _buildContent(context, session)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                session.translation.credit,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, _BibleSession session) {
    if (_view == _BibleView.search) {
      return Padding(
        padding: _pagePadding,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => _setSearchQuery(value, session),
                decoration: InputDecoration(
                  hintText: 'Search verses',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      _setSearchQuery('', session);
                    },
                    icon: const Icon(Icons.clear),
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close search',
              onPressed: () {
                _searchDebounce?.cancel();
                _searchController.clear();
                setState(() {
                  _view = _BibleView.reader;
                  _searchQuery = '';
                  _searchHits = const [];
                });
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }
    if (_view == _BibleView.bookmarks) {
      return Padding(
        padding: _pagePadding,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to Bible',
              onPressed: () => setState(() => _view = _BibleView.reader),
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              'Bookmarked verses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: _pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: session.translation.id,
              isExpanded: true,
              items: [
                for (final translation in _bibleTranslations)
                  DropdownMenuItem(
                    value: translation.id,
                    child: Text(
                      '${translation.id} - ${translation.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) _selectTranslation(session, value);
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _bookIndex,
                    isExpanded: true,
                    items: [
                      for (var i = 0; i < session.books.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            session.books[i].name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _selectLocation(session, value, 0);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _chooseChapter(context, session),
                child: Text('${_chapterIndex + 1}'),
              ),
              IconButton(
                tooltip: 'Listen to Audio Bible',
                onPressed: () => _openAudioBible(session),
                icon: const Icon(Icons.volume_up_outlined),
              ),
              IconButton(
                tooltip: 'Search the Bible',
                onPressed: () => setState(() => _view = _BibleView.search),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Bookmarks',
                onPressed: () => setState(() => _view = _BibleView.bookmarks),
                icon: const Icon(Icons.bookmarks_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterHeading(BuildContext context, _BibleSession session) {
    final book = session.books[_bookIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous chapter',
            onPressed: () => _changeChapter(session, -1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '${book.name} ${_chapterIndex + 1}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Copy chapter',
            onPressed: () => _copyChapter(session),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Next chapter',
            onPressed: () => _changeChapter(session, 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, _BibleSession session) {
    if (_view == _BibleView.search) {
      if (_searchQuery.length < 2) {
        return const Center(
          child: Text('Enter at least two letters to search.'),
        );
      }
      return _buildHits(
        context,
        session,
        _searchHits,
        emptyMessage: 'No verses found for “$_searchQuery”.',
      );
    }
    if (_view == _BibleView.bookmarks) {
      return _buildHits(
        context,
        session,
        _bookmarkedHits(session),
        emptyMessage: 'Your saved verses will appear here.',
      );
    }

    final book = session.books[_bookIndex];
    final verses = book.chapters[_chapterIndex];
    final visibleVerses = <_VerseHit>[];
    for (var i = 0; i < verses.length; i++) {
      final text = verses[i];
      if (text != null) {
        visibleVerses.add(
          _VerseHit(
            bookIndex: _bookIndex,
            chapterIndex: _chapterIndex,
            verseNumber: i + 1,
            text: text,
          ),
        );
      }
    }
    return ListView.separated(
      controller: _verseScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: visibleVerses.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.55)),
      itemBuilder: (context, index) {
        final hit = visibleVerses[index];
        final isBookmarked = session.bookmarks.contains(hit.key);
        return Container(
          color: hit.key == _highlightedVerse
              ? AppColors.gold100
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${hit.verseNumber}  ',
                          style: TextStyle(
                            color: AppColors.gold600,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: hit.text,
                          style: TextStyle(
                            color: AppColors.ink,
                            height: 1.6,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy verse',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyVerse(session, hit),
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark verse',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleBookmark(session, hit),
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 19,
                      color: isBookmarked ? AppColors.gold600 : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHits(
    BuildContext context,
    _BibleSession session,
    List<_VerseHit> hits, {
    required String emptyMessage,
  }) {
    if (hits.isEmpty) return Center(child: Text(emptyMessage));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: hits.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final hit = hits[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          title: Text(
            hit.reference(session.books),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.brandText),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(hit.text, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          trailing: _view == _BibleView.bookmarks
              ? IconButton(
                  tooltip: 'Remove bookmark',
                  onPressed: () => _toggleBookmark(session, hit),
                  icon: const Icon(Icons.bookmark),
                )
              : null,
          onTap: () => _openHit(session, hit),
        );
      },
    );
  }
}
