import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:test_app/config/secrets.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/primary_gradient_button.dart';
import 'package:test_app/ui/section_header.dart';
import 'package:video_player/video_player.dart';

// import '../app/ad_gate.dart'; // 기존 가짜 광고 삭제
import '../app/history.dart';
import '../services/media_watermark_service.dart';
import '../services/replicate_client.dart';
import '../services/admob_service.dart'; // [추가] AdMob 서비스

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoFlowController _controller;
  // [추가] AdMob 서비스 인스턴스
  final AdMobService _adMobService = AdMobService();
  bool _isSavingVideo = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoFlowController();
    // [추가] 광고 로드
    _adMobService.loadRewardedAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    // [추가] 광고 해제
    _adMobService.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    if (!Secrets.hasReplicateToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Replicate API key is missing. Please add REPLICATE_API_TOKEN to your .env file.',
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

    // [수정] AdMob 광고 표시
    final rewardEarned = await _adMobService.showRewardedAd(context);
    if (!rewardEarned) return;

    try {
      await _controller.generate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Video generated — scroll up to preview.')),
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
    if (watermarkedPath == null ||
        originalUrl == null ||
        job == null ||
        _isSavingVideo) {
      return;
    }

    Future<void> saveWithWatermarkStatus({required bool clearWatermark}) async {
      final target = clearWatermark ? originalUrl : watermarkedPath;
      if (clearWatermark) {
        await _controller.markWatermarkCleared();
      }
      await _saveVideoToGallery(target!);
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
                          
                          // [수정] 워터마크 제거 시 광고 시청
                          final rewardEarned = await _adMobService.showRewardedAd(context);
                          if (!rewardEarned) return;

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
      // [수정됨] Gal 패키지 사용
      await Gal.putVideo(url, album: 'Free AI Creation');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Photos.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingVideo = false);
      }
    }
  }

  /// 클립 편집 BottomSheet 열기 (수정됨: 안전한 위젯 사용)
  Future<void> _openClipEditor(int index) async {
    final clip = _controller.clips[index];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF050816),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _ClipEditorSheet(
          clip: clip,
          clipIndex: index,
          onDelete: () {
            Navigator.of(ctx).pop();
            _controller.removeClip(index);
          },
          onSave: (updatedData) {
            _controller.updateClip(
              index,
              prompt: updatedData['prompt'],
              duration: updatedData['duration'],
              aspectRatio: updatedData['aspectRatio'],
              cameraFixed: updatedData['cameraFixed'],
              seed: updatedData['seed'],
              image: updatedData['image'],
              lastFrameImage: updatedData['lastFrameImage'],
              referenceImages: updatedData['referenceImages'],
            );
            Navigator.of(ctx).pop();
          },
        );
      },
    );
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
                                  onTap: () => _openClipEditor(entry.key),
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
                    onPressed: _controller.isGenerating
                        ? null
                        : _handleGenerate,
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

// --- 아래부터는 새로 추가되거나 기존 클래스들입니다 ---

/// 1. 새로 추가된 편집 시트 위젯 (Crash 방지 + 키보드 처리)
class _ClipEditorSheet extends StatefulWidget {
  final _VideoClip clip;
  final int clipIndex;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onSave;

  const _ClipEditorSheet({
    required this.clip,
    required this.clipIndex,
    required this.onDelete,
    required this.onSave,
  });

  @override
  State<_ClipEditorSheet> createState() => _ClipEditorSheetState();
}

class _ClipEditorSheetState extends State<_ClipEditorSheet> {
  late final TextEditingController promptController;
  late final TextEditingController imageController;
  late final TextEditingController lastFrameController;
  late final TextEditingController referenceController;
  late final TextEditingController seedController;

  late int duration;
  late String aspectRatio;
  late bool cameraFixed;

