import 'package:flutter/material.dart';
import 'core/feature_registry.dart';
import 'features/wifi_transfer/wifi_transfer_feature.dart';
import 'features/pdf_viewer/pdf_viewer_feature.dart';
import 'features/music_player/music_player_feature.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final registry = FeatureRegistry();
  registry.register(WifiTransferFeature());
  registry.register(PdfViewerFeature());
  registry.register(MusicPlayerFeature());

  for (final feature in registry.enabledFeatures) {
    await feature.init();
  }

  runApp(const FileHubApp());
}

class FileHubApp extends StatelessWidget {
  const FileHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final features = FeatureRegistry().enabledFeatures;

    return MaterialApp(
      title: 'File Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: HomePage(features: features),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<dynamic> features;
  const HomePage({super.key, required this.features});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 核心 tab + 已启用模块的 tab
    final coreTabs = <Widget>[
      const Center(child: Text('文件浏览')),
      const Center(child: Text('快速访问')),
    ];
    final coreLabels = ['文件', '快速访问'];

    final tabs = [...coreTabs];
    final labels = [...coreLabels];

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            onPressed: () {
              // TODO: 模块管理页面
            },
          ),
        ],
      ),
      body: tabs[_currentIndex.clamp(0, tabs.length - 1)],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          for (int i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon(i == 0 ? Icons.folder : Icons.star_border),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}
