import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:test_app/config/secrets.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/primary_gradient_button.dart';
import 'package:test_app/ui/section_header.dart';
import 'package:video_player/video_player.dart';

import '../app/ad_gate.dart';
import '../app/history.dart';
import '../services/media_watermark_service.dart';
import '../services/replicate_client.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoFlowController _controller;
  bool _isSavingVideo = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoFlowController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    if (!Secrets.hasReplicateToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Replicate API 키가 설정되지 않았습니다. .env 파일에 REPLICATE_API_TOKEN 을 추가해 주세요.',
          ),
        ),
      );
      return;
    }
    if (!_controller.hasPrompts) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one clip prompt.')),
      );
      return;
    }

    final allowed = await showRewardAdGate(
      context,
      reason: AdRewardReason.generateVideo,
    );
    if (!allowed) return;

    try {
      await _controller.generate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video generated — scroll up to preview.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video error: $e')),
      );
    }
  }

  Future<void> _handleDownload() async {
    final watermarkedPath = _controller.currentVideoUrl;
    final originalUrl = _controller.originalVideoUrl ?? watermarkedPath;
    final job = _controller.currentJob;
    if (watermarkedPath == null || originalUrl == null || job == null || _isSavingVideo) {
      return;
    }

    Future<void> saveWithWatermarkStatus({required bool clearWatermark}) async {
      final target = clearWatermark ? originalUrl : watermarkedPath;
      if (clearWatermark) {
        await _controller.markWatermarkCleared();
      }
      await _saveVideoToGallery(target);
    }

    if (!job.hasWatermark) {
      await saveWithWatermarkStatus(clearWatermark: false);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B0F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Save video',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSavingVideo
                      ? null
                      : () {
                          Navigator.pop(context);
                          saveWithWatermarkStatus(clearWatermark: false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save with watermark'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSavingVideo
                      ? null
                      : () async {
                          Navigator.pop(context);
                          final unlocked = await showRewardAdGate(
                            context,
                            reason: AdRewardReason.removeVideoWatermark,
                          );
                          if (!unlocked) return;
                          await saveWithWatermarkStatus(clearWatermark: true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9F7CFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Watch ad to remove watermark'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveVideoToGallery(String url) async {
    if (_isSavingVideo) return;
    setState(() => _isSavingVideo = true);
    try {
      final success =
          await GallerySaver.saveVideo(url, albumName: 'Free AI Creation');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success == true
                ? '사진 앱에 저장했어요.'
                : '저장에 실패했습니다. 잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingVideo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: _VideoPreviewCard(
                    controller: _controller,
                    onDownload: _handleDownload,
                    isSaving: _isSavingVideo,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        SectionHeader(
                          title: 'Clips',
                          trailing: Text(
                            '${_controller.clips.length} total',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._controller.clips.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ClipSummaryTile(
                                  index: entry.key,
                                  clip: entry.value,
                                  onTap: () => _openClipEditor(
                                    context,
                                    entry.key,
                                  ),
                                ),
                              ),
                            ),
                        TextButton.icon(
                          onPressed: _controller.addClip,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add clip'),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: PrimaryGradientButton(
                    label: 'Generate Flow',
                    onPressed: _controller.isGenerating ? null : _handleGenerate,
                    isLoading: _controller.isGenerating,
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

  Future<void> _openClipEditor(BuildContext context, int index) async {
    final clip = _controller.clips[index];
    final promptController = TextEditingController(text: clip.prompt);
    final imageController = TextEditingController(text: clip.image ?? '');
    final lastFrameController =
        TextEditingController(text: clip.lastFrameImage ?? '');
    final referenceController = TextEditingController(
      text: (clip.referenceImages ?? []).join(', '),
    );
    final seedController =
        TextEditingController(text: clip.seed?.toString() ?? '');

    int duration = clip.duration.clamp(2, 5);
    String aspectRatio = clip.aspectRatio;
    bool cameraFixed = clip.cameraFixed;

    const durationOptions = [2, 3, 4, 5];
    const ratioOptions = [
      '16:9',
      '4:3',
      '1:1',
      '3:4',
      '9:16',
      '21:9',
      '9:21',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF050816),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (ctx, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: StatefulBuilder(
                builder: (ctx, setState) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Text(
                          'Clip ${index + 1}',
                          style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                                fontSize: 22,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edit prompt and parameters for this segment.',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: Colors.white54,
                              ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: promptController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Prompt',
                            hintText: 'Describe this clip...',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: imageController,
                          decoration: InputDecoration(
                            labelText: 'Image URL (optional)',
                            hintText: 'https://example.com/start_frame.png',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: lastFrameController,
                          decoration: InputDecoration(
                            labelText: 'Last frame image URL (optional)',
                            hintText: 'https://example.com/end_frame.png',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: referenceController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Reference images (comma separated)',
                            hintText:
                                'https://ex.com/a.png, https://ex.com/b.png',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: duration,
                                decoration: InputDecoration(
                                  labelText: 'Duration (seconds)',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                                dropdownColor: const Color(0xFF111322),
                                items: durationOptions
                                    .map(
                                      (d) => DropdownMenuItem<int>(
                                        value: d,
                                        child: Text('${d}s'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => duration = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: aspectRatio,
                                decoration: InputDecoration(
                                  labelText: 'Aspect ratio',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                                dropdownColor: const Color(0xFF111322),
                                items: ratioOptions
                                    .map(
                                      (r) => DropdownMenuItem<String>(
                                        value: r,
                                        child: Text(r),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => aspectRatio = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: cameraFixed,
                          onChanged: (value) =>
                              setState(() => cameraFixed = value),
                          title: const Text(
                            'Lock camera movement',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Use reference frame and keep camera static.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          activeColor: const Color(0xFF9F7CFF),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: seedController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Seed (optional)',
                            hintText: 'Leave empty for random',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'FPS: 24 (fixed) • Resolution: 480p',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (_controller.clips.length > 1)
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _controller.removeClip(index);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                                child: const Text('Delete clip'),
                              ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                final seedText = seedController.text.trim();
                                final seed =
                                    seedText.isEmpty ? null : int.tryParse(seedText);

                                final refText =
                                    referenceController.text.trim();
                                final refs = refText.isEmpty
                                    ? null
                                    : refText
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList();

                                _controller.updateClip(
                                  index,
                                  prompt: promptController.text,
                                  duration: duration,
                                  aspectRatio: aspectRatio,
                                  cameraFixed: cameraFixed,
                                  seed: seed,
                                  image: _normalizeUrl(imageController.text),
                                  lastFrameImage:
                                      _normalizeUrl(lastFrameController.text),
                                  referenceImages: refs,
                                );
                                Navigator.of(ctx).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9F7CFF),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    promptController.dispose();
    imageController.dispose();
    lastFrameController.dispose();
    referenceController.dispose();
    seedController.dispose();
  }

  String? _normalizeUrl(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({
    required this.controller,
    required this.onDownload,
    required this.isSaving,
  });

  final VideoFlowController controller;
  final VoidCallback onDownload;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo = controller.currentVideoUrl != null;
    final player = controller.videoController;

    return GlassCard(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: hasVideo
            ? Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          if (controller.isVideoReady && player != null)
                            Positioned.fill(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: player.value.size.width,
                                  height: player.value.size.height,
                                  child: VideoPlayer(player),
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                          if (controller.currentJob?.hasWatermark == true)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    'FREE AI CREATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (controller.isVideoReady)
                            Positioned.fill(
                              child: Center(
                                child: IconButton(
                                  iconSize: 70,
                                  color: Colors.white,
                                  icon: Icon(
                                    controller.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_filled_rounded,
                                  ),
                                  onPressed: controller.togglePlayback,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.currentJob?.subtitle ??
                              'Seedance Lite · ${player?.value.duration.inSeconds ?? 0}s',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (isSaving)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.download_rounded),
                          color: Colors.white,
                          onPressed: onDownload,
                        ),
                    ],
                  ),
                ],
              )
            : SizedBox(
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.primary,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '프롬프트를 입력하고 Generate Flow를 눌러 영상을 만들어 보세요.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ClipSummaryTile extends StatelessWidget {
  const _ClipSummaryTile({
    required this.index,
    required this.clip,
    required this.onTap,
  });

  final int index;
  final _VideoClip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = 'Clip ${index + 1}';
    final prompt = clip.prompt.trim();
    final subtitle =
        prompt.isEmpty ? 'Tap to edit clip' : prompt.split('\n').first;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white70,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ClipEditor extends StatelessWidget {
  const _ClipEditor({
    required this.index,
    required this.clip,
    required this.controller,
  });

  final int index;
  final _VideoClip clip;
  final VideoFlowController controller;

  static const durations = ['5s', '10s', '15s'];
  static const resolutions = ['480p', '720p', '1080p'];
  static const ratios = ['16:9', '9:16', '1:1'];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Clip ${index + 1}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (controller.clips.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.white.withOpacity(0.6),
                  onPressed: () => controller.removeClip(index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${clip.id}_${clip.revision}'),
            initialValue: clip.prompt,
            maxLines: 3,
            onChanged: (value) => controller.updateClip(index, prompt: value),
            decoration: InputDecoration(
              hintText: 'Describe this clip...',
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ReactiveDropdown(
                  label: 'Duration',
                  value: '${clip.duration}s',
                  items: durations,
                  onChanged: (value) {
                    controller.updateClip(
                      index,
                      duration: int.parse(value!.replaceAll('s', '')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReactiveDropdown(
                  label: 'Resolution',
                  value: clip.resolution,
                  items: resolutions,
                  onChanged: (value) {
                    controller.updateClip(index, resolution: value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ReactiveDropdown(
            label: 'Aspect ratio',
            value: clip.aspectRatio,
            items: ratios,
            onChanged: (value) {
              controller.updateClip(index, aspectRatio: value);
            },
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: clip.cameraFixed,
            onChanged: (value) {
              controller.updateClip(index, cameraFixed: value);
            },
            title: const Text(
              'Lock camera movement',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Use reference frame and keep camera static.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            activeColor: const Color(0xFF9F7CFF),
          ),
        ],
      ),
    );
  }
}

class _ReactiveDropdown extends StatelessWidget {
  const _ReactiveDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dropdownColor: const Color(0xFF111322),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _BottomCTA extends StatelessWidget {
  const _BottomCTA({
    required this.isBusy,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final bool isBusy;
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F1F),
        border: Border(
          top: BorderSide(color: Color(0x22000000)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBusy ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class VideoFlowController extends ChangeNotifier {
  VideoFlowController() {
    _selection.addListener(_handleSelection);
  }

  final ReplicateVideoClient _client = const ReplicateVideoClient();
   final MediaWatermarkService _media = MediaWatermarkService.instance;
  final GenerationHistory _history = GenerationHistory.instance;
  final JobSelection _selection = JobSelection.instance;

  final List<_VideoClip> _clips = [_VideoClip()];

  bool _isGenerating = false;
  bool _isVideoReady = false;
  bool _isPlaying = false;
  String? _currentVideoUrl;
  String? _originalVideoUrl;
  GenerationJob? _currentJob;
  VideoPlayerController? _videoController;

  List<_VideoClip> get clips => List.unmodifiable(_clips);
  bool get isGenerating => _isGenerating;
  bool get isVideoReady => _isVideoReady;
  bool get isPlaying => _isPlaying;
  String? get currentVideoUrl => _currentVideoUrl;
  String? get originalVideoUrl => _originalVideoUrl;
  GenerationJob? get currentJob => _currentJob;
  VideoPlayerController? get videoController => _videoController;

  bool get hasPrompts =>
      _clips.any((clip) => clip.prompt.trim().isNotEmpty);

  Future<void> generate() async {
    final activeClips =
        _clips.where((clip) => clip.prompt.trim().isNotEmpty).toList();
    if (activeClips.isEmpty) {
      throw StateError('No prompts provided');
    }

    _isGenerating = true;
    notifyListeners();

    try {
      final combinedPrompt = activeClips
          .asMap()
          .entries
          .map((entry) => 'Clip ${entry.key + 1}: ${entry.value.prompt}')
          .join('. ');

      final first = activeClips.first;
      final duration = first.duration.clamp(2, 5);

      final videoUrl = await _client.generate(
        prompt: combinedPrompt,
        durationSeconds: duration,
        resolution: '480p',
        aspectRatio: first.aspectRatio,
        cameraFixed: first.cameraFixed,
        fps: 24,
        seed: first.seed,
        image: first.image,
        lastFrameImage: first.lastFrameImage,
        referenceImages: first.referenceImages?.isEmpty == true
            ? null
            : first.referenceImages,
      );

      _originalVideoUrl = videoUrl;

      // Bake watermark into the local file before preview & save.
      final watermarkedFile =
          await _media.addWatermarkToVideo(inputUrl: videoUrl);
      _currentVideoUrl = watermarkedFile.path;
      await _preparePlayer(_currentVideoUrl!);

      final job = GenerationJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: JobType.video,
        title: first.prompt.split('\n').first,
        subtitle:
            'Seedance-1-lite • ${duration}s • 480p • ${first.aspectRatio}',
        createdAt: DateTime.now(),
        previewUrl: videoUrl,
        parameters: {
          'prompt': combinedPrompt,
          'duration': duration,
          'resolution': '480p',
          'aspectRatio': first.aspectRatio,
          'cameraFixed': first.cameraFixed,
          'clipCount': activeClips.length,
          'fps': 24,
          'seed': first.seed,
          'image': first.image,
          'lastFrameImage': first.lastFrameImage,
          'referenceImages': first.referenceImages,
          'originalUrl': videoUrl,
        },
        hasWatermark: true,
        watermarkRemoved: false,
      );

      _currentJob = job;
      _history.addJob(job);
      notifyListeners();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void addClip() {
    _clips.add(_VideoClip());
    notifyListeners();
  }

  void removeClip(int index) {
    if (_clips.length <= 1) return;
    _clips.removeAt(index);
    notifyListeners();
  }

  void updateClip(
    int index, {
    String? prompt,
    int? duration,
    String? resolution,
    String? aspectRatio,
    bool? cameraFixed,
    int? seed,
    String? image,
    String? lastFrameImage,
    List<String>? referenceImages,
  }) {
    final clip = _clips[index];
    if (prompt != null) clip.prompt = prompt;
    if (duration != null) clip.duration = duration;
    if (resolution != null) clip.resolution = resolution;
    if (aspectRatio != null) clip.aspectRatio = aspectRatio;
    if (cameraFixed != null) clip.cameraFixed = cameraFixed;
    if (seed != null) clip.seed = seed;
    if (image != null) clip.image = image;
    if (lastFrameImage != null) clip.lastFrameImage = lastFrameImage;
    if (referenceImages != null) clip.referenceImages = referenceImages;
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    final player = _videoController;
    if (player == null || !_isVideoReady) return;

    if (_isPlaying) {
      await player.pause();
      _isPlaying = false;
    } else {
      await player.play();
      _isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> markWatermarkCleared() async {
    final job = _currentJob;
    if (job == null || !job.hasWatermark) return;
    final updated = job.copyWith(
      hasWatermark: false,
      watermarkRemoved: true,
    );
    _currentJob = updated;
    _history.updateJob(updated);
    notifyListeners();
  }

  Future<void> _preparePlayer(String url) async {
    _isVideoReady = false;
    _isPlaying = false;
    notifyListeners();

    final previous = _videoController;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    controller.setLooping(true);
    await previous?.dispose();
    _videoController = controller;
    _isVideoReady = true;
    notifyListeners();
  }

  void _handleSelection() {
    final job = _selection.selected;
    if (job == null || job.type != JobType.video) {
      return;
    }
    _currentJob = job;
    _originalVideoUrl =
        (job.parameters['originalUrl'] as String?) ?? job.previewUrl;

    _clips
      ..clear()
      ..add(
        _VideoClip(
          prompt: (job.parameters['prompt'] as String?) ?? '',
          duration: (job.parameters['duration'] as int?) ?? 5,
          resolution: (job.parameters['resolution'] as String?) ?? '480p',
          aspectRatio: (job.parameters['aspectRatio'] as String?) ?? '16:9',
          cameraFixed: (job.parameters['cameraFixed'] as bool?) ?? false,
          seed: job.parameters['seed'] as int?,
          image: job.parameters['image'] as String?,
          lastFrameImage: job.parameters['lastFrameImage'] as String?,
          referenceImages: (job.parameters['referenceImages'] as List<dynamic>?)
              ?.cast<String>(),
        ),
      );
    _isVideoReady = false;
    notifyListeners();

    final originalUrl = _originalVideoUrl;
    if (originalUrl == null) return;

    unawaited(() async {
      try {
        if (job.hasWatermark) {
          final wmFile =
              await _media.addWatermarkToVideo(inputUrl: originalUrl);
          _currentVideoUrl = wmFile.path;
        } else {
          _currentVideoUrl = originalUrl;
        }
        if (_currentVideoUrl != null) {
          await _preparePlayer(_currentVideoUrl!);
        }
      } catch (e) {
        // If watermarking fails, fall back to streaming the original URL.
        await _preparePlayer(originalUrl);
      }
    }());
  }

  @override
  void dispose() {
    _selection.removeListener(_handleSelection);
    _videoController?.dispose();
    super.dispose();
  }
}

class _VideoClip {
  _VideoClip({
    this.prompt = '',
    this.duration = 5,
    this.resolution = '480p',
    this.aspectRatio = '16:9',
    this.cameraFixed = false,
    this.seed,
    this.image,
    this.lastFrameImage,
    this.referenceImages,
  }) : id = 'clip_${_counter++}';

  static int _counter = 0;
  final String id;
  String prompt;
  int duration;
  String resolution;
  String aspectRatio;
  bool cameraFixed;
  int revision = 0;
  int? seed;
  String? image;
  String? lastFrameImage;
  List<String>? referenceImages;
}
