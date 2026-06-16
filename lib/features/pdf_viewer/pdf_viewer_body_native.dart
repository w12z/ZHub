import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';

class PdfViewerBody extends StatelessWidget {
  final String? filePath;
  final String fileName;

  const PdfViewerBody({
    super.key,
    this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    if (filePath == null || !File(filePath!).existsSync()) {
      return Scaffold(
        appBar: AppBar(title: Text(fileName)),
        body: const Center(child: Text('文件不存在')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: PDF().fromPath(filePath!),
    );
  }
}
