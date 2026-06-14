import 'package:flutter_test/flutter_test.dart';
import 'package:z_hub/features/wifi_transfer/wifi_transfer.dart';

void main() {
  group('TransferTask', () {
    test('formattedSize', () {
      expect(
        TransferTask(
          id: '1',
          fileName: 'a.mp3',
          fileSize: 500,
          direction: TransferDirection.upload,
        ).formattedSize,
        '500 B',
      );
      expect(
        TransferTask(
          id: '2',
          fileName: 'b.mp3',
          fileSize: 2048,
          direction: TransferDirection.upload,
        ).formattedSize,
        '2.0 KB',
      );
      expect(
        TransferTask(
          id: '3',
          fileName: 'c.mp3',
          fileSize: 5 * 1024 * 1024,
          direction: TransferDirection.upload,
        ).formattedSize,
        '5.0 MB',
      );
      expect(
        TransferTask(
          id: '4',
          fileName: 'd.mp3',
          fileSize: 2 * 1024 * 1024 * 1024,
          direction: TransferDirection.upload,
        ).formattedSize,
        '2.0 GB',
      );
    });

    test('formattedSpeed', () {
      expect(
        TransferTask(
          id: '1',
          fileName: 'a.mp3',
          fileSize: 1000,
          direction: TransferDirection.upload,
          speed: 500,
        ).formattedSpeed,
        '500 B/s',
      );
      expect(
        TransferTask(
          id: '1',
          fileName: 'a.mp3',
          fileSize: 1000,
          direction: TransferDirection.upload,
          speed: 2048,
        ).formattedSpeed,
        '2.0 KB/s',
      );
    });

    test('formattedProgress', () {
      expect(
        TransferTask(
          id: '1',
          fileName: 'a.mp3',
          fileSize: 1000,
          direction: TransferDirection.upload,
          progress: 0.75,
        ).formattedProgress,
        '75%',
      );
    });

    test('formattedETA returns -- when speed is 0', () {
      final task = TransferTask(
        id: '1',
        fileName: 'a.mp3',
        fileSize: 1000000,
        direction: TransferDirection.upload,
        speed: 0,
        status: TransferStatus.transferring,
      );
      expect(task.formattedETA, '--');
    });

    test('formattedETA returns -- when not transferring', () {
      final task = TransferTask(
        id: '1',
        fileName: 'a.mp3',
        fileSize: 1000000,
        direction: TransferDirection.upload,
        speed: 1000,
        status: TransferStatus.pending,
      );
      expect(task.formattedETA, '--');
    });

    test('formattedETA computes remaining time', () {
      final task = TransferTask(
        id: '1',
        fileName: 'a.mp3',
        fileSize: 1000000,
        direction: TransferDirection.upload,
        speed: 1000,
        bytesTransferred: 200000,
        status: TransferStatus.transferring,
      );
      // (1000000-200000)/1000 = 800s = 13min
      expect(task.formattedETA, '13min');
    });
  });
}
