import 'dart:typed_data';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test_app/config/secrets.dart';
import 'package:test_app/theme/app_theme.dart';
import 'package:test_app/ui/glass_card.dart';
import 'package:test_app/ui/primary_gradient_button.dart';
import 'package:test_app/ui/section_header.dart';

// import '../app/ad_gate.dart'; // 기존 가짜 광고 삭제
import '../app/history.dart';
import '../services/replicate_client.dart';
import '../services/admob_service.dart'; // [추가] AdMob 서비스 임포트

class UpscaleScreen extends StatefulWidget {
  const UpscaleScreen({super.key});

  @override
  State<UpscaleScreen> createState() => _UpscaleScreenState();
}

class _UpscaleScreenState extends State<UpscaleScreen> {
  late final UpscaleController _controller;
  
  // [추가] AdMob 서비스 인스턴스 생성
  final AdMobService _adMobService = AdMobService();
  
  String? _friendlyError;
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _controller = UpscaleController();
    
    // [추가] 화면 진입 시 광고 미리 로드
    _adMobService.loadRewardedAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    // [추가] AdMob 리소스 해제
    _adMobService.dispose();
    super.dispose();
  }

  Future<void> _handleUpscale() async {
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
    if (!_controller.hasLocalImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('업스케일할 이미지를 먼저 업로드해 주세요.'),
        ),
      );
      return;
    }

    // [수정] 기존 가짜 광고 대신 AdMob 보상형 광고 표시
    // final gated = await showRewardAdGate(...) -> 삭제됨

    // 광고 보여주기 & 결과 대기
    final rewardEarned = await _adMobService.showRewardedAd(context);

    // 보상을 받지 못했으면(광고 닫음, 실패 등) 중단
    if (!rewardEarned) return;

    try {
      await _controller.upscale();
      if (!mounted) return;
      setState(() => _friendlyError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upscaled! Slide to compare.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _friendlyError = _mapError(e.toString()));
    }
  }

  Future<void> _handleDownload() async {
    final url = _controller.upscaledUrl;
    if (url == null || _isSavingImage) return;

    setState(() => _isSavingImage = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 400) {
        throw Exception('업스케일 이미지를 다운로드하지 못했습니다. (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/upscaled_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      final ok = await GallerySaver.saveImage(
        file.path,
        albumName: 'Free AI Creation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == true
                ? '업스케일 이미지를 사진 앱에 저장했습니다.'
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

  String _mapError(String raw) {
    if (raw.contains('Missing content')) {
      return '이미지를 업로드하지 못했어요. 잠시 후 다시 시도하거나 다른 파일을 선택해 주세요.';
    }
    if (raw.contains('No upscaled image URL')) {
      return '업스케일 결과를 받지 못했습니다. 이미지 해상도를 조금 낮춰 다시 시도해 주세요.';
    }
    if (raw.toLowerCase().contains('too large') ||
        raw.toLowerCase().contains('memory')) {
      return '이미지 해상도가 너무 커서 GPU 메모리 한도를 초과했습니다. 사진을 조금 줄인 뒤 다시 시도해 주세요.';
    }
    return '업스케일 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';
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
                  child: _UpscalePreview(
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
                            'Real-ESRGAN',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _UpscaleForm(controller: _controller),
                        const SizedBox(height: 16),
                        if (_friendlyError != null)
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 4,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: kDangerColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _friendlyError!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
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
                    label: 'Upscale Image',
                    onPressed:
                        _controller.isUpscaling || !_controller.hasLocalImage
                            ? null
                            : _handleUpscale,
                    isLoading: _controller.isUpscaling,
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

class _UpscalePreview extends StatelessWidget {
  const _UpscalePreview({required this.controller, required this.onDownload});

  final UpscaleController controller;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final hasBoth =
        (controller.originalUrl != null || controller.originalBytes != null) &&
            controller.upscaledUrl != null;

    return GlassCard(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: hasBoth
            ? Column(
                children: [
                  SizedBox(
                    height: 260,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final split = width * controller.sliderValue;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: _buildOriginalImage(BoxFit.cover),
                            ),
                            Positioned.fill(
                              child: ClipRect(
                                clipper: _SplitClipper(controller.sliderValue),
                                child: CachedNetworkImage(
                                  imageUrl: controller.upscaledUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const SizedBox(),
                                ),
                              ),
                            ),
                            Positioned(
                              left: split - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 2, color: Colors.white),
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppGradients.primary,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  color: Colors.white,
                                  onPressed: onDownload,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              top: 16,
                              child: _PreviewLabel('UPSCALED'),
                            ),
                            Positioned(
                              right: 16,
                              top: 16,
                              child: _PreviewLabel('ORIGINAL'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: controller.sliderValue,
                    onChanged: controller.setSliderValue,
                    activeColor: const Color(0xFF38BDF8),
                  ),
                ],
              )
            : SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    controller.originalBytes != null ||
                            controller.originalUrl != null
                        ? 'Upscale to view the before & after slider.'
                        : 'Paste an image URL or upload a photo to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOriginalImage(BoxFit fit) {
    final bytes = controller.originalBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.error_outline, color: Colors.red),
          );
        },
      );
    }

    final url = controller.originalUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );
    }
    return const SizedBox();
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _UpscaleForm extends StatelessWidget {
  const _UpscaleForm({required this.controller});

  final UpscaleController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.pickLocalImage,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload from device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.85),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (controller.hasLocalImage) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: controller.clearLocalImage,
                  child: const Text('Remove'),
                ),
              ],
            ],
          ),
          if (controller.hasLocalImage) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      controller.localImageName ?? 'Local image selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Scale: ${controller.scale.toStringAsFixed(1)}x',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: controller.scale,
            onChanged: controller.setScale,
            min: 1,
            max: 8,
            divisions: 28,
            activeColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: controller.faceEnhance,
            onChanged: controller.setFaceEnhance,
            title: const Text(
              'Face enhancement',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Helps portraits stay sharp during upscales.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            activeColor: const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }
}

