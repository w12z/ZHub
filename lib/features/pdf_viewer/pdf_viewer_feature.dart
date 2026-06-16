import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/feature_interface.dart';
import 'pdf_provider.dart';
import 'pdf_viewer_page.dart';

/// PDF 预览模块
class PdfViewerFeature extends AppFeature {
  @override
  String get id => 'pdf_viewer';

  @override
  String get name => 'PDF 预览';

  @override
  String get description => '查看 PDF 文件';

  @override
  String get iconAsset => 'assets/icons/pdf.svg';

  @override
  IconData get icon => Icons.picture_as_pdf;

  @override
  bool get enabledByDefault => false;

  @override
  Widget buildPage(BuildContext context) {
    return const PdfLandingPage();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  static void openPdf(BuildContext context, String filePath, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(filePath: filePath, fileName: fileName),
      ),
    );
  }

  static Future<void> pickAndOpenPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final fileName = result.files.single.name;
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes == null) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web PDF preview not supported')),
      );
    } else {
      final path = result.files.single.path;
      if (path == null) return;
      if (!context.mounted) return;
      openPdf(context, path, fileName);
    }
  }
}

class PdfLandingPage extends StatelessWidget {
  const PdfLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PdfProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: provider.recentPdfs.isNotEmpty
          ? AppBar(
              title: const Text('最近打开的 PDF'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清除记录',
                  onPressed: () => _confirmClear(context, provider),
                ),
              ],
            )
          : null,
      body: provider.recentPdfs.isEmpty
          ? _buildEmptyState(context)
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: provider.recentPdfs.length,
              itemBuilder: (context, index) {
                final info = provider.recentPdfs[index];
                return _RecentPdfCard(
                  info: info,
                  onTap: () {
                    PdfViewerFeature.openPdf(context, info.path, info.name);
                  },
                  onRemove: () => provider.removeRecent(info.path),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pdf_picker_fab',
        onPressed: () => PdfViewerFeature.pickAndOpenPdf(context),
        icon: const Icon(Icons.file_open),
        label: const Text('打开 PDF'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '从文件浏览器点击 PDF 文件开始查看',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => PdfViewerFeature.pickAndOpenPdf(context),
              icon: const Icon(Icons.file_open),
              label: const Text('选择 PDF 文件'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, PdfProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除记录'),
        content: const Text('确定要清除所有最近打开的 PDF 记录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearRecents();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

class _RecentPdfCard extends StatelessWidget {
  final PdfInfo info;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentPdfCard({
    required this.info,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.red.shade50,
                child: const Center(
                  child: Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(info.lastOpened),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.month}/${date.day}';
  }
}
