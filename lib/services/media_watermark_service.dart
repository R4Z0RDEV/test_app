import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

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

  /// [추가됨] 여러 영상 파일을 하나로 이어 붙이기 (Merge)
  Future<File> mergeVideos(List<String> videoUrls) async {
    final dir = await getTemporaryDirectory();
    final txtFile = File('${dir.path}/merge_list.txt');
    
    // 1. 영상들을 모두 다운로드하고, ffmpeg concat 리스트 파일 작성
    // 포맷: file '/path/to/video1.mp4'
    final sb = StringBuffer();
    
    for (int i = 0; i < videoUrls.length; i++) {
      final file = await _ensureLocalFile(videoUrls[i], 'clip_$i.mp4');
      sb.writeln("file '${file.path}'");
    }
    
    await txtFile.writeAsString(sb.toString());

    final outputPath = '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 2. FFmpeg Concat 명령 실행
    // -f concat: 이어붙이기 모드
    // -safe 0: 경로 허용
    // -c copy: 재인코딩 없이 복사 (빠름)
    final cmd = '-f concat -safe 0 -i "${txtFile.path}" -c copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      throw Exception('Failed to merge videos');
    }
  }

  /// 1) 비디오에 PNG 워터마크 입힌 새 mp4 파일 생성 (ffmpeg)
  Future<File> addWatermarkToVideo({required String inputUrl}) async {
    // 입력 비디오가 URL이면 다운로드, 아니면 로컬 파일 사용
    final inputFile = await _ensureLocalFile(inputUrl, 'video_input_for_wm.mp4');
    
    final wmBytes =
        await rootBundle.load('assets/watermark/free_ai_creation.png');
    final tmpDir = await getTemporaryDirectory();
    final wmFile = File('${tmpDir.path}/wm.png');
    await wmFile.writeAsBytes(wmBytes.buffer.asUint8List());

    final outputPath =
        '${tmpDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 워터마크: 너비 350px, 왼쪽 하단 배치
    final cmd =
        '-i "${inputFile.path}" -i "${wmFile.path}" -filter_complex "[1:v]scale=350:-1[wm];[0:v][wm]overlay=24:H-h-24" -codec:a copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      print('FFmpeg failed to add watermark. Returning original.');
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
    final wmBytes = await rootBundle.load('assets/watermark/free_ai_creation.png');
    
    // Isolate에서 처리할 데이터 준비
    final data = _WatermarkTaskData(
      imageBytes: bytes,
      watermarkBytes: wmBytes.buffer.asUint8List(),
    );

    // compute 함수로 백그라운드 실행
    final outBytes = await compute(_processImageWatermark, data);

    final dir = await getTemporaryDirectory();
    final outFile = File(
        '${dir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.png');
    await outFile.writeAsBytes(outBytes);

    return outFile;
  }
}

/// Isolate 전달용 데이터 클래스
class _WatermarkTaskData {
  final Uint8List imageBytes;
  final Uint8List watermarkBytes;

  _WatermarkTaskData({
    required this.imageBytes,
    required this.watermarkBytes,
  });
}

/// Isolate에서 실행될 정적/최상위 함수
Uint8List _processImageWatermark(_WatermarkTaskData data) {
  final original = img.decodeImage(data.imageBytes);
  if (original == null) {
    throw Exception('Invalid input image bytes');
  }

  final wmImage = img.decodeImage(data.watermarkBytes);
  if (wmImage == null) {
    throw Exception('Invalid watermark image');
  }

  final targetW = (original.width * 0.3).round().clamp(1, original.width);
  final resizedWm = img.copyResize(
    wmImage,
    width: targetW,
  );

  const margin = 24;
  // 왼쪽 하단 배치
  final dstX = margin;
  final dstY = original.height - resizedWm.height - margin;

  final composited = img.compositeImage(
    original,
    resizedWm,
    dstX: dstX,
    dstY: dstY,
  );

  return img.encodePng(composited);
}