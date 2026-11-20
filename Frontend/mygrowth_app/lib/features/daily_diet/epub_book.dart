import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A single readable section of an EPUB, in spine (book) order.
class EpubChapter {
  const EpubChapter({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  bool get isEmpty => paragraphs.isEmpty;
}

/// The readable contents of an EPUB file.
class EpubBook {
  const EpubBook({required this.title, this.author, required this.chapters});

  final String title;
  final String? author;
  final List<EpubChapter> chapters;

  bool get isEmpty => chapters.every((chapter) => chapter.isEmpty);
}

class EpubParseException implements Exception {
  const EpubParseException(this.message);

  final String message;

  @override
  String toString() => 'EpubParseException: $message';
}

/// Parses an EPUB archive into ordered, plain-text chapters.
///
/// This deliberately avoids a WebView/epub.js: those render a blank page for
/// the programme's EPUB 3 books on the web. Reading the archive directly means
/// every book's text is available on every platform, with no iframe, no remote
/// script and no same-origin/CORS dependency.
EpubBook parseEpub(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object catch (error) {
    throw EpubParseException('Not a valid EPUB archive: $error');
  }

  final files = <String, List<int>>{};
  for (final file in archive.files) {
    if (file.isFile) {
      files[_normalizePath(file.name)] = file.content as List<int>;
    }
  }

  final containerPath =
      _findFile(files, 'META-INF/container.xml') ??
      _findFile(files, 'container.xml');
  if (containerPath == null) {
    throw const EpubParseException('Missing META-INF/container.xml');
  }

  final opfPath = _readOpfPath(_decode(files[containerPath]!));
  final normalizedOpfPath = _normalizePath(opfPath);
  final opfBytes =
      files[normalizedOpfPath] ??
      files[_findFile(files, normalizedOpfPath) ?? ''] ??
      files[_findFile(files, _baseName(normalizedOpfPath)) ?? ''];
  if (opfBytes == null) {
    throw EpubParseException('EPUB package file not found: $opfPath');
  }

  final XmlDocument opf;
  try {
    opf = XmlDocument.parse(_decode(opfBytes));
  } on Object catch (error) {
    throw EpubParseException('Could not read EPUB package: $error');
  }

  final opfDir = _directoryOf(normalizedOpfPath);
  final manifest = <String, _ManifestItem>{};
  for (final item in opf.findAllElements('item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = _ManifestItem(
      path: _resolve(opfDir, href),
      mediaType: item.getAttribute('media-type') ?? '',
    );
  }

  final idrefs = <String>[];
  for (final itemref in opf.findAllElements('itemref')) {
    final idref = itemref.getAttribute('idref');
    if (idref == null) continue;
    if ((itemref.getAttribute('linear') ?? 'yes').toLowerCase() == 'no') {
      continue;
    }
    idrefs.add(idref);
  }
  if (idrefs.isEmpty) {
    throw const EpubParseException('EPUB has no readable spine');
  }

  final chapters = <EpubChapter>[];
  for (var index = 0; index < idrefs.length; index++) {
    final item = manifest[idrefs[index]];
    if (item == null) continue;
    final path = files.containsKey(item.path)
        ? item.path
        : _findFile(files, item.path);
    if (path == null) continue;
    final paragraphs = _htmlToParagraphs(_decode(files[path]!));
    if (paragraphs.isEmpty) continue;

    // The first short line is the chapter heading; keep it as the title only,
    // not duplicated in the body text.
    var title = 'Chapter ${index + 1}';
    final body = List<String>.from(paragraphs);
    if (body.first.length <= 90) {
      title = body.removeAt(0);
    }
    if (body.isEmpty) body.add(title);
    chapters.add(EpubChapter(title: title, paragraphs: body));
  }

  if (chapters.isEmpty) {
    throw const EpubParseException('EPUB contains no readable text');
  }

  return EpubBook(
    title: _metadataText(opf, 'title') ?? 'Book',
    author: _metadataText(opf, 'creator'),
    chapters: chapters,
  );
}

class _ManifestItem {
  const _ManifestItem({required this.path, required this.mediaType});

  final String path;
  final String mediaType;
}

/// Finds the OPF path in a container.xml document.
String _readOpfPath(String xml) {
  try {
    final doc = XmlDocument.parse(xml);
    for (final rootfile in doc.findAllElements('rootfile')) {
      final path = rootfile.getAttribute('full-path');
      if (path != null && path.isNotEmpty) return path;
    }
  } on Object {
    // Fall through to the tolerant regex below. Some publishers ship a
    // container.xml with a slightly malformed declaration.
  }
  final match = RegExp(
    '<rootfile\\b[^>]*\\bfull-path\\s*=\\s*[\'"]([^\'"]+)[\'"]',
    caseSensitive: false,
  ).firstMatch(xml);
  if (match == null) {
    throw const EpubParseException('container.xml has no rootfile path');
  }
  return match.group(1)!;
}

String? _metadataText(XmlDocument opf, String localName) {
  for (final node in opf.descendants) {
    if (node is XmlElement && node.name.local == localName) {
      final text = node.innerText.trim();
      if (text.isNotEmpty) return text;
    }
  }
  return null;
}

/// Converts an XHTML chapter into readable paragraphs.
List<String> _htmlToParagraphs(String html) {
  var text = html;
  text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
  text = text.replaceAll(
    RegExp(r'<(script|style|head)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
    ' ',
  );
  // Block boundaries become line breaks so paragraphs stay separate.
  text = text.replaceAll(
    RegExp(
      r'</?(?:p|div|h[1-6]|li|blockquote|tr|section|article|br|hr)\b[^>]*>',
      caseSensitive: false,
    ),
    '\n',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = _decodeEntities(text);

  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

String _decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

const Map<String, String> _htmlEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'mdash': '—',
  'ndash': '–',
  'lsquo': '\u2018',
  'rsquo': '\u2019',
  'ldquo': '\u201C',
  'rdquo': '\u201D',
  'hellip': '…',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'bull': '•',
  'middot': '·',
  'laquo': '«',
  'raquo': '»',
  'eacute': 'é',
  'aacute': 'á',
  'ograve': 'ò',
  'ugrave': 'ù',
  'ntilde': 'ñ',
  'cedil': 'ç',
  'pound': '£',
  'euro': '€',
  'cent': '¢',
  'yen': '¥',
  'sect': '§',
  'para': '¶',
  'deg': '°',
  'plusmn': '±',
  'times': '×',
  'divide': '÷',
};

String _decodeEntities(String text) {
  return text.replaceAllMapped(
    RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);'),
    (match) {
      final token = match.group(1)!;
      if (token.startsWith('#')) {
        final isHex = token.length > 1 && token[1].toLowerCase() == 'x';
        final digits = isHex ? token.substring(2) : token.substring(1);
        final value = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (value != null && value > 0 && value <= 0x10FFFF) {
          return String.fromCharCode(value);
        }
        return match.group(0)!;
      }
      return _htmlEntities[token.toLowerCase()] ?? match.group(0)!;
    },
  );
}

String _normalizePath(String path) {
  var result = path.replaceAll('\\', '/').trim();
  while (result.startsWith('./')) {
    result = result.substring(2);
  }
  while (result.startsWith('/')) {
    result = result.substring(1);
  }
  return result;
}

String _baseName(String path) {
  final index = path.lastIndexOf('/');
  return index < 0 ? path : path.substring(index + 1);
}

String _directoryOf(String path) {
  final index = path.lastIndexOf('/');
  return index < 0 ? '' : path.substring(0, index);
}

String _resolve(String base, String href) {
  final cleanHref = Uri.parse(href).path;
  if (href.startsWith('/')) return _normalizePath(cleanHref);
  if (base.isEmpty) return _normalizePath(cleanHref);
  return _normalizePath('$base/$cleanHref');
}

String? _findFile(Map<String, List<int>> files, String path) {
  if (path.isEmpty) return null;
  if (files.containsKey(path)) return path;
  // Fall back to a case-insensitive / basename match for archives that ship
  // inconsistent path casing.
  for (final key in files.keys) {
    if (key.toLowerCase() == path.toLowerCase()) return key;
  }
  final base = _baseName(path).toLowerCase();
  for (final key in files.keys) {
    if (_baseName(key).toLowerCase() == base) return key;
  }
  return null;
}
