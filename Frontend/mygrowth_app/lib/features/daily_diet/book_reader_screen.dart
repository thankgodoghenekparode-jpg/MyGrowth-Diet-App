import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/widgets/app_back_button.dart';

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
  final EpubController _epubController = EpubController();
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _pdfController = PdfControllerPinch(document: PdfDocument.openUri(_uri));
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  'This book could not be opened. Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _isPdf
          ? PdfViewPinch(
              controller: _pdfController!,
              onDocumentError: (error) {
                if (mounted) setState(() => _error = error);
              },
            )
          : EpubViewer(
              epubController: _epubController,
              epubSource: EpubSource.fromUrl(widget.url),
              displaySettings: EpubDisplaySettings(
                flow: EpubFlow.paginated,
                snap: true,
                theme: EpubTheme.light(),
                allowScriptedContent: false,
              ),
              onLoadError: (error) {
                if (mounted) setState(() => _error = error);
              },
            ),
    );
  }
}
