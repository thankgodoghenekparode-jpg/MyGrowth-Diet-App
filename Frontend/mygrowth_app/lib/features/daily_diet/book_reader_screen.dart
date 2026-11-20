import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    if (_isPdf) _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(_uri).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Download failed (HTTP ${response.statusCode})');
      }
      if (response.bodyBytes.isEmpty) {
        throw StateError('The downloaded book is empty');
      }
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(response.bodyBytes),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _pdfController?.dispose();
        _pdfController = controller;
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This book could not be opened. Check your internet '
                      'connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadPdf,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _loading || _pdfController == null
          ? const Center(child: CircularProgressIndicator())
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
