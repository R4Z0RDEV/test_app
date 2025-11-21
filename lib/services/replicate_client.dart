import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config/secrets.dart';

class ReplicateAuth {
  static String get _token => Secrets.replicateToken;

  static void ensureToken() {
    if (!Secrets.hasReplicateToken) {
      throw StateError(
        'REPLICATE_API_TOKEN is not set. Add it to your .env file.',
      );
    }
  }

  static Map<String, String> get authHeaders => {
        HttpHeaders.authorizationHeader: 'Bearer $_token',
      };
}

// ---------- Video (Seedance-1-lite) ----------

class ReplicateVideoClient {
  static const _endpoint =
      'https://api.replicate.com/v1/models/bytedance/seedance-1-lite/predictions';

  const ReplicateVideoClient();

  Future<String> generate({
    required String prompt,
    int durationSeconds = 5,
    String resolution = '720p',
    String aspectRatio = '16:9',
    bool cameraFixed = false,
    String? image,
    String? lastFrameImage,
    List<String>? referenceImages,
    int? seed,
    int fps = 24,
  }) async {
    ReplicateAuth.ensureToken();

    final uri = Uri.parse(_endpoint);
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${ReplicateAuth._token}')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('Prefer', 'wait');

      final input = <String, dynamic>{
        'prompt': prompt,
        'duration': durationSeconds,
        'resolution': resolution,
        'aspect_ratio': aspectRatio,
        'camera_fixed': cameraFixed,
        'fps': fps,
      };

      if (image != null) input['image'] = image;
      if (lastFrameImage != null) input['last_frame_image'] = lastFrameImage;
      if (referenceImages != null && referenceImages.isNotEmpty) {
        input['reference_images'] = referenceImages;
      }
      if (seed != null) input['seed'] = seed;

      request.add(utf8.encode(jsonEncode({'input': input})));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        throw Exception('Replicate video error ${response.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      final output = decoded['output'];

      if (output is List && output.isNotEmpty) {
        return output.first as String;
      } else if (output is String) {
        return output;
      } else {
        throw Exception('No video URL in Replicate response');
      }
    } finally {
      client.close(force: true);
    }
  }
}

// ---------- Image (Stable Diffusion) ----------

class ReplicateImageClient {
  static const _endpoint = 'https://api.replicate.com/v1/predictions';
  static const _version =
      'ac732df83cea7fff18b8472768c88ad041fa750ff7682a21affe81863cbe77e4';

  const ReplicateImageClient();

  Future<String> generate({
    required String prompt,
    int width = 768,
    int height = 768,
    String scheduler = 'K_EULER',
    int? seed,
    int numOutputs = 1,
    double guidanceScale = 7.5,
    String? negativePrompt,
    int numInferenceSteps = 50,
  }) async {
    ReplicateAuth.ensureToken();

    final uri = Uri.parse(_endpoint);
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${ReplicateAuth._token}')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('Prefer', 'wait');

      final input = <String, dynamic>{
        'prompt': prompt,
        'width': width,
        'height': height,
        'scheduler': scheduler,
        'num_outputs': numOutputs,
        'guidance_scale': guidanceScale,
        'num_inference_steps': numInferenceSteps,
      };

      if (seed != null) input['seed'] = seed;
      if (negativePrompt != null && negativePrompt.isNotEmpty) {
        input['negative_prompt'] = negativePrompt;
      }

      request.add(utf8.encode(jsonEncode({
        'version': _version,
        'input': input,
      })));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        throw Exception('Replicate image error ${response.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      final output = decoded['output'];

      if (output is List && output.isNotEmpty) {
        return output.first as String;
      } else if (output is String) {
        return output;
      } else {
        throw Exception('No image URL in Replicate response');
      }
    } finally {
      client.close(force: true);
    }
  }
}

// ---------- Upscale (Real-ESRGAN) ----------

class ReplicateUpscaleClient {
  static const _endpoint =
      'https://api.replicate.com/v1/models/nightmareai/real-esrgan/predictions';

  const ReplicateUpscaleClient();

  Future<String> upscale({
    required String imageUrl,
    double scale = 4,
    bool faceEnhance = false,
  }) async {
    ReplicateAuth.ensureToken();

    final uri = Uri.parse(_endpoint);
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${ReplicateAuth._token}')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('Prefer', 'wait');

      final input = <String, dynamic>{
        'image': imageUrl,
        'scale': scale,
        'face_enhance': faceEnhance,
      };

      request.add(utf8.encode(jsonEncode({'input': input})));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        throw Exception('Replicate upscale error ${response.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      final output = decoded['output'];

      if (output is List && output.isNotEmpty) {
        return output.first as String;
      } else if (output is String) {
        return output;
      } else {
        throw Exception('No upscaled image URL in Replicate response');
      }
    } finally {
      client.close(force: true);
    }
  }
}

class ReplicateFileUploader {
  static const _endpoint = 'https://api.replicate.com/v1/files';

  const ReplicateFileUploader();

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    ReplicateAuth.ensureToken();

    final boundary = '----FreeAICreation${DateTime.now().millisecondsSinceEpoch}';
    final client = HttpClient();

    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${ReplicateAuth._token}')
        ..set(
          HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary',
        );

      final builder = BytesBuilder();
      builder.add(utf8.encode('--$boundary\r\n'));
      builder.add(utf8.encode(
          'Content-Disposition: form-data; name="content"; filename="$filename"\r\n'));
      builder.add(utf8.encode('Content-Type: $contentType\r\n\r\n'));
      builder.add(bytes);
      builder.add(utf8.encode('\r\n--$boundary--\r\n'));

      request.add(builder.takeBytes());

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        throw Exception('Replicate upload error ${response.statusCode}: $body');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final urls = decoded['urls'] as Map<String, dynamic>?;
      final url = urls?['get'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('No file URL returned by Replicate');
      }
      return url;
    } finally {
      client.close(force: true);
    }
  }
}