  @override
  void initState() {
    super.initState();
    promptController = TextEditingController(text: widget.clip.prompt);
    imageController = TextEditingController(text: widget.clip.image ?? '');
    lastFrameController =
        TextEditingController(text: widget.clip.lastFrameImage ?? '');
    referenceController = TextEditingController(
      text: (widget.clip.referenceImages ?? []).join(', '),
    );
    seedController =
        TextEditingController(text: widget.clip.seed?.toString() ?? '');

    duration = widget.clip.duration.clamp(2, 5);
    aspectRatio = widget.clip.aspectRatio;
    cameraFixed = widget.clip.cameraFixed;
  }

  @override
  void dispose() {
    // 위젯이 화면에서 완전히 사라질 때 컨트롤러를 정리하여 안전합니다.
    promptController.dispose();
    imageController.dispose();
    lastFrameController.dispose();
    referenceController.dispose();
    seedController.dispose();
    super.dispose();
  }

  String? _normalizeUrl(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    const durationOptions = [2, 3, 4, 5];
    const ratioOptions = [
      '16:9',
      '4:3',
      '1:1',
      '3:4',
      '9:16',
      '21:9',
      '9:21'
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scrollController) {
        // GestureDetector를 사용하여 빈 곳 터치 시 키보드를 내립니다.
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Clip ${widget.clipIndex + 1}',
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
                      hintText: 'https://ex.com/a.png, https://ex.com/b.png',
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
                            labelText: 'Duration',
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
                              .map((d) => DropdownMenuItem(
                                  value: d, child: Text('${d}s')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => duration = val);
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
                              .map((r) => DropdownMenuItem(
                                  value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => aspectRatio = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: cameraFixed,
                    onChanged: (val) => setState(() => cameraFixed = val),
                    title: const Text(
                      'Lock camera movement',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Use reference frame and keep camera static.',
                      style: TextStyle(color: Colors.white70),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onDelete,
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

                          final refText = referenceController.text.trim();
                          final refs = refText.isEmpty
                              ? null
                              : refText
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                          widget.onSave({
                            'prompt': promptController.text,
                            'duration': duration,
                            'aspectRatio': aspectRatio,
                            'cameraFixed': cameraFixed,
                            'seed': seed,
                            'image': _normalizeUrl(imageController.text),
                            'lastFrameImage':
                                _normalizeUrl(lastFrameController.text),
                            'referenceImages': refs,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9F7CFF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
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
            ),
          ),
        );
      },
    );
  }
}

/// 2. 기존 위젯들 (변경 없음)
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
                          // [수정됨] 여기에 있던 "FREE AI CREATION" 워터마크 UI를 삭제했습니다.
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
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter a prompt and press Generate Flow to create a video.',
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

class VideoFlowController extends ChangeNotifier {
  VideoFlowController() {
    _selection.addListener(_handleSelection);
  }

  final ReplicateVideoClient _client = const ReplicateVideoClient();
  final MediaWatermarkService _media = MediaWatermarkService.instance;
  final GenerationHistory _history = GenerationHistory.instance;
  final JobSelection _selection = JobSelection.instance;

  final List<_VideoClip> _clips = [_VideoClip()];

  bool _disposed = false;
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

  bool get hasPrompts => _clips.any((clip) => clip.prompt.trim().isNotEmpty);

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> generate() async {
    final activeClips =
        _clips.where((clip) => clip.prompt.trim().isNotEmpty).toList();
    if (activeClips.isEmpty) {
      throw StateError('No prompts provided');
    }

    _isGenerating = true;
    _safeNotifyListeners();

    try {
      // [수정] 각 클립을 별도로 생성 (병렬 처리)
      // API 호출을 동시에 여러 개 보냅니다.
      final generateFutures = activeClips.map((clip) async {
        return await _client.generate(
          prompt: clip.prompt,
          durationSeconds: clip.duration.clamp(2, 5),
          resolution: '480p',
          aspectRatio: clip.aspectRatio,
          cameraFixed: clip.cameraFixed,
          fps: 24,
          seed: clip.seed,
          image: clip.image,
          lastFrameImage: clip.lastFrameImage,
          referenceImages: clip.referenceImages?.isEmpty == true
              ? null
              : clip.referenceImages,
        );
      }).toList();

      // 모든 클립이 생성될 때까지 대기
      final generatedUrls = await Future.wait(generateFutures);

      // [수정] 생성된 영상들을 하나로 합치기 (Merge)
      File finalVideoFile;
      if (generatedUrls.length == 1) {
        // 클립이 1개면 그냥 다운로드 (mergeVideos 내부에서 처리 가능하나 명시적 구분)
        finalVideoFile = await _media.mergeVideos([generatedUrls.first]);
      } else {
        // 클립이 2개 이상이면 이어 붙이기
        finalVideoFile = await _media.mergeVideos(generatedUrls);
      }

      _originalVideoUrl = finalVideoFile.path;

      // ffmpeg로 워터마크 박은 로컬 파일 생성
      final watermarkedFile = await _media.addWatermarkToVideo(
        inputUrl: _originalVideoUrl!,
      );
      _currentVideoUrl = watermarkedFile.path;
      await _preparePlayer(_currentVideoUrl!);

      // 첫 번째 클립을 기준으로 잡 정보 생성
      final first = activeClips.first;
      final job = GenerationJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: JobType.video,
        title: first.prompt.split('\n').first,
        subtitle:
            'Seedance-1-lite • ${activeClips.length} clips',
        createdAt: DateTime.now(),
        previewUrl: _originalVideoUrl!,
        parameters: {
          'prompt': first.prompt, // 단순화를 위해 첫 번째 프롬프트만 저장
          'clipCount': activeClips.length,
          'originalUrl': _originalVideoUrl,
        },
        hasWatermark: true,
        watermarkRemoved: false,
      );

      _currentJob = job;
      _history.addJob(job);
      _safeNotifyListeners();
    } finally {
      _isGenerating = false;
      _safeNotifyListeners();
    }
  }

  void addClip() {
    _clips.add(_VideoClip());
    _safeNotifyListeners();
  }

  void removeClip(int index) {
    if (_clips.length <= 1) return;
    _clips.removeAt(index);
    _safeNotifyListeners();
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
    if (referenceImages != null) {
      clip.referenceImages = referenceImages;
    }
    _safeNotifyListeners();
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
    _safeNotifyListeners();
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
    _safeNotifyListeners();
  }

  Future<void> _preparePlayer(String url) async {
    _isVideoReady = false;
    _isPlaying = false;
    _safeNotifyListeners();

    final previous = _videoController;
    VideoPlayerController controller;

    if (url.startsWith('http') || url.startsWith('https')) {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      controller = VideoPlayerController.file(File(url));
    }

    try {
      await controller.initialize();
      controller.setLooping(true);
      await previous?.dispose();
      _videoController = controller;
      _isVideoReady = true;
    } catch (e) {
      print('Video initialization error: $e');
    }

    _safeNotifyListeners();
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
          // 나머지 파라미터 복원은 단순화함
        ),
      );
    _isVideoReady = false;
    _safeNotifyListeners();

    final originalUrl = _originalVideoUrl;
    if (originalUrl == null) return;

    unawaited(() async {
      try {
        if (job.hasWatermark) {
          final wmFile = await _media.addWatermarkToVideo(
            inputUrl: originalUrl,
          );
          _currentVideoUrl = wmFile.path;
        } else {
          _currentVideoUrl = originalUrl;
        }
        if (_currentVideoUrl != null) {
          await _preparePlayer(_currentVideoUrl!);
        }
      } catch (_) {
        await _preparePlayer(originalUrl);
      }
    }());
  }

  @override
  void dispose() {
    _disposed = true;
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
  int? seed;
  String? image;
  String? lastFrameImage;
  List<String>? referenceImages;
}