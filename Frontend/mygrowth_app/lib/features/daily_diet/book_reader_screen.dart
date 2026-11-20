import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/widgets/app_back_button.dart';
import 'epub_reader_screen.dart';

/// Opens the programme's PDF or EPUB book inside the app.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late final Uri _uri = Uri.parse(widget.url);
  late final bool _isPdf = _uri.path.toLowerCase().endsWith('.pdf');

  PdfControllerPinch? _pdfController;

  Object? _error;

  @override
  void initState() {
    super.initState();

    if (_isPdf) {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(_downloadBytes()),
      );
    }
  }

  Future<Uint8List> _downloadBytes() async {
    final data = await NetworkAssetBundle(_uri).load(_uri.toString());
    return data.buffer.asUint8List();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // EPUBs are read by the self-contained text reader. The WebView/epub.js
    // viewer renders a blank page for EPUB 3 books on the web.
    if (!_isPdf) {
      return EpubReaderScreen(title: widget.title, url: widget.url);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'This book could not be opened. Check your internet '
                  'connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : PdfViewPinch(
              controller: _pdfController!,
              onDocumentError: (error) {
                if (mounted) {
                  setState(() => _error = error);
                }
              },
            ),
    );
  }
}
