import 'package:flutter/material.dart';
import 'package:test_app/app/app_tab.dart';
import 'package:test_app/app/tab_controller.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/section_header.dart';

import '../app/history.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = GenerationHistory.instance;
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) {
        final jobs = history.jobs;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        GlassCard(
        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Studio',
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '최근에 생성된 비디오, 이미지, 업스케일 작업을 한 곳에서 관리하세요.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _StatRow(jobs: jobs),
                        const SizedBox(height: 28),
                        SectionHeader(
                          title: 'Recent work',
                          trailing: Text(
                            '${jobs.length} items',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.all(0),
                          child: jobs.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(
                                    '아직 생성한 작업이 없습니다.\nVideo, Image, Upscale 탭에서 새로운 작품을 만들어보세요.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white54),
                                  ),
                                )
                              : Column(
          children: [
                                    for (final job in jobs) _JobTile(job: job),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.jobs});

  final List<GenerationJob> jobs;

  @override
  Widget build(BuildContext context) {
    final videoCount = jobs.where((j) => j.type == JobType.video).length;
    final imageCount = jobs.where((j) => j.type == JobType.image).length;
    final upscaleCount = jobs.where((j) => j.type == JobType.upscale).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final crossAxisCount = maxWidth < 360
            ? 1
            : maxWidth < 520
                ? 2
                : 3;
        final spacing = 12.0;
        final itemWidth =
            (maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
        final items = [
          _StatCard(
            icon: Icons.play_circle_fill_rounded,
            label: 'Videos',
            count: videoCount,
            accent: kPurpleStart,
            onTap: () => MainTabController.instance.navigate(AppTab.video),
          ),
          _StatCard(
            icon: Icons.image_rounded,
            label: 'Images',
            count: imageCount,
            accent: kSuccessColor,
            onTap: () => MainTabController.instance.navigate(AppTab.image),
          ),
          _StatCard(
            icon: Icons.auto_awesome_rounded,
            label: 'Upscales',
            count: upscaleCount,
            accent: const Color(0xFF38BDF8),
            onTap: () => MainTabController.instance.navigate(AppTab.upscale),
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 150,
        child: GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.5), accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ],
                ),
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});

  final GenerationJob job;

  Color get _accent {
    switch (job.type) {
      case JobType.video:
        return kPurpleStart;
      case JobType.image:
        return kSuccessColor;
      case JobType.upscale:
        return const Color(0xFF38BDF8);
    }
  }

  IconData get _icon {
    switch (job.type) {
      case JobType.video:
        return Icons.play_circle_fill_rounded;
      case JobType.image:
        return Icons.image_rounded;
      case JobType.upscale:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => JobSelection.instance.select(job),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
              width: 44,
              height: 44,
            decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
            ),
              child: Icon(_icon, color: _accent),
          ),
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          job.type.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                  ),
                ),
                      const SizedBox(width: 8),
                Text(
                        _timeAgo(job.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
