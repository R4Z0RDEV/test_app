import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 패키지 import 경로 통일 (상대 경로 대신 package: 사용)
import 'package:test_app/app/app_tab.dart';
import 'package:test_app/app/history.dart';
import 'package:test_app/app/tab_controller.dart';
import 'package:test_app/screens/image_screen.dart';
import 'package:test_app/screens/studio_screen.dart';
import 'package:test_app/screens/upscale_screen.dart';
import 'package:test_app/screens/video_screen.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_bottom_nav_bar.dart';

Future<void> main() async {
  // 1. Flutter 엔진 초기화 (가장 먼저 실행되어야 함)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 환경변수 로드 (에러 방지 처리 포함)
  await _loadEnv();

  // 3. 앱 실행
  runApp(const FreeAICreationApp());
}

/// 환경변수 파일(.env)을 로드합니다.
/// 실패 시 .env.example을 대신 로드하여 앱이 멈추지 않도록 합니다.
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
    // 앱이 켜지긴 하겠지만 API 호출 시 에러가 날 수 있음
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
  
  // 싱글톤 인스턴스 가져오기
  final _selection = JobSelection.instance;
  final _tabController = MainTabController.instance;

  @override
  void initState() {
    super.initState();
    // 리스너 등록
    _selection.addListener(_onJobSelected);
    _tabController.addListener(_onTabRouteChanged);
  }

  @override
  void dispose() {
    // 리스너 해제 (메모리 누수 방지)
    _selection.removeListener(_onJobSelected);
    _tabController.removeListener(_onTabRouteChanged);
    super.dispose();
  }

  /// 작업(Job)이 선택되었을 때 해당 탭으로 이동하는 로직
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

  /// 탭 컨트롤러의 상태가 바뀌었을 때 UI를 업데이트
  void _onTabRouteChanged() {
    if (mounted) {
      setState(() => _currentTab = _tabController.current);
    }
  }

  /// 하단 네비게이션 바를 탭했을 때 실행
  void _onTabSelected(int index) {
    final tab = AppTab.values[index];
    _tabController.navigate(tab);
    // 탭을 직접 누르면 기존 선택된 작업은 초기화
    JobSelection.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    // 각 탭에 해당하는 화면들
    const pages = <Widget>[
      StudioScreen(),
      VideoScreen(),
      ImageScreen(),
      UpscaleScreen(),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor, // app_theme.dart에 정의된 색상 사용
      body: Stack(
        children: [
          // 1. 메인 콘텐츠 영역
          Positioned.fill(
            child: Padding(
              // 하단 네비게이션 바 높이만큼 패딩을 줘서 가려지지 않게 함
              padding: const EdgeInsets.only(bottom: 110),
              child: IndexedStack(
                index: _currentTab.index,
                children: pages,
              ),
            ),
          ),
          
          // 2. 하단 네비게이션 바 (Glass effect)
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