class UpscaleController extends ChangeNotifier {
  UpscaleController() {
    _selection.addListener(_handleSelection);
  }

  final ReplicateUpscaleClient _client = const ReplicateUpscaleClient();
  final GenerationHistory _history = GenerationHistory.instance;
  final JobSelection _selection = JobSelection.instance;

  final ReplicateFileUploader _uploader = const ReplicateFileUploader();
  bool _disposed = false;
  double _scale = 4;
  bool _faceEnhance = false;
  String? _originalUrl;
  Uint8List? _originalBytes;
  String? _upscaledUrl;
  GenerationJob? _currentJob;
  bool _isUpscaling = false;
  double _sliderValue = 0.5;
  String? _localImageName;

  double get scale => _scale;
  bool get faceEnhance => _faceEnhance;
  String? get originalUrl => _originalUrl;
  Uint8List? get originalBytes => _originalBytes;
  String? get upscaledUrl => _upscaledUrl;
  GenerationJob? get currentJob => _currentJob;
  bool get isUpscaling => _isUpscaling;
  double get sliderValue => _sliderValue;
  bool get hasLocalImage => _originalBytes != null;
  String? get localImageName => _localImageName;

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> upscale() async {
    if (!hasLocalImage || _originalBytes == null || _localImageName == null) {
      throw StateError('Local image required');
    }

    final uploadUrl = await _uploader.uploadBytes(
      bytes: _originalBytes!,
      filename: _localImageName!,
      contentType: _inferMimeType(_localImageName!),
    );

    _isUpscaling = true;
    _safeNotifyListeners();

    try {
      final upscaled = await _client.upscale(
        imageUrl: uploadUrl,
        scale: _scale,
        faceEnhance: _faceEnhance,
      );

      // _originalUrl은 로컬 업로드 시 null일 수 있으므로 덮어쓰지 않음
      _upscaledUrl = upscaled;
      _sliderValue = 0.5;

      final job = GenerationJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: JobType.upscale,
        title: 'Upscaled x${_scale.toStringAsFixed(1)}',
        subtitle: 'Real-ESRGAN • scale ${_scale.toStringAsFixed(1)}',
        createdAt: DateTime.now(),
        previewUrl: upscaled,
        parameters: {
          'image': uploadUrl,
          'scale': _scale,
          'face_enhance': _faceEnhance,
        },
        hasWatermark: false,
        watermarkRemoved: true,
      );

      _currentJob = job;
      _history.addJob(job);
      _safeNotifyListeners();
    } finally {
      _isUpscaling = false;
      _safeNotifyListeners();
    }
  }

  void setScale(double value) {
    _scale = double.parse(value.toStringAsFixed(1));
    _safeNotifyListeners();
  }

  void setFaceEnhance(bool value) {
    if (_faceEnhance == value) return;
    _faceEnhance = value;
    _safeNotifyListeners();
  }

  void setSliderValue(double value) {
    _sliderValue = value;
    _safeNotifyListeners();
  }

  Future<void> pickLocalImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    _originalBytes = bytes;
    _originalUrl = null;
    _localImageName = picked.name;
    _safeNotifyListeners();
  }

  void clearLocalImage() {
    _originalBytes = null;
    _localImageName = null;
    _safeNotifyListeners();
  }

  void _handleSelection() {
    final job = _selection.selected;
    if (job == null || job.type != JobType.upscale) return;

    _currentJob = job;
    _upscaledUrl = job.previewUrl;
    _originalUrl = job.parameters['image'] as String?;
    _originalBytes = null;
    _localImageName = null;
    _scale = (job.parameters['scale'] as num?)?.toDouble() ?? 4;
    _faceEnhance = (job.parameters['face_enhance'] as bool?) ?? false;
    _sliderValue = 0.5;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _selection.removeListener(_handleSelection);
    super.dispose();
  }

  String _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

class _SplitClipper extends CustomClipper<Rect> {
  _SplitClipper(this.sliderValue);

  final double sliderValue;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * sliderValue, size.height);
  }

  @override
  bool shouldReclip(covariant _SplitClipper oldClipper) {
    return oldClipper.sliderValue != sliderValue;
  }
}