import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class MediaWatermarkService {
  MediaWatermarkService._();

  static final MediaWatermarkService instance = MediaWatermarkService._();

  /// 공통: URL이면 다운로드, 로컬 경로면 그냥 File 리턴
  Future<File> _ensureLocalFile(String input, String fileName) async {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      final res = await http.get(Uri.parse(input));
      if (res.statusCode != 200) {
        throw Exception('Failed to download file ($input)');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);
      return file;
    } else {
      return File(input);
    }
  }

  /// 1) 비디오에 PNG 워터마크 입힌 새 mp4 파일 생성 (ffmpeg)
  Future<File> addWatermarkToVideo({required String inputUrl}) async {
    final inputFile = await _ensureLocalFile(inputUrl, 'video_input.mp4');
    final wmBytes =
        await rootBundle.load('assets/watermark/free_ai_creation.png');
    final tmpDir = await getTemporaryDirectory();
    final wmFile = File('${tmpDir.path}/wm.png');
    await wmFile.writeAsBytes(wmBytes.buffer.asUint8List());

    final outputPath =
        '${tmpDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 워터마크 너비를 350px로 리사이즈하고 왼쪽 하단(여백 24px)에 배치
    final cmd =
        '-i "${inputFile.path}" -i "${wmFile.path}" -filter_complex "[1:v]scale=350:-1[wm];[0:v][wm]overlay=24:H-h-24" -codec:a copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      print('FFmpeg failed. Outputting original file instead.');
      return inputFile;
    }
  }

  /// 2) URL에서 이미지 받아서 워터마크 PNG 합성
  Future<File> addWatermarkToImageFromUrl(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Failed to download image ($url)');
    }
    return addWatermarkToImageBytes(res.bodyBytes);
  }

  /// 3) 바이트 배열 이미지를 받아 워터마크 PNG 합성 (image 패키지 사용)
  Future<File> addWatermarkToImageBytes(Uint8List bytes) async {
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Invalid input image bytes');
    }

    final wmBytes =
        await rootBundle.load('assets/watermark/free_ai_creation.png');
    final wmImage = img.decodeImage(wmBytes.buffer.asUint8List());
    if (wmImage == null) {
      throw Exception('Invalid watermark image');
    }

    // 워터마크를 원본 폭의 약 30% 정도로 리사이즈
    final targetW = (original.width * 0.3).round().clamp(1, original.width);
    final resizedWm = img.copyResize(
      wmImage,
      width: targetW,
    );

    const margin = 24;
    // [수정됨] 왼쪽 하단 위치 계산
    final dstX = margin; // 왼쪽 여백만 둠
    final dstY = original.height - resizedWm.height - margin; // 바닥 여백

    final composited = img.compositeImage(
      original,
      resizedWm,
      dstX: dstX,
      dstY: dstY,
    );

    final outBytes = img.encodePng(composited);
    final dir = await getTemporaryDirectory();
    final outFile = File(
        '${dir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.png');
    await outFile.writeAsBytes(outBytes);

    return outFile;
  }
}