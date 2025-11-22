import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/primary_gradient_button.dart';
import 'package:test_app/main.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 웰컴 페이지 데이터
  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'AI Video Creation',
      'description': 'Create amazing videos from text. Stitch multiple clips together to tell a story.',
      'icon': Icons.play_circle_fill_rounded,
    },
    {
      'title': 'Turn Imagination into Images',
      'description': 'Generate high-quality images with Stable Diffusion. Visualize your ideas instantly.',
      'icon': Icons.brush_rounded,
    },
    {
      'title': 'Upscale for Clarity',
      'description': 'Sharpen blurry photos and remove watermarks for free after watching an ad.',
      'icon': Icons.auto_awesome_rounded,
    },
  ];

  // 웰컴 완료 처리 및 메인으로 이동
  Future<void> _finishWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenWelcome', false);

    if (!mounted) return;
    // [수정] const 제거
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MainScaffold()), 
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 Skip 버튼
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishWelcome,
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(40),
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return AppGradients.primary.createShader(bounds);
                            },
                            child: Icon(
                              page['icon'],
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page['title'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 하단 인디케이터 및 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppGradients.primary.colors.first
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  PrimaryGradientButton(
                    label: isLastPage ? 'Get Started' : 'Continue',
                    onPressed: () {
                      if (isLastPage) {
                        _finishWelcome();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}