import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/features/daily_diet/epub_book.dart';
import 'package:mygrowth_app/features/daily_diet/epub_reader_screen.dart';

/// Builds a small EPUB 3 archive with the same structure as the programme's
/// books (container.xml -> OPF -> spine -> XHTML chapters).
Uint8List _buildEpub() {
  const container = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

  const opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>A Test Book</dc:title>
    <dc:creator>A Test Author</dc:creator>
    <dc:identifier id="id">test-book</dc:identifier>
  </metadata>
  <manifest>
    <item id="c1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>
''';

  const chapter1 = '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>First</title><style>body{color:red}</style></head>
  <body>
    <h1>The First Chapter</h1>
    <p>This is the opening paragraph of the first chapter.</p>
    <p>And this is a <strong>second</strong> paragraph with &amp; entities.</p>
  </body>
</html>
''';

  const chapter2 = '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Second</title></head>
  <body>
    <h2>The Second Chapter</h2>
    <p>The second chapter has its own readable content.</p>
  </body>
</html>
''';

  ArchiveFile makeFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  final archive = Archive()
    ..addFile(makeFile('mimetype', 'application/epub+zip'))
    ..addFile(makeFile('META-INF/container.xml', container))
    ..addFile(makeFile('OEBPS/content.opf', opf))
    ..addFile(makeFile('OEBPS/chapter1.xhtml', chapter1))
    ..addFile(makeFile('OEBPS/chapter2.xhtml', chapter2));

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('parses EPUB 3 metadata, spine order and readable text', () {
    final book = parseEpub(_buildEpub());

    expect(book.title, 'A Test Book');
    expect(book.author, 'A Test Author');
    expect(book.chapters, hasLength(2));

    expect(book.chapters[0].title, 'The First Chapter');
    expect(
      book.chapters[0].paragraphs,
      contains('This is the opening paragraph of the first chapter.'),
    );
    expect(
      book.chapters[0].paragraphs,
      contains('And this is a second paragraph with & entities.'),
    );

    expect(book.chapters[1].title, 'The Second Chapter');
    expect(
      book.chapters[1].paragraphs,
      contains('The second chapter has its own readable content.'),
    );
  });

  test('rejects data that is not an EPUB', () {
    expect(
      () => parseEpub(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<EpubParseException>()),
    );
  });

  testWidgets('reader shows each chapter and navigates to the next', (
    tester,
  ) async {
    final bytes = _buildEpub();
    await tester.pumpWidget(
      MaterialApp(
        home: EpubReaderScreen(
          title: 'A Test Book',
          url: 'https://example.test/book.epub',
          epubBytes: bytes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The First Chapter'), findsOneWidget);
    expect(
      find.text('This is the opening paragraph of the first chapter.'),
      findsOneWidget,
    );
    expect(find.text('1 / 2'), findsOneWidget);

    final next = find.byTooltip('Next chapter');
    expect(next, findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(find.text('The Second Chapter'), findsOneWidget);
    expect(
      find.text('The second chapter has its own readable content.'),
      findsOneWidget,
    );
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
