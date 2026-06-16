import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'core/feature_registry.dart';
import 'core/key_value_store.dart';
import 'core/module_services.dart';
import 'core/core_hub.dart';
import 'features/wifi_transfer/wifi_transfer_feature.dart';
import 'features/pdf_viewer/pdf_viewer_feature.dart';
import 'features/pdf_viewer/pdf_provider.dart';
import 'features/music_player/music_player_feature.dart';
import 'features/music_player/providers/music_library_provider.dart';
import 'features/music_player/providers/playlist_provider.dart';
import 'features/music_player/services/audio_player_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await KeyValueStore.instance.init();

  // Always create user directories inside Documents
  final docDir = await getApplicationDocumentsDirectory();
  setDocumentsPath(docDir.path);
  for (final name in ['transfer', 'Music']) {
    final d = Directory('${docDir.path}/$name');
    if (!await d.exists()) await d.create(recursive: true);
  }

  final registry = FeatureRegistry.instance;
  await registry.restore();
  registry.register(WifiTransferFeature());
  registry.register(PdfViewerFeature());
  registry.register(MusicPlayerFeature());

  for (final feature in registry.enabledFeatures) {
    await feature.init();
  }

  runApp(const ZHubApp());
}

class ZHubApp extends StatelessWidget {
  const ZHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileBrowserProvider()),
        ChangeNotifierProvider(create: (_) => QuickAccessProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = MusicLibraryProvider();
          provider.initPrefs();
          ModuleServices.instance.registerTargetFolder(provider);
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider.value(value: AudioPlayerService.instance),
        ChangeNotifierProvider.value(value: FeatureRegistry.instance),
        ChangeNotifierProvider(create: (_) => PdfProvider()),
      ],
      child: MaterialApp(
        title: 'ZHub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final features = context.watch<FeatureRegistry>().enabledFeatures;

    final pages = <Widget>[
      const FileBrowserPage(),
      const QuickAccessPage(),
      for (final f in features) f.buildPage(context),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: '文件',
      ),
      const NavigationDestination(
        icon: Icon(Icons.star_border),
        selectedIcon: Icon(Icons.star),
        label: '快速访问',
      ),
      for (final f in features)
        NavigationDestination(
          icon: Icon(f.icon),
          selectedIcon: Icon(f.icon),
          label: f.name,
        ),
    ];

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('ZHub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            tooltip: '模块管理',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: FeatureRegistry.instance,
                    child: const ModuleManagerPage(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: destinations,
      ),
    );
  }
}
