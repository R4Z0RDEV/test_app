import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:test_app/config/secrets.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/primary_gradient_button.dart';
import 'package:test_app/ui/section_header.dart';

import '../app/ad_gate.dart';
import '../app/history.dart';
import '../services/media_watermark_service.dart';
import '../services/replicate_client.dart';

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  late final ImageGenerationController _controller;
  final MediaWatermarkService _media = MediaWatermarkService.instance;
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _controller = ImageGenerationController();
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
    if (_controller.promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the image you want.')),
      );
      return;
    }

    final gated = await showRewardAdGate(
      context,
      reason: AdRewardReason.generateImage,
    );
    if (!gated) return;

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
    if (url == null || job == null || _isSavingImage) return;

    Future<void> saveImage({required bool withWatermark}) async {
      setState(() => _isSavingImage = true);
      try {
        File file;
        if (withWatermark) {
          file = await _media.addWatermarkToImageFromUrl(url);
        } else {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode >= 400) {
            throw Exception(
                '이미지를 다운로드하지 못했습니다. (${response.statusCode})');
          }
          final dir = await getTemporaryDirectory();
          file = File(
              '${dir.path}/image_raw_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(response.bodyBytes, flush: true);
        }

        final ok = await GallerySaver.saveImage(
          file.path,
          albumName: 'Free AI Creation',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok == true
                  ? '사진 앱에 저장했습니다.'
                  : '저장에 실패했습니다. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 저장 실패: $e')),
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
                          final unlocked = await showRewardAdGate(
                            context,
                            reason: AdRewardReason.removeImageWatermark,
                          );
                          if (!unlocked) return;
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
                  child: _ImagePreview(controller: _controller, onDownload: _handleDownload),
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
                            'Free to use, ad-supported. 워터마크 제거 및 고해상도 다운로드를 위해서는 보상형 광고를 시청해야 합니다.',
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

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.controller, required this.onDownload});

  final ImageGenerationController controller;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final hasImage = controller.imageUrl != null;
    final theme = Theme.of(context);

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
                      child: Image.network(
                        controller.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.red.withOpacity(0.8),
                              size: 48,
                            ),
                          );
                        },
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
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            ,
      ),
    );
  }
}

class _ImageForm extends StatelessWidget {
  const _ImageForm({required this.controller});

  final ImageGenerationController controller;

  static const sizeOptions = [
    64,
    128,
    192,
    256,
    320,
    384,
    448,
    512,
    576,
    640,
    704,
    768,
    832,
    896,
    960,
    1024,
  ];

  static const schedulerOptions = [
    'DDIM',
    'K_EULER',
    'DPMSolverMultistep',
    'K_EULER_ANCESTRAL',
    'PNDM',
    'KLMS',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prompt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            ),
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
          const Text(
            'Negative prompt (optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            ),
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
                  items: sizeOptions
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                      ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.setWidth(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: controller.height,
                  decoration: _dropdownDecoration('Height'),
                  dropdownColor: const Color(0xFF111322),
                  items: sizeOptions
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.setHeight(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: controller.scheduler,
            decoration: _dropdownDecoration('Scheduler'),
            dropdownColor: const Color(0xFF111322),
            items: schedulerOptions
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: controller.setScheduler,
          ),
          const SizedBox(height: 16),
          Text(
            'Guidance scale: ${controller.guidanceScale.toStringAsFixed(1)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: controller.guidanceScale,
            onChanged: controller.setGuidanceScale,
            min: 1,
            max: 20,
            divisions: 38,
            activeColor: const Color(0xFF4ADE80),
          ),
          const SizedBox(height: 8),
          Text(
            'Inference steps: ${controller.inferenceSteps}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: controller.inferenceSteps.toDouble(),
            onChanged: (value) => controller.setInferenceSteps(value.toInt()),
            min: 1,
            max: 500,
            divisions: 499,
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
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

  final TextEditingController promptController = TextEditingController();
  final TextEditingController negativePromptController = TextEditingController();

  bool _disposed = false;
  String? _imageUrl;
  GenerationJob? _currentJob;
  bool _isGenerating = false;
  int _width = 768;
  int _height = 768;
  String _scheduler = 'K_EULER';
  double _guidanceScale = 7.5;
  int _numSteps = 50;

  String? get imageUrl => _imageUrl;
  GenerationJob? get currentJob => _currentJob;
  bool get isGenerating => _isGenerating;
  int get width => _width;
  int get height => _height;
  String get scheduler => _scheduler;
  double get guidanceScale => _guidanceScale;
  int get inferenceSteps => _numSteps;

  void _safeNotifyListeners() {
    if (!_disposed) {
      _safeNotifyListeners();
    }
  }

  Future<void> generate() async {
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      throw StateError('Prompt is empty');
    }

    _isGenerating = true;
    _safeNotifyListeners();

    try {
      final imageUrl = await _client.generate(
        prompt: prompt,
        width: _width,
        height: _height,
        scheduler: _scheduler,
        guidanceScale: _guidanceScale,
        numInferenceSteps: _numSteps,
        negativePrompt: negativePromptController.text.trim().isEmpty
            ? null
            : negativePromptController.text.trim(),
      );

      _imageUrl = imageUrl;

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
    final updated = job.copyWith(
      hasWatermark: false,
      watermarkRemoved: true,
    );
    _currentJob = updated;
    _history.updateJob(updated);
    _safeNotifyListeners();
  }

  void setWidth(int value) {
    if (_width == value) return;
    _width = value;
    _safeNotifyListeners();
  }

  void setHeight(int value) {
    if (_height == value) return;
    _height = value;
    _safeNotifyListeners();
  }

  void setScheduler(String? value) {
    if (value == null || _scheduler == value) return;
    _scheduler = value;
    _safeNotifyListeners();
  }

  void setGuidanceScale(double value) {
    if (_guidanceScale == value) return;
    _guidanceScale = value;
    _safeNotifyListeners();
  }

  void setInferenceSteps(int value) {
    if (_numSteps == value) return;
    _numSteps = value;
    _safeNotifyListeners();
  }

  void _handleSelection() {
    final job = _selection.selected;
    if (job == null || job.type != JobType.image) return;

    _currentJob = job;
    _imageUrl = job.previewUrl;

    promptController.text = (job.parameters['prompt'] as String?) ?? '';
    negativePromptController.text =
        (job.parameters['negativePrompt'] as String?) ?? '';
    _width = (job.parameters['width'] as int?) ?? 768;
    _height = (job.parameters['height'] as int?) ?? 768;
    _scheduler = (job.parameters['scheduler'] as String?) ?? 'K_EULER';
    _guidanceScale =
        (job.parameters['guidanceScale'] as num?)?.toDouble() ?? 7.5;
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
