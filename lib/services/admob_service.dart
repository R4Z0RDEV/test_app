// lib/services/admob_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  // 테스트용 광고 단위 ID (실제 배포시 본인의 ID로 교체해야 함)
  final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android 테스트 ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID

  // 광고 로드 상태 확인
  bool get isAdReady => _rewardedAd != null;

  // 보상형 광고 로드
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('$ad loaded.');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _numRewardedLoadAttempts += 1;
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            // 로드 실패 시 재시도
            loadRewardedAd();
          }
        },
      ),
    );
  }

  // 보상형 광고 표시 및 결과 반환 (Future<bool>)
  Future<bool> showRewardedAd(BuildContext context) async {
    if (_rewardedAd == null) {
      print('Warning: Ad not ready yet.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오는 중입니다. 잠시 후 다시 시도해주세요.')),
      );
      // 광고가 없으면 다시 로드 시도
      loadRewardedAd();
      return false;
    }

    final completer = Completer<bool>();
    bool isRewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) =>
          print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _rewardedAd = null;
        // 광고가 닫히면 다음 광고를 미리 로드
        loadRewardedAd();
        // 보상을 받았는지 여부 반환
        if (!completer.isCompleted) {
          completer.complete(isRewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      print('$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
      // 보상 획득 플래그 설정
      isRewardEarned = true;
    });

    return completer.future;
  }

  // 리소스 해제
  void dispose() {
    _rewardedAd?.dispose();
  }
}