import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pdf_provider.dart';
import 'pdf_viewer_body_native.dart' if (dart.library.html) 'pdf_viewer_body_web.dart';

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  @override
  void initState() {
    super.initState();
    context.read<PdfProvider>().recordOpen(widget.filePath, widget.fileName);
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewerBody(
      filePath: widget.filePath,
      fileName: widget.fileName,
    );
  }
}
