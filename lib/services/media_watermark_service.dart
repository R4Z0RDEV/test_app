import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Shared media watermarking pipeline for videos and images.
///
/// This service is intentionally UI-agnostic so it can be reused from
/// Video / Image / Upscale flows.
class MediaWatermarkService {
  MediaWatermarkService._();

  static final MediaWatermarkService instance = MediaWatermarkService._();

  static const _watermarkAssetPath =
      'assets/watermark/free_ai_creation.png'; // user must provide this asset

  File? _cachedWatermarkFile;

  /// Returns a local mp4 file path with a "FREE AI CREATION" watermark baked in.
  ///
  /// [inputUrl] can be either a remote URL (https://...) or a local file path.
  Future<File> addWatermarkToVideo({
    required String inputUrl,
  }) async {
    final inputFile = await _ensureLocalFile(inputUrl, 'video_input.mp4');
    final wmPath = await _ensureWatermarkFile();

    final tempDir = await getTemporaryDirectory();
    final outputFile =
        File('${tempDir.path}/video_wm_${DateTime.now().millisecondsSinceEpoch}.mp4');

    final cmd = [
      '-y',
      '-i',
      '"${inputFile.path}"',
      '-i',
      '"$wmPath"',
      '-filter_complex',
      '"overlay=W-w-32:H-h-24"',
      '-codec:a',
      'copy',
      '"${outputFile.path}"',
    ].join(' ');

    final FFmpegSession session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputFile;
    }

    final logs = await session.getOutput();
    throw Exception(
      'FFmpeg watermark failed (${returnCode?.getValue()}): $logs',
    );
  }

  /// Downloads an image from [imageUrl], applies a bottom-right watermark,
  /// and returns the resulting local file.
  Future<File> addWatermarkToImageFromUrl(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      throw Exception(
          'Failed to download image (${response.statusCode}): ${response.body}');
    }
    return addWatermarkToImageBytes(response.bodyBytes);
  }

  /// Applies a bottom-right "FREE AI CREATION" watermark to [bytes] and
  /// writes the result into a temporary PNG file.
  Future<File> addWatermarkToImageBytes(Uint8List bytes) async {
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Unable to decode image bytes for watermarking.');
    }

    final image = img.copyResize(
      original,
      width: original.width,
      height: original.height,
    );

    // Compute overlay rect (roughly 30% width, 12% height).
    final overlayHeight =
        (image.height * 0.12).clamp(24, 96).toInt(); // between 24–96 px
    final overlayWidth =
        (image.width * 0.35).clamp(120, image.width.toDouble()).toInt();

    final margin = 24;
    final x1 = image.width - overlayWidth - margin;
    final y1 = image.height - overlayHeight - margin;
    final x2 = image.width - margin;
    final y2 = image.height - margin;

    final bgColor = img.getColor(0, 0, 0, 160); // semi-transparent black
    img.fillRect(image, x1, y1, x2, y2, bgColor);

    const text = 'FREE AI CREATION';
    final textColor = img.getColor(255, 255, 255, 230);
    final font = img.arial_24;

    final textX = x1 + 12;
    final textY = y1 + (overlayHeight ~/ 2) - (font.height ~/ 2);
    img.drawString(image, font, textX, textY, text,
        color: textColor, antialias: true);

    final encoded = img.encodePng(image);
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/image_wm_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<File> _ensureLocalFile(String input, String fileNameHint) async {
    final uri = Uri.tryParse(input);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final response = await http.get(uri);
      if (response.statusCode >= 400) {
        throw Exception(
            'Failed to download video (${response.statusCode}): ${response.body}');
      }
      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/$fileNameHint-${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    }

    final file = File(input);
    if (await file.exists()) return file;
    throw Exception('Input media not found: $input');
  }

  Future<String> _ensureWatermarkFile() async {
    final existing = _cachedWatermarkFile;
    if (existing != null && await existing.exists()) {
      return existing.path;
    }

    final bytes = await rootBundle.load(_watermarkAssetPath);
    final tempDir = await getTemporaryDirectory();
    final file =
        File('${tempDir.path}/wm_free_ai_creation.png');
    await file.writeAsBytes(
      bytes.buffer.asUint8List(),
      flush: true,
    );
    _cachedWatermarkFile = file;
    return file.path;
  }
}


