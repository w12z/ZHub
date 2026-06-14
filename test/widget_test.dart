import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:z_hub/core/core_hub.dart';
import 'package:z_hub/features/music_player/services/audio_player_service.dart';
import 'package:z_hub/main.dart';

void main() {
  testWidgets('App renders with navigation tabs', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FileBrowserProvider()),
          ChangeNotifierProvider(create: (_) => QuickAccessProvider()),
        ],
        child: const ZHubApp(),
      ),
    );
    await tester.pump();

    expect(find.text('文件'), findsWidgets);
    expect(find.text('快速访问'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    AudioPlayerService.instance.dispose();
  });
}
