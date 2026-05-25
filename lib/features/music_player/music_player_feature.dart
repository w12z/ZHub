import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/feature_interface.dart';
import 'pages/music_library_page.dart';
import 'providers/player_state_provider.dart';
import 'services/audio_player_service.dart';
import 'services/audio_routing_service.dart';
import 'services/equalizer_service.dart';
import 'services/playlist_repository.dart';
import 'widgets/mini_player.dart';

class MusicPlayerFeature extends AppFeature {

  @override
  String get id => 'music_player';

  @override
  String get name => '音乐';

  @override
  String get description => '管理播放列表和播放音乐文件';

  @override
  String get iconAsset => 'assets/icons/music.svg';

  @override
  bool get enabledByDefault => true;

  @override
  Widget buildPage(BuildContext context) {
    return Stack(
      children: [
        const MusicLibraryPage(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: const MiniPlayer(),
        ),
      ],
    );
  }

  @override
  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await SoLoud.instance.init();

    // Initialize DB to get settings
    final repo = PlaylistRepository.instance;
    await repo.db;
    final settings = repo.settings;

    // Wire settings to singletons
    EqualizerService.instance.attachSettings(settings);
    AudioRoutingService.instance.attachSettings(settings);

    // Load EQ settings (enabled, active preset, gains)
    await EqualizerService.instance.loadFromSettings();

    // Load interrupt mode
    final interruptModeStr = await settings.get('interrupt_mode');
    if (interruptModeStr != null) {
      final mode = AudioInterruptMode.values.firstWhere(
        (m) => m.name == interruptModeStr,
        orElse: () => AudioInterruptMode.pause,
      );
      PlayerStateProvider.setDefaultInterruptMode(mode);
    }

    // Save interrupt mode when changed by user
    PlayerStateProvider.onInterruptModeChanged = (mode) {
      settings.set('interrupt_mode', mode.name);
    };

    // Load output device preference
    await AudioRoutingService.instance.loadFromSettings();
  }

  @override
  Future<void> dispose() async {
    EqualizerService.instance.dispose();
    SoLoud.instance.deinit();
  }
}
