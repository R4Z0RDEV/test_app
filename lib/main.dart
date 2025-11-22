import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [추가]

// 패키지 import 경로 통일
import 'package:test_app/app/app_tab.dart';
import 'package:test_app/app/history.dart';
import 'package:test_app/app/tab_controller.dart';
import 'package:test_app/screens/image_screen.dart';
import 'package:test_app/screens/studio_screen.dart';
import 'package:test_app/screens/upscale_screen.dart';
import 'package:test_app/screens/video_screen.dart';
import 'package:test_app/screens/welcome_screen.dart'; // [추가] 웰컴 스크린 임포트 (파일이 있어야 함)
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_bottom_nav_bar.dart';

Future<void> main() async {
  // 1. Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 환경변수 로드
  await _loadEnv();

  // 3. AdMob 초기화
  await MobileAds.instance.initialize();
  
  // [추가] 에뮬레이터 테스트 기기 설정 (No fill 방지)
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['33BE2250B43518CCDA7DE426D04EE231', 'EMULATOR']), // 에뮬레이터 ID 추가
  );

  // [추가] 4. 첫 실행 여부 확인
  final prefs = await SharedPreferences.getInstance();
  // 'seenWelcome' 키가 없으면 true(첫 실행), 있으면 false
  final isFirstRun = prefs.getBool('seenWelcome') ?? true;

  // 5. 앱 실행 (첫 실행 여부 전달)
  runApp(FreeAICreationApp(isFirstRun: isFirstRun));
}

/// 환경변수 파일(.env) 로드 함수
Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ Loaded .env file successfully.");
    return;
  } catch (e) {
    debugPrint('⚠️ .env file not found or empty. Trying fallback...');
  }

  try {
    await dotenv.load(fileName: ".env.example");
    debugPrint('ℹ️ Loaded .env.example as fallback.');
  } catch (e) {
    debugPrint('❌ Failed to load any .env file: $e');
  }
}

class FreeAICreationApp extends StatelessWidget {
  final bool isFirstRun; // [추가] 첫 실행 여부 변수

  const FreeAICreationApp({
    super.key,
    required this.isFirstRun, // [추가] 생성자에서 받음
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Free AI Creation',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      // [수정] 첫 실행이면 WelcomeScreen, 아니면 MainScaffold
      home: isFirstRun ? const WelcomeScreen() : const MainScaffold(),
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
    // Using const for pages list ensures widgets aren't recreated on every build
    // However, since these screens are stateful (or contain stateful children) and are in IndexedStack,
    // they are built once and kept alive.
    const pages = <Widget>[
      StudioScreen(),
      VideoScreen(),
      ImageScreen(),
      UpscaleScreen(),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      // Using a Stack for bottom nav bar is fine, but ensure the body behind isn't
      // doing unnecessary work. IndexedStack is good here.
      body: Stack(
        children: [
          Positioned.fill(
            // Avoid rebuilding padding if possible, though trivial here.
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