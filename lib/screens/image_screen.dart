import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:test_app/config/secrets.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/primary_gradient_button.dart';
import 'package:test_app/ui/section_header.dart';

// import '../app/ad_gate.dart'; // 가짜 광고 삭제
import '../app/history.dart';
import '../services/media_watermark_service.dart';
import '../services/replicate_client.dart';
import '../services/admob_service.dart'; // AdMob 서비스

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  late final ImageGenerationController _controller;
  final MediaWatermarkService _media = MediaWatermarkService.instance;
  
  // AdMob 서비스 인스턴스
  final AdMobService _adMobService = AdMobService();
  
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _controller = ImageGenerationController();
    
    // 화면 진입 시 광고 미리 로드
    _adMobService.loadRewardedAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    // 광고 리소스 해제
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
    if (_controller.promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the image you want.')),
      );
      return;
    }

    // [수정] AdMob 보상형 광고 표시
    final rewardEarned = await _adMobService.showRewardedAd(context);

    // 보상을 받지 못했으면(광고 닫음, 실패 등) 중단
    if (!rewardEarned) return;

    try {
      await _controller.generate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image generated — preview updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image error: $e')),
      );
    }
  }

  Future<void> _handleDownload() async {
    final url = _controller.imageUrl;
    final job = _controller.currentJob;
    final wmFile = _controller.watermarkedFile;
    
    if (url == null || job == null || _isSavingImage) return;

    Future<void> saveImage({required bool withWatermark}) async {
      setState(() => _isSavingImage = true);
      try {
        File fileToSave;
        
        if (withWatermark) {
          if (wmFile != null && await wmFile.exists()) {
            fileToSave = wmFile;
          } else {
            fileToSave = await _media.addWatermarkToImageFromUrl(url);
          }
        } else {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode >= 400) {
            throw Exception(
                'Failed to download image. (${response.statusCode})');
          }
          final dir = await getTemporaryDirectory();
          fileToSave = File(
              '${dir.path}/image_raw_${DateTime.now().millisecondsSinceEpoch}.png');
          await fileToSave.writeAsBytes(response.bodyBytes, flush: true);
        }

        // [수정됨] Gal 패키지 사용
        await Gal.putImage(fileToSave.path, album: 'Free AI Creation');
        
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
          setState(() => _isSavingImage = false);
        }
      }
    }

    if (!job.hasWatermark) {
      await saveImage(withWatermark: false);
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
                  'Save image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSavingImage
                      ? null
                      : () {
                          Navigator.pop(context);
                          saveImage(withWatermark: true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save with watermark'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSavingImage
                      ? null
                      : () async {
                          Navigator.pop(context);
                          
                          // [수정] 워터마크 제거 시 AdMob 광고 시청
                          final rewardEarned = await _adMobService.showRewardedAd(context);
                          if (!rewardEarned) return;
                          
                          await _controller.markWatermarkCleared();
                          if (!mounted) return;
                          await saveImage(withWatermark: false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ADE80),
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
                  child: _ImagePreview(
                      controller: _controller, onDownload: _handleDownload),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        SectionHeader(
                          title: 'Parameters',
                          trailing: Text(
                            'Stable Diffusion',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ImageForm(controller: _controller),
                        const SizedBox(height: 16),
                        GlassCard(
                          child: Text(
                            'Free to use, ad-supported. Watch a rewarded ad to remove watermark and download in high resolution.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white60),
                          ),
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
                    label: 'Generate Image',
                    onPressed:
                        _controller.isGenerating ? null : _handleGenerate,
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

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.controller, required this.onDownload});

  final ImageGenerationController controller;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final hasImage = controller.imageUrl != null;
    final wmFile = controller.watermarkedFile;
    final showLocalFile = wmFile != null && (controller.currentJob?.hasWatermark ?? true);

    return GlassCard(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: controller.width / controller.height,
                      child: showLocalFile
                          ? Image.file(
                              wmFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return CachedNetworkImage(
                                  imageUrl: controller.imageUrl!,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : CachedNetworkImage(
                              imageUrl: controller.imageUrl!,
                              fit: BoxFit.cover,
                              progressIndicatorBuilder:
                                  (context, url, downloadProgress) =>
                                      const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.red.withOpacity(0.8),
                                  size: 48,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF9B5CFF), Color(0xFFDB5CFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.download_rounded),
                          color: Colors.white,
                          onPressed: onDownload,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 240,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [kPurpleStart, kPurpleEnd],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: const Icon(Icons.brush_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generate your first image to see it here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ImageForm extends StatelessWidget {
  const _ImageForm({required this.controller});

  final ImageGenerationController controller;

  static const sizeOptions = [
    64, 128, 192, 256, 320, 384, 448, 512, 576, 640, 704, 768, 832, 896, 960, 1024,
  ];

  static const schedulerOptions = [
    'DDIM', 'K_EULER', 'DPMSolverMultistep', 'K_EULER_ANCESTRAL', 'PNDM', 'KLMS',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prompt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller.promptController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'A cinematic portrait of a cyberpunk explorer...',
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Negative prompt (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller.negativePromptController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'blurry, low quality, watermark',
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: controller.width,
                  decoration: _dropdownDecoration('Width'),
                  dropdownColor: const Color(0xFF111322),
                  items: sizeOptions.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) { if (v != null) controller.setWidth(v); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: controller.height,
                  decoration: _dropdownDecoration('Height'),
                  dropdownColor: const Color(0xFF111322),
                  items: sizeOptions.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) { if (v != null) controller.setHeight(v); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: controller.scheduler,
            decoration: _dropdownDecoration('Scheduler'),
            dropdownColor: const Color(0xFF111322),
            items: schedulerOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: controller.setScheduler,
          ),
          const SizedBox(height: 16),
          Text('Guidance scale: ${controller.guidanceScale.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: controller.guidanceScale,
            onChanged: controller.setGuidanceScale,
            min: 1, max: 20, divisions: 38,
            activeColor: const Color(0xFF4ADE80),
          ),
          const SizedBox(height: 8),
          Text('Inference steps: ${controller.inferenceSteps}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: controller.inferenceSteps.toDouble(),
            onChanged: (v) => controller.setInferenceSteps(v.toInt()),
            min: 1, max: 500, divisions: 499,
            activeColor: const Color(0xFF4ADE80),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}

class ImageGenerationController extends ChangeNotifier {
  ImageGenerationController() {
    _selection.addListener(_handleSelection);
  }

  final ReplicateImageClient _client = const ReplicateImageClient();
  final GenerationHistory _history = GenerationHistory.instance;
  final JobSelection _selection = JobSelection.instance;
  final MediaWatermarkService _media = MediaWatermarkService.instance;

  final TextEditingController promptController = TextEditingController();
  final TextEditingController negativePromptController = TextEditingController();

  bool _disposed = false;
  String? _imageUrl;
  File? _watermarkedFile;

  GenerationJob? _currentJob;
  bool _isGenerating = false;
  int _width = 768;
  int _height = 768;
  String _scheduler = 'K_EULER';
  double _guidanceScale = 7.5;
  int _numSteps = 50;

  String? get imageUrl => _imageUrl;
  File? get watermarkedFile => _watermarkedFile;
  GenerationJob? get currentJob => _currentJob;
  bool get isGenerating => _isGenerating;
  int get width => _width;
  int get height => _height;
  String get scheduler => _scheduler;
  double get guidanceScale => _guidanceScale;
  int get inferenceSteps => _numSteps;

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  Future<void> generate() async {
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) throw StateError('Prompt is empty');

    _isGenerating = true;
    _watermarkedFile = null;
    _safeNotifyListeners();

    try {
      final imageUrl = await _client.generate(
        prompt: prompt,
        width: _width,
        height: _height,
        scheduler: _scheduler,
        guidanceScale: _guidanceScale,
        numInferenceSteps: _numSteps,
        negativePrompt: negativePromptController.text.trim().isEmpty ? null : negativePromptController.text.trim(),
      );

      _imageUrl = imageUrl;

      try {
        _watermarkedFile = await _media.addWatermarkToImageFromUrl(imageUrl);
      } catch (e) {
        print('Watermark creation failed during generation: $e');
      }

      final job = GenerationJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: JobType.image,
        title: prompt.split('\n').first,
        subtitle: 'Stable Diffusion • ${_width}x$_height • $_scheduler',
        createdAt: DateTime.now(),
        previewUrl: imageUrl,
        parameters: {
          'prompt': prompt,
          'negativePrompt': negativePromptController.text.trim(),
          'width': _width,
          'height': _height,
          'scheduler': _scheduler,
          'guidanceScale': _guidanceScale,
          'numSteps': _numSteps,
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

  Future<void> markWatermarkCleared() async {
    final job = _currentJob;
    if (job == null || !job.hasWatermark) return;
    final updated = job.copyWith(hasWatermark: false, watermarkRemoved: true);
    _currentJob = updated;
    _history.updateJob(updated);
    _safeNotifyListeners();
  }

  void setWidth(int value) { if (_width != value) { _width = value; _safeNotifyListeners(); } }
  void setHeight(int value) { if (_height != value) { _height = value; _safeNotifyListeners(); } }
  void setScheduler(String? value) { if (value != null && _scheduler != value) { _scheduler = value; _safeNotifyListeners(); } }
  void setGuidanceScale(double value) { if (_guidanceScale != value) { _guidanceScale = value; _safeNotifyListeners(); } }
  void setInferenceSteps(int value) { if (_numSteps != value) { _numSteps = value; _safeNotifyListeners(); } }

  void _handleSelection() {
    final job = _selection.selected;
    if (job == null || job.type != JobType.image) return;

    _currentJob = job;
    _imageUrl = job.previewUrl;
    _watermarkedFile = null;

    promptController.text = (job.parameters['prompt'] as String?) ?? '';
    negativePromptController.text = (job.parameters['negativePrompt'] as String?) ?? '';
    _width = (job.parameters['width'] as int?) ?? 768;
    _height = (job.parameters['height'] as int?) ?? 768;
    _scheduler = (job.parameters['scheduler'] as String?) ?? 'K_EULER';
    _guidanceScale = (job.parameters['guidanceScale'] as num?)?.toDouble() ?? 7.5;
    _numSteps = (job.parameters['numSteps'] as int?) ?? 50;

    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _selection.removeListener(_handleSelection);
    promptController.dispose();
    negativePromptController.dispose();
    super.dispose();
  }
}