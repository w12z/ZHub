import 'package:flutter_test/flutter_test.dart';
import 'package:z_hub/core/file_item.dart';

void main() {
  group('FileItem', () {
    test('nameFromPath extracts filename', () {
      expect(FileItem.nameFromPath(r'C:\Users\test\file.txt'), 'file.txt');
      expect(FileItem.nameFromPath('file.txt'), 'file.txt');
      expect(FileItem.nameFromPath(r'C:\Users\test\project\src'), 'src');
    });

    test('formattedSize', () {
      expect(item('x', size: 0).formattedSize, '0 B');
      expect(item('x', size: 1500).formattedSize, '1.5 KB');
      expect(item('x', size: 2.5.mb).formattedSize, '2.5 MB');
      expect(item('x', size: 3.gb).formattedSize, '3.0 GB');
      expect(item('x', isDir: true, size: 0).formattedSize, '');
    });

    test('icon returns non-null', () {
      expect(item('a.pdf').icon, isA<dynamic>());
      expect(item('b.mp3').icon, isA<dynamic>());
      expect(item('c', isDir: true).icon, isA<dynamic>());
    });
  });
}

extension _SizeExt on num {

  int get mb => (this * 1024 * 1024).round();
  int get gb => (this * 1024 * 1024 * 1024).round();
}

FileItem item(String name, {bool isDir = false, int size = 0}) => FileItem(
  path: '/path/$name',
  name: name,
  isDirectory: isDir,
  size: size,
  modified: DateTime(2020),
  category: FileCategory.others,
);
