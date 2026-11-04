import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Renders Bible book references as links to the matching chapter in the reader.
class BibleReferenceText extends StatelessWidget {
  const BibleReferenceText({
    required this.text,
    this.style,
    super.key,
  });

  final String text;
  final TextStyle? style;

  static const _books = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Psalm', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
    'Song of Songs', 'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel',
    'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
    'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi', 'Matthew',
    'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians', '2 Corinthians',
    'Galatians', 'Ephesians', 'Philippians', 'Colossians',
    '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus',
    'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John',
    '3 John', 'Jude', 'Revelation',
  ];

  static final _referencePattern = RegExp(
    r'(?<![A-Za-z0-9])('
    '${_books.map(RegExp.escape).join('|')})'
    r'(?:\s+(\d+)(?::\d+(?:[-–]\d+)?(?:,\s*\d+(?:[-–]\d+)?)*)?(?:[-–]\d+)?)?',
    // Don't link a book name that is only the start of another word.
    caseSensitive: false,
  );

  static String? firstReferenceRoute(String text) {
    final match = _referencePattern.firstMatch(text);
    if (match == null) return null;
    final book = _canonicalBook(match.group(1)!);
    final chapter = int.tryParse(match.group(2) ?? '') ?? 1;
    return _route(book, chapter);
  }

  static String _canonicalBook(String value) {
    if (value.toLowerCase() == 'psalm') return 'Psalms';
    if (value.toLowerCase() == 'song of songs') return 'Song of Solomon';
    return _books.firstWhere(
      (book) => book.toLowerCase() == value.toLowerCase(),
      orElse: () => value,
    );
  }

  static String _route(String book, int chapter) =>
      Uri(path: '/bible', queryParameters: {
        'book': book,
        'chapter': '$chapter',
      }).toString();

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? DefaultTextStyle.of(context).style;
    final matches = _referencePattern.allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: textStyle);

    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in matches) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final label = match.group(0)!;
      final book = _canonicalBook(match.group(1)!);
      final chapter = int.tryParse(match.group(2) ?? '') ?? 1;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            onTap: () => context.go(_route(book, chapter)),
            child: Text(
              label,
              style: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));

    return RichText(
      text: TextSpan(style: textStyle, children: spans),
      textAlign: TextAlign.start,
    );
  }
}
