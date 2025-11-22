import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:test_app/app/app_tab.dart';
import 'package:test_app/app/tab_controller.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_bottom_nav_bar.dart';

import 'app/history.dart';
import 'screens/image_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/upscale_screen.dart';
import 'screens/video_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  runApp(const FreeAICreationApp());
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: ".env");
    return;
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }
  try {
    await dotenv.load(fileName: ".env.example");
    debugPrint('Loaded .env.example as fallback.');
  } catch (e) {
    debugPrint('Failed to load .env.example: $e');
  }
}

class FreeAICreationApp extends StatelessWidget {
  const FreeAICreationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Free AI Creation',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  AppTab _currentTab = AppTab.video;
  final _selection = JobSelection.instance;
  final _tabController = MainTabController.instance;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onJobSelected);
    _tabController.addListener(_onTabRouteChanged);
  }

  @override
  void dispose() {
    _selection.removeListener(_onJobSelected);
    _tabController.removeListener(_onTabRouteChanged);
    super.dispose();
  }

  void _onJobSelected() {
    if (!mounted) return;
    
    final job = _selection.selected;
    if (job == null) return;

    switch (job.type) {
      case JobType.video:
        _tabController.navigate(AppTab.video);
        break;
      case JobType.image:
        _tabController.navigate(AppTab.image);
        break;
      case JobType.upscale:
        _tabController.navigate(AppTab.upscale);
        break;
    }
  }

  void _onTabRouteChanged() {
    if (mounted) {
      setState(() => _currentTab = _tabController.current);
    }
  }

  void _onTabSelected(int index) {
    final tab = AppTab.values[index];
    _tabController.navigate(tab);
    JobSelection.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      StudioScreen(),
      VideoScreen(),
      ImageScreen(),
      UpscaleScreen(),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 110),
              child: IndexedStack(
                index: _currentTab.index,
                children: pages,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassBottomNavBar(
              currentIndex: _currentTab.index,
              onTap: _onTabSelected,
        items: const [
                GlassBottomNavItem(icon: Icons.dashboard_rounded, label: 'Studio'),
                GlassBottomNavItem(icon: Icons.play_circle_fill_rounded, label: 'Video'),
                GlassBottomNavItem(icon: Icons.brush_rounded, label: 'Image'),
                GlassBottomNavItem(icon: Icons.auto_awesome_rounded, label: 'Upscale'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
