// lib/services/media_watermark_service.dart

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

  /// 1) 비디오에 PNG 워터마크 입힌 새 mp4 파일 생성
  Future<File> addWatermarkToVideo({required String inputUrl}) async {
    // 입력 비디오를 로컬 파일로 확보
    final inputFile = await _ensureLocalFile(inputUrl, 'video_input.mp4');

    // 워터마크 PNG를 임시 디렉토리에 저장
    final wmBytes =
        await rootBundle.load('assets/watermark/free_ai_creation.png');
    final tmpDir = await getTemporaryDirectory();
    final wmFile = File('${tmpDir.path}/wm.png');
    await wmFile.writeAsBytes(wmBytes.buffer.asUint8List());

    // 출력 경로
    final outputPath =
        '${tmpDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // ffmpeg 명령어: 우측 하단에 overlay
    final cmd =
        '-i "${inputFile.path}" -i "${wmFile.path}" -filter_complex "overlay=W-w-32:H-h-24" -codec:a copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      // 실패하면 원본 비디오라도 리턴해서 앱이 죽지 않게
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

  /// 3) 바이트 배열 이미지를 받아 워터마크 PNG 합성
  Future<File> addWatermarkToImageBytes(Uint8List bytes) async {
    // 원본 이미지 디코드
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Invalid input image bytes');
    }

    // 워터마크 PNG 로드 & 디코드
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

    // 우측 하단 위치 계산
    const margin = 24;
    final dstX = original.width - resizedWm.width - margin;
    final dstY = original.height - resizedWm.height - margin;

    // 워터마크 합성 (현재 image 패키지 버전에 맞게 compositeImage 사용)
    final composited = img.compositeImage(
      original,
      resizedWm,
      dstX: dstX,
      dstY: dstY,
    );

    // PNG로 인코드 후 temp 파일에 저장
    final outBytes = img.encodePng(composited);
    final dir = await getTemporaryDirectory();
    final outFile = File(
        '${dir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.png');
    await outFile.writeAsBytes(outBytes);

    return outFile;
  }
}