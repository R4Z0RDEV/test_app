import 'package:flutter/material.dart';

enum AdRewardReason {
  generateVideo,
  removeVideoWatermark,
  generateImage,
  removeImageWatermark,
  upscaleImage,
}

Future<bool> showRewardAdGate(
  BuildContext context, {
  required AdRewardReason reason,
}) async {
  String title;
  String message;

  switch (reason) {
    case AdRewardReason.generateVideo:
      title = 'Watch an ad to generate video';
      message = 'To keep this app free, please watch a short rewarded ad '
          'before generating your video.';
      break;
    case AdRewardReason.removeVideoWatermark:
      title = 'Remove watermark';
      message =
          'Watch another short ad to remove the watermark from this video.';
      break;
    case AdRewardReason.generateImage:
      title = 'Watch an ad to generate image';
      message =
          'Please watch a rewarded ad before generating your image preview.';
      break;
    case AdRewardReason.removeImageWatermark:
      title = 'Remove watermark from image';
      message =
          'Watch another ad to unlock the clean image without watermark.';
      break;
    case AdRewardReason.upscaleImage:
      title = 'Watch an ad to upscale';
      message =
          'Upscaling uses extra compute. Watch a rewarded ad to continue.';
      break;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      bool isPlaying = true;
      return StatefulBuilder(builder: (context, setState) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (isPlaying && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        });

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Simulating rewarded ad...\n(Replace this with a real ads SDK later.)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      });
    },
  );

  return result ?? false;
}

